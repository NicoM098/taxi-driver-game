extends Node
## Weapon upgrades (D-085), headless on the test course. Real shots through WeaponController:
##  A. WeaponUpgrades.apply: Mk II damage, Mk III mag / reload / spread, Mk IV drum (SMG)
##  B. WeaponController.upgrade: levels up, refills to the new max, stops at Mk IV
##  C. rifle Mk III stops at the first of three boards in a line; Mk IV (AP) goes through all three
##  D. revolver Mk IV (deadeye): an aimed shot deals double damage
##  E. sawed-off Mk IV (dragon's breath): the board keeps losing health after the shot
##  F. unlocking: WeaponUpgrades.is_unlocked follows ShiftManager.rides_completed
##  G. loadout (D-087): four guns at most; a fifth is stored; equip / unequip keep ammo; key 4
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/upgrades_autotest.tscn

const COURSE := preload("res://src/vehicle/test_drive.tscn")

var _taxi: Taxi
var _wc: WeaponController
var _cam: Camera3D
var _errors: PackedStringArray = []


func _ready() -> void:
	MapData.use_builtin()
	GameState.reset_run()
	GameState.owned_weapons = [&"revolver", &"smg", &"shotgun", &"rifle"]
	var course := COURSE.instantiate()
	add_child(course)
	_taxi = course.get_node("Taxi") as Taxi
	_run()


func _check(ok: bool, what: String) -> void:
	print("[UpgradesTest] %s %s" % ["OK  " if ok else "FAIL", what])
	if not ok:
		_errors.append(what)


func _run() -> void:
	await _wait(1.0)
	_wc = get_tree().get_first_node_in_group(&"weapon_controller") as WeaponController
	_cam = _wc.get_parent() as Camera3D

	# --- A. stats per level ---------------------------------------------------------------
	var smg := load("res://data/weapons/smg.tres") as WeaponData
	var mk2 := WeaponUpgrades.apply(smg, 2)
	var mk3 := WeaponUpgrades.apply(smg, 3)
	var mk4 := WeaponUpgrades.apply(smg, 4)
	_check(is_equal_approx(mk2.damage, smg.damage * 1.25) and mk2.mag_size == smg.mag_size,
			"Mk II: damage %.1f -> %.1f, same mag" % [smg.damage, mk2.damage])
	_check(mk3.mag_size == ceili(smg.mag_size * 1.5) and mk3.reload_time < smg.reload_time
			and mk3.spread_aimed < smg.spread_aimed, "Mk III: mag %d, reload %.2f, spread %.2f" % [
			mk3.mag_size, mk3.reload_time, mk3.spread_aimed])
	_check(mk4.mag_size == WeaponUpgrades.DRUM_MAG and mk4.reserve_max == smg.reserve_max * 2,
			"Mk IV SMG drum: mag %d, reserve %d" % [mk4.mag_size, mk4.reserve_max])
	_check(smg.damage == 12.0 and smg.mag_size == 30, "the .tres itself is never modified")
	_check(WeaponUpgrades.next_price(smg, 1) == smg.upgrade_prices[0]
			and WeaponUpgrades.next_price(smg, 4) == -1, "upgrade prices and the Mk IV cap")

	# --- B. controller upgrade -------------------------------------------------------------
	_wc.ammo[&"smg"]["reserve"] = 0
	_check(_wc.upgrade(&"smg"), "SMG to Mk II")
	_check(int(_wc.get_ammo(_wc.get_weapon(&"smg"))["reserve"]) == smg.reserve_max, "an upgrade refills the reserve")
	_wc.upgrade(&"smg")
	_wc.upgrade(&"smg")
	var carried := _wc.get_weapon(&"smg")
	var a := _wc.get_ammo(carried)
	_check(GameState.weapon_level(&"smg") == 4 and carried.mag_size == 75 and int(a["mag"]) == 75
			and int(a["reserve"]) == smg.reserve_max * 2,
			"SMG Mk IV carried: mag %d (%d loaded), reserve %d" % [carried.mag_size, a["mag"], a["reserve"]])
	_check(not _wc.upgrade(&"smg"), "no Mk V")

	# --- C. piercing --------------------------------------------------------------------
	GameState.weapon_levels[&"rifle"] = 2
	_wc.upgrade(&"rifle")                      # Mk III: no special yet
	var boards := _line_of_boards([9.0, 15.0, 21.0])
	await _shoot(4)
	var hurt := _hurt(boards)
	_check(hurt == 1, "rifle Mk III hits only the first board (%d hurt)" % hurt)
	_clear(boards)
	_wc.upgrade(&"rifle")                      # Mk IV: AP rounds
	boards = _line_of_boards([9.0, 15.0, 21.0])
	await _shoot(4)
	hurt = _hurt(boards)
	_check(hurt == 3, "rifle Mk IV (AP) goes through all three boards (%d hurt)" % hurt)
	_clear(boards)

	# --- D. deadeye -------------------------------------------------------------------
	var revolver := load("res://data/weapons/revolver.tres") as WeaponData
	GameState.weapon_levels[&"revolver"] = 3
	_wc.upgrade(&"revolver")
	boards = _line_of_boards([10.0])
	await _shoot(1)
	var dealt := boards[0].max_hp - boards[0].health.hp
	var expected := revolver.damage * WeaponUpgrades.DAMAGE_MULT * WeaponUpgrades.DEADEYE_MULT
	_check(absf(dealt - expected) < 1.0, "revolver Mk IV aimed shot deals %.0f (expected %.0f)" % [dealt, expected])
	_clear(boards)

	# --- E. dragon's breath ------------------------------------------------------------------
	GameState.weapon_levels[&"shotgun"] = 3
	_wc.upgrade(&"shotgun")
	boards = _line_of_boards([6.0])
	await _shoot(3)
	var after_shot := boards[0].health.hp
	var burning := boards[0].find_child("Burning", true, false) != null
	await _wait(2.0)
	var later := boards[0].health.hp
	_check(burning and later < after_shot - 10.0,
			"sawed-off Mk IV sets the board on fire: hp %.0f after the shot, %.0f two seconds later" % [after_shot, later])
	_clear(boards)

	# --- F. unlocking by rides -------------------------------------------------------------
	var rifle := load("res://data/weapons/rifle.tres") as WeaponData
	var shift := ShiftManager.new()
	add_child(shift)
	shift.rides_completed = rifle.unlock_rides - 1
	_check(not WeaponUpgrades.is_unlocked(rifle, get_tree()), "rifle locked at %d fares" % shift.rides_completed)
	shift.rides_completed = rifle.unlock_rides
	_check(WeaponUpgrades.is_unlocked(rifle, get_tree()), "rifle unlocked at %d fares" % shift.rides_completed)
	_check(WeaponUpgrades.is_unlocked(revolver, get_tree()), "the revolver is never locked")

	# --- G. loadout of four ------------------------------------------------------------
	_check(_wc.weapons.size() == 4 and _wc.loadout_full(), "four guns equipped (%d)" % _wc.weapons.size())
	_check(_wc.add_weapon(&"laser") and _wc.owns(&"laser") and not _wc.is_equipped(&"laser")
			and _wc.weapons.size() == 4, "a fifth gun is bought but stored")
	_check(not _wc.equip(&"laser"), "cannot equip a fifth")
	_wc.ammo[&"rifle"]["mag"] = 2
	_check(_wc.unequip(&"rifle") and _wc.weapons.size() == 3 and _wc.owns(&"rifle"), "unequip the rifle: still owned")
	_check(_wc.equip(&"laser") and _wc.index_of_weapon(&"laser") == 3, "the laser goes on key 4")
	_wc.select(0)
	await _wait(0.4)
	Input.action_press(&"weapon_4")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"weapon_4")
	_check(_wc.current_weapon().id == &"laser", "key 4 selects it (%s)" % _wc.current_weapon().id)
	_wc.unequip(&"laser")
	_wc.equip(&"rifle")
	_check(int(_wc.ammo[&"rifle"]["mag"]) == 2, "a stored gun keeps its ammo")
	for id: StringName in [&"revolver", &"smg", &"shotgun"]:
		_wc.unequip(id)
	_check(_wc.weapons.size() == 1 and not _wc.unequip(&"rifle"), "the last gun cannot be unequipped")
	_check(GameState.loadout.size() == _wc.weapons.size(), "GameState.loadout follows (%s)" % [GameState.loadout])

	if _errors.is_empty():
		print("[UpgradesTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[UpgradesTest] FAIL: ", e)
		get_tree().quit(1)


## Selects the weapon in `slot`, aims and fires one shot.
func _shoot(slot: int) -> void:
	_wc.select(_wc.index_of_slot(slot))
	await _wait(0.5)
	Input.action_press(&"aim")
	var t := 0.0
	while not _wc.is_aiming and t < 3.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
	Input.action_press(&"fire")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"fire")
	await _wait(0.3)
	Input.action_release(&"aim")


## Boards straight ahead of the camera at eye height, `distances` metres away. Tough enough not
## to die from one hit, so the damage can be read off them.
func _line_of_boards(distances: Array) -> Array[ShootingTarget]:
	var ahead := -_cam.global_basis.z
	var out: Array[ShootingTarget] = []
	for d: float in distances:
		var b := ShootingTarget.new()
		b.board_height = 1.6
		b.max_hp = 1000.0
		add_child(b)
		var at := _cam.global_position + ahead * d
		b.global_position = Vector3(at.x, at.y - 1.6, at.z)
		b.look_at(Vector3(_cam.global_position.x, b.global_position.y, _cam.global_position.z), Vector3.UP)
		out.append(b)
	return out


func _hurt(boards: Array[ShootingTarget]) -> int:
	var n := 0
	for b in boards:
		if b.health.hp < b.max_hp - 0.5:
			n += 1
	return n


func _clear(boards: Array[ShootingTarget]) -> void:
	for b in boards:
		b.queue_free()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
