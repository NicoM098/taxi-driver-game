class_name Hitbox
extends Area3D
## Shootable region (physics layer 6 "hitboxes"). Forwards hits to a HealthComponent with a
## damage multiplier (e.g. 2.0 for a driver's head). Make the shape slightly bigger than any
## solid body it covers, so weapon rays reach the hitbox first.

## Emitted on every hit with the effective damage and where the shot came from
## (Vector3.INF if unknown). Lets owners route damage (e.g. driver/passenger) or show indicators.
signal hit(damage: float, source: Vector3)

@export var health: HealthComponent
@export var damage_multiplier: float = 1.0


func _ready() -> void:
	collision_layer = 1 << 5   # layer 6: hitboxes
	collision_mask = 0
	monitoring = false
	monitorable = true


## Returns true if this hit killed the owner. `health` may be null (owner handles `hit`).
func take_hit(damage: float, source: Vector3 = Vector3.INF) -> bool:
	var dealt := damage * damage_multiplier
	hit.emit(dealt, source)
	if health == null or health.is_dead:
		return false
	health.apply_damage(dealt)
	return health.is_dead
