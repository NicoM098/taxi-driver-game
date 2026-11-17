extends Node
## Weapon upgrades (D-085, endless tracks D-093), headless on the test course. Real shots:
##  A. WeaponUpgrades.apply: mag / reserve / damage / fire rate tracks; the drum special (SMG)
##  B. WeaponController.upgrade: per track, refills to the new max, mag and reserve cap at 3
##  C. rifle one upgrade short of its special stops at the first of three boards; with it (AP)
##     goes through all three
##  D. revolver deadeye: an aimed shot deals double the upgraded damage
##  E. sawed-off dragon's breath: the board keeps losing health after the shot
##  H. the endless curve: steps grow every 3 levels, prices x1.35, fire rate past its cap turns
##     into damage (DPS unchanged), 40 levels deep still works
##  I. enemy health (D-093): x0.9 with nothing earned (D-095); an enemy car spawns with data.hp x the curve;
##     buying a gun's levels with SCALING_SHARE of the earnings matches the curve, half of it falls behind
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

	# --- A. stats per track ---------------------------------------------------------------
	var smg := load("res://data/weapons/smg.tres") as WeaponData
	GameState.weapon_levels[&"smg"] = {&"damage": 2, &"rate": 1, &"mag": 1, &"reserve": 1}
	var up := WeaponUpgrades.apply(smg)
	_check(is_equal_approx(up.damage, smg.damage * 1.1 * 1.1) and is_equal_approx(up.fire_rate, smg.fire_rate * 1.06),
			"damage 2 + rate 1: damage %.2f, rate %.2f" % [up.damage, up.fire_rate])
	_check(up.mag_size == ceili(smg.mag_size * 1.25) and up.reserve_max == roundi(smg.reserve_max * 1.4),
			"mag 1 + reserve 1: mag %d, reserve %d" % [up.mag_size, up.reserve_max])
	GameState.weapon_levels[&"smg"] = {&"damage": 8}
	up = WeaponUpgrades.apply(smg)
	_check(up.mag_size == WeaponUpgrades.DRUM_MAG and up.reserve_max == smg.reserve_max * 2,
			"drum after %d upgrades: mag %d, reserve %d" % [WeaponUpgrades.SPECIAL_AT, up.mag_size, up.reserve_max])
	_check(smg.damage == 12.0 and smg.mag_size == 30, "the .tres itself is never modified")
	_check(WeaponUpgrades.next_price(smg, &"damage") == WeaponUpgrades.price_at(smg.upgrade_cost, &"damage", 8)
			and WeaponUpgrades.price_at(smg.upgrade_cost, &"damage", 0) == smg.upgrade_cost, "damage prices start at upgrade_cost")
	GameState.weapon_levels.erase(&"smg")

	# --- B. controller upgrade -------------------------------------------------------------
	_wc.ammo[&"smg"]["reserve"] = 0
	_check(_wc.upgrade(&"smg", &"damage"), "SMG damage 1")
	_check(int(_wc.get_ammo(_wc.get_weapon(&"smg"))["reserve"]) == 0, "an upgrade does not refill (ammo drops from kills, D-094)")
	for i in 3:
		_wc.upgrade(&"smg", &"mag")
	_check(not _wc.upgrade(&"smg", &"mag") and WeaponUpgrades.level(&"smg", &"mag") == 3, "mag stops at 3")
	_check(not _wc.upgrade(&"smg", &"bogus"), "unknown track refused")
	for i in 4:
		_wc.upgrade(&"smg", &"rate")
	var carried := _wc.get_weapon(&"smg")
	var a := _wc.get_ammo(carried)
	# No refill: the loaded 30 stay; the drum's doubled reserve adds its new room (reserve_max more).
	_check(WeaponUpgrades.total(&"smg") == 8 and carried.mag_size == 75 and int(a["mag"]) == smg.mag_size
			and int(a["reserve"]) == smg.reserve_max,
			"SMG +8 carried with its drum: mag %d (%d loaded), reserve %d" % [carried.mag_size, a["mag"], a["reserve"]])
	_check(_wc.upgrade(&"smg", &"damage") and _wc.upgrade(&"smg", &"rate"), "damage and rate keep going past +8")

	# --- C. piercing --------------------------------------------------------------------
	GameState.weapon_levels[&"rifle"] = {&"damage": WeaponUpgrades.SPECIAL_AT - 2}
	_wc.upgrade(&"rifle", &"rate")             # one short of the special
	var boards := _line_of_boards([9.0, 15.0, 21.0])
	await _shoot(4)
	var hurt := _hurt(boards)
	_check(hurt == 1, "rifle +7 hits only the first board (%d hurt)" % hurt)
	_clear(boards)
	_wc.upgrade(&"rifle", &"mag")              # +8: AP rounds
	boards = _line_of_boards([9.0, 15.0, 21.0])
	await _shoot(4)
	hurt = _hurt(boards)
	_check(hurt == 3, "rifle +8 (AP) goes through all three boards (%d hurt)" % hurt)
	_clear(boards)

	# --- D. deadeye -------------------------------------------------------------------
	var revolver := load("res://data/weapons/revolver.tres") as WeaponData
	GameState.weapon_levels[&"revolver"] = {&"mag": 3, &"reserve": 3, &"rate": 1}
	_wc.upgrade(&"revolver", &"damage")
	boards = _line_of_boards([10.0])
	await _shoot(1)
	var dealt := boards[0].max_hp - boards[0].health.hp
	var expected := revolver.damage * 1.1 * WeaponUpgrades.DEADEYE_MULT
	_check(absf(dealt - expected) < 1.0, "revolver deadeye aimed shot deals %.0f (expected %.0f)" % [dealt, expected])
	_clear(boards)

	# --- E. dragon's breath ------------------------------------------------------------------
	GameState.weapon_levels[&"shotgun"] = {&"damage": WeaponUpgrades.SPECIAL_AT - 1}
	_wc.upgrade(&"shotgun", &"rate")
	boards = _line_of_boards([6.0])
	await _shoot(3)
	var after_shot := boards[0].health.hp
	var burning := boards[0].find_child("Burning", true, false) != null
	await _wait(2.0)
	var later := boards[0].health.hp
	_check(burning and later < after_shot - 10.0,
			"sawed-off dragon's breath sets the board on fire: hp %.0f after the shot, %.0f two seconds later" % [after_shot, later])
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

	_curve()
	await _enemy_scaling()

	if _errors.is_empty():
		print("[UpgradesTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[UpgradesTest] FAIL: ", e)
		get_tree().quit(1)


## H. the endless curve.
func _curve() -> void:
	_check(is_equal_approx(WeaponUpgrades.step(&"damage", 3), 0.10) and is_equal_approx(WeaponUpgrades.step(&"damage", 4), 0.15)
			and is_equal_approx(WeaponUpgrades.step(&"damage", 7), 0.20) and is_equal_approx(WeaponUpgrades.step(&"rate", 10), 0.15),
			"steps: damage 10/15/20 %, rate level 10 = 15 %")
	var p0 := WeaponUpgrades.price_at(200, &"damage", 0)
	var p10 := WeaponUpgrades.price_at(200, &"damage", 10)
	_check(p0 == 200 and absf(p10 / float(p0) - pow(1.35, 10)) < 0.05, "price x1.35 a level ($%d -> $%d)" % [p0, p10])
	_check(WeaponUpgrades.price_at(200, &"mag", 3) == -1 and WeaponUpgrades.price_at(200, &"damage", 60) > 0,
			"mag caps, damage never does")
	var laser := load("res://data/weapons/laser.tres") as WeaponData
	GameState.weapon_levels[&"laser"] = {&"rate": 12}
	var hot := WeaponUpgrades.apply(laser)
	var dps := hot.damage * hot.fire_rate
	var want := laser.damage * laser.fire_rate * WeaponUpgrades.mult(&"rate", 12)
	_check(hot.fire_rate <= WeaponUpgrades.RATE_CAP + 0.001 and absf(dps / want - 1.0) < 0.001,
			"laser rate 12: %.1f shots/s (capped), DPS %.0f = %.0f" % [hot.fire_rate, dps, want])
	GameState.weapon_levels[&"laser"] = {&"damage": 40, &"rate": 40}
	var deep := WeaponUpgrades.apply(laser)
	_check(is_finite(deep.damage) and deep.damage > laser.damage * 1000.0,
			"40 + 40 levels: damage %.0f (x%.0f)" % [deep.damage, deep.damage / laser.damage])
	GameState.weapon_levels.erase(&"laser")


## I. enemy health follows the curve.
func _enemy_scaling() -> void:
	var saved := GameState.earned
	GameState.earned = 0
	_check(is_equal_approx(WeaponUpgrades.enemy_hp_mult(), WeaponUpgrades.ENEMY_HP_SCALE),
			"nothing earned: enemies x%.2f (D-095)" % WeaponUpgrades.ENEMY_HP_SCALE)
	GameState.earned = 20000
	var m := WeaponUpgrades.enemy_hp_mult()
	_check(m > 1.5 and m < 12.0 and WeaponUpgrades.dedicated_power(30000.0) > WeaponUpgrades.dedicated_power(15000.0),
			"$20000 earned: enemies x%.2f, rising with earnings" % m)
	var data := load("res://data/enemies/police_cruiser.tres") as EnemyCarData
	var car := EnemyCar.new()
	car.data = data
	add_child(car)
	car.global_position = Vector3(0, -200, 0)   # far below the course: just read its health
	await get_tree().physics_frame
	_check(absf(car.health.max_hp - data.hp * m) < 0.5 and absf(car.health.hp - car.health.max_hp) < 0.5,
			"a cruiser spawns with %.0f hp (%.0f x %.2f)" % [car.health.max_hp, data.hp, m])
	car.queue_free()
	# All in on a gun priced like the reference vs half the money: buy cheapest-first by hand.
	var curve := m / WeaponUpgrades.ENEMY_HP_SCALE
	var all_in := _buy_power(GameState.earned * WeaponUpgrades.SCALING_SHARE)
	var half := _buy_power(GameState.earned * WeaponUpgrades.SCALING_SHARE * 0.5)
	# Whole levels only here; the curve also counts the level in progress: within one step.
	_check(all_in <= curve + 0.001 and all_in * 1.3 >= curve and half / curve < 0.8,
			"all-in DPS x%.2f keeps up with the curve x%.2f; half the money x%.2f falls behind" % [all_in, curve, half])
	# D-095: the shop's real price (upgrade_cost 225) + ENEMY_HP_SCALE -> an all-in gun is ahead.
	var smg := load("res://data/weapons/smg.tres") as WeaponData
	var real := WeaponUpgrades.dedicated_power(GameState.earned * WeaponUpgrades.SCALING_SHARE, smg.upgrade_cost)
	_check(smg.upgrade_cost < WeaponUpgrades.REFERENCE_COST and real / m > 1.1 and real / m < 1.6,
			"at the shop's prices an all-in gun is x%.2f ahead of the enemies" % (real / m))
	WeaponUpgrades.scale_enemies = false
	_check(is_equal_approx(WeaponUpgrades.enemy_hp_mult(), 1.0), "scale_enemies off: x1")
	WeaponUpgrades.scale_enemies = true
	GameState.earned = saved


## DPS multiplier of whole levels bought with `budget` on a gun priced at the reference.
func _buy_power(budget: float) -> float:
	var lv := {&"damage": 0, &"rate": 0}
	while true:
		var t: StringName = &"damage" if WeaponUpgrades.price_at(WeaponUpgrades.REFERENCE_COST, &"damage", lv[&"damage"]) \
				<= WeaponUpgrades.price_at(WeaponUpgrades.REFERENCE_COST, &"rate", lv[&"rate"]) else &"rate"
		var price := WeaponUpgrades.price_at(WeaponUpgrades.REFERENCE_COST, t, lv[t])
		if price > budget:
			break
		budget -= price
		lv[t] += 1
	return WeaponUpgrades.mult(&"damage", lv[&"damage"]) * WeaponUpgrades.mult(&"rate", lv[&"rate"])


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
