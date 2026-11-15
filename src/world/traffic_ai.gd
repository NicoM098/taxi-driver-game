class_name TrafficAI
extends Node
## Input provider for a TrafficCar: drives to a random reachable street point, then picks a
## new one. Follows the cell road graph but keeps to the RIGHT-hand lane (the lane point of
## each cell is worked out from how wide the street is there). Slows down for anything in
## front (ray along its nose), stops for a few seconds after a crash, backs out when stuck.
## `gave_up` tells StreetLife to recycle it (stuck for good, flipped).

@export var cruise_speed: float = 13.0       # m/s (~47 km/h)
@export var corner_speed: float = 6.5
@export var lane_reach: float = 6.0          # m: waypoint reached
@export var look_ahead_min: float = 7.0      # m: obstacle ray length at a standstill
@export var look_ahead_per_speed: float = 1.1
@export var steer_gain: float = 2.0
@export var crash_pause: float = 3.5         # s stopped after a hit (dazed driver)

var car: TrafficCar
var gave_up: bool = false

var _route: PackedVector3Array = PackedVector3Array()
var _city: City
var _pause: float = 0.0
var _stuck: float = 0.0
var _stuck_total: float = 0.0
var _reverse: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func poll(input: VehicleInput) -> void:
	input.clear()
	var dt := get_physics_process_delta_time()
	if car == null:
		return
	if _city == null:
		_city = get_tree().get_first_node_in_group(&"city") as City
		if _city == null:
			return
	if car.global_basis.y.y < 0.3:          # on its side / roof
		_stuck_total += dt
		gave_up = _stuck_total > 4.0
		return
	if _pause > 0.0:
		_pause -= dt
		input.brake = 1.0
		return
	if _reverse > 0.0:
		_reverse -= dt
		input.brake = 1.0                   # brake = reverse once stopped
		input.steer = 0.6
		return
	if _route.size() < 2:
		_plan()
		if _route.is_empty():
			input.brake = 1.0
			return
	while _route.size() > 1 and _flat(car.global_position, _route[0]) < lane_reach:
		_route.remove_at(0)
	if _route.size() <= 1 and _flat(car.global_position, _route[0]) < lane_reach:
		_route.clear()
		return

	var aim := _route[0]
	var local := car.global_transform.affine_inverse() * aim
	var angle := atan2(-local.x, -local.z)
	input.steer = clampf(-angle * steer_gain, -1.0, 1.0)
	var target := cruise_speed
	if _route.size() > 1:
		var leg := _route[1] - _route[0]
		var to_wp := _route[0] - car.global_position
		if leg.length() > 0.1 and to_wp.length() > 0.1 and to_wp.length() < 18.0 \
				and absf(to_wp.normalized().signed_angle_to(leg.normalized(), Vector3.UP)) > deg_to_rad(35.0):
			target = corner_speed
	if absf(angle) > 0.9:
		target = minf(target, corner_speed)
	target = minf(target, _clear_speed())
	var speed := car.forward_speed
	if target < 0.5:
		input.brake = 1.0 if speed > 0.3 else 0.0
	elif speed < target - 0.8:
		input.throttle = 1.0 if speed < target - 3.0 else 0.5
	elif speed > target + 1.0:
		input.brake = clampf((speed - target) / 5.0, 0.2, 1.0)
	else:
		input.throttle = 0.3
	_check_stuck(input, dt, target)


## Crash reaction (Taxi.crashed): stop for a moment.
func on_crash(impact: float) -> void:
	if impact > 3.0:
		_pause = crash_pause


## New random destination 80-260 m away, reachable, as right-lane points.
func _plan() -> void:
	var points := _city.road_points_reachable(car.global_position)
	if points.is_empty():
		_route = PackedVector3Array()
		return
	var goal := points[_rng.randi() % points.size()]
	for i in 8:
		var d := _flat(goal, car.global_position)
		if d > 80.0 and d < 260.0:
			break
		goal = points[_rng.randi() % points.size()]
	var cells := _city.get_route(car.global_position, goal, true)
	_route = PackedVector3Array()
	for i in cells.size():
		var p := cells[i]
		var dir := (cells[i + 1] - p) if i + 1 < cells.size() else (p - cells[i - 1] if i > 0 else -car.global_basis.z)
		dir.y = 0.0
		if dir.length() < 0.1:
			continue
		_route.append(lane_point(_city, p, dir.normalized()))


## The right-hand lane at street point `p` for travel direction `dir`: measures the plain
## street to both sides; wide-open spots (intersections, squares) get a fixed 3 m offset.
static func lane_point(city: City, p: Vector3, dir: Vector3) -> Vector3:
	var right := dir.cross(Vector3.UP).normalized()
	var r := 0.0
	var l := 0.0
	while r < 16.0 and city.is_plain_street(p + right * (r + 1.0)):
		r += 1.0
	while l < 16.0 and city.is_plain_street(p - right * (l + 1.0)):
		l += 1.0
	var width := r + l
	if width >= 30.0 or width < 3.0:
		return p + right * (3.0 if width >= 30.0 else 0.0)
	var center := p + right * (r - width * 0.5)
	return center + right * clampf(width * 0.25, 1.5, 4.0)


## Highest speed that keeps a gap to the vehicle in front. Only vehicles: the route already
## steers round walls, and a wall ahead while turning a corner would freeze the car for good.
func _clear_speed() -> float:
	var space := car.get_world_3d().direct_space_state
	var fwd := -car.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var reach := look_ahead_min + maxf(car.forward_speed, 0.0) * look_ahead_per_speed
	var origin := car.global_position + Vector3(0, 0.6, 0) + fwd * 2.4
	var best := INF
	for side: float in [-0.7, 0.7]:
		var o := origin + fwd.cross(Vector3.UP) * side
		var q := PhysicsRayQueryParameters3D.create(o, o + fwd * reach, 2 | 4 | 8, [car.get_rid()])
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			best = minf(best, o.distance_to(hit["position"]))
	if best == INF:
		return cruise_speed
	return clampf((best - 3.0) * 1.2, 0.0, cruise_speed)


func _check_stuck(input: VehicleInput, dt: float, target: float) -> void:
	if target > 2.0 and input.throttle > 0.2 and car.linear_velocity.length() < 0.8:
		_stuck += dt
		_stuck_total += dt
		if _stuck > 2.5:
			_stuck = 0.0
			_reverse = 1.2
			_route.clear()
		gave_up = _stuck_total > 12.0
	else:
		_stuck = 0.0
		_stuck_total = maxf(_stuck_total - dt * 0.5, 0.0)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
