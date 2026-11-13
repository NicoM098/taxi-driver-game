extends Node3D
## Phase 01 test course, built in code so it is quick to tweak:
## ground, walls, ramp line, tabletop, hill, speed bumps, slalom, cones and mini city blocks.
## Layout (taxi spawns at origin facing -Z, the runway straight ahead is kept clear):
##   +X side: ramps (x=40), tabletop (x=80), hill (x=150)
##   -X side: speed bumps (x=-30), slalom (x=-45, behind spawn), city blocks (x<-100)

const MAT_DIR := "res://assets/materials/"
const GROUND_SIZE := 600.0

@export var rng_seed: int = 1337

var _mats: Dictionary = {}


func _ready() -> void:
	for mat_name: String in ["ground", "road", "sidewalk", "wall", "building_a", "building_b",
			"building_c", "ramp", "prop", "prop_cone"]:
		_mats[mat_name] = load(MAT_DIR + mat_name + ".tres")
	_build_environment()
	_build_ground()
	_build_walls()
	_build_ramps()
	_build_bumps_and_slalom()
	_build_cones()
	_build_city()


# --- Environment ---------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.56, 0.6, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.78)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = env.background_color
	env.fog_density = 1.0
	env.fog_depth_begin = 70.0
	env.fog_depth_end = 220.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	add_child(sun)


# --- Static geometry -------------------------------------------------------------

func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GROUND_SIZE, 2.0, GROUND_SIZE)
	shape.shape = box
	shape.position.y = -1.0
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	plane.subdivide_width = 59
	plane.subdivide_depth = 59
	mesh.mesh = plane
	mesh.material_override = _mats["ground"]
	body.add_child(mesh)
	add_child(body)


func _build_walls() -> void:
	var h := GROUND_SIZE * 0.5 + 1.0
	_add_box(Vector3(0, 3, -h), Vector3(GROUND_SIZE + 4, 6, 2), "wall")
	_add_box(Vector3(0, 3, h), Vector3(GROUND_SIZE + 4, 6, 2), "wall")
	_add_box(Vector3(-h, 3, 0), Vector3(2, 6, GROUND_SIZE + 4), "wall")
	_add_box(Vector3(h, 3, 0), Vector3(2, 6, GROUND_SIZE + 4), "wall")


func _build_ramps() -> void:
	# Ramp line (approach from +Z driving towards -Z).
	_add_ramp(Vector3(40, 0, -30), 0.0, 8.0, 6.0, 1.5)
	_add_ramp(Vector3(40, 0, -100), 0.0, 12.0, 6.0, 3.0)
	_add_ramp(Vector3(40, 0, -180), 0.0, 18.0, 8.0, 5.5)
	# Tabletop: up 3 m, 20 m flat, down.
	_add_ramp(Vector3(80, 0, -40), 0.0, 12.0, 10.0, 3.0)
	_add_box(Vector3(80, 1.5, -62), Vector3(10, 3, 20), "ramp")
	_add_ramp(Vector3(80, 0, -84), PI, 12.0, 10.0, 3.0)
	# Hill: up 6 m, 40 m plateau, down.
	_add_ramp(Vector3(150, 0, 60), 0.0, 25.0, 20.0, 6.0)
	_add_box(Vector3(150, 3, 15), Vector3(20, 6, 40), "sidewalk")
	_add_ramp(Vector3(150, 0, -30), PI, 25.0, 20.0, 6.0)


func _build_bumps_and_slalom() -> void:
	for i in 10:
		_add_box(Vector3(-30, 0.05, -30.0 - i * 7.0), Vector3(8, 0.25, 0.8), "ramp")
	for i in 11:
		var offset := 4.0 if i % 2 == 0 else -4.0
		_add_box(Vector3(-45.0 + offset, 1.5, 20.0 + i * 14.0), Vector3(1, 3, 1), "prop")


func _build_cones() -> void:
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.03
	cone_mesh.bottom_radius = 0.25
	cone_mesh.height = 0.6
	cone_mesh.radial_segments = 6
	var cone_shape := CylinderShape3D.new()
	cone_shape.radius = 0.25
	cone_shape.height = 0.6
	for row in 2:
		for i in 20:
			var cone := RigidBody3D.new()
			cone.mass = 4.0
			cone.collision_layer = 256      # props
			cone.collision_mask = 1 | 2 | 256
			cone.position = Vector3(18.0 + row * 4.0, 0.31, 20.0 + i * 5.0)
			var shape := CollisionShape3D.new()
			shape.shape = cone_shape
			cone.add_child(shape)
			var mesh := MeshInstance3D.new()
			mesh.mesh = cone_mesh
			mesh.material_override = _mats["prop_cone"]
			cone.add_child(mesh)
			add_child(cone)


func _build_city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var block := 24.0
	var street := 14.0
	var pitch := block + street
	# Dark road surface under the whole district (visual only).
	var road := MeshInstance3D.new()
	var road_mesh := PlaneMesh.new()
	road_mesh.size = Vector2(4.0 * pitch + street, 8.0 * pitch + street)
	road.mesh = road_mesh
	road.material_override = _mats["road"]
	road.position = Vector3(-100.0 - 2.0 * pitch, 0.02, 0.0)
	add_child(road)
	var styles := ["building_a", "building_b", "building_c"]
	for bx in 4:
		for bz in 8:
			var center := Vector3(-100.0 - street * 0.5 - block * 0.5 - bx * pitch, 0.0,
				-4.0 * pitch + street * 0.5 + block * 0.5 + bz * pitch)
			_add_box(center + Vector3(0, 0.1, 0), Vector3(block + 2, 0.2, block + 2), "sidewalk")
			var height := rng.randf_range(6.0, 30.0)
			_add_box(center + Vector3(0, 0.2 + height * 0.5, 0), Vector3(block - 2, height, block - 2),
				styles[rng.randi() % styles.size()])


# --- Helpers ---------------------------------------------------------------------

func _add_box(pos: Vector3, size: Vector3, mat_name: String, basis := Basis.IDENTITY) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.transform = Transform3D(basis, pos)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = _mats[mat_name]
	body.add_child(mesh)
	add_child(body)
	return body


## Ramp whose low edge sits on the ground at `start`, rising along `yaw` (0 = towards -Z).
func _add_ramp(start: Vector3, yaw: float, length: float, width: float, height: float) -> void:
	var thickness := 0.6
	var angle := atan2(height, length)
	var slope_len := sqrt(length * length + height * height)
	var ramp_basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, angle)
	var dir := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var top_mid := start + dir * (length * 0.5) + Vector3.UP * (height * 0.5)
	var center := top_mid - ramp_basis.y * (thickness * 0.5)
	_add_box(center, Vector3(width, thickness, slope_len), "ramp", ramp_basis)
