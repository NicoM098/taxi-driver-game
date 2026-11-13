class_name EnemyDirector
extends Node3D
## Spawns / despawns enemy cars around the player (Phase 06). Phase 07 ride events call
## spawn_pursuers(). Pays bounties and raises heat on kills; heat decays over time; at
## heat >= police_heat a police cruiser joins periodically. Debug: F7 spawns two hitmen.

@export var max_enemies: int = 5
@export var spawn_min_distance: float = 70.0
@export var spawn_max_distance: float = 140.0
@export var despawn_distance: float = 330.0
@export var police_heat: int = 3
@export var police_interval: float = 20.0
@export var heat_decay_interval: float = 45.0

var enemies: Array[EnemyCar] = []

var _hitman: EnemyCarData
var _police: EnemyCarData
var _taxi: Taxi
var _city: City
var _police_timer: float = 0.0
var _heat_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _used_spawns: PackedVector3Array = PackedVector3Array()  # within one spawn_pursuers call


func _ready() -> void:
	add_to_group(&"enemy_director")
	_rng.randomize()
	_hitman = load("res://data/enemies/hitman_sedan.tres")
	_police = load("res://data/enemies/police_cruiser.tres")
	EventBus.enemy_destroyed.connect(_on_enemy_destroyed)
	EventBus.shift_started.connect(func(_n: int) -> void:
		clear_all()
		GameState.set_heat(0))


func _physics_process(delta: float) -> void:
	if _taxi == null:
		_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
		_city = get_tree().get_first_node_in_group(&"city") as City
		return
	if Input.is_action_just_pressed(&"debug_spawn_pursuers"):
		spawn_pursuers(2)
	_cleanup()
	if _gameplay_active():
		_police_timer -= delta
		if GameState.heat >= police_heat and _police_timer <= 0.0:
			_police_timer = police_interval
			spawn_pursuers(1, _police)
		_heat_timer += delta
		if GameState.heat > 0 and _heat_timer >= heat_decay_interval:
			_heat_timer = 0.0
			GameState.set_heat(GameState.heat - 1)


## Spawns `count` enemies behind / around the player, out of sight. Returns the new cars.
## TODO (Phase 07, user request 2026-11-11): during real gameplay (ride events) spawns must be
## STRATEGIC — ahead on the player's route to the destination to block / intercept, not only
## behind. See [[Passengers & Encounters]] §5 "SpawnPursuers" in the vault.
func spawn_pursuers(count: int, data: EnemyCarData = null) -> Array[EnemyCar]:
	var spawned: Array[EnemyCar] = []
	if _taxi == null:
		return spawned
	_used_spawns.clear()
	for i in count:
		if enemies.size() >= max_enemies:
			break
		var car := EnemyCar.new()
		car.data = data if data != null else _hitman
		car.target = _taxi
		car.name = "%s_%d" % [car.data.id, Time.get_ticks_msec() % 100000 + i]
		car.transform = _spawn_transform(i)  # set before entering the tree (director sits at origin)
		add_child(car)
		enemies.append(car)
		spawned.append(car)
	if not spawned.is_empty():
		EventBus.hud_message.emit("%s x%d ON YOUR TAIL!" % [spawned[0].data.display_name.to_upper(), spawned.size()], &"bad")
	return spawned


func clear_all() -> void:
	for car in enemies:
		if is_instance_valid(car):
			car.queue_free()
	enemies.clear()


func _spawn_transform(index: int) -> Transform3D:
	var taxi_pos := _taxi.global_position
	var taxi_fwd := -_taxi.global_basis.z
	taxi_fwd.y = 0.0
	taxi_fwd = taxi_fwd.normalized() if taxi_fwd.length() > 0.1 else Vector3.FORWARD
	var pos := Vector3.ZERO
	var found := false
	if _city != null:
		var best_score := -INF
		for p in _city.road_points():
			var d := Vector2(p.x - taxi_pos.x, p.z - taxi_pos.z).length()
			if d < spawn_min_distance or d > spawn_max_distance or _used_spawns.has(p):
				continue
			# Prefer behind the player, add randomness so cars don't stack.
			var score := -(p - taxi_pos).normalized().dot(taxi_fwd) + _rng.randf() * 0.8
			if score > best_score:
				best_score = score
				pos = p
				found = true
	if found:
		_used_spawns.append(pos)
	else:
		pos = taxi_pos - taxi_fwd * spawn_min_distance + taxi_fwd.cross(Vector3.UP) * (index * 6.0 - 3.0)
		pos.x = clampf(pos.x, -280.0, 280.0)
		pos.z = clampf(pos.z, -280.0, 280.0)
	pos += Vector3(index * 4.0, 1.2, 0.0)
	var face := taxi_pos - pos
	face.y = 0.0
	var basis := Basis.looking_at(face.normalized(), Vector3.UP) if face.length() > 0.5 else Basis.IDENTITY
	return Transform3D(basis, pos)


func _cleanup() -> void:
	for car in enemies.duplicate():
		if not is_instance_valid(car):
			enemies.erase(car)
			continue
		var far: bool = car.global_position.distance_to(_taxi.global_position) > despawn_distance
		if far or car.global_position.y < -20.0:
			enemies.erase(car)
			car.queue_free()


func _on_enemy_destroyed(enemy: Node, bounty: int) -> void:
	var car := enemy as EnemyCar
	if car == null:
		return
	_heat_timer = 0.0
	GameState.set_heat(GameState.heat + car.data.heat_on_kill)
	if bounty > 0:
		GameState.add_cash(bounty)
		var shift := get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
		if shift != null:
			shift.register_bonus_cash(bounty)
	EventBus.hud_message.emit("%s DOWN%s" % [car.data.display_name.to_upper(), "  +$%d" % bounty if bounty > 0 else ""], &"good")
	enemies.erase(car)  # the car frees itself (explodes instantly)


func _gameplay_active() -> bool:
	var shift := get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
	return shift == null or shift.is_active
