extends Node
## Headless vehicle sanity test: scripted inputs on the test course, prints telemetry, PASS/FAIL.
## Run:
##   Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/vehicle_autotest.tscn
## Add `-- --jump` for the ramp scenario (full throttle over the ramp line at x=40).
## Add `-- --handbrake-low` for a ~25 km/h handbrake turn (prints heading change);
## Add `-- --flip` to spawn upside down and check the auto-recovery.
## Add `-- --handbrake-high` (steer + hold handbrake 1 s at ~75 km/h) or `-- --handbrake-straight`
## (handbrake only, no steer): prints max drift angle + heading change; fails on spin-outs.
## Add `-- --reverse-throttle`: reverse at speed, then press throttle while still rolling back
## (S then W). Asserts the car does NOT snap around (no instant turn).
## Add `-- --weave` for normal driving (left/right S-curves at speed, NO handbrake): asserts the
## drift chain does not fire boosts and the car keeps its normal speed range.
## Add `-- --drift-chain` for left/right handbrake flicks: asserts links >= 3 and no speed loss.
## add `--hb-legacy` to compare with the old (not speed-scaled) handbrake.

const COURSE := preload("res://src/vehicle/test_drive.tscn")
const DURATION := 14.0

var _taxi: Taxi
var _t: float = 0.0
var _next_log: float = 0.0
var _settled: bool = false
var _max_kmh: float = 0.0
var _min_up: float = 1.0
var _min_speed_reverse: float = 0.0
var _drifted: bool = false
var _spun: bool = false
var _errors: PackedStringArray = []
var _jump_mode: bool = false
var _hb_mode: bool = false
var _flip_mode: bool = false
var _drift_mode: bool = false
var _hbh_mode: bool = false
var _weave_mode: bool = false
var _rev_mode: bool = false
var _rev_yaw0: float = 0.0
var _rev_max_turn: float = 0.0
var _rev_max_yaw_rate: float = 0.0
var _weave_links: int = 0
var _weave_max_kmh: float = 0.0
var _weave_drift_time: float = 0.0
var _hbh_steer: float = 1.0
var _hbh_start_yaw: float = 0.0
var _max_slip_angle: float = 0.0
var _max_links: int = 0
var _banked_points: float = 0.0
var _speed_before_chain: float = 0.0
var _speed_after_chain: float = 0.0
var _recovered_at: float = -1.0
var _hb_start_yaw: float = 0.0
var _airtime: float = 0.0
var _max_height: float = 0.0
var _air_run: float = 0.0          # current continuous airtime
var _min_air_pitch: float = 0.0    # most nose-down pitch while airborne (deg)
var _landing_timer: float = -1.0   # >= 0 while measuring the post-landing rebound
var _landing_pitch: float = 0.0
var _rebound: float = 0.0          # max upward velocity shortly after touchdown (m/s)
var _landings: int = 0
var _hop_height: float = 0.0       # max height above rest after touchdown (m)


func _ready() -> void:
	MapData.use_builtin()   # never the user's edited map
	var course := COURSE.instantiate()
	add_child(course)
	_taxi = course.get_node("Taxi") as Taxi
	_taxi.input_provider = self
	_jump_mode = OS.get_cmdline_user_args().has("--jump")
	_hb_mode = OS.get_cmdline_user_args().has("--handbrake-low")
	_flip_mode = OS.get_cmdline_user_args().has("--flip")
	_drift_mode = OS.get_cmdline_user_args().has("--drift-chain")
	_weave_mode = OS.get_cmdline_user_args().has("--weave")
	_rev_mode = OS.get_cmdline_user_args().has("--reverse-throttle")
	if _weave_mode:
		var wchain := _taxi.get_node("DriftChain") as DriftChain
		wchain.chain_link.connect(func(_l: int, _m: float) -> void: _weave_links += 1)
	_hbh_mode = OS.get_cmdline_user_args().has("--handbrake-high") or OS.get_cmdline_user_args().has("--handbrake-straight")
	if OS.get_cmdline_user_args().has("--handbrake-straight"):
		_hbh_steer = 0.0
	if _drift_mode:
		var chain := _taxi.get_node("DriftChain") as DriftChain
		chain.chain_link.connect(func(links: int, mult: float) -> void:
			_max_links = maxi(_max_links, links)
			print("[Autotest]   link %d  x%.2f  at %.1f km/h" % [links, mult, _taxi.linear_velocity.length() * 3.6]))
		chain.chain_banked.connect(func(pts: float, links: int) -> void:
			_banked_points += pts
			print("[Autotest]   banked %.0f pts (%d links)" % [pts, links]))
		print("[Autotest] DRIFT-CHAIN scenario")
	if _flip_mode:
		_taxi.global_transform = Transform3D(Basis(Vector3.FORWARD, PI), Vector3(0.0, 2.0, 0.0))
		_taxi.reset_performed.connect(func() -> void: _recovered_at = _t)
		print("[Autotest] FLIP scenario (spawned upside down)")
	if OS.get_cmdline_user_args().has("--hb-legacy"):
		_taxi.handbrake_min_speed = 0.0
		_taxi.handbrake_full_speed = 0.01
	if _jump_mode:
		_taxi.global_position = Vector3(40.0, 1.2, 15.0)
		print("[Autotest] JUMP scenario")


## Scripted driver (called by the taxi each physics tick).
func poll(input: VehicleInput) -> void:
	input.clear()
	if _flip_mode:
		return
	if _rev_mode:
		if _t < 1.0:
			return
		if _t < 4.0:
			input.brake = 1.0          # reverse up to speed
		elif _t < 6.0:
			input.throttle = 1.0       # W while still rolling backwards
			if is_equal_approx(snappedf(_t, 1.0 / 60.0), 4.0):
				_rev_yaw0 = _taxi.global_rotation.y
				print("[Autotest] reversing at %.1f m/s, now pressing throttle" % _taxi.forward_speed)
			_rev_max_turn = maxf(_rev_max_turn, rad_to_deg(absf(angle_difference(_rev_yaw0, _taxi.global_rotation.y))))
			_rev_max_yaw_rate = maxf(_rev_max_yaw_rate, rad_to_deg(absf(_taxi.angular_velocity.y)))
		return
	if _weave_mode:
		if _t < 1.0:
			return
		input.throttle = 1.0
		if _t >= 4.5 and _t < 10.5:
			input.steer = -1.0 if int((_t - 4.5) / 0.8) % 2 == 0 else 1.0
			_weave_max_kmh = maxf(_weave_max_kmh, _taxi.linear_velocity.length() * 3.6)
			if _taxi.is_drifting:
				_weave_drift_time += 1.0 / 60.0
		return
	if _hbh_mode:
		const HB_START := 4.5
		if _t < 1.0:
			return
		input.throttle = 1.0
		if _t >= HB_START and _t < HB_START + 1.0:
			input.steer = _hbh_steer
			input.handbrake = true
		if is_equal_approx(snappedf(_t, 1.0 / 60.0), HB_START):
			_hbh_start_yaw = _taxi.global_rotation.y
		if _t > HB_START and _t < HB_START + 2.0:
			var fwd := -_taxi.global_basis.z
			var vel := _taxi.linear_velocity
			if Vector2(vel.x, vel.z).length() > 3.0:
				var slip := rad_to_deg(absf(Vector2(fwd.x, fwd.z).angle_to(Vector2(vel.x, vel.z))))
				_max_slip_angle = maxf(_max_slip_angle, slip)
		return
	if _drift_mode:
		const START := 4.5
		const FLICK := 0.8
		const FLICKS := 8
		if _t < 1.0:
			return
		input.throttle = 1.0
		if _t >= START and _t < START + FLICK * FLICKS:
			# Like a player: steer into the flick with a short handbrake tap, then straighten.
			var phase := int((_t - START) / FLICK)
			var in_flick := fmod(_t - START, FLICK)
			input.steer = (-1.0 if phase % 2 == 0 else 1.0) if in_flick < 0.45 else 0.0
			input.handbrake = in_flick < 0.2
		if is_equal_approx(snappedf(_t, 1.0 / 60.0), START):
			_speed_before_chain = _taxi.linear_velocity.length() * 3.6
		if is_equal_approx(snappedf(_t, 1.0 / 60.0), START + FLICK * FLICKS):
			_speed_after_chain = _taxi.linear_velocity.length() * 3.6
		return
	if _hb_mode:
		if _t > 1.0 and _t < 2.2:
			input.throttle = 1.0
		elif _t >= 2.2 and _t < 3.7:
			input.throttle = 0.3
			input.steer = 1.0
			input.handbrake = true
		if is_equal_approx(snappedf(_t, 1.0 / 60.0), 2.2):
			_hb_start_yaw = _taxi.global_rotation.y
			print("[Autotest] handbrake starts at %.1f km/h" % _taxi.get_speed_kmh())
		if is_equal_approx(snappedf(_t, 1.0 / 60.0), 3.7):
			var turned := rad_to_deg(absf(angle_difference(_hb_start_yaw, _taxi.global_rotation.y)))
			print("[Autotest] HANDBRAKE-LOW heading change %.0f deg in 1.5 s, speed %.1f km/h" % [turned, _taxi.get_speed_kmh()])
			if turned > 130.0:  # user feedback 2026-11-11: low-speed handbrake must stay gentle (D-019)
				_errors.append("low-speed handbrake too aggressive (%.0f deg)" % turned)
		return
	if _jump_mode:
		input.throttle = 1.0 if _t > 1.0 and _t < 10.0 else 0.0
		input.brake = 1.0 if _t >= 10.0 else 0.0
		return
	if _t < 1.0:
		return                                   # settle on suspension
	elif _t < 5.0:
		input.throttle = 1.0                     # straight acceleration
	elif _t < 7.0:
		input.throttle = 1.0                     # hard left turn
		input.steer = -1.0
	elif _t < 8.0:
		input.throttle = 0.6                     # handbrake flick
		input.steer = 1.0
		input.handbrake = true
	elif _t < 11.0:
		input.brake = 1.0                        # brake to stop...
	else:
		input.brake = 1.0                        # ...then reverse


func _physics_process(delta: float) -> void:
	_t += delta
	var pos := _taxi.global_position
	var up := _taxi.global_basis.y.dot(Vector3.UP)
	if is_nan(pos.x) or is_nan(pos.y) or is_nan(pos.z):
		_fail("position became NaN")
	if absf(pos.y) > 60.0:
		_fail("vehicle left the world (y=%.1f)" % pos.y)
	if _t > 0.95 and not _settled and not _flip_mode:
		_settled = true
		if _taxi.grounded_wheel_count != 4 or up < 0.98:
			_errors.append("did not settle: wheels=%d up=%.2f" % [_taxi.grounded_wheel_count, up])
		print("[Autotest] rest height=%.3f" % pos.y)
	if is_equal_approx(snappedf(_t, 1.0 / 60.0), 5.0) or is_equal_approx(snappedf(_t, 1.0 / 60.0), 6.5):
		print("[Autotest] speed at t=%.1f: %.1f km/h" % [_t, _taxi.get_speed_kmh()])
	if _jump_mode and _t > 1.0:
		_track_jump(delta, pos)
	if not _jump_mode and not _drift_mode and not _hbh_mode and not _weave_mode and not _rev_mode and _t > 5.0 and _t < 7.0 and _taxi.forward_speed < -2.0 and not _spun:
		_spun = true
		_errors.append("spun out during full-lock turn at t=%.2f" % _t)
	if _t > 1.0:
		_min_up = minf(_min_up, up)
		_max_kmh = maxf(_max_kmh, _taxi.get_speed_kmh())
		_drifted = _drifted or _taxi.is_drifting
		_min_speed_reverse = minf(_min_speed_reverse, _taxi.forward_speed)
	if _t >= _next_log:
		_next_log += 0.5
		print("[Autotest] t=%5.2f pos=(%7.1f,%5.2f,%7.1f) %5.1f km/h fwd=%6.2f wheels=%d up=%.2f %s%s" % [
			_t, pos.x, pos.y, pos.z, _taxi.get_speed_kmh(), _taxi.forward_speed,
			_taxi.grounded_wheel_count, up, "DRIFT " if _taxi.is_drifting else "",
			"AIR" if not _taxi.is_grounded() else ""])
	if _t >= DURATION:
		_finish()


func _finish() -> void:
	if _max_kmh < 70.0 and not _hb_mode and not _flip_mode and not _drift_mode and not _hbh_mode and not _weave_mode and not _rev_mode:
		_errors.append("top speed too low: %.1f km/h" % _max_kmh)
	if _min_up < 0.5 and not _flip_mode:
		_errors.append("vehicle rolled over (min up=%.2f)" % _min_up)
	if _rev_mode:
		print("[Autotest] REVERSE-THROTTLE: heading change %.0f deg, max yaw rate %.0f deg/s" % [_rev_max_turn, _rev_max_yaw_rate])
		if _rev_max_turn > 20.0:
			_errors.append("car snaps around when throttling out of a reverse (%.0f deg)" % _rev_max_turn)
	if _weave_mode:
		print("[Autotest] WEAVE (no handbrake): drift-chain links %d, time flagged drifting %.1f s, max %.0f km/h, min up %.2f" % [
			_weave_links, _weave_drift_time, _weave_max_kmh, _min_up])
		if _weave_links > 0:
			_errors.append("drift chain fired %d boosts during normal (no-handbrake) driving" % _weave_links)
		if _weave_max_kmh > 125.0:
			_errors.append("normal driving exceeded top speed (%.0f km/h)" % _weave_max_kmh)
	if _hbh_mode:
		var turned := rad_to_deg(absf(angle_difference(_hbh_start_yaw, _taxi.global_rotation.y)))
		print("[Autotest] HANDBRAKE-HIGH steer=%.0f: max drift angle %.0f deg, heading change %.0f deg, end %.0f km/h fwd=%.1f" % [
			_hbh_steer, _max_slip_angle, turned, _taxi.linear_velocity.length() * 3.6, _taxi.forward_speed])
		if _max_slip_angle > 60.0:
			_errors.append("handbrake spins the car (drift angle %.0f deg > 60)" % _max_slip_angle)
	if _drift_mode:
		print("[Autotest] DRIFT-CHAIN max links %d, banked %.0f pts, speed %.1f -> %.1f km/h" % [
			_max_links, _banked_points, _speed_before_chain, _speed_after_chain])
		if _max_links < 3:
			_errors.append("drift chain too short (%d links)" % _max_links)
		if _speed_after_chain < _speed_before_chain * 0.9:
			_errors.append("chain lost momentum (%.1f -> %.1f km/h)" % [_speed_before_chain, _speed_after_chain])
	if _flip_mode:
		var up_now := _taxi.global_basis.y.dot(Vector3.UP)
		print("[Autotest] FLIP recovered at t=%.2f, final up=%.2f wheels=%d" % [_recovered_at, up_now, _taxi.grounded_wheel_count])
		if _recovered_at < 0.0 or up_now < 0.95 or _taxi.grounded_wheel_count < 4:
			_errors.append("flip recovery failed")
	elif _hb_mode:
		pass
	elif _jump_mode:
		print("[Autotest] airtime %.2f s, max height %.1f m" % [_airtime, _max_height])
		if _airtime < 0.5:
			_errors.append("never got real air (%.2f s)" % _airtime)
	elif not _hb_mode and not _flip_mode and not _drift_mode and not _hbh_mode and not _weave_mode and not _rev_mode and _min_speed_reverse > -2.0:
		_errors.append("did not reverse (min forward speed=%.2f)" % _min_speed_reverse)
	print("[Autotest] max %.1f km/h, min up %.2f, drifted=%s, min fwd %.2f" % [
		_max_kmh, _min_up, _drifted, _min_speed_reverse])
	if _errors.is_empty():
		print("[Autotest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[Autotest] FAIL: ", e)
		get_tree().quit(1)


func _track_jump(delta: float, pos: Vector3) -> void:
	# Logs every airborne phase: duration, apex above rest height, touchdown pitch.
	# Main jumps show long airtime; landing bounces show as short hops right after.
	var pitch := rad_to_deg(asin(clampf(-_taxi.global_basis.z.y, -1.0, 1.0)))  # + = nose up
	_max_height = maxf(_max_height, pos.y)
	if not _taxi.is_grounded():
		_airtime += delta
		_air_run += delta
		_hop_height = maxf(_hop_height, pos.y - 0.662)
		_min_air_pitch = minf(_min_air_pitch, pitch)
		return
	if _air_run > 0.05:
		_landings += 1
		print("[Autotest] AIR %d: %.2f s, apex %+.2f m vs rest, min pitch %.1f, touchdown pitch %.1f deg" % [
			_landings, _air_run, _hop_height, _min_air_pitch, pitch])
	_air_run = 0.0
	_hop_height = 0.0
	_min_air_pitch = 0.0


func _fail(msg: String) -> void:
	_errors.append(msg)
	_finish()
	set_physics_process(false)
