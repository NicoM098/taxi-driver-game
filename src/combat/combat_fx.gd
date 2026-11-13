class_name CombatFx
extends RefCounted
## Short-lived placeholder combat effects (PS1 blockout style): tracers, impacts.

const TRACER_MAT := "res://assets/materials/fx_tracer.tres"
const IMPACT_MAT := "res://assets/materials/fx_impact.tres"


static func tracer(parent: Node, from: Vector3, to: Vector3, life: float = 0.05) -> void:
	var length := from.distance_to(to)
	if parent == null or length < 0.3:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, length)
	var node := _spawn(parent, mesh, load(TRACER_MAT), (from + to) * 0.5)
	node.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	_fade(node, life)


static func impact(parent: Node, pos: Vector3, normal: Vector3, life: float = 0.18) -> void:
	if parent == null:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.18, 0.18)
	var node := _spawn(parent, mesh, load(IMPACT_MAT), pos + normal * 0.05)
	node.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
	_fade(node, life)


## Car explosion: fireball flash + flying debris (visual only, nothing to get stuck on).
static func explosion(parent: Node, pos: Vector3) -> void:
	if parent == null:
		return
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 8
	ball.rings = 4
	var fireball := _spawn(parent, ball, load("res://assets/materials/fx_fire.tres"), pos + Vector3.UP)
	fireball.scale = Vector3.ONE * 0.5
	var grow := fireball.create_tween()
	grow.tween_property(fireball, "scale", Vector3.ONE * 3.2, 0.18)
	grow.tween_property(fireball, "scale", Vector3.ONE * 0.1, 0.35)
	grow.tween_callback(fireball.queue_free)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 4.0
	light.omni_range = 18.0
	parent.add_child(light)
	light.global_position = pos + Vector3.UP * 1.5
	var fade := light.create_tween()
	fade.tween_property(light, "light_energy", 0.0, 0.5)
	fade.tween_callback(light.queue_free)
	var chunk := BoxMesh.new()
	chunk.size = Vector3(0.5, 0.3, 0.6)
	var dead_mat: Material = load("res://assets/materials/target_dead.tres")
	for i in 8:
		var debris := _spawn(parent, chunk, dead_mat, pos + Vector3.UP)
		var dir := Vector3(randf_range(-1, 1), randf_range(0.6, 1.4), randf_range(-1, 1)).normalized()
		var apex := pos + dir * randf_range(3.0, 7.0)
		var land := Vector3(apex.x + dir.x * 2.0, pos.y, apex.z + dir.z * 2.0)
		var tw := debris.create_tween()
		tw.tween_property(debris, "global_position", apex, 0.3).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(debris, "rotation", Vector3(randf() * 6, randf() * 6, 0), 0.8)
		tw.tween_property(debris, "global_position", land, 0.4).set_ease(Tween.EASE_IN)
		tw.tween_property(debris, "scale", Vector3.ONE * 0.05, 1.5)
		tw.tween_callback(debris.queue_free)


## Random direction inside a cone of half-angle `spread_deg` around `forward`.
static func spread_dir(forward: Vector3, spread_deg: float, rng: RandomNumberGenerator) -> Vector3:
	if spread_deg <= 0.0:
		return forward
	var angle := deg_to_rad(spread_deg) * sqrt(rng.randf())
	var roll := rng.randf() * TAU
	var right := forward.cross(Vector3.UP)
	right = right.normalized() if right.length() > 0.01 else Vector3.RIGHT
	var up := right.cross(forward).normalized()
	return (forward * cos(angle) + (right * cos(roll) + up * sin(roll)) * sin(angle)).normalized()


## Box-particle emitter (smoke / fire) in world space (trails behind moving vehicles).
static func make_particles(mat_path: String, amount: int, lifetime: float, size: float,
		rise: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * size
	box.material = load(mat_path)
	p.mesh = box
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = rise * 0.6
	p.initial_velocity_max = rise
	p.gravity = Vector3(0.0, 1.0, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	return p


static func _spawn(parent: Node, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(node)
	node.global_position = pos
	return node


static func _fade(node: Node3D, life: float) -> void:
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * 0.05, life)
	tween.tween_callback(node.queue_free)
