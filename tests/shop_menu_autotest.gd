extends Node
## Headless Iteration 18 test through Main: the shop menu (D-089).
##  A. The city has no gun shops / repair garages: their lots are plain buildings.
##  B. Tab (shop_menu) opens the menu and pauses; B again closes it.
##  C. Car upgrades: armor, engine, glass, ram change the taxi; maxed and broke purchases fail.
##  D. Monstrous Energy: buy up to the cup-holder capacity, the rack raises it, F drinks one
##     (and Monstrous XL heals more).
##  E. Repair anywhere for the quoted price.
##  F. Guns from their cards (D-090): one click buys, upgrades, refills, equips; Q / E switch tabs.
##  G. A wreck still ends the run; reset_run clears the levels and the cans.
##  H. Nitro tank: boosting drains it, it refills after a rest, an empty tank relights at
##     nitro_relight, the Nitro Tank upgrade makes it bigger.
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/shop_menu_autotest.tscn
## Windowed + `-- --shot-dir=<dir>` saves screenshots of the menu.

const MAIN := preload("res://src/main/main.tscn")
const TIMEOUT := 60.0

var _taxi: Taxi
var _damage: TaxiDamage
var _city: City
var _menu: ShopMenu
var _t: float = 0.0
var _errors: PackedStringArray = []
var _shot_dir: String = ""
var _done: bool = false


func _ready() -> void:
	ShopMenu.enabled = true
	# Cans and repair are off by default since D-091; this test still covers them (the
	# escalation test checks the default, without them).
	ShopMenu.sells_cans = true
	ShopMenu.sells_repair = true
	MapData.use_builtin()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			_shot_dir = arg.get_slice("=", 1)
	GameState.reset_run()
	add_child(MAIN.instantiate())
	_run()


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT and not _done:
		_errors.append("timeout")
		_finish()


func _process(delta: float) -> void:
	if get_tree().paused:   # physics stops while the menu pauses the world
		_t += delta


func _run() -> void:
	await _until(func() -> bool: return get_tree().get_first_node_in_group(&"player_vehicle") != null, 5.0)
	_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
	_damage = _taxi.get_node("TaxiDamage") as TaxiDamage
	_city = get_tree().get_first_node_in_group(&"city") as City
	_menu = get_tree().get_first_node_in_group(&"shop_menu") as ShopMenu
	var shift := get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
	await _until(func() -> bool: return shift.is_active, 5.0)
	var tutorial := get_tree().get_first_node_in_group(&"tutorial") as Tutorial
	if tutorial != null:
		tutorial.skip()
	await _wait(0.5)

	_test_no_shops()
	await _test_open_close()
	_test_car_upgrades()
	await _test_cans()
	_test_repair()
	await _test_gun_cards()
	_test_nitro()
	await _test_wreck_and_reset()
	_finish()


func _test_no_shops() -> void:
	var lots := 0
	for c in _city.get_children():
		if String(c.name).begins_with("closed_"):
			lots += 1
	print("[ShopMenuTest] A repair shops %d, gun shops %d, closed lots %d" % [
			_city.repair_shops.size(), _city.gun_shops.size(), lots])
	if not _city.repair_shops.is_empty() or not _city.gun_shops.is_empty():
		_errors.append("A: the city still has shops")
	if get_tree().get_first_node_in_group(&"repair_shops") != null or get_tree().get_first_node_in_group(&"gun_shops") != null:
		_errors.append("A: shop nodes in the tree")
	if lots == 0:
		_errors.append("A: no closed lot where the built-in city's shops were")


func _test_open_close() -> void:
	_press(&"shop_menu")
	await _frames(3)
	print("[ShopMenuTest] B after B: open=%s paused=%s" % [_menu.is_open, get_tree().paused])
	if not _menu.is_open or not get_tree().paused:
		_errors.append("B: B did not open the menu / pause the world")
	_shot("shop_menu.png")
	_press(&"shop_menu")
	await _frames(3)
	if _menu.is_open or get_tree().paused:
		_errors.append("B: B again did not close it")


func _test_car_upgrades() -> void:
	_menu.open()
	GameState.cash = 20000
	var force0 := _taxi.engine_force
	var speed0 := _taxi.max_speed
	var hp0 := _damage.taxi_health.max_hp
	var glass0 := _damage.driver_damage_mult
	var ram0 := _damage.crash_damage_scale
	for id: StringName in [&"armor", &"engine", &"glass", &"ram"]:
		if not _menu.activate(id):
			_errors.append("C: could not buy %s" % id)
	print("[ShopMenuTest] C engine %.0f -> %.0f, top speed %.1f -> %.1f, taxi hp %.0f -> %.0f (now %.0f), glass %.2f -> %.2f, ram %.2f -> %.2f" % [
			force0, _taxi.engine_force, speed0, _taxi.max_speed, hp0, _damage.taxi_health.max_hp,
			_damage.taxi_health.hp, glass0, _damage.driver_damage_mult, ram0, _damage.crash_damage_scale])
	_near("C: engine force", _taxi.engine_force, force0 * 1.12)
	_near("C: top speed", _taxi.max_speed, speed0 * 1.06)
	_near("C: taxi max hp", _damage.taxi_health.max_hp, hp0 * 1.25)
	_near("C: taxi hp topped up with the plates", _damage.taxi_health.hp, hp0 * 1.25)
	_near("C: driver damage", _damage.driver_damage_mult, glass0 * 0.8)
	_near("C: crash damage", _damage.crash_damage_scale, ram0 * 0.75)
	# Max out armor: the 4th purchase must fail, and the stat must not stack twice.
	_menu.activate(&"armor")
	_menu.activate(&"armor")
	if _menu.activate(&"armor"):
		_errors.append("C: armor bought past its last level")
	_near("C: armor maxed", _damage.taxi_health.max_hp, hp0 * 1.75)
	GameState.cash = 10
	if _menu.activate(&"engine"):
		_errors.append("C: bought an upgrade with $10")
	_menu.close()


func _test_cans() -> void:
	GameState.cash = 5000
	_menu.open()
	_menu.activate(ShopMenu.CANS)
	_menu.activate(ShopMenu.CANS)
	if GameState.cans != CarUpgrades.BASE_CANS:
		_errors.append("D: %d cans after two purchases" % GameState.cans)
	if _menu.activate(ShopMenu.CANS):
		_errors.append("D: bought a can past the cup holders")
	_menu.activate(&"can_holder")
	if CarUpgrades.can_capacity() != CarUpgrades.BASE_CANS + 2:
		_errors.append("D: rack level 1 holds %d" % CarUpgrades.can_capacity())
	_menu.activate(ShopMenu.CANS)
	_menu.close()
	# Drink with F while hurt; with Monstrous XL a can heals 35 % more.
	_damage.driver_health.hp = 20.0
	_press(&"drink")
	await _wait(2.0)
	var plain := _damage.driver_health.hp - 20.0
	print("[ShopMenuTest] D cans %d (capacity %d), one can healed the driver %.1f" % [GameState.cans, CarUpgrades.can_capacity(), plain])
	if GameState.cans != CarUpgrades.BASE_CANS:
		_errors.append("D: F did not use a can (%d left)" % GameState.cans)
	if absf(plain - CarUpgrades.CAN_DRIVER_HEAL) > 1.0:
		_errors.append("D: a can healed %.1f, want %.0f" % [plain, CarUpgrades.CAN_DRIVER_HEAL])
	GameState.car_levels[&"can_size"] = 1
	_damage.driver_health.hp = 20.0
	_press(&"drink")
	await _wait(2.0)
	var xl := _damage.driver_health.hp - 20.0
	print("[ShopMenuTest] D with Monstrous XL: %.1f" % xl)
	if absf(xl - CarUpgrades.CAN_DRIVER_HEAL * 1.35) > 1.0:
		_errors.append("D: an XL can healed %.1f, want %.1f" % [xl, CarUpgrades.CAN_DRIVER_HEAL * 1.35])


func _test_repair() -> void:
	_damage.taxi_health.apply_damage(60.0)
	_damage.driver_health.apply_damage(30.0)
	var quote := CarUpgrades.repair_quote(_damage)
	GameState.cash = 1000
	_menu.open()
	var ok := _menu.activate(ShopMenu.REPAIR)
	_menu.close()
	print("[ShopMenuTest] E repair quoted $%d, cash 1000 -> %d, taxi %.0f / %.0f" % [quote, GameState.cash,
			_damage.taxi_health.hp, _damage.taxi_health.max_hp])
	if not ok or quote <= 0 or GameState.cash != 1000 - quote:
		_errors.append("E: repair did not charge the quote")
	if _damage.taxi_health.hp < _damage.taxi_health.max_hp or _damage.driver_health.hp < _damage.driver_health.max_hp:
		_errors.append("E: not repaired")


func _test_gun_cards() -> void:
	_menu.open()
	_menu.show_tab(&"cab")
	await _frames(20)
	await _shot("shop_cab.png")
	_press_key(KEY_E)
	await _frames(2)
	if _menu.tab != &"energy":
		_errors.append("F: E did not move to the next tab (%s)" % _menu.tab)
	await _shot("shop_energy.png")
	_press_key(KEY_E)
	await _frames(2)
	if _menu.tab != &"guns":
		_errors.append("F: E did not wrap round to the guns (%s)" % _menu.tab)
	var wc := get_tree().get_first_node_in_group(&"weapon_controller") as WeaponController
	var shift := get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
	shift.rides_completed = 99   # every gun for sale
	var target: WeaponData = null
	for w in WeaponController.catalogue():
		if not wc.owns(w.id) and WeaponUpgrades.is_unlocked(w, get_tree()):
			target = w
			break
	if target == null:
		_errors.append("F: no unlocked gun left to buy")
	else:
		GameState.cash = 20000
		var bought := _menu.gun_action(target.id, &"main")
		var upgraded := _menu.gun_action(target.id, &"damage")
		print("[ShopMenuTest] F %s bought=%s owned=%s, upgraded=%s level %d" % [target.id, bought, wc.owns(target.id),
				upgraded, WeaponUpgrades.level(target.id, &"damage")])
		if not bought or not wc.owns(target.id):
			_errors.append("F: the card's BUY did not buy the %s" % target.id)
		if not upgraded or WeaponUpgrades.level(target.id, &"damage") != 1:
			_errors.append("F: the card's UPGRADE did not upgrade the %s" % target.id)
		var cash_before := GameState.cash
		if _menu.gun_action(target.id, &"main") or GameState.cash != cash_before:
			_errors.append("F: an owned gun's card sold ammo (ammo drops from enemies, D-094)")
		if wc.is_equipped(target.id):
			if not _menu.gun_action(target.id, &"equip") or wc.is_equipped(target.id):
				_errors.append("F: UNEQUIP from the card failed")
		elif _menu.gun_action(target.id, &"equip") and not wc.is_equipped(target.id):
			_errors.append("F: EQUIP from the card failed")
	GameState.cash = 10
	var poor: WeaponData = null
	for w in WeaponController.catalogue():
		if not wc.owns(w.id) and WeaponUpgrades.is_unlocked(w, get_tree()):
			poor = w
	if poor != null and _menu.gun_action(poor.id, &"main"):
		_errors.append("F: bought a gun with $10")
	await _frames(2)
	await _shot("shop_guns.png")
	if not _menu.is_open or not get_tree().paused:
		_errors.append("F: the menu closed while shopping guns")
	_menu.close()
	await _frames(2)


func _test_nitro() -> void:
	_taxi.nitro = _taxi.nitro_max
	_taxi.nitro_empty = false
	_taxi.is_boosting = true
	_taxi._update_nitro(_taxi.nitro_max / _taxi.nitro_drain + 0.1)
	var drained := _taxi.nitro
	var empty := _taxi.nitro_empty
	_taxi.is_boosting = false
	_taxi._update_nitro(_taxi.nitro_regen_delay * 0.95)    # resting: no refill yet
	_taxi._update_nitro((_taxi.nitro_relight - 1.0) / _taxi.nitro_regen)
	var still_empty := _taxi.nitro_empty
	_taxi._update_nitro(2.0 / _taxi.nitro_regen)
	print("[ShopMenuTest] H drained to %.1f (empty %s), refilled to %.1f, still empty below relight %s, relit %s" % [
			drained, empty, _taxi.nitro, still_empty, not _taxi.nitro_empty])
	if drained > 0.01 or not empty:
		_errors.append("H: a full boost did not empty the tank")
	if not still_empty or _taxi.nitro_empty:
		_errors.append("H: the empty tank did not relight at nitro_relight")
	var base := _taxi.nitro_max
	GameState.cash = 5000
	_menu.open()
	_menu.activate(&"nitro")
	_menu.close()
	_near("H: nitro tank after level 1", _taxi.nitro_max, base * 1.35)


func _press_key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event.call_deferred(up)


func _test_wreck_and_reset() -> void:
	_damage.taxi_health.apply_damage(100000.0)
	await _wait(0.5)
	print("[ShopMenuTest] G wrecked: dead=%s" % _damage.is_dead)
	if not _damage.is_dead:
		_errors.append("G: a wreck did not end the run without repair garages")
	if _menu.can_open():
		_errors.append("G: the menu can open once dead")
	GameState.reset_run()
	if not GameState.car_levels.is_empty() or GameState.cans != 0:
		_errors.append("G: reset_run kept upgrades / cans")


# --- helpers ----------------------------------------------------------------------------

func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event.call_deferred(up)


func _near(what: String, got: float, want: float) -> void:
	if absf(got - want) > maxf(absf(want) * 0.01, 0.01):
		_errors.append("%s: %.3f, want %.3f" % [what, got, want])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	var until := _t + seconds
	while _t < until and not _done:
		await get_tree().physics_frame


func _until(cond: Callable, timeout: float) -> bool:
	var until := _t + timeout
	while _t < until and not _done:
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())


func _shot(file: String) -> void:
	if _shot_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot_dir.path_join(file))
	print("[ShopMenuTest] screenshot ", file)


func _finish() -> void:
	if _done:
		return
	_done = true
	set_physics_process(false)
	get_tree().paused = false
	if _errors.is_empty():
		print("[ShopMenuTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[ShopMenuTest] FAIL: ", e)
		get_tree().quit(1)
