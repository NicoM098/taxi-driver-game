class_name Taxi
extends RigidBody3D
## Arcade raycast-suspension vehicle (player taxi; reused by AI cars in Phase 06).
## Each TaxiWheel probes the ground; this script applies suspension, grip, engine and brake
## forces per wheel. Driving commands come from `input_provider` (any node with poll(VehicleInput)).

signal crashed(impact: float)   # sudden velocity change (m/s in one tick)
signal reset_performed
signal landed(fall_speed: float)   # touchdown after a real jump (m/s downward)

@export var input_provider: Node
@export var steering_wheel: Node3D
@export var steering_wheel_turns: float = 2.4  # visual rad at full lock

@export_group("Suspension")
@export var rest_length: float = 0.45
@export var spring_strength: float = 22000.0
@export var spring_damping: float = 2400.0
@export var wheel_radius: float = 0.35

@export_group("Engine")
@export var engine_force: float = 9000.0
@export var max_speed: float = 33.0          # m/s (~120 km/h)
@export var reverse_force_mult: float = 0.6
@export var reverse_max_speed: float = 10.0
@export var brake_force: float = 14000.0
@export var boost_force: float = 6000.0
@export var boost_max_speed: float = 42.0    # m/s (~150 km/h)
@export var rolling_resistance: float = 40.0 # N per (m/s) per wheel
@export var air_drag: float = 0.9            # N per (m/s)^2

@export_group("Grip")
@export var front_grip: float = 1.6          # friction coefficient vs. wheel load
@export var rear_grip: float = 1.9           # > front = stable understeer; handbrake breaks it loose
## Arcade assist: damps yaw rate beyond what the steering asks for (prevents spin-outs).
## Reduced (not removed) while the handbrake is held so drifts stay possible but controllable.
@export var yaw_stability: float = 2500.0
@export_range(0.0, 1.0) var handbrake_yaw_stability_factor: float = 0.25
@export var handbrake_rear_grip: float = 0.6
@export var handbrake_force: float = 4000.0       # longitudinal braking at low speed
@export var handbrake_force_drift: float = 4000.0 # at drift speed: a tap should slide, not stop
## Handbrake effect (grip loss + reduced yaw stability) scales with speed: none below
## `handbrake_min_speed`, full at `handbrake_full_speed` (m/s). Keeps it gentle when slow.
@export var handbrake_min_speed: float = 3.0
@export var handbrake_full_speed: float = 12.0
@export var lateral_stiffness: float = 0.6   # fraction of sideways speed cancelled per tick
@export var downforce: float = 4.0           # N per (m/s)^2
@export var drift_slip_threshold: float = 3.0
## Arcade assist: fraction of the speed-scrubbing drag from sideways tyre forces that is
## given back along the direction of travel (0 = realistic scrub, 1 = turns cost no speed).
@export_range(0.0, 1.0) var turn_speed_retention: float = 0.7
## Same, while drifting at speed: higher so drifts (and drift chains) keep their momentum.
## Blends in between drift_assist_min_speed and drift_assist_full_speed (m/s) so the
## low-speed handbrake stays gentle (D-019).
@export_range(0.0, 1.0) var drift_speed_retention: float = 0.7
@export var drift_assist_min_speed: float = 10.0
@export var drift_assist_full_speed: float = 16.0

@export_group("Drift control")
## Arcade drift limiter: the car may slide up to this angle between its nose and its travel
## direction; beyond it a corrective yaw torque pushes back (no handbrake spin-outs).
@export var max_drift_angle_deg: float = 40.0
@export var drift_angle_stiffness: float = 60000.0  # N·m per rad beyond the limit
@export var drift_angle_damping: float = 20000.0     # N·m per rad/s of yaw rate pushing past it

@export_group("Steering")
@export var max_steer_angle_deg: float = 32.0
@export var high_speed_steer_factor: float = 0.25
@export var steer_speed: float = 4.0         # input units / s
@export var steer_return_speed: float = 6.0

@export_group("Air & Landing")
@export var air_control_torque: float = 2500.0   # steering = yaw in the air
## Self-levelling in the air (PD torque toward level pitch/roll) so the nose doesn't dive.
@export var air_level_strength: float = 28000.0
@export var air_level_damping: float = 11000.0
@export var air_target_pitch_deg: float = 0.0
## Landing bounce: on touchdown after `landing_min_airtime`, give back this fraction of the
## downward speed as an upward kick, and damp the nose-down rotation.
@export_range(0.0, 1.0) var landing_bounce: float = 0.7
@export var landing_max_bounce_speed: float = 5.5
@export_range(0.0, 1.0) var landing_pitch_damp: float = 0.6
@export var landing_min_airtime: float = 0.25
## After the bounce kick the suspension stops pushing/damping while the car rises, for at most
## this long, so the hop is a clean ballistic arc: height = kick^2 / (2 * g_eff). Predictable.
@export var bounce_free_rebound_time: float = 0.25

@export_group("Limp mode (wrecked)")
## A wrecked taxi still moves, badly, until it reaches a repair shop (TaxiDamage sets `limp`).
@export var limp_max_speed: float = 8.5       # m/s (~30 km/h)
@export var limp_engine_mult: float = 0.45
@export var limp_misfire_period: float = 1.9  # s; the engine cuts out once per period...
@export var limp_misfire_time: float = 0.45   # ...for this long
@export var limp_steer_wander: float = 0.22   # steering pulls left / right by this much
@export var limp_grip_mult: float = 0.8

@export_group("Recovery")
@export var flip_reset_delay: float = 2.5
@export var crash_threshold: float = 3.0     # m/s change in one tick

var input: VehicleInput = VehicleInput.new()
var wheels: Array[TaxiWheel] = []
var forward_speed: float = 0.0   # m/s along the car's forward axis (+ = forwards)
var grounded_wheel_count: int = 0
var is_drifting: bool = false
var is_boosting: bool = false
var steer_value: float = 0.0     # smoothed steering input -1..1
var limp: bool = false           # wrecked: slow, misfiring, pulling to the sides
var _limp_time: float = 0.0

var _steer_angle: float = 0.0
var _prev_velocity: Vector3 = Vector3.ZERO
var _flipped_time: float = 0.0
var _reset_requested: bool = false
var _skip_crash_check: bool = true
var _lateral_force_sum: Vector3 = Vector3.ZERO
var _wheelbase: float = 2.76
var _airtime: float = 0.0
var _air_fall_speed: float = 0.0
var _pending_bounce: float = 0.0     # upward kick (m/s) waiting for the suspension to bottom out
var _bounce_window: float = 0.0
var _free_rebound_time: float = 0.0
var _handbrake_amount: float = 0.0   # 0..1 effective handbrake strength (speed-scaled)
var _speed_bonus: float = 0.0        # temporary top-speed raise (drift chain), m/s
var _speed_bonus_time: float = 0.0
var _teleport_to: Variant = null     # Transform3D requested by teleport()
var rear_slip_signed: float = 0.0    # average sideways slip of the rear wheels (sign = drift side)
## Engine audio (D-066): three loops crossfaded and pitched by revs, plus the tyres.
const ENGINE_LAYERS: Array[StringName] = [&"engine_idle", &"engine_mid", &"engine_high"]
const ENGINE_DB: float = -6.0
const TYRE_DB: float = -6.0

## A gearbox. One tone rising from a standstill to top speed is the single thing that reads as
## fake (user, 2026-11-14: "al no tener el efecto de cambios y ser un ruido constante, es un poco
## irrealista y molesto"), so the revs run up inside a gear and drop when it shifts. Each entry is
## the fraction of top speed at which that gear runs out.
const GEAR_TOPS: Array[float] = [0.15, 0.31, 0.49, 0.71, 1.01]
## Deliberately narrow: the complaint was that it got shrill at the top (was 0.72 - 1.65).
const GEAR_PITCH_LO: float = 0.80
const GEAR_PITCH_HI: float = 1.24
const SHIFT_TIME: float = 0.16

var _engine_players: Array[AudioStreamPlayer] = []
var _tyre_player: AudioStreamPlayer = null
var _revs: float = 0.0           # 0..1 within the current gear
var _gear: int = 0
var _shift_t: float = 0.0        # counts down through a gear change (the throttle-cut dip)
var _headlights: Array[SpotLight3D] = []
var _headlight_lenses: Array[MeshInstance3D] = []
var _lens_lit: Material = load("res://assets/materials/headlight.tres")
var _lens_dark: Material = load("res://assets/materials/headlight_off.tres")


func _ready() -> void:
	for child in find_children("*", "TaxiWheel", true, false):
		var wheel := child as TaxiWheel
		wheel.setup(self, rest_length, wheel_radius)
		wheels.append(wheel)
	if wheels.is_empty():
		push_error("[Taxi] no TaxiWheel children found")
		return
	var front_z := 0.0
	var rear_z := 0.0
	for wheel in wheels:
		if wheel.is_front:
			front_z = minf(front_z, wheel.position.z)
		else:
			rear_z = maxf(rear_z, wheel.position.z)
	_wheelbase = maxf(rear_z - front_z, 0.5)
	_add_headlights()
	_add_engine_audio()
	EventBus.mood_changed.connect(_on_mood_changed)
	# The city may have set the mood before this taxi existed (tests build bare worlds with no
	# city at all, where the headlights stay on).
	var city := get_tree().get_first_node_in_group(&"city") as City
	if city != null:
		_set_headlights(Lighting.headlights_on(city.mood()))


## --- Engine and tyre audio (D-066) ----------------------------------------------------------
## Three generated loops (idle / mid / high) crossfaded by revs and pitched together: the classic
## arcade engine. `Audio` is an autoload and silent in headless runs, so the tests stay quiet.
func _add_engine_audio() -> void:
	if not Audio.enabled:
		return
	for layer in ENGINE_LAYERS:
		var p := Audio.make_loop(layer, self, Audio.BUS_ENGINE)
		p.play()
		_engine_players.append(p)
	_tyre_player = Audio.make_loop(&"tyre_screech", self, Audio.BUS_SFX)
	_tyre_player.play()


func _update_engine_audio(delta: float) -> void:
	if _engine_players.is_empty():
		return
	var speed_t := clampf(absf(forward_speed) / maxf(max_speed, 1.0), 0.0, 1.0)

	# Which gear the speed puts us in, with a little hysteresis so it cannot flutter on a boundary.
	var g := 0
	while g < GEAR_TOPS.size() - 1 and speed_t >= GEAR_TOPS[g]:
		g += 1
	if g < _gear:
		var prev_floor: float = 0.0 if _gear == 0 else GEAR_TOPS[_gear - 1]
		if speed_t > prev_floor - 0.03:
			g = _gear
	if g != _gear:
		_shift_t = SHIFT_TIME
		_gear = g
	_shift_t = maxf(_shift_t - delta, 0.0)

	# Revs climb through the gear and fall back when it changes.
	var lo: float = 0.0 if _gear == 0 else GEAR_TOPS[_gear - 1]
	var hi: float = GEAR_TOPS[_gear]
	var target := clampf((speed_t - lo) / maxf(hi - lo, 0.001), 0.0, 1.0)
	if _gear == 0:
		target = maxf(target, input.throttle * 0.5)   # standing on the gas at a stop
	if is_boosting:
		target = minf(target + 0.12, 1.0)
	if limp:
		target = minf(target, 0.4)
	_revs = lerpf(_revs, target, clampf(delta * 9.0, 0.0, 1.0))

	# Pitch comes from the revs (so it cycles per gear); timbre comes from road speed (so the
	# engine gets fuller as the car gets faster instead of resetting to an idle note every shift).
	var pitch := lerpf(GEAR_PITCH_LO, GEAR_PITCH_HI, _revs) * (0.82 if limp else 1.0)
	var duck := -7.0 * (_shift_t / SHIFT_TIME)      # the throttle cut you hear between gears
	var weights := [
		clampf(1.0 - speed_t * 3.2, 0.0, 1.0),
		clampf(1.0 - absf(speed_t - 0.42) * 2.6, 0.0, 1.0),
		clampf((speed_t - 0.38) * 1.9, 0.0, 1.0),
	]
	var load := 0.45 + 0.55 * clampf(maxf(input.throttle, speed_t), 0.0, 1.0)
	for i in _engine_players.size():
		var p: AudioStreamPlayer = _engine_players[i]
		p.pitch_scale = clampf(pitch * (1.0 + 0.04 * float(i)), 0.1, 3.0)
		var w: float = float(weights[i]) * load
		p.volume_db = ENGINE_DB + duck + linear_to_db(clampf(w, 0.0001, 1.0))

	if _tyre_player == null:
		return
	# Two different noises share one sample: a drift squeal (lateral slip, higher) and the scrub
	# of braking hard at speed (lower). Braking never made a sound before (user, 2026-11-14).
	var slip := absf(rear_slip_signed)
	var drift_loud := clampf((slip - drift_slip_threshold * 0.6) / (drift_slip_threshold * 2.0), 0.0, 1.0)
	var speed_abs := absf(forward_speed)
	var brake_loud := 0.0
	if speed_abs > 6.0:
		var hard := 1.0 if input.handbrake else clampf((input.brake - 0.45) / 0.55, 0.0, 1.0)
		brake_loud = hard * clampf((speed_abs - 6.0) / 12.0, 0.0, 1.0)
	var loud := maxf(drift_loud, brake_loud)
	if grounded_wheel_count == 0:
		loud = 0.0
	_tyre_player.volume_db = TYRE_DB + linear_to_db(clampf(loud, 0.0001, 1.0))
	_tyre_player.pitch_scale = lerpf(0.84, 1.16, drift_loud) if drift_loud >= brake_loud else 0.76



func _on_mood_changed(mood: int) -> void:
	_set_headlights(Lighting.headlights_on(mood as Lighting.Mood))


## Headlights off in daylight (D-065): the user drove all three moods and the one thing that read
## as wrong was the car and the street being lit at midday.
func _set_headlights(on: bool) -> void:
	for spot in _headlights:
		spot.visible = on
	for lens in _headlight_lenses:
		lens.material_override = _lens_lit if on else _lens_dark


## Headlights (D-064). Built in code so taxi.tscn stays hand-editable.
func _add_headlights() -> void:
	var lens := BoxMesh.new()
	lens.size = Vector3(0.34, 0.16, 0.08)
	var lens_mat: Material = _lens_lit
	for side in [-1.0, 1.0]:
		var mesh := MeshInstance3D.new()
		mesh.mesh = lens
		mesh.material_override = lens_mat
		mesh.position = Vector3(side * 0.62, 0.02, -2.32)
		add_child(mesh)

		var spot := SpotLight3D.new()
		spot.position = Vector3(side * 0.62, 0.35, -2.36)
				# Aimed well down at the tarmac: a headlight only 0.5 m off the ground that points straight
		# ahead hits the road at a grazing angle, where lambert gives it almost nothing (measured).
		spot.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
		spot.spot_range = 45.0
		spot.spot_angle = 38.0
		spot.spot_angle_attenuation = 1.0
		spot.spot_attenuation = 1.0
		spot.light_color = Color(1.0, 0.95, 0.84)
		spot.light_energy = 45.0
		spot.shadow_enabled = false
		add_child(spot)
		_headlights.append(spot)
		_headlight_lenses.append(mesh)


func _physics_process(delta: float) -> void:
	_poll_input()
	var up := global_basis.y
	forward_speed = -global_basis.z.dot(linear_velocity)
	_update_steering(delta)

	grounded_wheel_count = 0
	var driven_grounded := 0
	for wheel in wheels:
		wheel.force_raycast_update()
		wheel.is_grounded = wheel.is_colliding()
		if wheel.is_grounded:
			grounded_wheel_count += 1
			if wheel.is_driven:
				driven_grounded += 1

	is_boosting = input.boost and input.throttle > 0.0 and grounded_wheel_count > 0 and not limp
	if limp:
		_limp_time += delta
	_handbrake_amount = 0.0
	if input.handbrake:
		_handbrake_amount = clampf(inverse_lerp(handbrake_min_speed, handbrake_full_speed,
			absf(forward_speed)), 0.0, 1.0)
	_update_landing(delta, up)
	var drive := _compute_drive_force()
	var brake := _compute_brake_force()
	var com := global_transform * center_of_mass

	var rear_slip := 0.0
	var rear_sum := 0.0
	var rear_count := 0
	_lateral_force_sum = Vector3.ZERO
	for wheel in wheels:
		_process_wheel(wheel, delta, up, drive, brake, driven_grounded, com)
		if not wheel.is_front:
			rear_slip = maxf(rear_slip, absf(wheel.lateral_slip))
			rear_sum += wheel.lateral_slip
			rear_count += 1
	rear_slip_signed = rear_sum / float(maxi(rear_count, 1))
	is_drifting = grounded_wheel_count > 0 and rear_slip > drift_slip_threshold
	_update_engine_audio(delta)
	_apply_turn_speed_retention()
	_apply_yaw_stability(up)
	_apply_drift_angle_limit(up)

	var speed_sq := linear_velocity.length_squared()
	apply_central_force(-linear_velocity * sqrt(speed_sq) * air_drag)
	if grounded_wheel_count > 0:
		apply_central_force(-up * speed_sq * downforce)
	else:
		_apply_air_control(up)

	if _speed_bonus_time > 0.0:
		_speed_bonus_time -= delta
		if _speed_bonus_time <= 0.0:
			_speed_bonus = 0.0
	_update_flip_recovery(delta, up)
	_check_crash()
	_update_visuals(delta)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not _reset_requested:
		return
	_reset_requested = false
	if _teleport_to is Transform3D:
		state.transform = _teleport_to
		_teleport_to = null
	else:
		var flat_forward := -state.transform.basis.z
		flat_forward.y = 0.0
		if flat_forward.length() < 0.1:
			flat_forward = Vector3.FORWARD
		state.transform = Transform3D(Basis.looking_at(flat_forward.normalized(), Vector3.UP),
			state.transform.origin + Vector3.UP * 1.5)
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	_skip_crash_check = true
	reset_physics_interpolation.call_deferred()
	reset_performed.emit.call_deferred()


## Drift-chain reward: instant forward speed kick (m/s) + temporary top-speed raise.
func add_speed_boost(kick: float, top_bonus: float, duration: float) -> void:
	var flat_forward := -global_basis.z
	flat_forward.y = 0.0
	if flat_forward.length() > 0.1:
		apply_central_impulse(flat_forward.normalized() * kick * mass)
	_speed_bonus = maxf(_speed_bonus, top_bonus)
	_speed_bonus_time = maxf(_speed_bonus_time, duration)


## Moves the taxi (zero velocity) on the next physics step.
func teleport(xform: Transform3D) -> void:
	_teleport_to = xform
	_reset_requested = true


func get_speed_kmh() -> float:
	return absf(forward_speed) * 3.6


func is_grounded() -> bool:
	return grounded_wheel_count > 0


func request_reset() -> void:
	_reset_requested = true


# --- Internals ---------------------------------------------------------------

func _poll_input() -> void:
	if input_provider != null and input_provider.has_method(&"poll"):
		input_provider.call(&"poll", input)
	else:
		input.clear()


## 0 at low speed .. 1 at drift speed: how much of the arcade drift assist applies.
func _drift_assist() -> float:
	return clampf(inverse_lerp(drift_assist_min_speed, drift_assist_full_speed, linear_velocity.length()), 0.0, 1.0)


func _top_speed() -> float:
	if limp:
		return limp_max_speed
	return (boost_max_speed if is_boosting else max_speed) + _speed_bonus


func _update_steering(delta: float) -> void:
	var target := input.steer
	if limp and absf(forward_speed) > 1.0:
		# Bent steering: the wheel wanders, you have to keep correcting.
		target = clampf(target + sin(_limp_time * 1.7) * limp_steer_wander + sin(_limp_time * 0.6) * limp_steer_wander * 0.5, -1.0, 1.0)
	var rate := steer_speed if absf(target) > 0.01 else steer_return_speed
	steer_value = move_toward(steer_value, target, rate * delta)
	var speed_t := clampf(absf(forward_speed) / max_speed, 0.0, 1.0)
	_steer_angle = -deg_to_rad(max_steer_angle_deg) * steer_value * lerpf(1.0, high_speed_steer_factor, speed_t)


func _compute_drive_force() -> float:
	var force := 0.0
	if input.throttle > 0.0 and forward_speed > -1.0:
		var top := _top_speed()
		var ratio := clampf(forward_speed / top, 0.0, 1.0)
		var engine := engine_force
		if limp:
			engine *= 0.0 if fmod(_limp_time, limp_misfire_period) < limp_misfire_time else limp_engine_mult
		force += engine * input.throttle * (1.0 - ratio * ratio)
		if is_boosting:
			force += boost_force
	if input.brake > 0.0 and forward_speed < 1.0:
		var rratio := clampf(-forward_speed / reverse_max_speed, 0.0, 1.0)
		force -= engine_force * reverse_force_mult * input.brake * (1.0 - rratio * rratio)
	return force


func _compute_brake_force() -> float:
	var force := 0.0
	if input.brake > 0.0 and forward_speed >= 1.0:
		force += brake_force * input.brake
	if input.throttle > 0.0 and forward_speed <= -1.0:
		force += brake_force * input.throttle
	return force


func _process_wheel(wheel: TaxiWheel, delta: float, up: Vector3, drive: float, brake: float,
		driven_grounded: int, com: Vector3) -> void:
	wheel.steer_angle = _steer_angle if wheel.is_front else 0.0
	if not wheel.is_grounded:
		wheel.suspension_length = rest_length
		wheel.load_force = 0.0
		wheel.lateral_slip = 0.0
		return

	var hit := wheel.get_collision_point()
	var normal := wheel.get_collision_normal()
	var dist := clampf(wheel.global_position.distance_to(hit) - wheel_radius, 0.0, rest_length)
	wheel.suspension_length = dist
	var point_vel := linear_velocity + angular_velocity.cross(hit - com)

	# Suspension (spring + damper along the car's up axis).
	var spring := (rest_length - dist) * spring_strength
	var vertical_vel := up.dot(point_vel)
	var damper := vertical_vel * spring_damping
	var wheel_load := maxf(spring - damper, 0.0)
	if _free_rebound_time > 0.0 and linear_velocity.y > 0.0:
		wheel_load = 0.0  # bounce in progress: clean hop, springs neither add nor soak energy
	wheel.load_force = wheel_load
	apply_force(up * wheel_load, hit - global_position)

	# Wheel axes projected on the contact plane.
	var wheel_basis := global_basis.rotated(up, wheel.steer_angle)
	var w_forward := (-wheel_basis.z).slide(normal).normalized()
	var w_right := wheel_basis.x.slide(normal).normalized()
	var lat_vel := w_right.dot(point_vel)
	var long_vel := w_forward.dot(point_vel)
	wheel.lateral_slip = lat_vel

	var mass_per_wheel := mass / float(wheels.size())
	var stop_force := absf(long_vel) * mass_per_wheel / delta  # force that would stop this wheel in one tick

	# Lateral grip, limited by friction -> natural slides/drifts.
	var grip := front_grip
	if not wheel.is_front:
		grip = lerpf(rear_grip, handbrake_rear_grip, _handbrake_amount)
	var max_friction := grip * wheel_load
	var lat_force := clampf(-lat_vel * mass_per_wheel / delta * lateral_stiffness, -max_friction, max_friction)

	# Longitudinal: engine, brakes, handbrake, rolling resistance / parking.
	var long_force := 0.0
	if wheel.is_driven and driven_grounded > 0:
		long_force += drive / float(driven_grounded)
	if brake > 0.0:
		long_force -= signf(long_vel) * minf(brake / float(grounded_wheel_count), stop_force)
	if input.handbrake and not wheel.is_front:
		var hb_force := lerpf(handbrake_force, handbrake_force_drift, _drift_assist())
		long_force -= signf(long_vel) * minf(hb_force * 0.5, stop_force)
	if input.throttle < 0.01 and input.brake < 0.01:
		long_force -= long_vel * rolling_resistance
		if absf(long_vel) < 1.0:  # parking: hold still on slopes
			long_force -= signf(long_vel) * minf(stop_force * 0.5, max_friction)

	# Applied at the wheel mount (not the ground) to limit body roll/pitch: arcade stability.
	apply_force(w_right * lat_force + w_forward * long_force, wheel.global_position - global_position)
	_lateral_force_sum += w_right * lat_force


func _apply_yaw_stability(up: Vector3) -> void:
	if yaw_stability <= 0.0 or grounded_wheel_count < 2:
		return
	var strength := yaw_stability * lerpf(1.0, handbrake_yaw_stability_factor, _handbrake_amount)
	# Yaw rate a car rolling without slip would have for this steering angle.
	var target_yaw := forward_speed * tan(_steer_angle) / _wheelbase
	var yaw_rate := angular_velocity.dot(up)
	var excess := yaw_rate - target_yaw
	if absf(yaw_rate) > absf(target_yaw) or signf(yaw_rate) != signf(target_yaw):
		apply_torque(-up * excess * strength)


func _apply_drift_angle_limit(up: Vector3) -> void:
	if grounded_wheel_count < 2:
		return
	var vel := linear_velocity - up * linear_velocity.dot(up)
	var fwd := -global_basis.z
	# Only for forward travel: rolling backwards (e.g. W after reversing) is not a drift.
	# Without this the limiter snapped the car 180° in < 0.5 s (playtest "instant turn").
	if vel.length() < 5.0 or vel.dot(fwd) < 0.0:
		return
	var beta := atan2(up.dot(vel.cross(fwd)), vel.dot(fwd))  # + = nose rotated left of travel
	var excess := absf(beta) - deg_to_rad(max_drift_angle_deg)
	if excess <= 0.0:
		return
	var yaw_rate := angular_velocity.dot(up)
	var torque := -signf(beta) * excess * drift_angle_stiffness
	if signf(yaw_rate) == signf(beta):  # still rotating further out: damp it
		torque -= yaw_rate * drift_angle_damping
	apply_torque(up * torque)


func _apply_turn_speed_retention() -> void:
	if turn_speed_retention <= 0.0 or grounded_wheel_count == 0:
		return
	var speed := linear_velocity.length()
	var top := _top_speed()
	if speed < 2.0 or speed > top:
		return
	var dir := linear_velocity / speed
	var scrub := _lateral_force_sum.dot(dir)  # < 0 when sideways grip is slowing the car
	if scrub < 0.0:
		var retention := turn_speed_retention
		if is_drifting:
			retention = lerpf(turn_speed_retention, drift_speed_retention, _drift_assist())
		apply_central_force(-dir * scrub * retention)


func _apply_air_control(up: Vector3) -> void:
	# Steering yaws the car; throttle/brake do NOT pitch it (holding W made the nose dive).
	apply_torque(up * -input.steer * air_control_torque)
	# PD self-levelling of pitch (about the car's right axis) and roll (about its back axis).
	var right := global_basis.x
	var back := global_basis.z
	var pitch := asin(clampf(-back.y, -1.0, 1.0))      # + = nose up
	var pitch_error := pitch - deg_to_rad(air_target_pitch_deg)
	var roll := asin(clampf(right.y, -1.0, 1.0))       # + = right side up
	var torque := right * (-pitch_error * air_level_strength - angular_velocity.dot(right) * air_level_damping)
	torque += back * (-roll * air_level_strength - angular_velocity.dot(back) * air_level_damping)
	apply_torque(torque)


func _update_landing(delta: float, _up: Vector3) -> void:
	if grounded_wheel_count == 0:
		_airtime += delta
		_air_fall_speed = maxf(-linear_velocity.y, 0.0)
		_pending_bounce = 0.0
		return
	if _airtime >= landing_min_airtime:
		# Touchdown: damp the nose-down rotation so the front doesn't slam...
		var right := global_basis.x
		angular_velocity -= right * angular_velocity.dot(right) * landing_pitch_damp
		# ...and queue the bounce for when the suspension bottoms out (kicking at first
		# contact just gets absorbed by the springs).
		_pending_bounce = minf(_air_fall_speed * landing_bounce, landing_max_bounce_speed)
		landed.emit(_air_fall_speed)
		_bounce_window = 0.35
	_airtime = 0.0
	_free_rebound_time = maxf(_free_rebound_time - delta, 0.0)
	if _pending_bounce > 0.0:
		_bounce_window -= delta
		if linear_velocity.y >= 0.0:
			linear_velocity.y = maxf(linear_velocity.y, _pending_bounce)
			_pending_bounce = 0.0
			_free_rebound_time = bounce_free_rebound_time
		elif _bounce_window <= 0.0:
			_pending_bounce = 0.0


func _update_flip_recovery(delta: float, up: Vector3) -> void:
	if input.reset:
		_reset_requested = true
		_flipped_time = 0.0
		return
	if up.dot(Vector3.UP) < 0.3 and linear_velocity.length() < 4.0:
		_flipped_time += delta
		if _flipped_time > flip_reset_delay:
			_reset_requested = true
			_flipped_time = 0.0
	else:
		_flipped_time = 0.0


func _check_crash() -> void:
	var dv := (linear_velocity - _prev_velocity).length()
	_prev_velocity = linear_velocity
	if _skip_crash_check:
		_skip_crash_check = false
		return
	if dv > crash_threshold:
		crashed.emit(dv)


func _update_visuals(delta: float) -> void:
	for wheel in wheels:
		wheel.update_visual(delta, rest_length, wheel_radius, forward_speed)
	if steering_wheel != null:
		steering_wheel.rotation.y = -steer_value * steering_wheel_turns
