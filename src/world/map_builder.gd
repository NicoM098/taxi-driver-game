class_name MapBuilder
extends RefCounted
## Turns MapData pieces into blockout geometry. Used by the City (game) and by the map editor
## (same geometry + markers for the things that are invisible or scripted in the game: stops,
## energy drinks, zones, the player start).
##
## Every piece is built in LOCAL space under one Node3D placed at the centre of its footprint
## and turned by its `rot`: local -Z is the piece's "front" (the way stairs / ramps rise, the
## side a repair shop's pad is on). `size` below = footprint in metres as seen in local space.

const MAT_DIR := "res://assets/materials/"
const CURB := 0.2            # sidewalk height
const STEP_HEIGHT := 0.2     # low stairs: rise per step
const STEP_RUN := 0.6        # plaza steps: depth per step

static var _mats: Dictionary = {}
static var _flat_mats: Dictionary = {}


static func mat(mat_name: String) -> Material:
	if not _mats.has(mat_name):
		var path := MAT_DIR + mat_name + ".tres"
		_mats[mat_name] = load(path) if ResourceLoader.exists(path) else load(MAT_DIR + "building_a.tres")
	return _mats[mat_name]


## Footprint of a piece in its own (rotated) space: x = width, y = length along local Z.
static func local_size(p: Dictionary) -> Vector2:
	var w := int(p["w"]) * MapData.CELL
	var d := int(p["d"]) * MapData.CELL
	return Vector2(w, d) if int(p["rot"]) % 2 == 0 else Vector2(d, w)


static func yaw_of(rot: int) -> float:
	return -rot * PI * 0.5


## Builds one piece. `editor` adds markers for stops / drinks / zones / spawn (the game creates
## its own nodes for those).
static func build_piece(map: MapData, p: Dictionary, editor: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "%s_%d_%d" % [p["type"], p["x"], p["z"]]
	root.position = map.piece_center(p)
	root.rotation.y = yaw_of(int(p["rot"]))
	var size := local_size(p)
	var h := float(p["h"])
	match String(p["type"]):
		"building":
			_building(root, size, h, String(p["shape"]), mat(String(p["mat"])))
		"plaza":
			_plaza(root, size, h, String(p["shape"]))
		"stairs":
			_stairs(root, size, h)
		"ramp":
			_ramp(root, size, h, String(p["shape"]))
		"sidewalk":
			Blockout.add_box(root, Vector3(0, h * 0.5, 0), Vector3(size.x, h, size.y), mat("sidewalk"))
		"containers":
			_containers(root, size, int(round(h)), hash(Vector2i(int(p["x"]), int(p["z"]))))
		"pillar":
			Blockout.add_box(root, Vector3(0, h * 0.5, 0), Vector3(1.2, h, 1.2), mat("prop"))
		"repair":
			_repair(root, size, h)
		"stop":
			if editor:
				_stop_marker(root)
		"drink":
			if editor:
				_marker_cylinder(root, 0.9, 3.0, Color(0.95, 0.95, 0.95), 1.6)
		"spawn":
			if editor:
				_spawn_marker(root)
		"zone":
			if editor:
				_zone_marker(root, size, String(p["id"]), String(p["name"]))
	return root


## Where the taxi has to stop to get repaired (global, y = 0) and how close.
static func repair_pad(map: MapData, p: Dictionary) -> Dictionary:
	var size := local_size(p)
	var local := Vector3(0, 0, -size.y * 0.25)
	var pos := map.piece_center(p) + Basis(Vector3.UP, yaw_of(int(p["rot"]))) * local
	return {"pos": pos, "radius": maxf(minf(size.x, size.y * 0.5) * 0.5, 4.0)}


# --- Buildings ------------------------------------------------------------------------

static func _building(root: Node3D, size: Vector2, h: float, shape: String, m: Material) -> void:
	Blockout.add_box(root, Vector3(0, CURB * 0.5, 0), Vector3(size.x, CURB, size.y), mat("sidewalk"))
	var margin := 1.5 if minf(size.x, size.y) > MapData.CELL else 1.0
	var w := size.x - margin * 2.0
	var l := size.y - margin * 2.0
	var y0 := CURB
	match shape:
		"tower":   # setback crown
			Blockout.add_box(root, Vector3(0, y0 + h * 0.5, 0), Vector3(w, h, l), m)
			var crown := maxf(h * 0.25, 3.0)
			Blockout.add_box(root, Vector3(0, y0 + h + crown * 0.5, 0), Vector3(w * 0.6, crown, l * 0.6), m)
		"stepped":   # three tiers
			var y := y0
			for tier: Array in [[1.0, 0.45], [0.72, 0.3], [0.45, 0.25]]:
				var th := h * float(tier[1])
				Blockout.add_box(root, Vector3(0, y + th * 0.5, 0), Vector3(w * float(tier[0]), th, l * float(tier[0])), m)
				y += th
		"l_shape":   # a bar along the back + a lower wing towards the front-left
			Blockout.add_box(root, Vector3(0, y0 + h * 0.5, l * 0.25), Vector3(w, h, l * 0.5), m)
			var wing := maxf(h * 0.6, 2.0)
			Blockout.add_box(root, Vector3(-w * 0.25, y0 + wing * 0.5, -l * 0.25), Vector3(w * 0.5, wing, l * 0.5), m)
		"round":
			_cylinder(root, Vector3(0, y0 + h * 0.5, 0), minf(w, l) * 0.5, h, m)
		"house":   # box + pitched roof (ridge along local Z)
			Blockout.add_box(root, Vector3(0, y0 + h * 0.5, 0), Vector3(w, h, l), m)
			var roof := PrismMesh.new()
			var rh := clampf(h * 0.45, 1.5, 5.0)
			roof.size = Vector3(w + 0.6, rh, l + 0.6)
			Blockout.add_mesh(root, roof, Vector3(0, y0 + h + rh * 0.5, 0), mat("prop"))
		_:
			Blockout.add_box(root, Vector3(0, y0 + h * 0.5, 0), Vector3(w, h, l), m)


static func _cylinder(root: Node3D, pos: Vector3, radius: float, height: float, m: Material) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	body.add_child(col)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	Blockout.add_mesh(body, mesh, Vector3.ZERO, m)
	root.add_child(body)


# --- Plazas, stairs, ramps ------------------------------------------------------------

## "steps": a raised plaza with low stairs all the way round (drivable from every side).
## "flat": a sheer platform (reach the top with stairs / wedge ramps placed next to it).
static func _plaza(root: Node3D, size: Vector2, h: float, shape: String) -> void:
	var m := mat("sidewalk")
	if shape == "flat":
		Blockout.add_box(root, Vector3(0, h * 0.5, 0), Vector3(size.x, h, size.y), m)
		return
	var steps := maxi(roundi(h / STEP_HEIGHT), 1)
	var sh := h / steps
	# Keep at least a third of the plaza flat on top.
	var run := minf(STEP_RUN, minf(size.x, size.y) / 3.0 / steps)
	for k in steps:
		var box := BoxMesh.new()
		box.size = Vector3(size.x - 2.0 * k * run, sh, size.y - 2.0 * k * run)
		Blockout.add_mesh(root, box, Vector3(0, sh * (k + 0.5), 0), m if k % 2 == 0 else mat("ground"))
	# Collision: one smooth truncated pyramid, so wheels roll up the steps instead of hitting them.
	var top := Vector2(size.x * 0.5 - (steps - 0.5) * run, size.y * 0.5 - (steps - 0.5) * run)
	var pts := PackedVector3Array()
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * size.x * 0.5, 0.0, sz * size.y * 0.5))
			pts.append(Vector3(sx * top.x, h, sz * top.y))
			pts.append(Vector3(sx * size.x * 0.5, -0.5, sz * size.y * 0.5))
	_convex(root, pts)


## A straight flight of low steps rising towards local -Z (wheels get a smooth wedge).
static func _stairs(root: Node3D, size: Vector2, h: float) -> void:
	var steps := maxi(roundi(h / STEP_HEIGHT), 1)
	var sh := h / steps
	var run := size.y / steps
	for k in steps:
		var box := BoxMesh.new()
		box.size = Vector3(size.x - 0.4, sh * (k + 1), run)
		Blockout.add_mesh(root, box, Vector3(0, sh * (k + 1) * 0.5, size.y * 0.5 - run * (k + 0.5)),
			mat("sidewalk") if k % 2 == 0 else mat("ground"))
	_convex(root, _wedge_points(size.x - 0.4, size.y, h))


static func _ramp(root: Node3D, size: Vector2, h: float, shape: String) -> void:
	if shape == "wedge":   # solid, full width: the way up to a platform
		var prism := PrismMesh.new()
		prism.left_to_right = 0.0
		prism.size = Vector3(size.y, h, size.x - 0.4)
		var mesh := Blockout.add_mesh(root, prism, Vector3(0, h * 0.5, 0), mat("ramp"))
		mesh.rotation.y = -PI * 0.5   # high edge towards local -Z
		_convex(root, _wedge_points(size.x - 0.4, size.y, h))
	else:   # kicker: a thin jump ramp, open underneath at the high end
		Blockout.add_ramp(root, Vector3(0, 0, size.y * 0.5), 0.0, size.y, size.x - 1.0, h, mat("ramp"))


## Right-angled wedge: low edge at +Z, `h` high at -Z.
static func _wedge_points(w: float, l: float, h: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for sx: float in [-0.5, 0.5]:
		pts.append(Vector3(sx * w, -0.5, l * 0.5))
		pts.append(Vector3(sx * w, 0.0, l * 0.5))
		pts.append(Vector3(sx * w, -0.5, -l * 0.5))
		pts.append(Vector3(sx * w, h, -l * 0.5))
	return pts


static func _convex(root: Node3D, points: PackedVector3Array) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	col.shape = shape
	body.add_child(col)
	root.add_child(body)


# --- Props ----------------------------------------------------------------------------

## Rows of shipping containers (2.6 x 2.6 x 6 m), stacked up to `levels` high.
static func _containers(root: Node3D, size: Vector2, levels: int, piece_seed: int) -> void:
	Blockout.add_box(root, Vector3(0, CURB * 0.5, 0), Vector3(size.x, CURB, size.y), mat("sidewalk"))
	var colors: Array[String] = ["container_red", "container_blue", "container_green"]
	var cols := maxi(floori((size.x - 1.0) / 3.4), 1)
	var rows := maxi(floori((size.y - 1.0) / 6.6), 1)
	var n := 0
	for r in rows:
		for c in cols:
			var x := (c - (cols - 1) * 0.5) * 3.4
			var z := (r - (rows - 1) * 0.5) * 6.6
			var roll := absi(hash(Vector3i(piece_seed, r, c)))
			if roll % 5 == 0:
				continue   # a gap
			for level in 1 + (roll / 7) % maxi(levels, 1):
				Blockout.add_box(root, Vector3(x, CURB + 1.3 + level * 2.6, z), Vector3(2.6, 2.6, 6.0),
					mat(colors[(roll / 11 + level + n) % colors.size()]))
			n += 1


## Garage on the back half, a marked pad on the front half (local -Z): stop on the pad.
static func _repair(root: Node3D, size: Vector2, h: float) -> void:
	Blockout.add_box(root, Vector3(0, CURB * 0.5, size.y * 0.25), Vector3(size.x, CURB, size.y * 0.5), mat("sidewalk"))
	var gw := size.x - 2.0
	var gl := size.y * 0.5 - 2.0
	Blockout.add_box(root, Vector3(0, CURB + h * 0.5, size.y * 0.25), Vector3(gw, h, gl), mat("building_c"))
	# Roller door + sign on the front wall, wrench-red stripe along the roof.
	var door := BoxMesh.new()
	door.size = Vector3(minf(gw * 0.55, 7.0), minf(h - 1.2, 3.6), 0.2)
	Blockout.add_mesh(root, door, Vector3(0, CURB + door.size.y * 0.5, size.y * 0.25 - gl * 0.5 - 0.05), mat("taxi_black"))
	var stripe := BoxMesh.new()
	stripe.size = Vector3(gw + 0.4, 1.0, gl + 0.4)
	# Red roof cap (0.05 above the roof: no z-fighting, visible from the street and from above).
	Blockout.add_mesh(root, stripe, Vector3(0, CURB + h - 0.45, size.y * 0.25), mat("siren_red"))
	# The pad (visual only: it lies on the asphalt).
	var pad := BoxMesh.new()
	pad.size = Vector3(minf(gw, size.x - 3.0), 0.06, size.y * 0.5 - 2.0)
	Blockout.add_mesh(root, pad, Vector3(0, 0.05, -size.y * 0.25), mat("taxi_yellow"))
	var inner := BoxMesh.new()
	inner.size = Vector3(pad.size.x - 1.2, 0.07, pad.size.z - 1.2)
	Blockout.add_mesh(root, inner, Vector3(0, 0.06, -size.y * 0.25), mat("road"))
	# Tall sign post at the front-left corner of the garage.
	var post_pos := Vector3(-gw * 0.5 + 0.5, 0, size.y * 0.25 - gl * 0.5 - 0.6)
	Blockout.add_box(root, post_pos + Vector3(0, 5.0, 0), Vector3(0.5, 10.0, 0.5), mat("prop"))
	var board := BoxMesh.new()
	board.size = Vector3(3.2, 1.8, 0.5)
	Blockout.add_mesh(root, board, post_pos + Vector3(1.2, 10.4, 0), mat("siren_red"))


# --- Editor markers -------------------------------------------------------------------

static func flat_mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _flat_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_flat_mats[key] = m
	return _flat_mats[key]


static func _marker_cylinder(root: Node3D, radius: float, height: float, color: Color, y: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	Blockout.add_mesh(root, mesh, Vector3(0, y, 0), flat_mat(color))


## Green disc where the taxi stops + a figure where the passenger waits (local -Z).
static func _stop_marker(root: Node3D) -> void:
	_marker_cylinder(root, 3.2, 0.12, Color(0.2, 0.95, 0.35), 0.1)
	var person := BoxMesh.new()
	person.size = Vector3(0.7, 1.8, 0.7)
	Blockout.add_mesh(root, person, Vector3(0, 1.1, -4.6), flat_mat(Color(1.0, 0.85, 0.1)))
	var link := BoxMesh.new()
	link.size = Vector3(0.3, 0.1, 3.0)
	Blockout.add_mesh(root, link, Vector3(0, 0.15, -3.0), flat_mat(Color(0.2, 0.95, 0.35)))


## Taxi-sized box with a nose showing the start direction (local -Z).
static func _spawn_marker(root: Node3D) -> void:
	var body := BoxMesh.new()
	body.size = Vector3(1.9, 1.2, 4.4)
	Blockout.add_mesh(root, body, Vector3(0, 0.8, 0), flat_mat(Color(1.0, 0.8, 0.1)))
	var nose := PrismMesh.new()
	nose.size = Vector3(2.4, 2.4, 0.4)
	var n := Blockout.add_mesh(root, nose, Vector3(0, 0.3, -3.6), flat_mat(Color(1.0, 0.45, 0.1)))
	n.rotation.x = -PI * 0.5


static func zone_color(id: String) -> Color:
	var presets := {"suburbs": Color(0.3, 0.8, 0.35), "downtown": Color(0.3, 0.55, 1.0), "docks": Color(1.0, 0.55, 0.15)}
	if presets.has(id):
		return presets[id]
	return Color.from_hsv(float(absi(hash(id)) % 360) / 360.0, 0.75, 1.0)


static func _zone_marker(root: Node3D, size: Vector2, id: String, zone_name: String) -> void:
	var color := zone_color(id)
	var quad := PlaneMesh.new()
	quad.size = size - Vector2(0.6, 0.6)
	Blockout.add_mesh(root, quad, Vector3(0, 0.03, 0), flat_mat(Color(color, 0.1)))
	# Outline.
	for edge: Array in [[Vector3(0, 0.05, -size.y * 0.5 + 0.3), Vector3(size.x, 0.1, 0.6)],
			[Vector3(0, 0.05, size.y * 0.5 - 0.3), Vector3(size.x, 0.1, 0.6)],
			[Vector3(-size.x * 0.5 + 0.3, 0.05, 0), Vector3(0.6, 0.1, size.y)],
			[Vector3(size.x * 0.5 - 0.3, 0.05, 0), Vector3(0.6, 0.1, size.y)]]:
		var bar := BoxMesh.new()
		bar.size = edge[1]
		Blockout.add_mesh(root, bar, edge[0], flat_mat(Color(color, 0.8)))
	var label := Label3D.new()
	label.text = zone_name if zone_name != "" else (id if id != "" else "(zone without id)")
	label.font_size = 96
	label.pixel_size = 0.05
	label.modulate = color
	label.outline_size = 24
	label.rotation.x = -PI * 0.5
	label.position = Vector3(0, 0.4, -size.y * 0.5 + 4.0)
	label.no_depth_test = true
	root.add_child(label)
