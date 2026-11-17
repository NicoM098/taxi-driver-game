class_name Rocket
extends Node3D
## A rocket from the launcher (D-086). Flies straight, ray-casting each step so it cannot tunnel
## through a car at speed, and explodes (Blast) on the first thing it touches or at the end of
## its range. Never collides with the taxi that fired it.

## world | enemy_vehicles | traffic | characters | hitboxes | props (as WeaponController)
const HIT_MASK := (1 << 0) | (1 << 2) | (1 << 3) | (1 << 4) | (1 << 5) | (1 << 8)

var velocity: Vector3 = Vector3.ZERO
var damage: float = 180.0
var radius: float = 6.0
var max_distance: float = 300.0
var exclude: Array[RID] = []

var _travelled: float = 0.0
var _puff: float = 0.0
var _done: bool = false


func _ready() -> void:
	add_to_group(&"rockets")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var body := BoxMesh.new()
	body.size = Vector3(0.16, 0.16, 0.7)
	Blockout.add_mesh(self, body, Vector3.ZERO, load("res://assets/materials/viewmodel_gun.tres"))
	var flame := BoxMesh.new()
	flame.size = Vector3(0.14, 0.14, 0.3)
	Blockout.add_mesh(self, flame, Vector3(0, 0, 0.48), load("res://assets/materials/fx_fire.tres"))
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP)


func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := velocity * delta
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + step, HIT_MASK, exclude)
	query.collide_with_areas = true
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		_explode(hit["position"])
		return
	global_position += step
	_travelled += step.length()
	_puff -= delta
	if _puff <= 0.0:
		_puff = 0.03
		CombatFx.impact(get_parent(), global_position - velocity.normalized() * 0.6, Vector3.UP, 0.25)
	if _travelled >= max_distance:
		_explode(global_position)


func _explode(at: Vector3) -> void:
	_done = true
	Blast.detonate(get_parent() as Node3D, at, radius, damage)
	queue_free()
