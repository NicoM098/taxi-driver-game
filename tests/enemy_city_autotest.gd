extends Node
## Headless: hitmen navigating the real city (road graph) to a parked taxi.
## Spawns 2 hitmen 70-140 m away (behind buildings) and checks that both get within 30 m,
## logging stuck recoveries and flips; then watches 8 s with the taxi parked (standoff, hit rate).
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/enemy_city_autotest.tscn
## Windowed + `-- --shot-dir=<dir>`: runs through Main (HUD) and saves a screenshot looking at
## the first hitman that arrives.

const GAME := preload("res://src/main/game.tscn")
const MAIN := preload("res://src/main/main.tscn")

var _taxi: Taxi
var _director: EnemyDirector
var _enemies: Array[EnemyCar] = []
var _t: float = 0.0
var _reached: Dictionary = {}
var _unstuck: Dictionary = {}
var _flips: int = 0
var _errors: PackedStringArray = []
var _spawned: bool = false
var _shot_dir: String = ""
var _shot_at: float = -1.0
var _look_at: EnemyCar
var _all_reached_at: float = -1.0
var _min_dist: float = INF
var _close_time: float = 0.0   # seconds with any hitman within 4 m (glued to the taxi)
var _close_modes: Dictionary = {}
var _crashes_on_taxi: int = 0
var _hits: int = 0
var _hit_sum: float = 0.0
var _tracers: int = 0


func _ready() -> void:
	MapData.use_builtin()   # never the user's edited map
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			_shot_dir = arg.get_slice("=", 1)
	add_child(MAIN.instantiate() if not _shot_dir.is_empty() else GAME.instantiate())


func _physics_process(delta: float) -> void:
	_t += delta
	if not _shot_dir.is_empty():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # real mouse must not move the view during shots
	if _taxi == null:
		_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
		_director = get_tree().get_first_node_in_group(&"enemy_director") as EnemyDirector
		return
	if not _spawned and _t > 2.0:
		_spawned = true
		_enemies = _director.spawn_pursuers(2)
		for e in _enemies:
			print("[CityEnemyTest] %s spawned %.0f m away" % [e.name, e.global_position.distance_to(_taxi.global_position)])
			_unstuck[e.name] = 0
		return
	if not _spawned:
		return
	if not _shot_dir.is_empty() and absf(_t - 5.0) < delta * 0.5:
		get_viewport().get_texture().get_image().save_png(_shot_dir.path_join("enemy_approach.png"))
		print("[CityEnemyTest] approach screenshot saved")
	for e in _enemies:
		if not is_instance_valid(e):
			continue
		if e.ai.mode == EnemyDriverAI.Mode.UNSTUCK and e.ai._mode_time < delta * 1.5:
			_unstuck[e.name] += 1
		if e.global_basis.y.dot(Vector3.UP) < 0.3 and int(_t * 60) % 60 == 0:
			_flips += 1
		if not _reached.has(e.name) and e.global_position.distance_to(_taxi.global_position) < 30.0:
			_reached[e.name] = _t - 2.0
			print("[CityEnemyTest] %s reached the taxi after %.1f s" % [e.name, _t - 2.0])
			if _look_at == null and not _shot_dir.is_empty():
				_look_at = e
				_shot_at = _t + 2.5
	if not _shot_dir.is_empty() and _look_at != null and is_instance_valid(_look_at):
		if _shot_at > 0.0 and absf(_t - (_shot_at - 0.5)) < delta * 0.5:
			# Turn the parked taxi to face the hitman (head look can't reach behind the seats).
			var to := _look_at.global_position - _taxi.global_position
			to.y = 0.0
			_taxi.teleport(Transform3D(Basis.looking_at(to.normalized(), Vector3.UP), _taxi.global_position + Vector3(0, 0.3, 0)))
		if _shot_at > 0.0 and _t >= _shot_at:
			_shot_at = -1.0
			get_viewport().get_texture().get_image().save_png(_shot_dir.path_join("enemy_attack.png"))
			print("[CityEnemyTest] screenshot saved")
	if _reached.size() == _enemies.size() and _all_reached_at < 0.0:
		_all_reached_at = _t
		var dmg0 := _taxi.get_node("TaxiDamage") as TaxiDamage
		dmg0.taxi_health.max_hp = 100000.0  # keep the taxi alive while we observe
		dmg0.taxi_health.revive()
		dmg0.driver_health.max_hp = 100000.0
		dmg0.driver_health.revive()
		_taxi.crashed.connect(func(_i: float) -> void: _crashes_on_taxi += 1)
		EventBus.player_hit.connect(func(a: float, _f: Vector3) -> void:
			_hits += 1
			_hit_sum += a)
	if _all_reached_at > 0.0:
		var closest := INF
		for e in _enemies:
			if is_instance_valid(e):
				var d := e.global_position.distance_to(_taxi.global_position)
				closest = minf(closest, d)
				if d < 4.0:
					var key := "%s spd%.0f" % [EnemyDriverAI.Mode.keys()[e.ai.mode], e.linear_velocity.length()]
					_close_modes[key] = _close_modes.get(key, 0) + 1
		_min_dist = minf(_min_dist, closest)
		if closest < 4.0:
			_close_time += delta
	if (_all_reached_at > 0.0 and _t - _all_reached_at > 8.0 and _shot_at < 0.0) or _t > 50.0:
		_finish()


func _finish() -> void:
	set_physics_process(false)
	print("[CityEnemyTest] reached %d/%d, unstuck recoveries %s, flip-seconds %d" % [_reached.size(), _enemies.size(), _unstuck, _flips])
	var dmg := _taxi.get_node("TaxiDamage") as TaxiDamage
	print("[CityEnemyTest] next 8 s with the taxi parked: closest %.1f m, taxi bumped %d times, damage taken body %.0f driver %.0f" % [
		_min_dist, _crashes_on_taxi, dmg.taxi_health.max_hp - dmg.taxi_health.hp, dmg.driver_health.max_hp - dmg.driver_health.hp])
	print("[CityEnemyTest] player_hit events %d, raw damage %.0f" % [_hits, _hit_sum])
	for e in _enemies:
		if is_instance_valid(e):
			print("[CityEnemyTest]   %s gunner shots %d (gunners on car: %d)" % [e.name, e.gunner.shots_fired, e.find_children("*", "EnemyGunner", true, false).size()])
	var elapsed := _t - _all_reached_at if _all_reached_at > 0.0 else 0.0
	print("[CityEnemyTest] observed %.1f s after arrival -> %.1f hits/s" % [elapsed, _hits / maxf(elapsed, 0.01)])
	print("[CityEnemyTest] time glued to the taxi (< 4 m): %.1f s  modes(frames): %s" % [_close_time, _close_modes])
	if _close_time > 1.5:
		_errors.append("hitmen crowd into a parked taxi (%.1f s within 4 m)" % _close_time)
	if _reached.size() < _enemies.size():
		for e in _enemies:
			if is_instance_valid(e) and not _reached.has(e.name):
				print("[CityEnemyTest]   %s still %.0f m away at %s, mode %s" % [e.name, e.global_position.distance_to(_taxi.global_position), e.global_position.round(), EnemyDriverAI.Mode.keys()[e.ai.mode]])
				var city := get_tree().get_first_node_in_group(&"city") as City
				var cell := city.map.world_to_cell(e.global_position)
				var near := PackedStringArray()
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						var idx := city.map.piece_at(cell + Vector2i(dx, dz), false)
						near.append(String(city.map.pieces[idx]["type"]) if idx >= 0 else "street")
				print("[CityEnemyTest]   cell %s, 3x3 around: %s" % [cell, near])
		_errors.append("not all hitmen reached the taxi within 40 s")
	if _errors.is_empty():
		print("[CityEnemyTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[CityEnemyTest] FAIL: ", e)
		get_tree().quit(1)
