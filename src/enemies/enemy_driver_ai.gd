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
## Close to a waypoint (or past it) -> the next one. Was 10 m: cars turned early and cut the
## corner into the building (D-092).
@export var waypoint_reach: float = 6.0
@export var replan_interval: float = 1.2
@export var corner_speed: float = 11.0       # m/s through intersections
@export var corner_lookahead: float = 45.0   # start slowing this far before a sharp turn
@export var ram_time: float = 2.0
@export var retreat_hp_ratio: float = 0.25
@export var steer_gain: float = 1.8          # steer per radian of heading error
@export var ambush_trigger: float = 45.0     # target this close -> the ambush springs
@export var ambush_patience: float = 40.0    # s; after this the ambusher goes hunting
@export var ambush_bypass: float = 25.0      # target got this much farther away again -> it took another street: hunt

var car: EnemyCar
var mode: Mode = Mode.CHASE

var _route: PackedVector3Array = PackedVector3Array()
var _replan: float = 0.0
var _mode_time: float = 0.0
var _stuck_time: float = 0.0
var _unstuck_steer: float = 0.0
## Getting out of corners (D-092): every stuck in a row reverses longer; after a few the
## director moves the car out of sight. Progress is also checked by distance, since a car
## scraping along a wall still moves a little.
var _unstuck_count: int = 0
var _unstuck_time: float = 1.0
var _unstuck_clear_t: float = 0.0
var _progress_pos: Vector3 = Vector3.ZERO
var _progress_t: float = 0.0
var _reverse_blocked: float = 0.0
## Line of sight to the target (layer 1 = buildings), refreshed a few times a second: with a
## building in between, the direct modes would drive into it, so the car follows the streets.
var _sight: bool = true
var _sight_t: float = 0.0
## Three-point turn (D-092): the way to go is behind and the car is slow, so it reverses with
## the wheels turned the other way instead of hitting the wall with a too-wide U-turn.
var _turning: float = 0.0
var _turn_forward: bool = false   # the forward leg of the turn (reversing was blocked)
var _turn_blocked: float = 0.0
var _side: float = 1.0
var _standoff_dir: Vector3 = Vector3.ZERO   # chosen once per hold, so it doesn't flip sides
var _ambush_closest: float = INF            # closest the target has been while we waited
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
	_sight_t -= dt
	if _sight_t <= 0.0:
		_sight_t = 0.25
		_sight = _clear_line(target.global_position)
	if mode == Mode.AMBUSH:
		# Parked across the road until the target shows up, drives past on another street,
		# we get shot, or we lose patience.
		_ambush_closest = minf(_ambush_closest, dist)
		if dist < ambush_trigger or dist > _ambush_closest + ambush_bypass \
				or car.health.hp < car.health.max_hp or _mode_time > ambush_patience:
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
			# Backed into something too: drive forward the other way instead.
			_reverse_blocked = _reverse_blocked + dt if _mode_time > 0.4 and car.linear_velocity.length() < 0.8 else 0.0
			if _reverse_blocked > 0.5:
				input.brake = 0.0
				input.throttle = 0.8
				input.steer = _unstuck_steer * -1.0 if _unstuck_count % 2 == 0 else _unstuck_steer
			return
		Mode.RETREAT:
			aim = car.global_position + (car.global_position - target.global_position).normalized() * 60.0
		Mode.RAM:
			aim = target.global_position + target.linear_velocity * 0.4
			target_speed = car.max_speed + 6.0
			input.boost = true
		Mode.FLANK when not _sight and _city != null:
			# The target is round the corner: take the streets, not the building.
			aim = _route_point(target.global_position, dt)
			target_speed = _route_speed()
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
			if (dist > direct_range or not _sight) and _city != null:
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
	_check_progress(dt, dist)


func _update_mode(dist: float, _dt: float) -> void:
	if mode == Mode.UNSTUCK:
		if _mode_time > _unstuck_time:
			_route.clear()   # plan again from where it ended up
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
	_ambush_closest = INF
	_set_mode(Mode.AMBUSH)


## Stop waiting and go after the target (the fare was delivered / the ride ended).
func release_ambush() -> void:
	if mode == Mode.AMBUSH:
		_set_mode(Mode.CHASE)


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
	while _route.size() > 1 and (_flat(car.global_position, _route[0]) < waypoint_reach or _passed(_route[0], _route[1])):
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
	if turn > deg_to_rad(40.0) and to_wp.length() < corner_lookahead:
		# Brake in time: the closer to the corner, the nearer to corner_speed.
		return minf(car.max_speed, corner_speed + maxf(to_wp.length() - 12.0, 0.0) * 0.6)
	return car.max_speed


func _drive_to(input: VehicleInput, aim: Vector3, target_speed: float) -> void:
	var local := car.global_transform.affine_inverse() * aim
	var angle := atan2(-local.x, -local.z)   # + = aim is to the left
	input.steer = clampf(-angle * steer_gain, -1.0, 1.0)
	var speed := car.forward_speed
	var dt := get_physics_process_delta_time()
	if _turning <= 0.0 and absf(angle) > 2.2 and speed < 7.0 and target_speed > 0.5:
		_turning = 6.0
		_turn_forward = false
		_turn_blocked = 0.0
	if _turning > 0.0:
		_turning -= dt
		if absf(angle) < 1.3:
			_turning = 0.0
		else:
			# Back and forth until the nose points the right way: reverse with the wheels the
			# other way, and when the wall behind (or ahead) stops it, switch direction.
			_turn_blocked = _turn_blocked + dt if absf(speed) < 1.0 else 0.0
			if _turn_blocked > 0.45:
				_turn_forward = not _turn_forward
				_turn_blocked = 0.0
			var lock := 1.0 if angle > 0.0 else -1.0
			if _turn_forward:
				input.throttle = 0.7
				input.steer = -lock
			else:
				input.brake = 1.0
				input.steer = lock
			return
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
	_unstuck_clear_t += dt
	if _unstuck_clear_t > 8.0:
		_unstuck_count = 0   # free for a while: the next corner starts from a short reverse
	if input.throttle > 0.3 and car.linear_velocity.length() < 1.5:
		_stuck_time += dt
		if _stuck_time > 0.75:
			_start_unstuck(input.steer)
	else:
		_stuck_time = 0.0


## Hunting but barely moving for 3 s (scraping a wall, wedged at an angle) is stuck too.
func _check_progress(dt: float, dist: float) -> void:
	if mode == Mode.UNSTUCK or mode == Mode.AMBUSH or dist < standoff_distance + 6.0:
		_progress_t = 0.0
		_progress_pos = car.global_position
		return
	_progress_t += dt
	if _progress_t < 3.0:
		return
	if _flat(car.global_position, _progress_pos) < 4.0:
		_start_unstuck(car.input.steer)
	_progress_t = 0.0
	_progress_pos = car.global_position


func _start_unstuck(steer: float) -> void:
	_stuck_time = 0.0
	_progress_t = 0.0
	_progress_pos = car.global_position
	_reverse_blocked = 0.0
	_turning = 0.0
	_unstuck_count += 1
	_unstuck_clear_t = 0.0
	if _unstuck_count >= 4:
		# Truly wedged: let the director move it, out of the player's sight.
		var director := get_tree().get_first_node_in_group(&"enemy_director") as EnemyDirector
		if director != null and director.rescue_stuck(car):
			_unstuck_count = 0
			_route.clear()
			_set_mode(Mode.CHASE)
			return
	_unstuck_time = minf(1.0 + (_unstuck_count - 1) * 0.6, 2.8)
	_unstuck_steer = signf(steer) if absf(steer) > 0.2 else (1.0 if _rng.randf() < 0.5 else -1.0)
	if _unstuck_count % 2 == 0:
		_unstuck_steer = -_unstuck_steer   # the same way out failed: try the other one
	_set_mode(Mode.UNSTUCK)


## True once the car is beyond `wp` along the leg towards `next` (it went past it).
func _passed(wp: Vector3, next: Vector3) -> bool:
	var leg := next - wp
	leg.y = 0.0
	var off := car.global_position - wp
	off.y = 0.0
	return leg.length() > 0.1 and off.dot(leg.normalized()) > 0.0 and off.length() < waypoint_reach * 2.5


func _clear_line(to: Vector3) -> bool:
	var space := car.get_world_3d().direct_space_state
	if space == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(car.global_position + Vector3(0, 0.8, 0), to + Vector3(0, 0.8, 0), 1)
	q.exclude = [car.get_rid()]
	return space.intersect_ray(q).is_empty()


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
