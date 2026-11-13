class_name PassengerSpawner
extends Node3D
## Keeps `max_waiting` passengers waiting at random free TaxiStops around the taxi.
## Profiles are loaded from every resource in `profiles_dir` (data-driven: add a .tres, done).

@export var profiles_dir: String = "res://data/passengers/"
@export var max_waiting: int = 8
@export var min_spawn_distance: float = 35.0
@export var max_spawn_distance: float = 230.0
@export var respawn_interval: float = 1.0

var profiles: Array[PassengerProfile] = []
var waiting: Array[WaitingPassenger] = []

var _city: City
var _taxi: Node3D
var _timer: float = 0.0
var _beam_mat: Material
var _rng := RandomNumberGenerator.new()


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
	_timer -= delta
	if _timer <= 0.0 and waiting.size() < max_waiting:
		_timer = respawn_interval
		spawn_one()


func spawn_one() -> WaitingPassenger:
	var profile := _pick_profile()
	var taxi_pos := _taxi.global_position
	var candidates: Array[TaxiStop] = []
	for stop in _city.stops:
		if stop.occupied:
			continue
		if not profile.districts.is_empty() and not profile.districts.has(stop.district):
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


func _pick_profile() -> PassengerProfile:
	var total := 0.0
	for p in profiles:
		total += p.spawn_weight
	var roll := randf() * total
	for p in profiles:
		roll -= p.spawn_weight
		if roll <= 0.0:
			return p
	return profiles.back()


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
