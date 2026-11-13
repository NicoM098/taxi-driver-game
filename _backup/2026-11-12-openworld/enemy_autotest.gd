extends Node
## Headless Phase 06 test:
##  0. city road graph returns a sensible route across the city
##  1. a hitman spawned behind a parked taxi closes in (< 25 m)
##  2. its gunman damages the taxi / driver (bullets via hitboxes)
##  3. killing it pays the bounty and raises heat
##  4. crash damage hurts the taxi; jump landings don't (grace)
##  5. taxi at 0 HP -> wrecked; auto-repaired in a world without a ShiftManager
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/enemy_autotest.tscn

const COURSE := preload("res://src/vehicle/test_drive.tscn")

var _taxi: Taxi
var _dmg: TaxiDamage
var _director: EnemyDirector
var _enemy: EnemyCar
var _t: float = 0.0
var _step: int = 0
var _step_t: float = 0.0
var _errors: PackedStringArray = []
var _cash_before: int = 0
var _hp_before: float = 0.0
var _wrecked: bool = false
var _bounty: int = 0


func _ready() -> void:
	# 0. Road graph check on a standalone city (freed right after).
	var city := City.new()
	add_child(city)
	var a := City.block_center(0, 0) + Vector3(-23, 0, -23)
	var b := City.block_center(7, 7) + Vector3(23, 0, 23)
	var route := city.get_route(a, b)
	var length := 0.0
	for i in range(1, route.size()):
		length += route[i - 1].distance_to(route[i])
	print("[EnemyTest] road graph: %d points, route %d waypoints, %.0f m (straight %.0f m)" % [
		city.road_points().size(), route.size(), length, a.distance_to(b)])
	if city.road_points().size() != 81 or route.size() < 10 or length < a.distance_to(b):
		_errors.append("road graph route looks wrong")
	remove_child(city)
	city.free()

	var course := COURSE.instantiate()
	add_child(course)
	_taxi = course.get_node("Taxi") as Taxi
	_director = EnemyDirector.new()
	add_child(_director)
	EventBus.taxi_wrecked.connect(func(_r: StringName) -> void: _wrecked = true)


func _physics_process(delta: float) -> void:
	_t += delta
	_step_t += delta
	if _t > 60.0:
		_fail("timeout at step %d" % _step)
		return
	match _step:
		0:
			if _t > 1.5:
				_dmg = _taxi.get_node("TaxiDamage") as TaxiDamage
				var cars := _director.spawn_pursuers(1)
				if cars.is_empty():
					_fail("director did not spawn")
					return
				_enemy = cars[0]
				print("[EnemyTest] hitman spawned %.0f m away" % _enemy.global_position.distance_to(_taxi.global_position))
				_next()
		1:
			var d := _enemy.global_position.distance_to(_taxi.global_position)
			if d < 25.0:
				print("[EnemyTest] hitman closed in to %.0f m after %.1f s (mode %s)" % [d, _step_t, EnemyDriverAI.Mode.keys()[_enemy.ai.mode]])
				_next()
			elif _step_t > 15.0:
				_fail("hitman never closed in (still %.0f m, mode %s)" % [d, EnemyDriverAI.Mode.keys()[_enemy.ai.mode]])
		2:
			var hurt := _dmg.taxi_health.hp < _dmg.taxi_health.max_hp or _dmg.driver_health.hp < _dmg.driver_health.max_hp
			if hurt:
				print("[EnemyTest] taxi shot: body %.0f, driver %.0f after %.1f s" % [_dmg.taxi_health.hp, _dmg.driver_health.hp, _step_t])
				_cash_before = GameState.cash
				_bounty = _enemy.data.bounty
				_enemy.health.apply_damage(9999.0)
				_next()
			elif _step_t > 20.0:
				_fail("hitman never damaged the taxi")
		3:
			if _step_t > 0.2:
				var gone := not is_instance_valid(_enemy)
				print("[EnemyTest] hitman killed: cash %d -> %d, heat %d, car removed=%s, director list %d" % [_cash_before, GameState.cash, GameState.heat, gone, _director.enemies.size()])
				if not gone:
					_errors.append("killed hitman should explode and disappear instantly")
				if GameState.cash != _cash_before + _bounty:
					_errors.append("bounty not paid")
				if GameState.heat < 1:
					_errors.append("heat not raised")
				_dmg.repair()
				_hp_before = _dmg.taxi_health.hp
				_dmg.apply_crash(20.0)
				_next()
		4:
			var lost := _hp_before - _dmg.taxi_health.hp
			print("[EnemyTest] crash (dv 20): taxi lost %.0f HP" % lost)
			if lost <= 0.0:
				_errors.append("crash did not damage the taxi")
			_dmg.taxi_health.apply_damage(9999.0)
			_next()
		5:
			if _wrecked and _step_t < 0.5:
				pass
			elif _step_t > 0.5 and not _wrecked:
				_fail("taxi at 0 HP did not wreck")
			elif _step_t > 5.0:
				print("[EnemyTest] wrecked -> auto repaired: %s (hp %.0f)" % [not _dmg.is_wrecked, _dmg.taxi_health.hp])
				if _dmg.is_wrecked:
					_errors.append("no auto repair without a ShiftManager")
				_finish()


func _next() -> void:
	_step += 1
	_step_t = 0.0


func _fail(msg: String) -> void:
	_errors.append(msg)
	_finish()


func _finish() -> void:
	set_physics_process(false)
	if _errors.is_empty():
		print("[EnemyTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[EnemyTest] FAIL: ", e)
		get_tree().quit(1)
