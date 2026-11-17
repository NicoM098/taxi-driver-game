extends Node
## Ammo drops (D-094), headless on the test course:
##  A. which gun a box is for: weighted to the emptiest equipped gun; size = 30 % of the reserve
##     (at least a magazine)
##  B. a killed enemy drops a box on the road (a boss drops several, at most MAX_BOXES)
##  C. driving through a box adds its rounds to that gun (capped at the reserve), the box goes,
##     EventBus.ammo_picked_up fires; a box for a full gun stays
##  D. an untouched box disappears after LIFETIME
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/ammo_drop_autotest.tscn

const COURSE := preload("res://src/vehicle/test_drive.tscn")

var _taxi: Taxi
var _wc: WeaponController
var _errors: PackedStringArray = []
var _picked: Array = []
var _throttle: bool = false


func _ready() -> void:
	MapData.use_builtin()
	GameState.reset_run()
	GameState.owned_weapons = [&"revolver", &"smg"]
	var course := COURSE.instantiate()
	add_child(course)
	_taxi = course.get_node("Taxi") as Taxi
	EventBus.ammo_picked_up.connect(func(id: StringName, n: int) -> void: _picked.append([id, n]))
	_run()


func poll(input: VehicleInput) -> void:
	input.clear()
	input.throttle = 1.0 if _throttle else 0.0
	input.brake = 0.0 if _throttle else 1.0


func _check(ok: bool, what: String) -> void:
	print("[AmmoDropTest] %s %s" % ["OK  " if ok else "FAIL", what])
	if not ok:
		_errors.append(what)


func _run() -> void:
	await _wait(1.0)
	_wc = get_tree().get_first_node_in_group(&"weapon_controller") as WeaponController
	_taxi.input_provider = self
	var smg := _wc.get_weapon(&"smg")
	var revolver := _wc.get_weapon(&"revolver")

	# --- A. picking ---------------------------------------------------------------------------
	_wc.ammo[&"smg"]["reserve"] = 0
	_wc.ammo[&"smg"]["mag"] = 0
	var smg_picks := 0
	for i in 400:
		if AmmoPickup.pick_weapon(_wc).id == &"smg":
			smg_picks += 1
	_check(smg_picks > 300 and smg_picks < 400, "empty SMG gets most boxes, the full revolver some (%d / 400)" % smg_picks)
	_check(AmmoPickup.amount_for(smg) == ceili(smg.reserve_max * 0.3) and AmmoPickup.amount_for(revolver) >= revolver.mag_size,
			"box size: SMG %d, revolver %d" % [AmmoPickup.amount_for(smg), AmmoPickup.amount_for(revolver)])

	# --- B. enemies drop them -----------------------------------------------------------------
	var before := get_tree().get_nodes_in_group(&"ammo_pickups").size()
	var car := EnemyCar.new()
	car.data = load("res://data/enemies/gang_red.tres") as EnemyCarData
	add_child(car)
	car.global_position = Vector3(20, 1.0, -60)
	await _wait(0.3)
	car.health.apply_damage(99999.0)
	await get_tree().physics_frame
	var boxes := get_tree().get_nodes_in_group(&"ammo_pickups")
	_check(boxes.size() == before + 1, "a gang car drops one box (%d)" % (boxes.size() - before))
	if not boxes.is_empty():
		var b := boxes.back() as AmmoPickup
		_check(absf(b.global_position.y) < 1.0 and Vector2(b.global_position.x - 20, b.global_position.z + 60).length() < 1.0,
				"the box sits on the road where the car died (%s)" % b.global_position)
		b.queue_free()
	var boss := AmmoPickup.drop_for_kill(self, Vector3(-20, 1, -60), 1800.0)
	_check(boss.size() == AmmoPickup.MAX_BOXES, "a 1800 hp boss drops %d boxes" % boss.size())
	for b in boss:
		b.queue_free()

	# --- C. driving through ---------------------------------------------------------------------
	var box := AmmoPickup.new()
	box.weapon_id = &"smg"
	add_child(box)
	box.global_position = _taxi.global_position - _taxi.global_transform.basis.z * 22.0
	box.global_position.y = 0.0
	var full := AmmoPickup.new()
	full.weapon_id = &"revolver"
	add_child(full)
	full.global_position = _taxi.global_position - _taxi.global_transform.basis.z * 12.0
	full.global_position.y = 0.0
	var shot_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			shot_dir = arg.get_slice("=", 1)
	if not shot_dir.is_empty():
		await _wait(0.6)
		get_viewport().get_texture().get_image().save_png(shot_dir.path_join("ammo_boxes.png"))
	_throttle = true
	var t := 0.0
	while is_instance_valid(box) and t < 8.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
	_throttle = false
	var got := int(_wc.ammo[&"smg"]["reserve"])
	_check(not is_instance_valid(box), "the SMG box was taken by driving through it (%.1f s)" % t)
	_check(got == AmmoPickup.amount_for(smg), "SMG reserve 0 -> %d" % got)
	_check(_picked.size() == 1 and _picked[0][0] == &"smg", "ammo_picked_up fired once for the SMG (%s)" % [_picked])
	_check(is_instance_valid(full), "a box for the full revolver stays on the road")
	_wc.ammo[&"smg"]["reserve"] = smg.reserve_max - 3
	var top := AmmoPickup.new()
	top.weapon_id = &"smg"
	add_child(top)
	top.global_position = Vector3(0, -300, 0)
	_check(top.collect(_wc) and int(_wc.ammo[&"smg"]["reserve"]) == smg.reserve_max, "a box only tops the reserve up to its max")

	# --- D. lifetime --------------------------------------------------------------------------
	if is_instance_valid(full):
		full._time = AmmoPickup.LIFETIME - 0.1
		await _wait(0.3)
		_check(not is_instance_valid(full), "an untouched box goes after %.0f s" % AmmoPickup.LIFETIME)
	_finish()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _finish() -> void:
	if _errors.is_empty():
		print("[AmmoDropTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[AmmoDropTest] FAIL: ", e)
		get_tree().quit(1)
