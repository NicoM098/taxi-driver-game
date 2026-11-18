class_name Pedestrian
extends Node3D
## A passer-by walking laps around a block's curb (street life, D-065). No physics body:
## it checks the player's taxi itself.
##  WALK   along the loop at its own pace, slight bob.
##  DODGE  a fast car heading at it -> jumps aside, then drifts back to the curb line.
##  FLEE   gunfire nearby -> runs (StreetLife calls panic()).
##  DOWN   hit by the taxi -> thrown, lies there, then sinks into the ground (StreetLife frees
##         it), instead of vanishing in plain view (D-103).

enum State { WALK, DODGE, FLEE, DOWN }

const HIT_HALF_WIDTH := 1.25      # taxi half width 0.9 + a body
const HIT_HALF_LENGTH := 2.6       # taxi half length 2.2 + a body
const HIT_MIN_SPEED := 3.5         # m/s: slower than this the taxi just nudges past
const DODGE_RANGE := 11.0
const DODGE_MIN_SPEED := 6.0

var state: State = State.WALK
var loop: Rect2                    # world XZ rectangle the walker circles
var height: float = 0.2            # y of the walking surface
var speed: float = 1.3
var done: bool = false             # StreetLife frees it

var _s: float = 0.0                # distance along the loop
var _dir: float = 1.0
var _offset: Vector3 = Vector3.ZERO
var _state_t: float = 0.0
var _vel: Vector3 = Vector3.ZERO   # DOWN: flight velocity
var _spin: Vector3 = Vector3.ZERO
var _grounded: bool = false
var _visual: Node3D
var _rng := RandomNumberGenerator.new()


func setup(p_loop: Rect2, p_height: float, color: Color, start: float = -1.0) -> void:
	_rng.randomize()
	loop = p_loop
	height = p_height
	speed = _rng.randf_range(1.0, 1.7)
	_dir = 1.0 if _rng.randf() < 0.5 else -1.0
	_s = start if start >= 0.0 else _rng.randf() * _perimeter()
	_visual = PassengerVisual.build(color)
	add_child(_visual)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	position = _loop_point(_s)


func _physics_process(delta: float) -> void:
	_state_t += delta
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
	match state:
		State.DOWN:
			_tumble(delta)
			return
		State.FLEE:
			if _state_t > 5.0:
				_set_state(State.WALK)
		State.DODGE:
			if _state_t > 0.45:
				_set_state(State.WALK)
	if taxi != null and _check_taxi(taxi):
		return
	var pace := speed
	if state == State.FLEE:
		pace = 4.8
	elif state == State.DODGE:
		pace = 0.0
	_s = fposmod(_s + pace * _dir * delta, _perimeter())
	if state == State.WALK:
		_offset = _offset.move_toward(Vector3.ZERO, 1.2 * delta)
	var base := _loop_point(_s)
	var ahead := _loop_point(fposmod(_s + _dir * 0.5, _perimeter()))
	position = base + _offset
	if pace > 0.0 and ahead.distance_to(base) > 0.01:
		var look := ahead - base
		rotation.y = atan2(-look.x, -look.z)
	_visual.position.y = absf(sin(_s * PI * 1.4)) * (0.09 if state == State.FLEE else 0.04)


## Gunfire close by: run (the direction they were going), for a few seconds.
func panic() -> void:
	if state == State.DOWN:
		return
	_set_state(State.FLEE)


func _check_taxi(taxi: Taxi) -> bool:
	var to_me := global_position - taxi.global_position
	to_me.y = 0.0
	var dist := to_me.length()
	var vel := taxi.linear_velocity
	vel.y = 0.0
	var spd := vel.length()
	if dist < 4.0 and spd > HIT_MIN_SPEED and absf(global_position.y - taxi.global_position.y) < 2.0:
		# Inside the taxi's footprint (+ a body's width)?
		var local := taxi.global_transform.affine_inverse() * global_position
		if absf(local.x) < HIT_HALF_WIDTH and absf(local.z) < HIT_HALF_LENGTH:
			_knock(vel)
			return true
	if state == State.WALK and dist < DODGE_RANGE and spd > DODGE_MIN_SPEED \
			and vel.normalized().dot(to_me / maxf(dist, 0.01)) > 0.85:
		# Jump aside, away from the car's line.
		var side := vel.normalized().cross(Vector3.UP)
		if side.dot(to_me) < 0.0:
			side = -side
		_offset += side * 2.6
		_set_state(State.DODGE)
	return false


func _knock(vel: Vector3) -> void:
	_set_state(State.DOWN)
	_vel = vel * 0.75 + Vector3(0, 4.5 + vel.length() * 0.15, 0)
	_spin = Vector3(_rng.randf_range(-8, 8), _rng.randf_range(-4, 4), _rng.randf_range(-8, 8))
	EventBus.pedestrian_hit.emit(global_position)


func _tumble(delta: float) -> void:
	if not _grounded:
		_vel.y -= 20.0 * delta
		position += _vel * delta
		rotation += _spin * delta
		if position.y <= height and _vel.y < 0.0:
			position.y = height
			_grounded = true
			rotation = Vector3(PI * 0.5, rotation.y, 0.0)   # lying flat
	elif _state_t > 7.0:
		position.y -= 0.5 * delta   # sink out of sight before StreetLife frees it
		if _state_t > 9.0:
			done = true


func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0


func _perimeter() -> float:
	return 2.0 * (loop.size.x + loop.size.y)


## Point on the loop at distance `s` (clockwise from the min corner), y = walking surface.
func _loop_point(s: float) -> Vector3:
	var w := loop.size.x
	var d := loop.size.y
	var p := loop.position
	var v: Vector2
	if s < w:
		v = p + Vector2(s, 0)
	elif s < w + d:
		v = p + Vector2(w, s - w)
	elif s < 2.0 * w + d:
		v = p + Vector2(w - (s - w - d), d)
	else:
		v = p + Vector2(0, d - (s - 2.0 * w - d))
	return Vector3(v.x, height, v.y)
