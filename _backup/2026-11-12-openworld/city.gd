class_name City
extends Node3D
## Phase 02 blockout city, built in code:
## 8x8 blocks in 3 districts (columns 0-2 suburbs / 3-5 downtown / 6-7 docks), 16 m streets,
## a plaza with a kicker, street ramps, lane dashes, perimeter walls, and named TaxiStops
## (pickup / drop-off points) on the north and east side of every block.
## Street intersection (0,0) is the city centre; the taxi spawns there facing -Z.

const MAT_DIR := "res://assets/materials/"
const BLOCKS := 8
const BLOCK := 30.0
const STREET := 16.0
const PITCH := BLOCK + STREET
const HALF := (BLOCKS * PITCH + STREET) * 0.5   # 192 m
const PLAZA := Vector2i(4, 3)

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

@export var rng_seed: int = 4242
@export var energy_drink_count: int = 12

var stops: Array[TaxiStop] = []
## Road graph for AI drivers: one point per street intersection (9x9), linked to its 4 neighbours.
var road_graph: AStar3D = AStar3D.new()

var _mats: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _name_index: Dictionary = {}


func _ready() -> void:
	add_to_group(&"city")
	_rng.seed = rng_seed
	for mat_name: String in ["ground", "road", "sidewalk", "wall", "building_a", "building_b",
			"building_c", "ramp", "prop", "lane_marking", "container_red", "container_blue",
			"container_green", "beacon_green"]:
		_mats[mat_name] = load(MAT_DIR + mat_name + ".tres")
	Blockout.add_environment(self)
	_build_ground_and_walls()
	_build_lane_dashes()
	for i in BLOCKS:
		for j in BLOCKS:
			_build_block(i, j)
	_build_street_ramps()
	_build_road_graph()
	_place_energy_drinks()


# --- Queries ---------------------------------------------------------------------

static func district_of_column(i: int) -> StringName:
	if i <= 2:
		return &"suburbs"
	if i <= 5:
		return &"downtown"
	return &"docks"


static func block_center(i: int, j: int) -> Vector3:
	return Vector3(-HALF + STREET + BLOCK * 0.5 + i * PITCH, 0.0, -HALF + STREET + BLOCK * 0.5 + j * PITCH)


static func street_center(k: int) -> float:
	return -HALF + STREET * 0.5 + k * PITCH


## Route along the streets from `from` to `to`: intersection waypoints + the final position.
## The first waypoint is skipped when it lies behind (already passed).
func get_route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := road_graph.get_closest_point(from)
	var b := road_graph.get_closest_point(to)
	var path := road_graph.get_point_path(a, b)
	if path.size() >= 2 and from.distance_to(path[1]) < path[0].distance_to(path[1]):
		path.remove_at(0)
	path.append(to)
	return path


func road_points() -> PackedVector3Array:
	var pts := PackedVector3Array()
	for id in road_graph.get_point_ids():
		pts.append(road_graph.get_point_position(id))
	return pts


func get_district_at(pos: Vector3) -> StringName:
	return district_of_column(clampi(floori((pos.x + HALF - STREET * 0.5) / PITCH), 0, BLOCKS - 1))


# --- Build -----------------------------------------------------------------------

func _build_ground_and_walls() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HALF * 2.0 + 60.0, 2.0, HALF * 2.0 + 60.0)
	shape.shape = box
	shape.position.y = -1.0
	ground.add_child(shape)
	add_child(ground)

	var road := PlaneMesh.new()
	road.size = Vector2(HALF * 2.0, HALF * 2.0)
	road.subdivide_width = 31
	road.subdivide_depth = 31
	Blockout.add_mesh(self, road, Vector3.ZERO, _mats["road"])
	# Ground only AROUND the city (4 strips), never under the road: overlapping flat planes
	# z-fought at distance, made worse by PS1 vertex snapping (playtest: asphalt flicker).
	var border := 30.0
	var full := HALF * 2.0 + border * 2.0
	for strip: Array in [[Vector2(full, border), Vector3(0, -0.05, -(HALF + border * 0.5))],
			[Vector2(full, border), Vector3(0, -0.05, HALF + border * 0.5)],
			[Vector2(border, HALF * 2.0), Vector3(-(HALF + border * 0.5), -0.05, 0)],
			[Vector2(border, HALF * 2.0), Vector3(HALF + border * 0.5, -0.05, 0)]]:
		var plane := PlaneMesh.new()
		plane.size = strip[0]
		Blockout.add_mesh(self, plane, strip[1], _mats["ground"])

	var w := HALF + 1.0
	var length := HALF * 2.0 + 4.0
	Blockout.add_box(self, Vector3(0, 3, -w), Vector3(length, 6, 2), _mats["wall"])
	Blockout.add_box(self, Vector3(0, 3, w), Vector3(length, 6, 2), _mats["wall"])
	Blockout.add_box(self, Vector3(-w, 3, 0), Vector3(2, 6, length), _mats["wall"])
	Blockout.add_box(self, Vector3(w, 3, 0), Vector3(2, 6, length), _mats["wall"])


## Dashed centre lines on every street segment (one MultiMesh = one draw call).
func _build_lane_dashes() -> void:
	var dash := BoxMesh.new()
	dash.size = Vector3(0.5, 0.03, 3.0)  # wide enough to stay visible at 240p
	var xforms: Array[Transform3D] = []
	var along := [-10.0, 0.0, 10.0]
	for k in BLOCKS + 1:
		for seg in BLOCKS:
			var mid := -HALF + STREET + BLOCK * 0.5 + seg * PITCH
			for d: float in along:
				# North-south streets (dash along Z) and east-west streets (dash along X).
				xforms.append(Transform3D(Basis.IDENTITY, Vector3(street_center(k), 0.06, mid + d)))
				xforms.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(mid + d, 0.06, street_center(k))))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = dash
	mm.instance_count = xforms.size()
	for idx in xforms.size():
		mm.set_instance_transform(idx, xforms[idx])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mats["lane_marking"]
	add_child(mmi)


func _build_block(i: int, j: int) -> void:
	var c := block_center(i, j)
	var district := district_of_column(i)
	Blockout.add_box(self, c + Vector3(0, 0.1, 0), Vector3(BLOCK + 2.0, 0.2, BLOCK + 2.0), _mats["sidewalk"])
	if Vector2i(i, j) == PLAZA:
		_build_plaza(c)
	else:
		match district:
			&"suburbs":
				_build_houses(c)
			&"downtown":
				_build_tower(c)
			_:
				_build_docks_block(c)
	_add_stops(c, district)


func _build_houses(c: Vector3) -> void:
	for ox: float in [-7.5, 7.5]:
		for oz: float in [-7.5, 7.5]:
			var h := _rng.randf_range(4.0, 8.0)
			var mat_name: String = ["building_a", "building_c"][_rng.randi() % 2]
			Blockout.add_box(self, c + Vector3(ox, 0.2 + h * 0.5, oz), Vector3(9, h, 9), _mats[mat_name])


func _build_tower(c: Vector3) -> void:
	var h := _rng.randf_range(20.0, 60.0)
	var mat_name: String = ["building_a", "building_b", "building_b"][_rng.randi() % 3]
	var size := BLOCK - 4.0
	Blockout.add_box(self, c + Vector3(0, 0.2 + h * 0.5, 0), Vector3(size, h, size), _mats[mat_name])
	if _rng.randf() < 0.5:  # setback crown
		var h2 := _rng.randf_range(6.0, 16.0)
		Blockout.add_box(self, c + Vector3(0, 0.2 + h + h2 * 0.5, 0), Vector3(size * 0.6, h2, size * 0.6), _mats[mat_name])


func _build_docks_block(c: Vector3) -> void:
	var h := _rng.randf_range(8.0, 12.0)
	Blockout.add_box(self, c + Vector3(0, 0.2 + h * 0.5, -4.0), Vector3(BLOCK - 4.0, h, BLOCK - 12.0), _mats["building_c"])
	var colors: Array[String] = ["container_red", "container_blue", "container_green"]
	for n in _rng.randi_range(3, 5):
		var x := -10.5 + n * 5.0
		var stack := _rng.randi_range(1, 2)
		for level in stack:
			Blockout.add_box(self, c + Vector3(x, 0.2 + 1.3 + level * 2.6, 10.0), Vector3(2.6, 2.6, 6.0),
				_mats[colors[_rng.randi() % colors.size()]])


func _build_plaza(c: Vector3) -> void:
	Blockout.add_ramp(self, c + Vector3(0, 0.2, 9.0), 0.0, 8.0, 6.0, 1.8, _mats["ramp"])
	for ox: float in [-10.0, 10.0]:
		for oz: float in [-10.0, 10.0]:
			Blockout.add_box(self, c + Vector3(ox, 1.7, oz), Vector3(1.2, 3.0, 1.2), _mats["prop"])


func _build_street_ramps() -> void:
	var mat: Material = _mats["ramp"]
	# North-south streets (rise towards -Z): (street k, block row j)
	for kj: Vector2i in [Vector2i(2, 5), Vector2i(6, 2), Vector2i(4, 6)]:
		var z := block_center(0, kj.y).z
		Blockout.add_ramp(self, Vector3(street_center(kj.x), 0.0, z + 5.0), 0.0, 10.0, 7.0, 2.2, mat)
	# East-west streets (rise towards -X): (street m, block column i)
	for mi: Vector2i in [Vector2i(3, 1), Vector2i(5, 6), Vector2i(2, 4)]:
		var x := block_center(mi.y, 0).x
		Blockout.add_ramp(self, Vector3(x + 5.0, 0.0, street_center(mi.x)), PI * 0.5, 10.0, 7.0, 2.2, mat)


func _build_road_graph() -> void:
	var n := BLOCKS + 1
	for k in n:
		for m in n:
			road_graph.add_point(k * n + m, Vector3(street_center(k), 0.0, street_center(m)))
	for k in n:
		for m in n:
			if k + 1 < n:
				road_graph.connect_points(k * n + m, (k + 1) * n + m)
			if m + 1 < n:
				road_graph.connect_points(k * n + m, k * n + m + 1)


## Monstrous Energy cans float over random intersections (not the spawn one).
func _place_energy_drinks() -> void:
	var points := road_points()
	var order := range(points.size())
	for i in range(order.size() - 1, 0, -1):   # seeded shuffle
		var j := _rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	var placed := 0
	for idx: int in order:
		if placed >= energy_drink_count:
			break
		var p := points[idx]
		if p.length() < 30.0:
			continue
		var can := EnergyDrinkPickup.new()
		can.position = p
		add_child(can)
		placed += 1


func _add_stops(c: Vector3, district: StringName) -> void:
	var curb := BLOCK * 0.5 + 1.0
	for side: Vector3 in [Vector3(0, 0, -1), Vector3(1, 0, 0)]:
		var stop := TaxiStop.new()
		add_child(stop)
		stop.setup(_next_name(district), district, c + side * (curb + 3.0),
			c + side * (curb - 0.8) + Vector3(0, 0.2, 0), _mats["beacon_green"])
		stops.append(stop)


func _next_name(district: StringName) -> String:
	var names: Array = PLACE_NAMES[district]
	var idx: int = _name_index.get(district, 0)
	_name_index[district] = idx + 1
	if idx < names.size():
		return names[idx]
	var streets: Array = STREET_NAMES[district]
	return "%d %s" % [100 + (idx * 37) % 800, streets[idx % streets.size()]]
