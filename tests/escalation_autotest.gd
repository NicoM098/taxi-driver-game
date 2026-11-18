extends Node
## Headless Iteration 20 test through Main (D-091).
##  A. The shop sells no cans and no repair: no MONSTROUS ENERGY tab, Monstrous XL under THE CAB.
##  B. The run starts at stage 1: police + gang coupes, 5 cars at once.
##  C. Kills count; fares + kills + time reach the boss; "BOSS INCOMING", then the Precinct
##     Captain (bigger, plowed, never given up on) arrives with two cruisers.
##  D. Destroying the boss clears the stage (reward) and starts stage 2: SWAT, 6 cars, heat >= 2.
##  E. Stage 2's boss fight is the three gang bosses; all down -> stage 3: military + cartel.
##  F. Stage 3 mini-bosses: a cartel lieutenant hunts at heat 3.
##  G. Final fight: the APC and the Kingpin; a boss that vanishes comes back; both down -> VICTORY.
## The taxi is patched up every frame so the hunters cannot end the run.
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/escalation_autotest.tscn
## Windowed + `-- --shot-dir=<dir>` saves screenshots (the boss, the stage panel).

const MAIN := preload("res://src/main/main.tscn")
const TIMEOUT := 120.0

var _taxi: Taxi
var _damage: TaxiDamage
var _esc: Escalation
var _director: EnemyDirector
var _t: float = 0.0
var _errors: PackedStringArray = []
var _shot_dir: String = ""
var _done: bool = false


func _ready() -> void:
	MapData.use_builtin()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			_shot_dir = arg.get_slice("=", 1)
	GameState.reset_run()
	add_child(MAIN.instantiate())
	_run()


func _physics_process(delta: float) -> void:
	_t += delta
	if _damage != null and not _damage.is_dead:
		_damage.repair()
	if _t > TIMEOUT and not _done:
		_errors.append("timeout (phase %s, stage %d)" % [_esc.phase if _esc else -1, _esc.index + 1 if _esc else 0])
		_finish()


func _run() -> void:
	await _until(func() -> bool: return get_tree().get_first_node_in_group(&"player_vehicle") != null, 5.0)
	_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
	_damage = _taxi.get_node("TaxiDamage") as TaxiDamage
	_esc = get_tree().get_first_node_in_group(&"escalation") as Escalation
	_director = get_tree().get_first_node_in_group(&"enemy_director") as EnemyDirector
	var shift := get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
	await _until(func() -> bool: return shift.is_active, 5.0)
	var tutorial := get_tree().get_first_node_in_group(&"tutorial") as Tutorial
	if tutorial != null:
		tutorial.skip()
	await _wait(0.5)

	_test_shop()
	_test_stage_one()
	await _test_first_boss()
	await _test_stage_two()
	await _test_elite()
	await _test_final()
	_finish()


func _test_shop() -> void:
	var menu := get_tree().get_first_node_in_group(&"shop_menu") as ShopMenu
	print("[EscalationTest] A tabs %s" % [ShopMenu.active_tabs()])
	if ShopMenu.active_tabs().has(&"energy"):
		_errors.append("A: the MONSTROUS ENERGY tab is still there")
	if menu.activate(ShopMenu.REPAIR) or menu.activate(ShopMenu.CANS) or menu.activate(&"can_holder"):
		_errors.append("A: repair / cans / cup holders can still be bought")
	if ShopMenu.tab_of(CarUpgrades.get_upgrade(&"can_size")) != &"cab":
		_errors.append("A: Monstrous XL is not under THE CAB")


func _test_stage_one() -> void:
	print("[EscalationTest] B %d stages, stage %d (%s), police %s, gang %s, cap %d" % [_esc.stages.size(), _esc.index + 1,
			_esc.stage().title, _director._police.id, _director._gang.id, _director.max_enemies])
	if _esc.stages.size() != 3 or _esc.index != 0 or _esc.phase != Escalation.Phase.STAGE:
		_errors.append("B: the run does not start at stage 1 of 3")
	if _director._police.id != &"police_cruiser" or _director.max_enemies != 5:
		_errors.append("B: stage 1 roster wrong")


func _test_first_boss() -> void:
	# A kill counts.
	var cars := _director.spawn_pursuers(1)
	await _wait(0.3)
	if not cars.is_empty():
		cars[0].health.apply_damage(100000.0)
	await _wait(0.3)
	print("[EscalationTest] C kills after one kill: %d" % _esc.kills)
	if _esc.kills != 1:
		_errors.append("C: a kill did not count (%d)" % _esc.kills)
	_director.clear_all()
	var s := _esc.stage()
	_esc.fares = s.fares
	_esc.kills = s.kills
	await _wait(0.2)
	if _esc.phase != Escalation.Phase.STAGE:
		_errors.append("C: the boss came before the time was survived")
	_esc.seconds = s.seconds
	await _wait(0.3)
	if _esc.phase != Escalation.Phase.BOSS_INCOMING:
		_errors.append("C: objectives met but no boss warning (phase %d)" % _esc.phase)
	await _until(func() -> bool: return _esc.phase == Escalation.Phase.BOSS, Escalation.BOSS_WARNING + 2.0)
	var boss := _boss(0)
	var escorts := _director.enemies.filter(func(c: EnemyCar) -> bool: return c.data.id == &"police_cruiser").size()
	print("[EscalationTest] C boss %s, hp %.0f, mass %.0f, escorts %d" % [boss.data.id if boss else &"none",
			boss.health.max_hp if boss else 0.0, boss.mass if boss else 0.0, escorts])
	if boss == null or boss.data.id != &"boss_captain":
		_errors.append("C: the Precinct Captain did not come")
		return
	if escorts != 2:
		_errors.append("C: %d escort cruisers, want 2" % escorts)
	if boss.relocations_left < 100:
		_errors.append("C: the boss can be lost")
	await _wait(6.0)
	print("[EscalationTest] C boss after 6 s at y %.2f, speed %.1f" % [boss.global_position.y, boss.linear_velocity.length()])
	if boss.global_position.y < -2.0 or boss.global_position.y > 6.0:
		_errors.append("C: the big boss car does not sit on the road (y %.2f)" % boss.global_position.y)
	if boss.linear_velocity.length() < 3.0:
		_errors.append("C: the boss is not driving after 6 s")
	await _shot_boss(boss, "boss_captain.png")
	var cash := GameState.cash
	boss.health.apply_damage(100000.0)
	await _wait(0.3)
	print("[EscalationTest] D phase %d, cash %d -> %d" % [_esc.phase, cash, GameState.cash])
	if _esc.phase != Escalation.Phase.CLEARED or GameState.cash < cash + _esc.stage().reward:
		_errors.append("D: the stage was not cleared / paid")
	await _until(func() -> bool: return _esc.index == 1, Escalation.NEXT_STAGE_DELAY + 2.0)
	await _wait(0.3)
	print("[EscalationTest] D stage %d: police %s, cap %d, heat %d" % [_esc.index + 1, _director._police.id, _director.max_enemies, GameState.heat])
	if _director._police.id != &"swat_van" or _director.max_enemies != 6 or GameState.heat < 2:
		_errors.append("D: stage 2 roster / heat floor wrong")


func _test_stage_two() -> void:
	_director.clear_all()
	await _fast_forward()
	var ids: Array[StringName] = []
	for i in _esc.bosses.size():
		ids.append(_boss(i).data.id if _boss(i) else &"none")
	print("[EscalationTest] E bosses %s" % [ids])
	if ids.size() != 3 or not ids.has(&"gang_boss_red") or not ids.has(&"gang_boss_purple") or not ids.has(&"gang_boss_orange"):
		_errors.append("E: the three gang bosses did not come")
	await _shot("stage_panel_bosses.png")
	for i in _esc.bosses.size():
		if _boss(i):
			_boss(i).health.apply_damage(100000.0)
			await _wait(0.2)
	await _until(func() -> bool: return _esc.index == 2, Escalation.NEXT_STAGE_DELAY + 2.0)
	await _wait(0.3)
	print("[EscalationTest] E stage %d: police %s, gang %s, heat %d" % [_esc.index + 1, _director._police.id, _director._gang.id, GameState.heat])
	if _director._police.id != &"military_jeep" or _director._gang.id != &"cartel_truck" or GameState.heat < 3:
		_errors.append("E: stage 3 roster / heat floor wrong")


func _test_elite() -> void:
	_director.clear_all()
	GameState.set_heat(3)
	_esc._elite_timer = 0.0
	await _wait(0.5)
	var elites := _director.enemies.filter(func(c: EnemyCar) -> bool: return c.data.id == &"cartel_lieutenant").size()
	print("[EscalationTest] F cartel lieutenants hunting: %d" % elites)
	if elites != 1:
		_errors.append("F: no cartel lieutenant at heat 3")


func _test_final() -> void:
	_director.clear_all()
	await _fast_forward()
	var first := _boss(0)
	var second := _boss(1)
	print("[EscalationTest] G bosses %s, %s" % [first.data.id if first else &"none", second.data.id if second else &"none"])
	if first == null or second == null:
		_errors.append("G: the final bosses did not come")
		return
	first.health.apply_damage(100000.0)
	await _wait(0.3)
	if _esc.phase != Escalation.Phase.BOSS:
		_errors.append("G: one boss down ended the fight")
	second.queue_free()   # vanished without being destroyed
	await _wait(0.5)
	var back := _boss(1)
	print("[EscalationTest] G the vanished boss is back: %s" % (back != null and back != second))
	if back == null or back == second:
		_errors.append("G: a vanished boss did not come back")
		return
	back.health.apply_damage(100000.0)
	await _wait(0.5)
	print("[EscalationTest] G phase %d (victory = %d)" % [_esc.phase, Escalation.Phase.VICTORY])
	if _esc.phase != Escalation.Phase.VICTORY:
		_errors.append("G: no victory after the last boss")


## Objectives met -> the boss warning -> the fight.
func _fast_forward() -> void:
	var s := _esc.stage()
	_esc.fares = s.fares
	_esc.kills = s.kills
	_esc.seconds = s.seconds
	await _until(func() -> bool: return _esc.phase == Escalation.Phase.BOSS, Escalation.BOSS_WARNING + 2.0)
	await _wait(0.3)


func _boss(i: int) -> EnemyCar:
	if i >= _esc.bosses.size():
		return null
	return _esc.bosses[i]["car"] as EnemyCar if Escalation._alive(_esc.bosses[i]) else null


# --- helpers ----------------------------------------------------------------------------

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


## Teleports the boss in front of the taxi for a picture of it.
func _shot_boss(boss: EnemyCar, file: String) -> void:
	if _shot_dir.is_empty():
		return
	var fwd := -_taxi.global_basis.z
	fwd.y = 0.0
	var pos := _taxi.global_position + fwd.normalized() * 16.0 + Vector3(0, 0.6, 0)
	boss.teleport(Transform3D(Basis.looking_at(-fwd.normalized().rotated(Vector3.UP, 0.6), Vector3.UP), pos))
	boss.ai.set_physics_process(false)
	await _wait(0.6)
	await _shot(file)
	# From further off: the boss marker's gold beam and BOSS tag (D-102).
	boss.teleport(Transform3D(boss.global_basis, _taxi.global_position + fwd.normalized() * 50.0 + Vector3(0, 0.6, 0)))
	await _wait(0.6)
	await _shot(file.replace(".png", "_far.png"))
	boss.ai.set_physics_process(true)


func _shot(file: String) -> void:
	if _shot_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot_dir.path_join(file))
	print("[EscalationTest] screenshot ", file)


func _finish() -> void:
	if _done:
		return
	_done = true
	set_physics_process(false)
	if _errors.is_empty():
		print("[EscalationTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[EscalationTest] FAIL: ", e)
		get_tree().quit(1)
