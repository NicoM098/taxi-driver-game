class_name StreetEncounters
extends Node
## Random hostile situations on the open streets (StreetEncounter resources in
## res://data/events/): after a quiet stretch with no enemy around, one that fits the moment
## (fare aboard or not, level, cash carried, kills, district) is rolled and its cars are
## spawned by the EnemyDirector, out of sight and on streets they can drive out of.
## Debug: H fires the next encounter in the list, ignoring its conditions.
## Automated tests run on MapData.override: there the timer is off unless `run_in_tests`.

@export var encounters_dir: String = "res://data/events/"
## Quiet seconds before the first one (min, max).
@export var first_delay: Vector2 = Vector2(70.0, 100.0)
## Quiet seconds between two (min, max) at level 1...
@export var interval: Vector2 = Vector2(80.0, 140.0)
## ...shortened by this fraction per level after the first, never below min_interval.
@export var level_speedup: float = 0.07
@export var min_interval: float = 40.0
## Nothing new right after a fare gets in (let the file and the first seconds breathe).
@export var ride_start_grace: float = 10.0
@export var run_in_tests: bool = false

var encounters: Array[StreetEncounter] = []
var fired: int = 0
var last_id: StringName = &""

var _taxi: Taxi
var _city: City
var _director: EnemyDirector
var _rides: RideManager
var _shift: ShiftManager
var _timer: float = 0.0
var _ride_time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _debug_index: int = -1
var _debug_held: bool = false


func _ready() -> void:
	add_to_group(&"street_encounters")
	_rng.randomize()
	for file in ResourceLoader.list_directory(encounters_dir):
		var res := load(encounters_dir + file)
		if res is StreetEncounter:
			encounters.append(res)
	_timer = _rng.randf_range(first_delay.x, first_delay.y)
	EventBus.taxi_wrecked.connect(func(_reason: StringName) -> void: _timer = maxf(_timer, interval.x))


func _physics_process(delta: float) -> void:
	if _taxi == null:
		_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
		_city = get_tree().get_first_node_in_group(&"city") as City
		_director = get_tree().get_first_node_in_group(&"enemy_director") as EnemyDirector
		_rides = get_tree().get_first_node_in_group(&"ride_manager") as RideManager
		_shift = get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
		return
	if _director == null or encounters.is_empty():
		return
	var key := Input.is_physical_key_pressed(KEY_H)
	if key and not _debug_held:
		debug_fire_next()
	_debug_held = key
	_ride_time = _ride_time + delta if _on_ride() else 0.0
	if MapData.override != null and not run_in_tests:
		return
	if GameState.tutorial_active:
		return
	if _shift != null and not _shift.is_active:
		return
	if _rides != null and _rides.is_wrecked():
		return
	# The clock only runs while nobody is after the taxi: trouble comes after a quiet stretch.
	if not _director.enemies.is_empty():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	var pick := _pick()
	if pick == null or (_on_ride() and _ride_time < ride_start_grace):
		_timer = 15.0
		return
	fire(pick)
	_timer = next_interval()


## Quiet seconds until the next encounter at the current level.
func next_interval() -> float:
	var level := maxi(GameState.shift_number, 1)
	var scale := maxf(1.0 - level_speedup * (level - 1), 0.3)
	return maxf(_rng.randf_range(interval.x, interval.y) * scale, min_interval)


## True if `e` fits the current moment.
func is_eligible(e: StreetEncounter) -> bool:
	var on_ride := _on_ride()
	if (e.when == StreetEncounter.When.ON_RIDE and not on_ride) or (e.when == StreetEncounter.When.FREE_ROAM and on_ride):
		return false
	if maxi(GameState.shift_number, 1) < e.min_level or GameState.cash < e.min_cash:
		return false
	if e.min_kills > 0 and (_shift == null or _shift.enemies_destroyed < e.min_kills):
		return false
	if not e.districts.is_empty() and (_city == null or not e.districts.has(_city.get_district_at(_taxi.global_position))):
		return false
	return true


## Starts an encounter now. Returns the cars that showed up.
func fire(e: StreetEncounter) -> Array[EnemyCar]:
	var n := e.count + floori(e.extra_per_level * maxi(GameState.shift_number - 1, 0))
	var data: EnemyCarData = null
	if e.enemy != "":
		data = load(e.enemy) as EnemyCarData
	var pattern := SpawnPursuersEvent.PATTERN_NAMES[e.pattern]
	# Ambushes need somewhere the taxi is heading: the fare's destination, or just ahead.
	var heading_to := _rides.ride.destination.global_position if _on_ride() else _director.point_ahead()
	EventBus.hud_message.emit(e.title, &"bad")
	var cars := _director.spawn_on_route(heading_to, pattern, n, data)
	if e.heat_delta != 0:
		GameState.set_heat(GameState.heat + e.heat_delta)
	if not cars.is_empty():
		fired += 1
		last_id = e.id
	return cars


func debug_fire_next() -> Array[EnemyCar]:
	_debug_index = (_debug_index + 1) % encounters.size()
	return fire(encounters[_debug_index])


func _pick() -> StreetEncounter:
	var pool: Array[StreetEncounter] = []
	for e in encounters:
		if is_eligible(e):
			pool.append(e)
	# Not the same one twice in a row when there is a choice.
	if pool.size() > 1:
		pool = pool.filter(func(e: StreetEncounter) -> bool: return e.id != last_id)
	var total := 0.0
	for e in pool:
		total += e.weight
	var roll := _rng.randf() * total
	for e in pool:
		roll -= e.weight
		if roll <= 0.0:
			return e
	return pool.back() if not pool.is_empty() else null


func _on_ride() -> bool:
	return _rides != null and _rides.state == RideManager.State.RIDING and _rides.ride != null
