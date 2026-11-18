extends Node
## Headless Iteration 24 test through Main: spare parts, slot tickets, the slot machine (D-106).
##  A. Every enemy killed pays its spare parts (1 a common car, 2 an elite / boss); cash still comes.
##  B. A boss beaten in a boss fight pays a slot ticket, and a stage-2 gang boss in its fight
##     is shown as a boss (gold marker).
##  C. The cab's upgrades cost spare parts, not cash; perks cannot be bought.
##  D. The slot machine: no ticket, no spin; every spin costs one ticket and pays a perk level or
##     +5 Damage / Fire rate on the 1st / 2nd most upgraded gun; perks stop once maxed.
##  E. The parts budget (printed): what the kill targets of the three stages afford, and that
##     killing twice a stage's target before its boss buys 2-3 levels more.
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/currencies_autotest.tscn

const MAIN := preload("res://src/main/main.tscn")
const TIMEOUT := 60.0

var _taxi: Taxi
var _wc: WeaponController
var _menu: ShopMenu
var _t: float = 0.0
var _errors: PackedStringArray = []
var _done: bool = false


func _ready() -> void:
	ShopMenu.enabled = true
	MapData.use_builtin()
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.reset_run()
	add_child(MAIN.instantiate())
	_run()


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT and not _done:
		_errors.append("timeout")
		_finish()


func _check(ok: bool, what: String) -> void:
	print("[CurrencyTest] %s %s" % ["OK  " if ok else "FAIL", what])
	if not ok:
		_errors.append(what)


func _run() -> void:
	await _until(func() -> bool: return get_tree().get_first_node_in_group(&"player_vehicle") != null, 5.0)
	_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
	_wc = get_tree().get_first_node_in_group(&"weapon_controller") as WeaponController
	_menu = get_tree().get_first_node_in_group(&"shop_menu") as ShopMenu
	var shift := get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
	await _until(func() -> bool: return shift.is_active, 5.0)
	GameState.tutorial_active = false
	var tutorial := get_tree().get_first_node_in_group(&"tutorial") as Tutorial
	if tutorial != null:
		tutorial.skip()
	var dmg := _taxi.get_node("TaxiDamage") as TaxiDamage
	dmg.taxi_health.max_hp = 1e9
	dmg.taxi_health.revive()
	await _wait(0.5)

	await _test_kills()
	await _test_boss_ticket()
	_test_cab_prices()
	_test_slots()
	_test_budget()
	await _test_perks()
	_test_devastator()
	await _test_machine()
	_finish()


# --- F: the strong perks (D-107) ----------------------------------------------------------

func _test_perks() -> void:
	# All seven are won by now (D). Guardian Angel: a lethal hit leaves half health once.
	var dmg := _taxi.get_node("TaxiDamage") as TaxiDamage
	dmg.taxi_health.max_hp = 100.0
	dmg.taxi_health.revive()
	dmg.angel_cooldown = 0.0
	dmg.taxi_health.apply_damage(500.0)
	await get_tree().physics_frame
	_check(not dmg.is_dead and not dmg.is_wrecked and is_equal_approx(dmg.taxi_health.hp, 50.0),
			"F: Guardian Angel: a lethal hit leaves %.0f / 100" % dmg.taxi_health.hp)
	_check(dmg.angel_cooldown > TaxiDamage.ANGEL_RECHARGE - 1.0, "F: ...and recharges for 5 minutes (%.0f s)" % dmg.angel_cooldown)
	dmg.taxi_health.apply_damage(500.0)
	await get_tree().physics_frame
	_check(dmg.is_dead, "F: a second lethal hit while it recharges is death")
	dmg.is_dead = false   # back to life for the rest of the test
	dmg.is_wrecked = false
	dmg.taxi_health.revive()
	# Road Vampire: a kill heals 10 %.
	dmg.taxi_health.hp = 40.0
	await _kill("res://data/enemies/gang_red.tres")
	_check(is_equal_approx(dmg.taxi_health.hp, 50.0), "F: Road Vampire: a kill heals 40 -> %.0f" % dmg.taxi_health.hp)
	# Deep Pockets: +50 % reserve.
	var smg := _wc.get_weapon(&"smg")
	GameState.car_levels[&"perk_deep_pockets"] = 0
	var without := WeaponUpgrades.apply(WeaponController._base(&"smg")).reserve_max
	GameState.car_levels[&"perk_deep_pockets"] = 1
	_check(smg.reserve_max == roundi(without * 1.5), "F: Deep Pockets: SMG carries %d spare (%d without)" % [smg.reserve_max, without])
	dmg.taxi_health.max_hp = 1e9
	dmg.taxi_health.revive()


# --- G: The Devastator (D-107) ------------------------------------------------------------

func _test_devastator() -> void:
	var base := WeaponController._base(&"devastator")
	_check(base != null and not base.upgradable and WeaponUpgrades.tracks_for(base).is_empty(), "G: The Devastator has no upgrade tracks")
	_wc.add_weapon(&"devastator")
	var w := _wc.get_weapon(&"devastator")
	_check(w != null and is_equal_approx(w.damage, base.damage) and is_equal_approx(w.fire_rate, base.fire_rate),
			"G: perks do not touch it (Double Tap is on: %.2f shots/s)" % (w.fire_rate if w != null else -1.0))
	_check(not _wc.upgrade(&"devastator", &"damage"), "G: and it cannot be upgraded")
	_check(not SlotMachine.ranked_guns(get_tree()).has(&"devastator"), "G: and the slot machine never picks it")


# --- H: playing the machine (D-107) -------------------------------------------------------

func _test_machine() -> void:
	var m := _menu.get_node("SlotMachine") as SlotMachineScreen
	_menu.open()
	_menu.show_tab(&"perks")
	GameState.tickets = 1
	_menu.activate(ShopMenu.SLOTS)
	_check(m.visible and m.state == SlotMachineScreen.State.IDLE, "H: SLOTS opens the machine, ticket in the tray")
	m.advance()
	_check(m.state == SlotMachineScreen.State.INSERTING and GameState.tickets == 1, "H: the ticket goes in (not spent yet)")
	await _wait(1.0)
	_check(m.state == SlotMachineScreen.State.READY, "H: then: pull the lever")
	m.advance()
	await _wait(0.6)
	_check(m.state == SlotMachineScreen.State.SPINNING and GameState.tickets == 0, "H: the lever spends the ticket and the reels roll")
	await _until(func() -> bool: return m.state == SlotMachineScreen.State.REVEAL, 6.0)
	_check(m.state == SlotMachineScreen.State.REVEAL and m.prize.has("title"), "H: the reels stop and the prize is revealed: %s" % m.prize.get("text", "?"))
	var n := SlotMachine.REEL_SYMBOLS.size()
	var landed := true
	for o in m._offsets:
		landed = landed and SlotMachine.REEL_SYMBOLS[posmod(roundi(o), n)] == m.prize["symbol"]
	_check(landed, "H: all three reels show the prize's symbol (%s)" % m.prize["symbol"])
	await _wait(0.6)
	m.advance()
	_check(m.state == SlotMachineScreen.State.IDLE and _menu._prize == m.prize, "H: collect: the card shows the win")
	m.close()
	_menu.close()


# --- A ----------------------------------------------------------------------------------

func _test_kills() -> void:
	GameState.parts = 0
	var cash0 := GameState.cash
	await _kill("res://data/enemies/gang_red.tres")
	_check(GameState.parts == 1, "A: a gang car pays 1 part (%d)" % GameState.parts)
	_check(GameState.cash > cash0, "A: ...and its bounty in cash")
	await _kill("res://data/enemies/gang_boss_red.tres")
	_check(GameState.parts == 3, "A: an elite gang boss pays 2 more (%d)" % GameState.parts)


func _kill(path: String) -> void:
	var car := EnemyCar.new()
	car.data = load(path) as EnemyCarData
	_taxi.get_parent().add_child(car)
	car.global_position = Vector3(0, -200, 0)
	await get_tree().physics_frame
	car.health.apply_damage(1e9)
	await get_tree().physics_frame


# --- B ----------------------------------------------------------------------------------

func _test_boss_ticket() -> void:
	var esc := get_tree().get_first_node_in_group(&"escalation") as Escalation
	GameState.tickets = 0
	var entry := {"data": load("res://data/enemies/gang_boss_purple.tres"), "car": null, "down": false}
	esc._spawn_boss(entry)
	var car: EnemyCar = entry["car"]
	if car == null:
		_check(false, "B: no boss spawned")
		return
	_check(car.is_boss() and car.marker._tag != null, "B: a stage-2 gang boss in its fight wears the gold BOSS marker")
	car.health.apply_damage(1e9)
	await get_tree().physics_frame
	_check(GameState.tickets == 1 and entry["down"], "B: beating it pays a slot ticket (%d)" % GameState.tickets)


# --- C ----------------------------------------------------------------------------------

func _test_cab_prices() -> void:
	GameState.cash = 100000
	GameState.parts = 4
	_menu.open()
	_check(not _menu.activate(&"armor"), "C: armor (5 parts) is not bought with 4 parts and $100000")
	GameState.parts = 5
	_check(_menu.activate(&"armor") and GameState.parts == 0 and GameState.cash == 100000,
			"C: with 5 parts it is, and no cash is taken")
	_check(not _menu.activate(&"perk_fast_reload"), "C: a perk cannot be bought")
	_menu.close()


# --- D ----------------------------------------------------------------------------------

func _test_slots() -> void:
	_menu.open()
	GameState.tickets = 0
	_check(not _menu.spin(), "D: no ticket, no spin")
	_menu.close()
	# Two guns: the revolver with 3 upgrades (1st), the SMG with 1 (2nd).
	_wc.add_weapon(&"smg")
	GameState.weapon_levels[&"revolver"] = {&"damage": 3}
	GameState.weapon_levels[&"smg"] = {&"mag": 1}
	_wc.refresh_arsenal()
	var ranked := SlotMachine.ranked_guns(get_tree())
	_check(ranked.size() >= 2 and ranked[0] == &"revolver" and ranked[1] == &"smg", "D: guns ranked by upgrades %s" % [ranked])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var perk_levels0 := _perk_levels()
	var gun_levels0 := WeaponUpgrades.total(&"revolver") + WeaponUpgrades.total(&"smg")
	GameState.tickets = 40
	var perk_wins := 0
	var gun_wins := 0
	var kinds := {}
	for i in 40:
		var prize := SlotMachine.spin(get_tree(), rng)
		if prize.has("error"):
			_check(false, "D: spin %d: %s" % [i, prize["error"]])
			break
		if prize["kind"] == &"perk":
			perk_wins += 1
		else:
			gun_wins += 1
			kinds["%s %s" % [prize["gun"], prize["track"]]] = true
	print("[CurrencyTest]   40 spins: %d perk levels, %d gun prizes %s" % [perk_wins, gun_wins, kinds.keys()])
	_check(GameState.tickets == 0, "D: every spin took one ticket")
	_check(_perk_levels() - perk_levels0 == perk_wins and _perk_levels() == 7,
			"D: every perk win is a new perk, all seven won once (%d)" % _perk_levels())
	var gun_levels := WeaponUpgrades.total(&"revolver") + WeaponUpgrades.total(&"smg")
	_check(gun_levels - gun_levels0 == gun_wins * SlotMachine.GUN_LEVELS, "D: each gun prize is +5 levels (%d -> %d)" % [gun_levels0, gun_levels])
	_check(kinds.size() == 4, "D: all four gun prizes came up (1st / 2nd gun x damage / rate)")
	var pool := SlotMachine.prizes(get_tree())
	var only_guns := true
	for p in pool:
		if p["kind"] == &"perk":
			only_guns = false
	_check(only_guns and not pool.is_empty(), "D: with every perk maxed, the machine pays gun levels only")


func _perk_levels() -> int:
	var n := 0
	for u in CarUpgrades.catalogue():
		if CarUpgrades.is_perk(u):
			n += CarUpgrades.level(u.id)
	return n


# --- E ----------------------------------------------------------------------------------

## The cab prices against the stages' kill targets (1 part a kill), buying the cheapest level
## each time: what the targets alone afford, and with the stage's target killed twice over.
## (Elites, bosses and escorts pay on top: not counted.)
func _test_budget() -> void:
	var stages: Array[int] = []
	for i in 3:
		stages.append((load("res://data/stages/stage_%d.tres" % (i + 1)) as StageData).kills)
	var prices: Array = []
	for u in CarUpgrades.catalogue():
		if u.currency == &"parts" and ShopMenu.tab_of(u) == &"cab":
			prices.append(Array(u.prices))
	var total := 0
	for i in 3:
		total += stages[i]
		var exact := _levels_for(total, prices)
		var extra := _levels_for(total + stages[i], prices)
		print("[CurrencyTest] E stage %d boss: %d kills in all -> %d cab levels (of 18); %d more kills in the stage -> %d" % [
				i + 1, total, exact, stages[i], extra])
		if i == 0:
			_check(exact >= 2 and exact <= 3, "E: stage 1's 10 kills buy 2-3 cab levels (%d)" % exact)
		_check(extra - exact >= 2 and extra - exact <= 3, "E: twice stage %d's kills buy 2-3 levels more (%d)" % [i + 1, extra - exact])


## Levels `parts` buys, cheapest next level first.
static func _levels_for(parts: int, prices: Array) -> int:
	var lv: Array[int] = []
	lv.resize(prices.size())
	lv.fill(0)
	var n := 0
	while true:
		var best := -1
		for i in prices.size():
			if lv[i] < (prices[i] as Array).size() and (best < 0 or prices[i][lv[i]] < prices[best][lv[best]]):
				best = i
		if best < 0 or prices[best][lv[best]] > parts:
			return n
		parts -= prices[best][lv[best]]
		lv[best] += 1
		n += 1
	return n


# --- Helpers ----------------------------------------------------------------------------

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


func _finish() -> void:
	if _done:
		return
	_done = true
	set_physics_process(false)
	get_tree().paused = false
	if _errors.is_empty():
		print("[CurrencyTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[CurrencyTest] FAIL: ", e)
		get_tree().quit(1)
