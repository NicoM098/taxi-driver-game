class_name Blockout
extends RefCounted
## Static helpers to build blockout geometry and the default PS1 environment in code.


static func add_environment(parent: Node) -> void:
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
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	parent.add_child(sun)


## Static box with collision (layer `world`).
static func add_box(parent: Node, pos: Vector3, size: Vector3, mat: Material,
		basis: Basis = Basis.IDENTITY) -> StaticBody3D:
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
	mesh.material_override = mat
	body.add_child(mesh)
	parent.add_child(body)
	return body


## Ramp whose low edge sits at `start`, rising along `yaw` (0 = towards -Z, PI/2 = towards -X).
static func add_ramp(parent: Node, start: Vector3, yaw: float, length: float, width: float,
		height: float, mat: Material) -> StaticBody3D:
	var thickness := 0.6
	var angle := atan2(height, length)
	var slope_len := sqrt(length * length + height * height)
	var ramp_basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, angle)
	var dir := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var top_mid := start + dir * (length * 0.5) + Vector3.UP * (height * 0.5)
	var center := top_mid - ramp_basis.y * (thickness * 0.5)
	return add_box(parent, center, Vector3(width, thickness, slope_len), mat, ramp_basis)


## Visual-only mesh.
static func add_mesh(parent: Node, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = mat
	parent.add_child(instance)
	return instance
