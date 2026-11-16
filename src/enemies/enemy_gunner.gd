class_name EnemyGunner
extends Node3D
## The enemy car's gunman: fires bursts from the side window facing the player when in range
## and with line of sight. Hitscan; hits the taxi's hitboxes (body / cabin).

## world | player_taxi | hitboxes
const LOS_MASK := (1 << 0) | (1 << 1) | (1 << 5)

## Being shot at used to be silent: tracers and a muzzle flash, no sound (D-080). The gun is
## picked from the car's own fire rate, so it needs no new field and a new enemy sorts itself:
## a slow, deliberate cadence is the police sidearm, anything faster is a criminal's SMG.
const SMG_FIRE_RATE: float = 6.0
## Under the player's own shots (-2 dB), and positional, so a burst from across the street reads
## as distance rather than as being next to your ear.
const SHOT_DB: float = -4.0

var car: EnemyCar
var shots_fired: int = 0

var _cooldown: float = 1.5
var _burst_left: int = 0
var _exclude: Array[RID] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if car == null or car.is_destroyed or car.target == null or not car.data.shoots:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	if _exclude.is_empty():
		_exclude.append(car.get_rid())
		for node in car.find_children("*", "CollisionObject3D", true, false):
			_exclude.append((node as CollisionObject3D).get_rid())

	var target := car.target
	var local_target := car.global_transform.affine_inverse() * target.global_position
	var side := 1.0 if local_target.x > 0.0 else -1.0
	var muzzle := car.global_transform * Vector3(0.9 * side, 1.1, -0.1)
	var aim := target.global_position + Vector3(0.0, 0.8, 0.0) + target.linear_velocity * 0.06
	var to := aim - muzzle
	if to.length() > car.data.gun_range or not _has_line_of_sight(muzzle, aim):
		_cooldown = 0.3
		return

	shots_fired += 1
	var rel_speed := (target.linear_velocity - car.linear_velocity).length()
	var dir := CombatFx.spread_dir(to.normalized(), car.data.spread_deg + rel_speed * 0.08, _rng)
	var end := muzzle + dir * car.data.gun_range
	var query := PhysicsRayQueryParameters3D.create(muzzle, end, LOS_MASK, _exclude)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var fx_parent := car.get_parent()
	if not hit.is_empty():
		end = hit["position"]
		if hit["collider"] is Hitbox:
			(hit["collider"] as Hitbox).take_hit(car.data.damage, muzzle)
		CombatFx.impact(fx_parent, end, hit["normal"], 0.12)
	CombatFx.tracer(fx_parent, muzzle, end)
	_play_shot(muzzle)

	_burst_left -= 1
	if _burst_left <= 0:
		_burst_left = car.data.burst
		_cooldown = car.data.burst_pause
	else:
		_cooldown = 1.0 / car.data.fire_rate


## One shot, from the muzzle. The pool in `Audio` is round-robin, so a firefight cuts its own
## oldest shots instead of piling up (DV-066).
func _play_shot(muzzle: Vector3) -> void:
	var fast := car.data.fire_rate >= SMG_FIRE_RATE
	var sound: StringName = &"shot_smg" if fast else &"shot_revolver"
	# The faster the cadence, the snappier the report.
	var pitch := 1.0 + clampf((car.data.fire_rate - 5.0) * 0.04, 0.0, 0.2)
	Audio.play_at(sound, muzzle, Audio.BUS_SFX, SHOT_DB, pitch * _rng.randf_range(0.97, 1.03))


func _has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, LOS_MASK, _exclude)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Object = hit["collider"]
	return collider == car.target or (collider is Node and car.target.is_ancestor_of(collider as Node))
