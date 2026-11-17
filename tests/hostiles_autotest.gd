extends Node
## Headless test through Main on a map with walled-in courtyards (playtest 2026-11-13).
##  A. Enemy spawns (tail, relocation, ambush) are never in a courtyard that has no way out.
##  B. Street encounters: every file in data/events/ fires its own enemy type; conditions
##     (fare aboard / cash / kills / level) are respected; the quiet-time clock fires one.
##  C. The three hostile passengers bring the enemies their file promises.
##  D. New enemy types: the Bruiser does not shoot and is heavier than the taxi; old maps
##     (format 1) get the jumpable ramp / container defaults.
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/hostiles_autotest.tscn

const MAIN := preload("res://src/main/main.tscn")
const TIMEOUT := 120.0

var _taxi: Taxi
var _rides: RideManager
var _shift: ShiftManager
var _spawner: PassengerSpawner
var _dossier: Dossier
var _city: City
var _director: EnemyDirector
var _encounters: StreetEncounters
var _damage: TaxiDamage
var _t: float = 0.0
var _errors: PackedStringArray = []
var _done: bool = false


func _ready() -> void:
	GangRides.enabled = false   # the passenger-file game (D-088 keeps it, switched off)
	MapData.override = _courtyard_map()
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(MAIN.instantiate())
	_run()


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT and not _done:
		_errors.append("timeout")
		_finish()


## 40 x 40 cells, four hollow rings of buildings (6 x 6 cell courtyards with no way in) around
## the player start, stops on the streets between them.
static func _courtyard_map() -> MapData:
	var map := MapData.make_empty("courtyards", 40, 40)
	for corner: Vector2i in [Vector2i(8, 8), Vector2i(24, 8), Vector2i(8, 24), Vector2i(24, 24)]:
		for rect: Rect2i in [Rect2i(0, 0, 8, 1), Rect2i(0, 7, 8, 1), Rect2i(0, 1, 1, 6), Rect2i(7, 1, 1, 6)]:
			map.pieces.append(MapData.make_piece("building", corner.x + rect.position.x, corner.y + rect.position.y, rect.size.x, rect.size.y))
	for cell: Vector2i in [Vector2i(20, 4), Vector2i(4, 20), Vector2i(36, 20), Vector2i(20, 36), Vector2i(3, 3), Vector2i(36, 36), Vector2i(18, 12), Vector2i(22, 28),
			Vector2i(4, 12), Vector2i(12, 4), Vector2i(28, 4), Vector2i(36, 12), Vector2i(4, 28), Vector2i(12, 36),
			Vector2i(28, 36), Vector2i(36, 28), Vector2i(20, 14), Vector2i(20, 26), Vector2i(14, 20), Vector2i(26, 20)]:
		map.pieces.append(MapData.make_piece("stop", cell.x, cell.y))
	map.pieces.append(MapData.make_piece("repair", 1, 34, 3, 3))
	map.pieces.append(MapData.make_piece("spawn", 20, 20))
	return map


func _run() -> void:
	await _until(func() -> bool: return get_tree().get_first_node_in_group(&"player_vehicle") != null, 5.0)
	_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
	_rides = get_tree().get_first_node_in_group(&"ride_manager") as RideManager
	_shift = get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
	_spawner = get_tree().get_first_node_in_group(&"passenger_spawner") as PassengerSpawner
	_dossier = get_tree().get_first_node_in_group(&"dossier") as Dossier
	_city = get_tree().get_first_node_in_group(&"city") as City
	_director = get_tree().get_first_node_in_group(&"enemy_director") as EnemyDirector
	_encounters = get_tree().get_first_node_in_group(&"street_encounters") as StreetEncounters
	_damage = _taxi.get_node("TaxiDamage") as TaxiDamage
	await _until(func() -> bool: return _shift.is_active, 5.0)
	await _wait(1.0)
	_damage.taxi_health.max_hp = 100000.0
	_damage.taxi_health.revive()
	_damage.driver_health.max_hp = 100000.0
	_damage.driver_health.revive()
	if _encounters == null:
		_errors.append("no StreetEncounters node in the game scene")
		return _finish()

	_test_data()
	await _test_walled_in()
	await _test_encounters()
	await _test_passengers()
	_finish()


# --- D (pure data, first) ---------------------------------------------------------------

func _test_data() -> void:
	var bruiser := load("res://data/enemies/bruiser.tres") as EnemyCarData
	var gang := load("res://data/enemies/gang_coupe.tres") as EnemyCarData
	if bruiser == null or gang == null:
		_errors.append("D: new enemy files do not load")
		return
	print("[HostilesTest] D bruiser: %d hp, %d kg, shoots=%s | gang coupe: %d hp, %.0f m/s" % [
		bruiser.hp, bruiser.mass, bruiser.shoots, gang.hp, gang.max_speed])
	if bruiser.shoots or bruiser.mass <= _taxi.mass:
		_errors.append("D: the bruiser should be an unarmed car heavier than the taxi")
	var old := {"format": 1, "name": "old", "width": 20, "depth": 20, "pieces": [
		{"type": "ramp", "x": 3, "z": 3, "w": 1, "d": 1, "h": 2.0, "shape": "kicker"},
		{"type": "ramp", "x": 5, "z": 3, "w": 1, "d": 1, "h": 2.5, "shape": "kicker"},
		{"type": "ramp", "x": 7, "z": 3, "w": 1, "d": 1, "h": 2.0, "shape": "wedge"},
		{"type": "containers", "x": 3, "z": 2, "w": 1, "d": 1, "h": 2.0},
		{"type": "containers", "x": 5, "z": 2, "w": 1, "d": 1, "h": 3.0}]}
	var upgraded := MapData.from_dict(old)
	var heights: Array[float] = []
	for p in upgraded.pieces:
		heights.append(float(p["h"]))
	old["format"] = 2
	var kept := MapData.from_dict(old)
	print("[HostilesTest] D format 1 map heights after loading: %s (format 2 stays %.1f)" % [heights, float(kept.pieces[0]["h"])])
	var expected: Array[float] = [3.0, 2.5, 2.0, 1.0, 3.0]
	if heights != expected:
		_errors.append("D: old-map upgrade gave %s" % [heights])
	if not is_equal_approx(float(kept.pieces[0]["h"]), 2.0):
		_errors.append("D: a format 2 map must not be changed on load")


# --- A ----------------------------------------------------------------------------------

func _test_walled_in() -> void:
	var cut_off := _city.count_cut_off_cells()
	print("[HostilesTest] A map: %d street cells are walled in (4 courtyards of 36)" % cut_off)
	if cut_off != 144:
		_errors.append("A: expected 144 walled-in cells, got %d" % cut_off)
	var courtyard := _city.map.cell_center(11, 11)
	if _city.can_reach(courtyard, _taxi.global_position):
		_errors.append("A: the courtyard counts as reachable")
	var spawned := 0
	var trapped := 0
	for round_index in 12:
		for car in _director.spawn_pursuers(4):
			spawned += 1
			if not _city.can_reach(car.global_position, _taxi.global_position):
				trapped += 1
		await _wait(0.05)
		_director.clear_all()
		await _wait(0.05)
	# Ambushes on the way to the far corner, from several places.
	for cell: Vector2i in [Vector2i(20, 20), Vector2i(4, 4), Vector2i(20, 3), Vector2i(36, 22)]:
		_taxi.teleport(Transform3D(Basis.IDENTITY, _city.map.cell_center(cell.x, cell.y) + Vector3(0, 1.0, 0)))
		await _wait(0.4)
		for car in _director.spawn_on_route(_city.map.cell_center(37, 37), &"pincer", 4):
			spawned += 1
			if not _city.can_reach(car.global_position, _taxi.global_position):
				trapped += 1
		await _wait(0.05)
		_director.clear_all()
		await _wait(0.05)
	print("[HostilesTest] A %d enemy cars spawned, %d of them in a walled-in courtyard" % [spawned, trapped])
	if spawned < 40:
		_errors.append("A: only %d cars spawned" % spawned)
	if trapped > 0:
		_errors.append("A: %d cars spawned where they cannot get out" % trapped)
	# Relocation of an outrun car uses the same rule.
	var cars := _director.spawn_pursuers(1)
	await _wait(0.2)
	if not cars.is_empty():
		cars[0].teleport(Transform3D(Basis.IDENTITY, Vector3(0, -40, 0)))   # "fell out of the world"
		await _wait(3.0)
		if is_instance_valid(cars[0]):
			var ok := _city.can_reach(cars[0].global_position, _taxi.global_position)
			print("[HostilesTest] A relocated car at cell %s, can reach the taxi: %s" % [_city.map.world_to_cell(cars[0].global_position), ok])
			if not ok:
				_errors.append("A: a relocated car ended up walled in")
	_director.clear_all()
	_taxi.teleport(Transform3D(Basis.IDENTITY, _city.map.cell_center(20, 20) + Vector3(0, 1.0, 0)))
	await _wait(0.5)


# --- B ----------------------------------------------------------------------------------

func _test_encounters() -> void:
	var ids := PackedStringArray()
	for e in _encounters.encounters:
		ids.append(String(e.id))
	print("[HostilesTest] B encounters: ", ids)
	if _encounters.encounters.size() < 5:
		_errors.append("B: expected at least 5 encounter files, found %d" % _encounters.encounters.size())
	# Conditions, with no fare aboard, no cash, no kills, level 1.
	GameState.cash = 0
	GameState.shift_number = 1
	_shift.enemies_destroyed = 0
	var eligible := _eligible_ids()
	print("[HostilesTest] B free roam, broke, level 1: eligible ", eligible)
	for id: String in ["roadblock", "cash_robbery_crew", "payback", "turf_war"]:
		if eligible.has(id):
			_errors.append("B: '%s' should not be possible yet" % id)
	if not eligible.has("gang_drive_by"):
		_errors.append("B: the drive-by should always be possible")
	GameState.cash = 400
	GameState.shift_number = 2
	_shift.enemies_destroyed = 3
	eligible = _eligible_ids()
	print("[HostilesTest] B free roam, $400, level 2, 3 kills: eligible ", eligible)
	for id: String in ["cash_robbery_crew", "payback", "turf_war"]:
		if not eligible.has(id):
			_errors.append("B: '%s' should be possible now" % id)
	# Every encounter spawns its own cars, none of them walled in.
	for e in _encounters.encounters:
		var cars := _encounters.fire(e)
		var want := "hitman_sedan" if e.enemy == "" else e.enemy.get_file().get_basename()
		var wrong := 0
		var trapped := 0
		var waiting := 0
		for car in cars:
			if String(car.data.id) != want:
				wrong += 1
			if not _city.can_reach(car.global_position, _taxi.global_position):
				trapped += 1
			if car.ai.mode == EnemyDriverAI.Mode.AMBUSH:
				waiting += 1
		print("[HostilesTest] B %s: %d x %s (%d waiting ahead)" % [e.id, cars.size(), want, waiting])
		if cars.is_empty() or wrong > 0 or trapped > 0:
			_errors.append("B: %s -> %d cars, %d of the wrong type, %d walled in" % [e.id, cars.size(), wrong, trapped])
		await _wait(0.1)
		_director.clear_all()
		await _wait(0.1)
	# The quiet-time clock.
	var before := _encounters.fired
	_encounters.run_in_tests = true
	_encounters.set("_timer", 1.0)
	await _until(func() -> bool: return _encounters.fired > before, 4.0)
	print("[HostilesTest] B clock: fired '%s' after a quiet second, next one in %.0f s, %d enemies around" % [
		_encounters.last_id, float(_encounters.get("_timer")), _director.enemies.size()])
	if _encounters.fired == before:
		_errors.append("B: the clock never started an encounter")
	var frozen: float = _encounters.get("_timer")
	await _wait(1.0)
	if not is_equal_approx(float(_encounters.get("_timer")), frozen):
		_errors.append("B: the clock keeps running while enemies are around")
	_encounters.run_in_tests = false
	_director.clear_all()
	GameState.cash = 0
	GameState.shift_number = 1
	await _wait(0.2)


func _eligible_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for e in _encounters.encounters:
		if _encounters.is_eligible(e):
			out.append(String(e.id))
	return out


# --- C ----------------------------------------------------------------------------------

func _test_passengers() -> void:
	for spec: Array in [["bank_robber", "police_cruiser", 2], ["key_witness", "bruiser", 0], ["gang_courier", "gang_coupe", 0]]:
		var id: String = spec[0]
		GameState.set_heat(0)
		if not await _start_ride(id, &"drive"):
			continue
		await _wait(0.3)
		var heat := GameState.heat
		_rides.events.debug_fire_pending()
		await _wait(0.2)
		var kinds: Dictionary = {}
		var trapped := 0
		for car in _director.enemies:
			kinds[String(car.data.id)] = int(kinds.get(String(car.data.id), 0)) + 1
			if not _city.can_reach(car.global_position, _taxi.global_position):
				trapped += 1
		print("[HostilesTest] C %s -> %s: heat %d, enemies %s" % [id, _rides.ride.destination.stop_name, heat, kinds])
		if not kinds.has(spec[1]):
			_errors.append("C: %s brought no %s" % [id, spec[1]])
		if heat < int(spec[2]):
			_errors.append("C: %s should raise the heat to %d (is %d)" % [id, spec[2], heat])
		if trapped > 0:
			_errors.append("C: %s: %d cars walled in" % [id, trapped])
		_rides.fail_ride(&"test", "")
		await _until(func() -> bool: return _rides.state == RideManager.State.IDLE, 4.0)
		_director.clear_all()
		await _wait(0.3)


# --- Helpers ----------------------------------------------------------------------------

func _start_ride(profile_id: String, action: StringName) -> bool:
	var profile := load("res://data/passengers/%s.tres" % profile_id) as PassengerProfile
	if profile == null:
		_errors.append("%s: profile does not load" % profile_id)
		return false
	var best: TaxiStop = null
	var best_d := INF
	for s in _city.stops:
		var d := s.global_position.distance_to(_taxi.global_position)
		if not s.occupied and d < best_d:
			best_d = d
			best = s
	if best == null:
		_errors.append("%s: no free taxi stop to board at" % profile_id)
		return false
	var p := _spawner.spawn_at(profile, best)
	var to := p.global_position - best.global_position
	to.y = 0.0
	_taxi.teleport(Transform3D(Basis.looking_at(to.normalized().cross(Vector3.UP), Vector3.UP), best.global_position + Vector3(0, 1.0, 0)))
	if not await _until(func() -> bool: return _dossier.is_open, 5.0):
		_errors.append("%s: file never opened (state %d)" % [profile_id, _rides.state])
		return false
	_dossier.choose(action)
	if not await _until(func() -> bool: return _rides.state == RideManager.State.RIDING, 3.0):
		_errors.append("%s: ride did not start" % profile_id)
		return false
	return true


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
	MapData.override = null
	if _errors.is_empty():
		print("[HostilesTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[HostilesTest] FAIL: ", e)
		get_tree().quit(1)
