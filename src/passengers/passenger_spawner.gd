class_name PassengerSpawner
extends Node3D
## Keeps `max_waiting` passengers waiting at random free TaxiStops around the taxi.
## Profiles are loaded from every resource in `profiles_dir` (data-driven: add a .tres, done).

@export var profiles_dir: String = "res://data/passengers/"
@export var max_waiting: int = 8
@export var min_spawn_distance: float = 35.0
@export var max_spawn_distance: float = 230.0
@export var respawn_interval: float = 1.0
## Profiles used while the tutorial runs (GameState.tutorial_active): calm fares only.
@export var tutorial_profiles: Array[StringName] = [&"commuter"]

var profiles: Array[PassengerProfile] = []
var waiting: Array[WaitingPassenger] = []

var _city: City
var _taxi: Node3D
var _timer: float = 0.0
var _beam_mat: Material
var _rng := RandomNumberGenerator.new()
var _debug_index: int = -1


func _ready() -> void:
	add_to_group(&"passenger_spawner")
	_rng.randomize()
	_beam_mat = load("res://assets/materials/beam_yellow.tres")
	for file in ResourceLoader.list_directory(profiles_dir):
		var res := load(profiles_dir + file)
		if res is PassengerProfile:
			profiles.append(res)
	if profiles.is_empty():
		push_error("[Spawner] no PassengerProfile resources in " + profiles_dir)


func _physics_process(delta: float) -> void:
	if _city == null:
		_city = get_tree().get_first_node_in_group(&"city") as City
	if _taxi == null:
		_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Node3D
	if _city == null or _taxi == null or profiles.is_empty():
		return
	if Input.is_action_just_pressed(&"debug_next_passenger"):
		debug_spawn_next()
	_timer -= delta
	if _timer <= 0.0 and waiting.size() < max_waiting:
		_timer = respawn_interval
		spawn_one()


func spawn_one() -> WaitingPassenger:
	var profile := _pick_profile()
	var taxi_pos := _taxi.global_position
	var candidates: Array[TaxiStop] = []
	# A profile tied to districts this map does not have can show up anywhere.
	var restricted := false
	for d in profile.districts:
		if _city.districts.has(d):
			restricted = true
	for stop in _city.stops:
		if stop.occupied:
			continue
		if restricted and not profile.districts.has(stop.district):
			continue
		var d := stop.global_position.distance_to(taxi_pos)
		if d >= min_spawn_distance and d <= max_spawn_distance:
			candidates.append(stop)
	if candidates.is_empty():
		return null
	return spawn_at(profile, candidates.pick_random())


## Spawns a specific profile at a specific stop (also used by tests / future scripted events).
func spawn_at(profile: PassengerProfile, stop: TaxiStop) -> WaitingPassenger:
	var passenger := WaitingPassenger.new()
	passenger.name = "Waiting_%s" % profile.id
	passenger.instance = PassengerInstance.create(profile, _rng)
	add_child(passenger)
	passenger.setup(profile, stop, _beam_mat)
	waiting.append(passenger)
	return passenger


## Nearest waiting passenger within `radius` (horizontal distance), or null.
func get_passenger_near(pos: Vector3, radius: float) -> WaitingPassenger:
	var best: WaitingPassenger = null
	var best_d := radius
	for p in waiting:
		var d := _flat_distance(p.global_position, pos)
		if d <= best_d:
			best_d = d
			best = p
	return best


func get_nearest(pos: Vector3) -> WaitingPassenger:
	return get_passenger_near(pos, INF)


## Removes a passenger from the waiting list (they are boarding).
func take(passenger: WaitingPassenger) -> void:
	waiting.erase(passenger)


## Debug (F8): puts the next archetype (cycling through all of them, ignoring min_shift)
## at the free stop nearest to the taxi, so every passenger can be tested on demand.
func debug_spawn_next() -> WaitingPassenger:
	_debug_index = (_debug_index + 1) % profiles.size()
	var profile := profiles[_debug_index]
	var best: TaxiStop = null
	var best_d := INF
	for stop in _city.stops:
		var d := _flat_distance(stop.global_position, _taxi.global_position)
		if not stop.occupied and d > 10.0 and d < best_d:
			best_d = d
			best = stop
	if best == null:
		return null
	EventBus.hud_message.emit("DEBUG: %s waiting at %s (%d m)" % [profile.display_name, best.stop_name, roundi(best_d)], &"info")
	return spawn_at(profile, best)


## A calm profile for the tutorial (the first of `tutorial_profiles` that exists), or null.
func tutorial_profile() -> PassengerProfile:
	for id in tutorial_profiles:
		for p in profiles:
			if p.id == id:
				return p
	return null


## Weighted random among the profiles allowed in the current shift.
func _pick_profile() -> PassengerProfile:
	if GameState.tutorial_active:
		var calm := tutorial_profile()
		if calm != null:
			return calm
	var shift := maxi(GameState.shift_number, 1)
	var total := 0.0
	for p in profiles:
		if p.min_shift <= shift:
			total += p.spawn_weight
	var roll := _rng.randf() * total
	var last: PassengerProfile = profiles[0]
	for p in profiles:
		if p.min_shift > shift:
			continue
		last = p
		roll -= p.spawn_weight
		if roll <= 0.0:
			return p
	return last


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
