extends Node
## Headless weapon test on the test course (input simulated with Input.action_press):
##  1. aim raises the gun; one revolver shot at a board 12 m ahead -> damage, ammo -1, hit marker
##  2. the shot never hits the taxi itself (board took the damage)
##  3. empty the mag -> auto reload on fire / R reload refills from reserve
##  4. switch to SMG (key 2): hold fire 1 s -> ~fire_rate shots, automatic
##  5. switch to shotgun (key 3): one shot = several pellet hits on a close board
##  6. spread grows with speed (measured while driving)
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/weapon_autotest.tscn

const COURSE := preload("res://src/vehicle/test_drive.tscn")

var _taxi: Taxi
var _wc: WeaponController
var _board: ShootingTarget
var _close_board: ShootingTarget
var _t: float = 0.0
var _step: int = 0
var _step_t: float = 0.0
var _errors: PackedStringArray = []
var _hits: int = 0
var _shots_at_step: int = 0
var _hp_before: float = 0.0
var _spread_still: float = 0.0
var _burst_start: int = -1
var _shotgun_fired: bool = false


func _ready() -> void:
	MapData.use_builtin()   # never the user's edited map
	# A run starts with the revolver only; this test switches through bought weapons.
	GameState.owned_weapons = [&"revolver", &"smg", &"shotgun", &"rifle"]
	var course := COURSE.instantiate()
	add_child(course)
	_taxi = course.get_node("Taxi") as Taxi
	EventBus.hit_confirmed.connect(func(_k: bool) -> void: _hits += 1)


func _physics_process(delta: float) -> void:
	_t += delta
	_step_t += delta
	if _t > 40.0:
		_fail("timeout at step %d" % _step)
		return
	match _step:
		0:
			if _t > 1.0:  # taxi settled; place boards in front of the camera
				_wc = get_tree().get_first_node_in_group(&"weapon_controller") as WeaponController
				var cam := _wc.get_parent() as Camera3D
				var ahead := -cam.global_basis.z
				ahead.y = 0.0
				ahead = ahead.normalized()
				_board = _spawn_board(cam.global_position + ahead * 12.0, cam.global_position.y)
				# Close board for the shotgun, parked 40 m to the side until needed.
				_close_board = _spawn_board(cam.global_position + ahead * 6.0 + Vector3(40, 0, 0), cam.global_position.y)
				_next()
		1:  # aim
			Input.action_press(&"aim")
			if _wc.raise_amount >= 1.0 and _step_t > 0.4:
				print("[WeaponTest] gun raised, weapon=%s, spread aimed=%.2f deg" % [_wc.current_weapon().id, _wc.current_spread_deg])
				_spread_still = _wc.current_spread_deg
				_hp_before = _board.health.hp
				_shots_at_step = _wc.shots_fired
				Input.action_press(&"fire")
				_next()
		2:
			Input.action_release(&"fire")
			if _step_t > 0.3:
				var a := _wc.get_ammo()
				print("[WeaponTest] revolver shot: board hp %.0f -> %.0f, mag %d, hit markers %d" % [_hp_before, _board.health.hp, a["mag"], _hits])
				if _board.health.hp >= _hp_before:
					_errors.append("revolver shot did not damage the board (self-hit or miss)")
				if a["mag"] != 5:
					_errors.append("mag should be 5 after one shot, is %d" % a["mag"])
				if _hits < 1:
					_errors.append("no hit marker")
				_next()
		3:  # empty the revolver (tap fire) -> reload starts automatically on the last round
			if _wc.is_reloading:
				Input.action_release(&"fire")
				print("[WeaponTest] auto-reload started when the mag ran dry")
				_next()
			elif int(_wc.get_ammo()["mag"]) > 0:
				if Engine.get_physics_frames() % 30 == 0:
					Input.action_press(&"fire")
				else:
					Input.action_release(&"fire")
			elif _step_t > 8.0:
				_fail("no auto reload on empty mag")
		4:
			if not _wc.is_reloading:
				var a := _wc.get_ammo()
				print("[WeaponTest] reloaded: mag %d reserve %d" % [a["mag"], a["reserve"]])
				if a["mag"] != 6 or a["reserve"] != 36:
					_errors.append("reload math wrong (mag %d reserve %d)" % [a["mag"], a["reserve"]])
				Input.action_press(&"weapon_2")
				_next()
			elif _step_t > 3.0:
				_fail("reload never finished")
		5:  # SMG: hold fire for 1 s once raised
			# Simulated presses need to be held for a couple of frames (like a real key tap).
			if _step_t < 0.1:
				return
			Input.action_release(&"weapon_2")
			if _wc.current_weapon().id != &"smg":
				_fail("weapon_2 did not select the SMG")
				return
			if _step_t > 0.8 and _burst_start < 0:
				_burst_start = _wc.shots_fired
				Input.action_press(&"fire")
			if _burst_start >= 0 and _step_t > 1.8:
				Input.action_release(&"fire")
				var fired := _wc.shots_fired - _burst_start
				print("[WeaponTest] SMG auto fire: %d shots in 1.0 s (fire_rate %.0f)" % [fired, _wc.current_weapon().fire_rate])
				if fired < 8 or fired > 13:
					_errors.append("SMG automatic fire count off (%d)" % fired)
				Input.action_press(&"weapon_3")
				_next()
		6:  # shotgun at a close board
			if _step_t > 0.1:
				Input.action_release(&"weapon_3")
			if _step_t > 0.15 and _step_t < 0.17:
				_close_board.position.x -= 40.0   # swap: close board in, far board out
				_board.position.x += 40.0
			if _step_t > 1.0 and not _shotgun_fired:
				_shotgun_fired = true
				_hp_before = _close_board.health.hp
				Input.action_press(&"fire")
			if _shotgun_fired and _step_t > 1.4:
				Input.action_release(&"fire")
				var dmg := _hp_before - _close_board.health.hp
				print("[WeaponTest] shotgun: %s, one shot dealt %.0f damage (%.0f per pellet)" % [_wc.current_weapon().id, dmg, _wc.current_weapon().damage])
				if dmg < _wc.current_weapon().damage * 3.0:
					_errors.append("shotgun pellets: expected several pellet hits, dealt %.0f" % dmg)
				Input.action_release(&"aim")
				_next()
		7:  # spread grows with speed (clear the road first)
			if _step_t < 0.02:
				_close_board.position.x += 40.0
			_taxi.input_provider = self
			if _step_t > 3.0:
				Input.action_press(&"aim")
			if _step_t > 3.6:
				print("[WeaponTest] shotgun spread still %.2f vs driving %.0f km/h %.2f deg" % [
					_spread_for(&"shotgun"), _taxi.get_speed_kmh(), _wc.current_spread_deg])
				if _wc.current_spread_deg <= _spread_for(&"shotgun") + 0.3:
					_errors.append("spread does not grow with speed")
				Input.action_release(&"aim")
				_finish()


func poll(input: VehicleInput) -> void:
	input.clear()
	input.throttle = 1.0


func _spread_for(id: StringName) -> float:
	var w := load("res://data/weapons/%s.tres" % id) as WeaponData
	return w.spread_aimed


func _spawn_board(pos: Vector3, eye_y: float) -> ShootingTarget:
	var b := ShootingTarget.new()
	b.board_height = 1.6
	add_child(b)
	b.global_position = Vector3(pos.x, eye_y - 1.6, pos.z)  # board centre at eye height
	return b


func _next() -> void:
	_step += 1
	_step_t = 0.0


func _fail(msg: String) -> void:
	_errors.append(msg)
	_finish()


func _finish() -> void:
	set_physics_process(false)
	for action: StringName in [&"aim", &"fire", &"weapon_2", &"weapon_3"]:
		Input.action_release(action)
	if _errors.is_empty():
		print("[WeaponTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[WeaponTest] FAIL: ", e)
		get_tree().quit(1)
