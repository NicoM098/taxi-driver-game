class_name Mine
extends Node3D
## A mine dropped behind the taxi (D-086). Arms after ARM_TIME, then any enemy or civilian car
## within TRIGGER_RADIUS sets it off (Blast). The player's taxi never does. At most MAX_ACTIVE
## lie on the map; dropping one more removes the oldest.

const ARM_TIME := 0.8
const TRIGGER_RADIUS := 3.2
const MAX_ACTIVE := 8
## enemy_vehicles | traffic
const TRIGGER_MASK := (1 << 2) | (1 << 3)

var damage: float = 220.0
var radius: float = 5.0

var _age: float = 0.0
var _done: bool = false
var _light: MeshInstance3D


## Drops a mine on the ground at `pos` (y is found by a ray down) under `parent`.
static func drop(parent: Node3D, pos: Vector3, p_damage: float, p_radius: float) -> Mine:
	var old := parent.get_tree().get_nodes_in_group(&"mines")
	if old.size() >= MAX_ACTIVE:
		old[0].queue_free()
	var mine := Mine.new()
	mine.damage = p_damage
	mine.radius = p_radius
	parent.add_child(mine)
	var space := parent.get_world_3d().direct_space_state
	var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 2.0,
			pos + Vector3.DOWN * 6.0, 1 << 0))
	mine.global_position = ground["position"] if not ground.is_empty() else pos
	return mine


func _ready() -> void:
	add_to_group(&"mines")
	var disc := CylinderMesh.new()
	disc.top_radius = 0.35
	disc.bottom_radius = 0.42
	disc.height = 0.14
	disc.radial_segments = 8
	disc.rings = 1
	Blockout.add_mesh(self, disc, Vector3(0, 0.07, 0), load("res://assets/materials/viewmodel_gun.tres"))
	var led := BoxMesh.new()
	led.size = Vector3(0.12, 0.08, 0.12)
	_light = Blockout.add_mesh(self, led, Vector3(0, 0.17, 0), load("res://assets/materials/siren_red.tres"))


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	# Slow blink while arming, fast once live.
	var period := 0.5 if _age < ARM_TIME else 0.18
	_light.visible = fmod(_age, period) < period * 0.5
	if _age < ARM_TIME:
		return
	var sphere := SphereShape3D.new()
	sphere.radius = TRIGGER_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = TRIGGER_MASK
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		explode()


func explode() -> void:
	if _done:
		return
	_done = true
	Blast.detonate(get_parent() as Node3D, global_position + Vector3.UP * 0.3, radius, damage)
	queue_free()
