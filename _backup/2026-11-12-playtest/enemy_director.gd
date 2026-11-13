class_name EnemyDirector
extends Node3D
## Spawns / despawns enemy cars around the player (Phase 06). Phase 07 ride events call
## spawn_on_route() (ambush ahead / pincer / tail). Pays bounties and raises heat on kills; heat decays over time; at
## heat >= police_heat a police cruiser joins periodically. Debug: F7 spawns two hitmen.

@export var max_enemies: int = 5
@export var spawn_min_distance: float = 70.0
@export var spawn_max_distance: float = 140.0
@export var despawn_distance: float = 330.0
@export var police_heat: int = 3
@export var police_interval: float = 20.0
@export var heat_decay_interval: float = 45.0
@export_group("Strategic spawns")
@export var ambush_min_distance: float = 70.0    # driving distance ahead on the route
@export var ambush_max_distance: float = 240.0

var enemies: Array[EnemyCar] = []

var _hitman: EnemyCarData
var _police: EnemyCarData
var _taxi: Taxi
var _city: City
var _police_timer: float = 0.0
var _heat_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _used_spawns: PackedVector3Array = PackedVector3Array()  # within one spawn call
var _spawn_serial: int = 0


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


## Spawns `count` enemies behind / around the player, out of sight ("tail"). Returns the new cars.
func spawn_pursuers(count: int, data: EnemyCarData = null) -> Array[EnemyCar]:
	var spawned: Array[EnemyCar] = []
	if _taxi == null:
		return spawned
	_used_spawns.clear()
	spawned = _spawn_behind(count, data)
	if not spawned.is_empty():
		EventBus.hud_message.emit("%s x%d ON YOUR TAIL!" % [spawned[0].data.display_name.to_upper(), spawned.size()], &"bad")
	return spawned


## Strategic spawn for ride events (user request 2026-11-11): enemies are placed relative to
## the player's ROUTE to `destination`, never in direct view.
##   &"tail"          all behind (same as spawn_pursuers)
##   &"ambush_ahead"  all waiting on the route ahead: parked across an intersection the player
##                    will drive through (or in a side street next to it)
##   &"pincer"        half ahead (at least one), the rest behind
func spawn_on_route(destination: Vector3, pattern: StringName = &"tail", count: int = 2,
		data: EnemyCarData = null) -> Array[EnemyCar]:
	if _taxi == null or _city == null or pattern == &"tail":
		return spawn_pursuers(count, data)
	var spawned: Array[EnemyCar] = []
	_used_spawns.clear()
	@warning_ignore("integer_division")
	var ahead := count if pattern == &"ambush_ahead" else maxi(count / 2, 1)
	for xform in _ambush_transforms(destination, ahead):
		if enemies.size() >= max_enemies:
			break
		var car := _spawn_car(data, xform, spawned.size())
		car.ai.hold_ambush()
		spawned.append(car)
	var ahead_count := spawned.size()
	spawned.append_array(_spawn_behind(count - ahead_count, data))
	if not spawned.is_empty():
		var who := spawned[0].data.display_name.to_upper()
		if ahead_count == 0:
			EventBus.hud_message.emit("%s x%d ON YOUR TAIL!" % [who, spawned.size()], &"bad")
		elif ahead_count == spawned.size():
			EventBus.hud_message.emit("%s x%d WAITING AHEAD!" % [who, spawned.size()], &"bad")
		else:
			EventBus.hud_message.emit("%s x%d — AHEAD AND BEHIND!" % [who, spawned.size()], &"bad")
	return spawned


func _spawn_behind(count: int, data: EnemyCarData) -> Array[EnemyCar]:
	var spawned: Array[EnemyCar] = []
	for i in count:
		if enemies.size() >= max_enemies:
			break
		spawned.append(_spawn_car(data, _spawn_transform(i), i))
	return spawned


func _spawn_car(data: EnemyCarData, xform: Transform3D, index: int) -> EnemyCar:
	var car := EnemyCar.new()
	car.data = data if data != null else _hitman
	car.target = _taxi
	_spawn_serial += 1
	car.name = "%s_%d_%d" % [car.data.id, _spawn_serial, index]
	car.transform = xform  # set before entering the tree (director sits at origin)
	add_child(car)
	enemies.append(car)
	return car


## Up to `count` ambush positions on the street route from the taxi to `destination`,
## between ambush_min_distance and ambush_max_distance of driving distance, preferring spots
## the player cannot see right now. If a spot on the route is in view (long straight street)
## the car waits in a side street next to it instead.
func _ambush_transforms(destination: Vector3, count: int) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var taxi_pos := _taxi.global_position
	var route := _city.get_route(taxi_pos, destination)
	if route.size() < 2:
		return out
	var hidden: Array[Dictionary] = []    # {pos, dir}; dir = travel direction of the player there
	var in_view: Array[Dictionary] = []
	var travelled := 0.0
	var prev := taxi_pos
	for i in route.size() - 1:   # the last point is the destination itself: never ambush there
		var p := route[i]
		var leg := p - prev
		leg.y = 0.0
		travelled += leg.length()
		var dir := leg.normalized() if leg.length() > 0.5 else Vector3.FORWARD
		prev = p
		if travelled < ambush_min_distance or travelled > ambush_max_distance:
			continue
		if Vector2(p.x - destination.x, p.z - destination.z).length() < 30.0:
			continue
		var spot := {"pos": p, "dir": dir}
		if _is_visible_from_taxi(p):
			in_view.append(spot)
		else:
			hidden.append(spot)
	# 1) hidden intersections on the route (nearest first): park across the road.
	for spot in hidden:
		if out.size() >= count:
			return out
		out.append(_across_road(spot["pos"], spot["dir"]))
		_used_spawns.append(spot["pos"])
	# 2) side streets next to visible route points: wait there, nose towards the route.
	for spot in in_view:
		var spot_pos: Vector3 = spot["pos"]
		var id := _city.road_graph.get_closest_point(spot_pos)
		for n in _city.road_graph.get_point_connections(id):
			if out.size() >= count:
				return out
			var side := _city.road_graph.get_point_position(n)
			if route.has(side) or _used_spawns.has(side) or _is_visible_from_taxi(side):
				continue
			if Vector2(side.x - taxi_pos.x, side.z - taxi_pos.z).length() < ambush_min_distance * 0.7:
				continue
			var face := spot_pos - side
			out.append(Transform3D(Basis.looking_at(face.normalized(), Vector3.UP), side + Vector3(0, 1.2, 0)))
			_used_spawns.append(side)
	# 3) nothing hidden at all: the farthest visible route point is the least bad.
	if out.is_empty() and not in_view.is_empty():
		var last: Dictionary = in_view.back()
		out.append(_across_road(last["pos"], last["dir"]))
		_used_spawns.append(last["pos"])
	return out


## Parked sideways on the road, blocking the way the player arrives.
func _across_road(pos: Vector3, travel_dir: Vector3) -> Transform3D:
	var across := travel_dir.cross(Vector3.UP).normalized()
	if _rng.randf() < 0.5:
		across = -across
	return Transform3D(Basis.looking_at(across, Vector3.UP), pos + Vector3(0, 1.2, 0))


## Line of sight from the driver's seat to a point on the street (buildings block it).
func _is_visible_from_taxi(point: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(
		_taxi.global_position + Vector3(0, 1.3, 0), point + Vector3(0, 1.3, 0), 1)
	return space.intersect_ray(query).is_empty()


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
			# Prefer behind the player and out of sight, add randomness so cars don't stack.
			var score := -(p - taxi_pos).normalized().dot(taxi_fwd) + _rng.randf() * 0.8
			if _is_visible_from_taxi(p):
				score -= 2.0
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
