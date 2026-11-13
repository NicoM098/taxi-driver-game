extends Node
## Headless: drive through a Monstrous Energy can -> consumed, driver + taxi healed over ~1 s,
## can hidden, respawns. Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/pickup_autotest.tscn

const COURSE := preload("res://src/vehicle/test_drive.tscn")

var _taxi: Taxi
var _dmg: TaxiDamage
var _can: EnergyDrinkPickup
var _t: float = 0.0
var _consumed_at: float = -1.0
var _driver_before: float = 0.0
var _body_before: float = 0.0
var _errors: PackedStringArray = []
var _done_heal_check: bool = false
var _shot_dir: String = ""


func _ready() -> void:
	MapData.use_builtin()   # never the user's edited map
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			_shot_dir = arg.get_slice("=", 1)
	var course := COURSE.instantiate()
	add_child(course)
	_taxi = course.get_node("Taxi") as Taxi
	_can = EnergyDrinkPickup.new()
	_can.respawn_time = 2.0
	_can.position = Vector3(0, 0, -25)
	add_child(_can)
	EventBus.energy_drink_consumed.connect(func() -> void: _consumed_at = _t)


func poll(input: VehicleInput) -> void:
	input.clear()
	input.throttle = 1.0 if _t > 1.2 and _t < 4.2 else 0.0
	input.brake = 1.0 if _t >= 4.2 and _taxi.forward_speed > 1.0 else 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	if not _shot_dir.is_empty():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		for when: float in [2.5, 4.05, 4.35]:
			if absf(_t - when) < delta * 0.5:
				get_viewport().get_texture().get_image().save_png(_shot_dir.path_join("drink_%.2f.png" % when))
				print("[PickupTest] screenshot %.2f" % when)
	if is_equal_approx(snappedf(_t, 1.0 / 60.0), 1.0):
		_dmg = _taxi.get_node("TaxiDamage") as TaxiDamage
		_dmg.driver_health.apply_damage(60.0)
		_dmg.taxi_health.apply_damage(50.0)
		_driver_before = _dmg.driver_health.hp
		_body_before = _dmg.taxi_health.hp
		_taxi.input_provider = self
		print("[PickupTest] hurt: driver %.0f, taxi %.0f; driving through the can" % [_driver_before, _body_before])
	if _consumed_at > 0.0 and not _done_heal_check and _t > _consumed_at + 1.6:
		_done_heal_check = true
		var dh := _dmg.driver_health.hp - _driver_before
		var bh := _dmg.taxi_health.hp - _body_before
		print("[PickupTest] drank at %.1f s: driver +%.0f, taxi +%.0f, can available=%s" % [_consumed_at, dh, bh, _can.is_available()])
		if dh < 45.0 or bh < 25.0:
			_errors.append("heal too small (driver +%.0f, taxi +%.0f)" % [dh, bh])
		if _can.is_available():
			_errors.append("can should be gone after drinking")
	if _done_heal_check and _t > _consumed_at + 2.6:
		print("[PickupTest] respawned: %s" % _can.is_available())
		if not _can.is_available():
			_errors.append("can did not respawn")
		_finish()
	if _t > 12.0:
		_errors.append("never drove through the can")
		_finish()


func _finish() -> void:
	set_physics_process(false)
	if _errors.is_empty():
		print("[PickupTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[PickupTest] FAIL: ", e)
		get_tree().quit(1)
