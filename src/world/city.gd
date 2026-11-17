class_name City
extends Node3D
## The playable city, built in code from a MapData (the map made in the in-game map editor,
## or the built-in starter city): ground, perimeter walls, every map piece (MapBuilder), lane
## dashes, named TaxiStops, energy drinks, repair shops, and the road graph for AI drivers.
## Everything that is not a solid piece is drivable asphalt.

const MAT_DIR := "res://assets/materials/"
## Block spacing of the built-in starter city (tests and tools that reason about its layout).
const PITCH := MapData.GEN_PITCH * MapData.CELL   # 48 m
const BORDER := 30.0

const PLACE_NAMES := {
	&"downtown": ["Grand Hotel", "City Hall", "Central Station", "Stock Exchange", "Neon Club",
		"Plaza Mall", "Opera House", "Police HQ", "Metro Bank", "Skyline Tower", "Courthouse",
		"Museum of Art"],
	&"suburbs": ["Maple St.", "Oak Avenue", "Sunny Diner", "Elm Park", "Pine Lane",
		"Willow School", "Bingo Hall", "Retirement Home", "Little League Field", "Corner Bakery",
		"Cedar Church", "Laundromat"],
	&"docks": ["Pier 7", "Warehouse 13", "Fish Market", "Container Yard", "Shipyard",
		"Customs Office", "Rusty Anchor Bar", "Lighthouse Rd.", "Cold Storage", "Dock Gate B",
		"Ferry Terminal", "Boathouse"],
}

## Used once the landmark names of a district run out ("212 Harbor Rd.").
const STREET_NAMES := {
	&"downtown": ["5th Ave.", "Main St.", "Broadway", "Union Blvd."],
	&"suburbs": ["Maple St.", "Birch Rd.", "Elm St.", "Poplar Ave."],
	&"docks": ["Harbor Rd.", "Wharf St.", "Anchor Way", "Pier Rd."],
}
const GENERIC_STREETS := ["Main St.", "Station Rd.", "Park Ave.", "Mill Lane", "High St.", "Canal St."]

## The map to build. Left null, the active map is loaded (MapData.load_active()).
var map: MapData
var stops: Array[TaxiStop] = []
var repair_shops: Array[RepairShop] = []
var gun_shops: Array[GunShop] = []
## District ids that have at least one stop.
var districts: Dictionary = {}

var _grid: AStarGrid2D = AStarGrid2D.new()
var _flags: PackedByteArray = PackedByteArray()
var _road_points: PackedVector3Array = PackedVector3Array()
## Per cell: id of the connected drivable area it belongs to (-1 = solid). A courtyard walled
## in by buildings is its own region: nothing spawned there could ever get out.
var _region: PackedInt32Array = PackedInt32Array()
var _name_index: Dictionary = {}
## Street lamps: one every LAMP_SPACING cells along a kerb (8 m cells -> one every 32 m).
const LAMP_SPACING: int = 4
const LAMP_POST_HEIGHT: float = 4.4
const LAMP_REACH: float = 0.75
const LAMP_RANGE: float = 17.0
const LAMP_MAX: int = 420

var _mood: Lighting.Mood = Lighting.DEFAULT
var _env: Environment = null
var _sun: DirectionalLight3D = null
var _lamps: Array[OmniLight3D] = []


func _ready() -> void:
	add_to_group(&"city")
	if map == null:
		map = MapData.load_active()
	_flags = map.flags()
	var lit := Blockout.add_environment(self, _mood)
	_env = lit["env"]
	_sun = lit["sun"]
	_build_ground_and_walls()
	_build_road_graph()
	_build_lane_dashes()
	_build_street_lamps()
	for p in map.pieces:
		_build_piece(p)
	var map_stops := stops.size()
	_build_curbside_stops()
	set_mood(_mood)
	print("[City] map '%s': %d x %d cells, %d pieces, %d stops (+%d curbside), %d repair shops, %d lamps (%s)" % [
		map.name, map.width, map.depth, map.pieces.size(), map_stops, stops.size() - map_stops, repair_shops.size(),
		_lamps.size(), Lighting.mood_name(_mood)])
	_place_player.call_deferred()


## Time of day. Switches the environment, the street lamps and how hard lit windows burn (D-064).
func set_mood(mood: Lighting.Mood) -> void:
	_mood = mood
	Lighting.apply(_env, _sun, mood)
	var energy := Lighting.lamp_energy(mood)
	for lamp in _lamps:
		lamp.light_energy = energy
		lamp.visible = energy > 0.0
	# The lamp's own glass has to stop glowing too, or a switched-off lamp still looks lit (D-065).
	var glow := Lighting.lamp_glow(mood)
	var head_mat := MapBuilder.mat("lamp_head") as ShaderMaterial
	if head_mat != null:
		head_mat.set_shader_parameter(&"emission_strength", glow)
	var emission := Lighting.window_emission(mood)
	var lit_amount := Lighting.window_lit_amount(mood)
	for name in [&"building_a", &"building_b", &"building_c"]:
		var mat := MapBuilder.mat(String(name)) as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter(&"window_lit_emission", emission)
			mat.set_shader_parameter(&"window_lit_amount", lit_amount)
	# Anything that owns its own lights (the taxi's headlights) listens for this.
	EventBus.mood_changed.emit(int(mood))


func mood() -> Lighting.Mood:
	return _mood


func cycle_mood() -> Lighting.Mood:
	set_mood(Lighting.next(_mood))
	return _mood


# --- Queries ---------------------------------------------------------------------

## Centre of block (i, j) of the built-in starter city.
static func block_center(i: int, j: int) -> Vector3:
	var c := MapData.gen_block_cell(i, j)
	var size := (MapData.GEN_BLOCKS * MapData.GEN_PITCH + MapData.GEN_STREET) * MapData.CELL
	var half_block := MapData.GEN_BLOCK * MapData.CELL * 0.5
	return Vector3(c.x * MapData.CELL - size * 0.5 + half_block, 0.0, c.y * MapData.CELL - size * 0.5 + half_block)


## Route for a car from `from` to `to`: the corners of the cell path + the final position.
## The first waypoint is skipped when it lies behind (already passed). With `dense` every
## cell of the path is returned (one point every ~8 m; used to pick ambush spots).
func get_route(from: Vector3, to: Vector3, dense: bool = false) -> PackedVector3Array:
	var path := PackedVector3Array()
	var a := _nearest_free(map.world_to_cell(from))
	var b := _nearest_free(map.world_to_cell(to))
	if a.x >= 0 and b.x >= 0:
		var cells := _grid.get_point_path(a, b)
		for i in cells.size():
			if not dense and i > 0 and i < cells.size() - 1:
				var before := (cells[i] - cells[i - 1]).normalized()
				var after := (cells[i + 1] - cells[i]).normalized()
				if before.dot(after) > 0.99:
					continue   # straight on: not a waypoint
			path.append(Vector3(cells[i].x, 0.0, cells[i].y))
	if path.size() >= 2 and from.distance_to(path[1]) < path[0].distance_to(path[1]):
		path.remove_at(0)
	path.append(to)
	return path


## Centres of all plain street cells (spawn candidates for enemy cars).
func road_points() -> PackedVector3Array:
	return _road_points


## Street cells a car can drive to from `from` (spawn candidates that are not walled in).
func road_points_reachable(from: Vector3) -> PackedVector3Array:
	var region := region_at(from)
	var out := PackedVector3Array()
	for p in _road_points:
		var c := map.world_to_cell(p)
		if _region[c.y * map.width + c.x] == region:
			out.append(p)
	return out


## Id of the connected drivable area around `pos` (the nearest free cell's if `pos` is solid).
func region_at(pos: Vector3) -> int:
	var c := _nearest_free(map.world_to_cell(pos))
	return _region[c.y * map.width + c.x] if c.x >= 0 else -1


## True if a car can drive from `a` to `b` (both free and in the same connected area).
func can_reach(a: Vector3, b: Vector3) -> bool:
	return is_free(a) and is_free(b) and region_at(a) == region_at(b)


## Number of free cells that cannot be reached from the biggest drivable area (map editor).
func count_cut_off_cells() -> int:
	var sizes: Dictionary = {}
	for r in _region:
		if r >= 0:
			sizes[r] = int(sizes.get(r, 0)) + 1
	var total := 0
	var biggest := 0
	for r: int in sizes:
		total += int(sizes[r])
		biggest = maxi(biggest, int(sizes[r]))
	return total - biggest


## True if `pos` is on plain street (not solid, not under any area piece such as a sidewalk).
func is_plain_street(pos: Vector3) -> bool:
	var c := map.world_to_cell(pos)
	return _plain(c.x, c.y)


## True if a car can be at `pos` (inside the map, not in a solid piece).
func is_free(pos: Vector3) -> bool:
	var c := map.world_to_cell(pos)
	return c.x >= 0 and c.y >= 0 and c.x < map.width and c.y < map.depth \
			and _flags[c.y * map.width + c.x] & MapData.F_SOLID == 0


func get_district_at(pos: Vector3) -> StringName:
	return map.district_at(map.world_to_cell(pos))


func nearest_repair_shop(pos: Vector3) -> RepairShop:
	var best: RepairShop = null
	var best_d := INF
	for shop in repair_shops:
		var d := shop.pad_position.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = shop
	return best


# --- Build -----------------------------------------------------------------------

func _build_ground_and_walls() -> void:
	var half := map.half()
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(half.x * 2.0 + BORDER * 2.0, 2.0, half.y * 2.0 + BORDER * 2.0)
	shape.shape = box
	shape.position.y = -1.0
	ground.add_child(shape)
	add_child(ground)

	var road := PlaneMesh.new()
	road.size = half * 2.0
	# ~6 m quads: the PS1 vertex snapping needs a tessellated plane, and since Iteration 09 the
	# road has a texture, so affine mapping warps it as well — the bigger the quad, the more the
	# texture swims when the camera moves (D-063). Halved from 12 m.
	road.subdivide_width = maxi(roundi(half.x * 2.0 / 6.0) - 1, 1)
	road.subdivide_depth = maxi(roundi(half.y * 2.0 / 6.0) - 1, 1)
	Blockout.add_mesh(self, road, Vector3.ZERO, MapBuilder.mat("road"))
	# Ground only AROUND the city (4 strips), never under the road: overlapping flat planes
	# z-fought at distance, made worse by PS1 vertex snapping (playtest: asphalt flicker).
	var full_x := half.x * 2.0 + BORDER * 2.0
	for strip: Array in [[Vector2(full_x, BORDER), Vector3(0, -0.05, -(half.y + BORDER * 0.5))],
			[Vector2(full_x, BORDER), Vector3(0, -0.05, half.y + BORDER * 0.5)],
			[Vector2(BORDER, half.y * 2.0), Vector3(-(half.x + BORDER * 0.5), -0.05, 0)],
			[Vector2(BORDER, half.y * 2.0), Vector3(half.x + BORDER * 0.5, -0.05, 0)]]:
		var plane := PlaneMesh.new()
		plane.size = strip[0]
		# Same reason as the road: these strips were single huge quads, the worst case for
		# affine warping (D-063).
		plane.subdivide_width = maxi(roundi(plane.size.x / 12.0) - 1, 1)
		plane.subdivide_depth = maxi(roundi(plane.size.y / 12.0) - 1, 1)
		Blockout.add_mesh(self, plane, strip[1], MapBuilder.mat("ground"))

	var wall := MapBuilder.mat("wall")
	Blockout.add_box(self, Vector3(0, 3, -(half.y + 1.0)), Vector3(half.x * 2.0 + 4.0, 6, 2), wall)
	Blockout.add_box(self, Vector3(0, 3, half.y + 1.0), Vector3(half.x * 2.0 + 4.0, 6, 2), wall)
	Blockout.add_box(self, Vector3(-(half.x + 1.0), 3, 0), Vector3(2, 6, half.y * 2.0 + 4.0), wall)
	Blockout.add_box(self, Vector3(half.x + 1.0, 3, 0), Vector3(2, 6, half.y * 2.0 + 4.0), wall)


func _build_piece(p: Dictionary) -> void:
	var type := String(p["type"])
	match type:
		"stop":
			_add_stop(p)
		"drink":
			var can := EnergyDrinkPickup.new()
			can.position = map.cell_center(int(p["x"]), int(p["z"]))
			add_child(can)
		"zone", "spawn":
			pass
		"repair", "gunshop" when ShopMenu.enabled:
			# Shop-menu mode (D-089): the shops are bought from the menu; the lot is a plain building.
			add_child(ShopMenu.build_closed_lot(map, p))
		"repair":
			add_child(MapBuilder.build_piece(map, p))
			var shop := RepairShop.new()
			var pad := MapBuilder.repair_pad(map, p)
			shop.pad_position = pad["pos"]
			shop.pad_radius = pad["radius"]
			add_child(shop)
			repair_shops.append(shop)
		"gunshop":
			add_child(MapBuilder.build_piece(map, p))
			var store := GunShop.new()
			var store_pad := MapBuilder.repair_pad(map, p)
			store.pad_position = store_pad["pos"]
			store.pad_radius = store_pad["radius"]
			add_child(store)
			gun_shops.append(store)
		_:
			add_child(MapBuilder.build_piece(map, p))


func _add_stop(p: Dictionary) -> void:
	var cell := Vector2i(int(p["x"]), int(p["z"]))
	var street := map.cell_center(cell.x, cell.y)
	var dir := MapData.DIRS[int(p["rot"])]
	var walk := street + dir * (MapData.CELL * 0.5 + 0.6)
	walk.y = _surface_height(map.world_to_cell(walk))
	var district := map.district_at(cell)
	var stop := TaxiStop.new()
	add_child(stop)
	var stop_name := String(p["name"]).strip_edges()
	stop.setup(stop_name if stop_name != "" else _next_name(district, cell), district, street, walk,
		MapBuilder.mat("beacon_green"))
	stops.append(stop)
	districts[district] = true


## Extra pick-up / drop-off points along the kerbs (user request 2026-11-15: "the drop off zones
## are always the same"). Any plain street cell next to a sidewalk, plaza or building front can be one,
## kept CURBSIDE_SPACING apart from each other and from the map's own stops and shops, and
## only in the drivable area the map's stops are in (never in a walled-in courtyard).
## A fresh random set every run (fixed in automated tests).
const CURBSIDE_SPACING: float = 44.0
const CURBSIDE_MAX: int = 90


func _build_curbside_stops() -> void:
	var rng := RandomNumberGenerator.new()
	if MapData.override != null:
		rng.seed = 1234
	else:
		rng.randomize()
	var taken: Array[Vector3] = []
	for stop in stops:
		taken.append(stop.global_position)
	for shop in repair_shops:
		taken.append(shop.pad_position)
	for shop in gun_shops:
		taken.append(shop.pad_position)
	var region := region_at(stops[0].global_position) if not stops.is_empty() else -1
	# Candidates: [cell, direction index towards the kerb].
	var candidates: Array[Array] = []
	for z in map.depth:
		for x in map.width:
			if not _plain(x, z):
				continue
			if region >= 0 and _region[z * map.width + x] != region:
				continue
			for d in 4:
				var dir := MapData.DIRS[d]
				var n := Vector2i(x + int(dir.x), z + int(dir.z))
				var idx := map.piece_at(n, false)
				if idx < 0:
					continue
				var kind := String(map.pieces[idx]["type"])
				if kind == "sidewalk" or kind == "plaza" or kind == "building":
					candidates.append([Vector2i(x, z), d])
					break
	# Shuffle (Fisher-Yates with our rng, so tests are repeatable).
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Array = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var added := 0
	for c: Array in candidates:
		if added >= CURBSIDE_MAX:
			break
		var cell: Vector2i = c[0]
		var street := map.cell_center(cell.x, cell.y)
		var too_close := false
		for t in taken:
			if Vector2(t.x - street.x, t.z - street.z).length() < CURBSIDE_SPACING:
				too_close = true
				break
		if too_close:
			continue
		var dir := MapData.DIRS[int(c[1])]
		var walk := street + dir * (MapData.CELL * 0.5 + 0.6)
		walk.y = _surface_height(map.world_to_cell(walk))
		var district := map.district_at(cell)
		var stop := TaxiStop.new()
		add_child(stop)
		stop.curbside = true
		stop.setup(_next_name(district, cell), district, street, walk, MapBuilder.mat("beacon_green"))
		stops.append(stop)
		districts[district] = true
		taken.append(street)
		added += 1


## Height a pedestrian stands at in a cell (sidewalk / plaza top / street).
func _surface_height(cell: Vector2i) -> float:
	var idx := map.piece_at(cell, false)
	if idx < 0:
		return 0.0
	var p := map.pieces[idx]
	match String(p["type"]):
		"plaza":
			return float(p["h"])
		"building", "sidewalk", "containers", "repair", "gunshop":
			return MapBuilder.CURB
	return 0.0


func _next_name(district: StringName, cell: Vector2i) -> String:
	var idx: int = _name_index.get(district, 0)
	_name_index[district] = idx + 1
	if PLACE_NAMES.has(district):
		var names: Array = PLACE_NAMES[district]
		if idx < names.size():
			return names[idx]
		var streets: Array = STREET_NAMES[district]
		return "%d %s" % [100 + (idx * 37) % 800, streets[idx % streets.size()]]
	var zone := map.zone_name_at(cell)
	if zone != "" and idx < 6:
		return "%s %s" % [zone, ["Square", "Corner", "Market", "Station", "Gate", "Cross"][idx]]
	return "%d %s" % [100 + (idx * 37) % 800, GENERIC_STREETS[idx % GENERIC_STREETS.size()]]


## Cell graph: every non-solid cell is a node (8-way, no corner cutting). Covered cells
## (plazas, sidewalks) cost more, so cars prefer the street.
func _build_road_graph() -> void:
	var half := map.half()
	_grid.region = Rect2i(0, 0, map.width, map.depth)
	_grid.cell_size = Vector2(MapData.CELL, MapData.CELL)
	_grid.offset = Vector2(-half.x + MapData.CELL * 0.5, -half.y + MapData.CELL * 0.5)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	for z in map.depth:
		for x in map.width:
			var f := _flags[z * map.width + x]
			if f & MapData.F_SOLID:
				_grid.set_point_solid(Vector2i(x, z), true)
			elif f & MapData.F_COVERED:
				_grid.set_point_weight_scale(Vector2i(x, z), 3.0)
			else:
				_road_points.append(map.cell_center(x, z))
	_build_regions()


## Flood fill over the free cells (4-way: the graph never cuts a corner between two solids).
func _build_regions() -> void:
	_region.resize(map.width * map.depth)
	_region.fill(-1)
	var next_id := 0
	for start in map.width * map.depth:
		if _region[start] >= 0 or _flags[start] & MapData.F_SOLID:
			continue
		_region[start] = next_id
		var stack: PackedInt32Array = [start]
		while not stack.is_empty():
			var cell := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			var cx := cell % map.width
			@warning_ignore("integer_division")
			var cz := cell / map.width
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := cx + d.x
				var nz := cz + d.y
				if nx < 0 or nz < 0 or nx >= map.width or nz >= map.depth:
					continue
				var n := nz * map.width + nx
				if _region[n] < 0 and _flags[n] & MapData.F_SOLID == 0:
					_region[n] = next_id
					stack.append(n)
		next_id += 1


## The free cell nearest to `cell` (itself if free); (-1, -1) if the whole map is solid.
func _nearest_free(cell: Vector2i) -> Vector2i:
	cell = cell.clamp(Vector2i.ZERO, Vector2i(map.width - 1, map.depth - 1))
	if _flags[cell.y * map.width + cell.x] & MapData.F_SOLID == 0:
		return cell
	for radius in range(1, maxi(map.width, map.depth)):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dz)) != radius:
					continue
				var c := cell + Vector2i(dx, dz)
				if c.x < 0 or c.y < 0 or c.x >= map.width or c.y >= map.depth:
					continue
				if _flags[c.y * map.width + c.x] & MapData.F_SOLID == 0 and Vector2(dx, dz).length() < best_d:
					best_d = Vector2(dx, dz).length()
					best = c
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


func _plain(x: int, z: int) -> bool:
	return x >= 0 and z >= 0 and x < map.width and z < map.depth and _flags[z * map.width + x] == 0


## Dashed centre lines wherever a street is exactly two cells wide (one MultiMesh = one draw
## call): between two plain cells whose outer neighbours are not street.
func _build_lane_dashes() -> void:
	var dash := BoxMesh.new()
	dash.size = Vector3(0.5, 0.03, 3.0)  # wide enough to stay visible at 240p
	var xforms: Array[Transform3D] = []
	var turned := Basis(Vector3.UP, PI * 0.5)
	for z in map.depth:
		for x in map.width:
			if not _plain(x, z):
				continue
			var corner := map.cell_corner(x, z)
			# North-south street: this cell and its east neighbour, walled in on both sides.
			if _plain(x + 1, z) and not _plain(x - 1, z) and not _plain(x + 2, z):
				xforms.append(Transform3D(Basis.IDENTITY, corner + Vector3(MapData.CELL, 0.06, MapData.CELL * 0.5)))
			# East-west street: this cell and its south neighbour.
			if _plain(x, z + 1) and not _plain(x, z - 1) and not _plain(x, z + 2):
				xforms.append(Transform3D(turned, corner + Vector3(MapData.CELL * 0.5, 0.06, MapData.CELL)))
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = dash
	mm.instance_count = xforms.size()
	for idx in xforms.size():
		mm.set_instance_transform(idx, xforms[idx])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = MapBuilder.mat("lane_marking")
	add_child(mmi)


## Street lamps along the kerbs (D-064). Visual only — no collision, like the lane dashes, so
## nothing about driving, routing or the autotests changes. Posts and heads are one MultiMesh
## each (two draw calls); only the omni lights are real nodes, and they carry no shadows.
func _build_street_lamps() -> void:
	var post_xforms: Array[Transform3D] = []
	var head_xforms: Array[Transform3D] = []
	var lights: Array[Vector3] = []
	for z in map.depth:
		for x in map.width:
			if not _plain(x, z) or post_xforms.size() >= LAMP_MAX:
				continue
			# A lamp stands where a drivable cell meets something built, every LAMP_SPACING
			# cells along that kerb.
			var dir := Vector2i.ZERO
			if not _plain(x - 1, z) and z % LAMP_SPACING == 0:
				dir = Vector2i(-1, 0)
			elif not _plain(x + 1, z) and z % LAMP_SPACING == 0:
				dir = Vector2i(1, 0)
			elif not _plain(x, z - 1) and x % LAMP_SPACING == 0:
				dir = Vector2i(0, -1)
			elif not _plain(x, z + 1) and x % LAMP_SPACING == 0:
				dir = Vector2i(0, 1)
			if dir == Vector2i.ZERO:
				continue
			var out := Vector3(dir.x, 0.0, dir.y)
			var base := map.cell_center(x, z) + out * (MapData.CELL * 0.5 - 0.5)
			base.y = 0.0
			post_xforms.append(Transform3D(Basis.IDENTITY,
					base + Vector3(0, LAMP_POST_HEIGHT * 0.5, 0)))
			# The head leans out over the road, away from the building.
			var head := base + Vector3(0, LAMP_POST_HEIGHT, 0) - out * LAMP_REACH
			var turn := Basis(Vector3.UP, PI * 0.5) if dir.x != 0 else Basis.IDENTITY
			head_xforms.append(Transform3D(turn, head))
			lights.append(head - Vector3(0, 0.25, 0))
	if post_xforms.is_empty():
		return

	var post := BoxMesh.new()
	post.size = Vector3(0.22, LAMP_POST_HEIGHT, 0.22)
	_add_multimesh(post, post_xforms, MapBuilder.mat("lamp_post"))
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.5, 0.22, LAMP_REACH * 2.0)
	_add_multimesh(head_mesh, head_xforms, MapBuilder.mat("lamp_head"))

	for pos in lights:
		var omni := OmniLight3D.new()
		omni.position = pos
		omni.omni_range = LAMP_RANGE
		omni.omni_attenuation = 1.4
		omni.light_color = Lighting.LAMP_COLOR
		omni.light_energy = Lighting.lamp_energy(_mood)
		omni.shadow_enabled = false
		add_child(omni)
		_lamps.append(omni)


func _add_multimesh(mesh: Mesh, xforms: Array[Transform3D], mat: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for idx in xforms.size():
		mm.set_instance_transform(idx, xforms[idx])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)


## Puts the player's taxi on the map's start point (the scene places it at the origin).
func _place_player() -> void:
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
	if taxi == null or not is_ancestor_of_world(taxi):
		return
	var spawn := map.spawn_point()
	var pos: Vector3 = spawn["pos"]
	if Vector2(taxi.global_position.x - pos.x, taxi.global_position.z - pos.z).length() < 0.5 and int(spawn["rot"]) == 0:
		return
	taxi.teleport(Transform3D(Basis.looking_at(MapData.DIRS[int(spawn["rot"])], Vector3.UP), pos + Vector3(0, 1.2, 0)))


## Only move a taxi that lives in the same world as this city (tests build bare cities).
func is_ancestor_of_world(node: Node) -> bool:
	return get_parent() != null and get_parent().is_ancestor_of(node)
