class_name EnemyDriverAI
extends Node
## Input provider for an EnemyCar (same VehicleInput as the player).
## Modes: CHASE (road-graph route when far, direct when near), FLANK (drive alongside so the
## gunman can shoot), RAM (aim at where the target will be, full throttle), RETREAT (low HP),
## UNSTUCK (reverse out after getting stuck), AMBUSH (parked, waiting for the target to come
## close: strategic spawns ahead on the player's route, Phase 07).

enum Mode { CHASE, FLANK, RAM, RETREAT, UNSTUCK, AMBUSH }

@export var direct_range: float = 50.0
@export var flank_range: float = 24.0
@export var flank_offset: float = 6.0
## When the target is (nearly) stopped: hold this far away instead of crowding it.
@export var standoff_distance: float = 9.0
@export var standoff_target_speed: float = 4.0   # m/s; below this the target counts as stopped
@export var comfort_decel: float = 5.0           # m/s^2 used to plan stops (real braking is ~14)
@export var waypoint_reach: float = 10.0
@export var replan_interval: float = 1.2
@export var corner_speed: float = 12.0       # m/s through intersections
@export var ram_time: float = 2.0
@export var retreat_hp_ratio: float = 0.25
@export var steer_gain: float = 1.8          # steer per radian of heading error
@export var ambush_trigger: float = 45.0     # target this close -> the ambush springs
@export var ambush_patience: float = 40.0    # s; after this the ambusher goes hunting

var car: EnemyCar
var mode: Mode = Mode.CHASE

var _route: PackedVector3Array = PackedVector3Array()
var _replan: float = 0.0
var _mode_time: float = 0.0
var _stuck_time: float = 0.0
var _unstuck_steer: float = 0.0
var _side: float = 1.0
var _standoff_dir: Vector3 = Vector3.ZERO   # chosen once per hold, so it doesn't flip sides
var _city: City
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_side = 1.0 if _rng.randf() < 0.5 else -1.0


func poll(input: VehicleInput) -> void:
	input.clear()
	var dt := get_physics_process_delta_time()
	if car == null or car.target == null or car.is_destroyed:
		input.handbrake = car != null and car.is_destroyed
		return
	if _city == null:
		_city = get_tree().get_first_node_in_group(&"city") as City
	var target := car.target
	var to_target := target.global_position - car.global_position
	to_target.y = 0.0
	var dist := to_target.length()
	_mode_time += dt
	if mode == Mode.AMBUSH:
		# Parked across the road until the target shows up, we get shot, or we lose patience.
		if dist < ambush_trigger or car.health.hp < car.health.max_hp or _mode_time > ambush_patience:
			_set_mode(Mode.CHASE)
		else:
			input.handbrake = true
			return
	_update_mode(dist, dt)

	var aim := target.global_position
	var target_speed := car.max_speed
	match mode:
		Mode.UNSTUCK:
			input.brake = 1.0
			input.steer = -_unstuck_steer
			return
		Mode.RETREAT:
			aim = car.global_position + (car.global_position - target.global_position).normalized() * 60.0
		Mode.RAM:
			aim = target.global_position + target.linear_velocity * 0.4
			target_speed = car.max_speed + 6.0
			input.boost = true
		Mode.FLANK:
			if target.linear_velocity.length() < standoff_target_speed:
				# Target parked: take a standoff position on one side (locked) and hold.
				if _standoff_dir == Vector3.ZERO:
					_standoff_dir = car.global_position - target.global_position
					_standoff_dir.y = 0.0
					_standoff_dir = _standoff_dir.normalized() if _standoff_dir.length() > 0.1 else Vector3.BACK
				aim = target.global_position + _standoff_dir * standoff_distance
				target_speed = _stop_speed(_flat(car.global_position, aim) - 1.5, 10.0)
				_drive_to(input, aim, target_speed)
				_check_stuck(input, get_physics_process_delta_time())
				return
			_standoff_dir = Vector3.ZERO
			var t_fwd := -target.global_basis.z
			t_fwd.y = 0.0
			t_fwd = t_fwd.normalized()
			var t_right := t_fwd.cross(Vector3.UP)
			aim = target.global_position + t_right * flank_offset * _side + t_fwd * 1.5
			var along := (aim - car.global_position).dot(t_fwd)
			target_speed = clampf(target.linear_velocity.length() + clampf(along * 0.8, -6.0, 8.0), 4.0, car.max_speed + 4.0)
		Mode.CHASE:
			if dist > direct_range and _city != null:
				aim = _route_point(target.global_position, dt)
				target_speed = _route_speed()
			elif target.linear_velocity.length() < standoff_target_speed:
				# Closing in on a parked target: head for the standoff point and brake early
				# (full speed until the last 24 m overshoots right past the taxi).
				var away := car.global_position - target.global_position
				away.y = 0.0
				aim = target.global_position + away.normalized() * standoff_distance
				target_speed = maxf(_stop_speed(dist - standoff_distance, car.max_speed), 4.0)
			else:
				aim = target.global_position + target.linear_velocity * 0.5
	_drive_to(input, aim, target_speed)
	_check_stuck(input, dt)


func _update_mode(dist: float, _dt: float) -> void:
	if mode == Mode.UNSTUCK:
		if _mode_time > 1.0:
			_set_mode(Mode.CHASE)
		return
	if car.health.hp < car.health.max_hp * retreat_hp_ratio:
		if mode != Mode.RETREAT:
			_set_mode(Mode.RETREAT)
		return
	if mode == Mode.RAM:
		# Ram over after the hit (contact) or when it takes too long / target got away.
		if (_mode_time > 0.4 and dist < 5.5) or _mode_time > ram_time or dist > flank_range * 1.6:
			_set_mode(Mode.FLANK if dist < flank_range else Mode.CHASE)
		return
	if dist < flank_range:
		if mode != Mode.FLANK:
			_set_mode(Mode.FLANK)
		# Chance per second to switch to ramming, scaled by aggression. Only against a MOVING
		# taxi (run it off the road) — ramming a parked one just pins it (user feedback).
		elif _mode_time > 1.5 and car.target.linear_velocity.length() > standoff_target_speed 				and _rng.randf() < car.data.aggression * 0.35 * get_physics_process_delta_time():
			_set_mode(Mode.RAM)
	elif mode != Mode.CHASE:
		_set_mode(Mode.CHASE)


## Wait in place (strategic spawn) until the target is within `trigger_distance`.
func hold_ambush(trigger_distance: float = -1.0) -> void:
	if trigger_distance > 0.0:
		ambush_trigger = trigger_distance
	_set_mode(Mode.AMBUSH)


func _set_mode(m: Mode) -> void:
	mode = m
	_mode_time = 0.0
	_standoff_dir = Vector3.ZERO
	if m == Mode.FLANK:
		_side = 1.0 if _rng.randf() < 0.5 else -1.0


func _route_point(goal: Vector3, dt: float) -> Vector3:
	_replan -= dt
	if _replan <= 0.0 or _route.is_empty():
		_replan = replan_interval
		_route = _city.get_route(car.global_position, goal)
	while _route.size() > 1 and _flat(car.global_position, _route[0]) < waypoint_reach:
		_route.remove_at(0)
	return _route[0] if not _route.is_empty() else goal


## Slow down before sharp turns at intersections.
func _route_speed() -> float:
	if _route.size() < 2:
		return car.max_speed
	var to_wp := _route[0] - car.global_position
	var next_leg := _route[1] - _route[0]
	to_wp.y = 0.0
	next_leg.y = 0.0
	if to_wp.length() < 0.1 or next_leg.length() < 0.1:
		return car.max_speed
	var turn := absf(to_wp.normalized().signed_angle_to(next_leg.normalized(), Vector3.UP))
	if turn > deg_to_rad(40.0) and to_wp.length() < 35.0:
		return corner_speed
	return car.max_speed


func _drive_to(input: VehicleInput, aim: Vector3, target_speed: float) -> void:
	var local := car.global_transform.affine_inverse() * aim
	var angle := atan2(-local.x, -local.z)   # + = aim is to the left
	input.steer = clampf(-angle * steer_gain, -1.0, 1.0)
	var speed := car.forward_speed
	if target_speed <= 0.5:
		# Hold position: brake to a stop, never reverse.
		if speed > 1.0:
			input.brake = clampf(speed / 6.0, 0.3, 1.0)
		return
	if absf(angle) > 1.2 and speed > 14.0:
		input.brake = 0.6                     # too fast for this turn
	elif speed < target_speed - 1.0:
		input.throttle = 1.0
	elif speed > target_speed + 1.5:
		input.brake = clampf((speed - target_speed) / 4.0, 0.3, 1.0)
	else:
		input.throttle = 0.35


## Highest speed from which the car can still stop within `distance` at comfort_decel.
func _stop_speed(distance: float, cap: float) -> float:
	return minf(sqrt(2.0 * comfort_decel * maxf(distance, 0.0)), cap)


func _check_stuck(input: VehicleInput, dt: float) -> void:
	if input.throttle > 0.5 and car.linear_velocity.length() < 1.2:
		_stuck_time += dt
		if _stuck_time > 1.2:
			_stuck_time = 0.0
			_unstuck_steer = input.steer if absf(input.steer) > 0.2 else 1.0
			_set_mode(Mode.UNSTUCK)
	else:
		_stuck_time = 0.0


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
