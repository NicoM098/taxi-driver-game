class_name Burning
extends Node3D
## Fire on something that was hit by Dragon's breath (sawed-off Mk IV, D-085): damage over time
## to its HealthComponent, with flames spitting off it. One per target; another hit refreshes the
## timer instead of stacking.

var health: HealthComponent
var dps: float = 9.0
var time_left: float = 4.0

var _spark: float = 0.0
var _rng := RandomNumberGenerator.new()


## Sets `health`'s owner on fire (or keeps an existing fire going). Returns the Burning node.
static func ignite(target_health: HealthComponent, damage_per_second: float, seconds: float) -> Burning:
	if target_health == null or target_health.is_dead:
		return null
	var host := target_health.get_parent()
	var fire := host.get_node_or_null(^"Burning") as Burning
	if fire == null:
		fire = Burning.new()
		fire.name = "Burning"
		fire.health = target_health
		host.add_child(fire)
	fire.dps = damage_per_second
	fire.time_left = seconds
	return fire


func _physics_process(delta: float) -> void:
	if health == null or not is_instance_valid(health) or health.is_dead or time_left <= 0.0:
		queue_free()
		return
	time_left -= delta
	health.apply_damage(dps * delta)
	_spark -= delta
	if _spark <= 0.0:
		_spark = 0.12
		var at := global_position + Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(0.6, 1.6),
				_rng.randf_range(-1.0, 1.0))
		CombatFx.impact(get_parent(), at, Vector3.UP, 0.3)
