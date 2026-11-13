class_name CabCamera
extends Node3D
## First-person driver's head inside the cab.
## Free look (mouse via InputDevice, right stick via look_* actions), auto-recentre,
## look-behind, g-force lean, speed FOV kick and crash shake.
## Attach to the HeadPivot node; expects a Camera3D child.

@export var vehicle: Taxi

@export_group("Look")
@export var mouse_sensitivity: float = 0.0025   # rad per screen pixel
@export var stick_sensitivity: float = 3.0      # rad/s at full deflection
@export var max_yaw_deg: float = 110.0
@export var max_pitch_up_deg: float = 60.0
@export var max_pitch_down_deg: float = 50.0
@export var invert_y: bool = false
@export var recenter_with_mouse: bool = false
@export var recenter_with_stick: bool = true
@export var recenter_delay: float = 0.8
@export var recenter_speed: float = 3.0
@export var look_behind_yaw_deg: float = 160.0

@export_group("Motion")
@export var lean_amount: float = 0.004         # m of head offset per m/s^2
@export var max_lean: float = 0.08
@export var lean_smoothing: float = 6.0
@export var roll_per_accel_deg: float = 0.25
@export var max_roll_deg: float = 4.0

@export_group("FOV")
@export var base_fov: float = 75.0
@export var max_fov_kick: float = 12.0
@export var boost_fov_kick: float = 6.0

@export_group("Shake")
@export var shake_max_offset: float = 0.06
@export var shake_max_roll_deg: float = 3.0
@export var shake_decay: float = 1.6
@export var trauma_per_impact: float = 0.06

@export_group("Landing")
## Camera reaction on touchdown: shake + a springy head dip, both scaled by fall speed.
@export var landing_trauma_per_speed: float = 0.07
@export var landing_dip_per_speed: float = 0.035   # head dip velocity (m/s) per m/s of fall
@export var landing_dip_max: float = 0.18          # max dip (m)
@export var dip_stiffness: float = 120.0
@export var dip_damping: float = 11.0

@export_group("Aiming")
@export var aim_fov_offset: float = -10.0
@export var recoil_return_speed: float = 10.0
## Fraction of each recoil kick that stays (the aim climbs a little, like a real gun).
@export_range(0.0, 1.0) var recoil_permanent: float = 0.25

@onready var camera: Camera3D = $Camera3D

## Set by WeaponController: gun is up -> no auto-recentre; aim_zoom 0..1 narrows the FOV.
var hold_look: bool = false
var aim_zoom: float = 0.0

var _yaw: float = 0.0
var _pitch: float = 0.0
var _idle_time: float = 0.0
var _using_stick: bool = false
var _behind_blend: float = 0.0
var _rest_position: Vector3
var _lean: Vector3 = Vector3.ZERO
var _roll: float = 0.0
var _accel_local: Vector3 = Vector3.ZERO
var _prev_velocity: Vector3 = Vector3.ZERO
var _trauma: float = 0.0
var _dip: float = 0.0
var _dip_velocity: float = 0.0
var _time: float = 0.0
var _noise: FastNoiseLite = FastNoiseLite.new()
var _recoil: Vector2 = Vector2.ZERO  # pitch, yaw offset (rad), springs back
var _force_behind: float = 0.0       # seconds of forced look-back (execution from the file)


func _ready() -> void:
	# The head is driven every rendered frame; the parent body is physics-interpolated.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_rest_position = position
	_noise.frequency = 0.08
	camera.fov = base_fov
	if vehicle == null:
		vehicle = get_parent() as Taxi
	if vehicle != null:
		vehicle.crashed.connect(_on_vehicle_crashed)
		vehicle.reset_performed.connect(_on_vehicle_reset)
		vehicle.landed.connect(_on_vehicle_landed)
	EventBus.explosion.connect(_on_explosion)
	EventBus.passenger_executed.connect(func(_p: RefCounted) -> void:
		_force_behind = 0.9
		add_trauma(0.35)
		add_recoil(5.0, 0.0))


func _physics_process(delta: float) -> void:
	if vehicle == null:
		return
	var velocity := vehicle.linear_velocity
	var accel := ((velocity - _prev_velocity) / delta).limit_length(40.0)
	_prev_velocity = velocity
	_accel_local = vehicle.global_basis.inverse() * accel


func _process(delta: float) -> void:
	_time += delta
	_update_look(delta)
	_update_motion(delta)
	_update_fov(delta)
	_update_dip(delta)
	_apply()


## Weapon recoil: kicks the view up/sideways; most of it springs back.
func add_recoil(pitch_deg: float, yaw_deg: float) -> void:
	var kick := Vector2(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg))
	_recoil += kick * (1.0 - recoil_permanent)
	_pitch = clampf(_pitch + kick.x * recoil_permanent, -deg_to_rad(max_pitch_down_deg), deg_to_rad(max_pitch_up_deg))
	_yaw = clampf(_yaw + kick.y * recoil_permanent, -deg_to_rad(max_yaw_deg), deg_to_rad(max_yaw_deg))


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _update_look(delta: float) -> void:
	var y_sign := -1.0 if invert_y else 1.0
	var had_input := false

	var mouse := InputDevice.consume_mouse_delta()
	if mouse != Vector2.ZERO:
		_yaw -= mouse.x * mouse_sensitivity
		_pitch -= mouse.y * mouse_sensitivity * y_sign
		had_input = true
		_using_stick = false

	var stick := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if stick != Vector2.ZERO:
		_yaw -= stick.x * stick_sensitivity * delta
		_pitch -= stick.y * stick_sensitivity * delta * y_sign
		had_input = true
		_using_stick = true

	_yaw = clampf(_yaw, -deg_to_rad(max_yaw_deg), deg_to_rad(max_yaw_deg))
	_pitch = clampf(_pitch, -deg_to_rad(max_pitch_down_deg), deg_to_rad(max_pitch_up_deg))

	_idle_time = 0.0 if had_input else _idle_time + delta
	var recenter := recenter_with_stick if _using_stick else recenter_with_mouse
	if recenter and _idle_time > recenter_delay and not hold_look and not Input.is_action_pressed(&"aim"):
		var t := 1.0 - exp(-recenter_speed * delta)
		_yaw = lerpf(_yaw, 0.0, t)
		_pitch = lerpf(_pitch, 0.0, t)

	_force_behind = maxf(_force_behind - delta, 0.0)
	var behind_target := 1.0 if Input.is_action_pressed(&"look_behind") or _force_behind > 0.0 else 0.0
	_behind_blend = move_toward(_behind_blend, behind_target, delta * 6.0)


func _update_motion(delta: float) -> void:
	var t := 1.0 - exp(-lean_smoothing * delta)
	var target_lean := (-_accel_local * lean_amount).limit_length(max_lean)
	_lean = _lean.lerp(target_lean, t)
	var max_roll := deg_to_rad(max_roll_deg)
	var target_roll := clampf(_accel_local.x * deg_to_rad(roll_per_accel_deg), -max_roll, max_roll)
	_roll = lerpf(_roll, target_roll, t)
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	_recoil = _recoil.lerp(Vector2.ZERO, 1.0 - exp(-recoil_return_speed * delta))


func _update_fov(delta: float) -> void:
	if vehicle == null:
		return
	var speed_t := clampf(absf(vehicle.forward_speed) / vehicle.max_speed, 0.0, 1.0)
	var target := base_fov + max_fov_kick * speed_t * speed_t
	if vehicle.is_boosting:
		target += boost_fov_kick
	target += aim_fov_offset * aim_zoom
	camera.fov = lerpf(camera.fov, target, 1.0 - exp(-4.0 * delta))


func _apply() -> void:
	var shake := _trauma * _trauma
	var t := _time * 60.0
	var shake_offset := Vector3(_noise.get_noise_2d(t, 0.0), _noise.get_noise_2d(t, 100.0), 0.0) \
		* shake_max_offset * shake
	var shake_roll := _noise.get_noise_2d(t, 200.0) * deg_to_rad(shake_max_roll_deg) * shake

	position = _rest_position + _lean + shake_offset + Vector3(0.0, _dip, 0.0)
	var yaw := lerpf(_yaw, -deg_to_rad(look_behind_yaw_deg), _behind_blend) + _recoil.y
	var pitch := lerpf(_pitch, 0.0, _behind_blend) + _recoil.x
	rotation = Vector3(pitch, yaw, _roll + shake_roll)


func _on_vehicle_crashed(impact: float) -> void:
	add_trauma(impact * trauma_per_impact)


func _update_dip(delta: float) -> void:
	# Damped spring back to 0 (semi-implicit Euler).
	_dip_velocity += (-_dip * dip_stiffness - _dip_velocity * dip_damping) * delta
	_dip = clampf(_dip + _dip_velocity * delta, -landing_dip_max, landing_dip_max)


func _on_vehicle_landed(fall_speed: float) -> void:
	add_trauma(fall_speed * landing_trauma_per_speed)
	_dip_velocity -= fall_speed * landing_dip_per_speed * 10.0


func _on_explosion(pos: Vector3, strength: float) -> void:
	var d := global_position.distance_to(pos)
	if d < 40.0:
		add_trauma(strength * clampf(1.0 - d / 40.0, 0.0, 1.0) * 0.8)


func _on_vehicle_reset() -> void:
	_prev_velocity = Vector3.ZERO
	_lean = Vector3.ZERO
