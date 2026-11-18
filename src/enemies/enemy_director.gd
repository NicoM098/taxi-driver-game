class_name EnemyDirector
extends Node3D
## Spawns / despawns enemy cars around the player (Phase 06). Phase 07 ride events call
## spawn_on_route() (ambush ahead / pincer / tail). Pays bounties and raises heat on kills; heat decays over time; at
## heat >= police_heat a police cruiser joins periodically. Debug: F7 spawns two hitmen.
## Pursuers do NOT give up when the fare is delivered (user feedback 2026-11-12): ambushers
## start hunting when the ride ends, and a car that was outrun is put back on the player's
## tail (out of sight) `pursuit_relocations` times before it is really lost.

@export var max_enemies: int = 5
@export var spawn_min_distance: float = 70.0
@export var spawn_max_distance: float = 140.0
@export var despawn_distance: float = 330.0
## Heat is more aggressive since 2026-11-15 (user: "a little more aggressive", then "really
## hard, make it in between"): police from heat 2, a bit more often, heat cools a bit slower.
@export var police_heat: int = 2
@export var police_interval: float = 19.0
@export var heat_decay_interval: float = 55.0
@export_group("Crimes against civilians")
## Heat for running a pedestrian over / blowing up a civilian car.
@export var pedestrian_heat: int = 1
@export var civilian_car_heat: int = 1
## Seconds until the police react once the heat is high enough (instead of police_interval).
@export var crime_response_time: float = 8.0
## Every kill bounty (EnemyCarData.bounty) is paid x this (D-096: more money for guns and upgrades).
const BOUNTY_SCALE := 2.0

@export_group("Price on your head")
## From this heat on, somebody has put a reward on the driver: street gangs come hunting too
## (user request 2026-11-15), on top of the police.
@export var bounty_heat: int = 4
## Seconds between two waves of bounty hunters (shrinks a bit with every heat star above).
@export var bounty_interval: float = 50.0
## Gang cars per wave at bounty_heat; one more per heat star above it.
@export var bounty_wave: int = 2
@export_group("Relentless pursuit")
## How often an outrun car comes back (0 = it is gone once you lose it).
@export var pursuit_relocations: int = 2
## A hunting car this far away counts as outrun.
@export var lose_distance: float = 210.0
@export_group("Strategic spawns")
@export var ambush_min_distance: float = 70.0    # driving distance ahead on the route
@export var ambush_max_distance: float = 240.0

var enemies: Array[EnemyCar] = []

var _hitman: EnemyCarData
var _police: EnemyCarData
var _taxi: Taxi
var _city: City
var _police_timer: float = 0.0
var _bounty_timer: float = 8.0
var _gang: EnemyCarData
var _heat_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _used_spawns: PackedVector3Array = PackedVector3Array()  # within one spawn call
var _spawn_serial: int = 0


## Escalation (D-091): the stage decides who answers the heat — `police` replaces the police
## cruiser, `gang` the bounty hunters' coupe — and how many cars may hunt at once.
func set_roster(police: EnemyCarData, gang: EnemyCarData, cap: int) -> void:
	if police != null:
		_police = police
	if gang != null:
		_gang = gang
	max_enemies = cap


## Last resort for a car the AI could not get out of a corner (D-092): if the player cannot
## see it, it is put back on the street behind the player. True if it was moved.
## Never while it is on screen, at any distance (D-104, user: the boss "is teleporting all the
## time"; before, anything 60 m+ away was moved even in plain view).
func rescue_stuck(car: EnemyCar) -> bool:
	if _taxi == null or not is_instance_valid(car):
		return false
	if on_screen(car.global_position) or (car.global_position.distance_to(_taxi.global_position) < 60.0
			and _is_visible_from_taxi(car.global_position)):
		return false
	if Engine.get_physics_frames() - car.relocated_frame < RELOCATE_COOLDOWN:
		return false
	_relocate(car, "stuck")
	return true


## Frames between two moves of the same car.
const RELOCATE_COOLDOWN := 300


## Puts `car` back on the street behind the player (out of sight and off screen when there is
## such a street), and says so in the log.
func _relocate(car: EnemyCar, why: String) -> void:
	var from := car.global_position
	car.relocated_frame = Engine.get_physics_frames()
	_used_spawns.clear()
	var to := _spawn_transform(0)
	car.teleport(to)
	print("[Director] moved %s (%s): %.0f m from the taxi -> %.0f m, %s" % [car.data.display_name if car.data != null else "car",
			why, from.distance_to(_taxi.global_position), to.origin.distance_to(_taxi.global_position),
			"ON SCREEN" if on_screen(to.origin) else "off screen"])


## Whether a car at `p` would be on the player's screen (the cab camera's frustum, a car's
## width either side, up to the far plane). Walls in between are not checked: on the safe side.
func on_screen(p: Vector3) -> bool:
	var cam := _taxi.get_node_or_null("HeadPivot/Camera3D") as Camera3D if _taxi != null else null
	if cam == null:
		return false
	var up := Vector3(0, 1.2, 0)
	var side := cam.global_basis.x * 2.5
	return cam.is_position_in_frustum(p + up) or cam.is_position_in_frustum(p + up + side) \
			or cam.is_position_in_frustum(p + up - side)


## A boss (D-091): spawned behind, out of sight, past the car cap, and never given up on.
func spawn_boss(data: EnemyCarData) -> EnemyCar:
	if _taxi == null:
		return null
	_used_spawns.clear()
	var car := _spawn_car(data, _spawn_transform(0), 0)
	car.relocations_left = 999
	return car


func _ready() -> void:
	add_to_group(&"enemy_director")
	_rng.randomize()
	_hitman = load("res://data/enemies/hitman_sedan.tres")
	_police = load("res://data/enemies/police_cruiser.tres")
	_gang = load("res://data/enemies/gang_coupe.tres")
	EventBus.heat_changed.connect(_on_heat_changed)
	# Crimes against civilians (user request 2026-11-15): the police hear about it.
	EventBus.pedestrian_hit.connect(func(_pos: Vector3) -> void:
		_civilian_crime(pedestrian_heat, "PEDESTRIAN DOWN - WITNESSES CALLED THE COPS"))
	EventBus.civilian_killed.connect(func(_pos: Vector3, _kind: StringName) -> void:
		_civilian_crime(civilian_car_heat, "CIVILIAN CAR DESTROYED - THE COPS ARE COMING"))
	EventBus.enemy_destroyed.connect(_on_enemy_destroyed)
	EventBus.shift_started.connect(func(_n: int) -> void:
		clear_all()
		GameState.set_heat(0))
	# Job done: whoever was after the taxi drives off once it is a wreck (and the heat is off).
	EventBus.taxi_wrecked.connect(func(_reason: StringName) -> void:
		clear_all()
		GameState.set_heat(0))
	# The ride is over, the contract is not: whoever was waiting ahead comes hunting.
	EventBus.ride_completed.connect(func(_r: RefCounted, _p: int) -> void: release_ambushes())
	EventBus.ride_failed.connect(func(_r: RefCounted, _reason: StringName) -> void: release_ambushes())


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
			# Heat 5: they come in pairs.
			if GameState.heat >= police_heat + 3:
				spawn_pursuers(1, _police)
		_bounty_timer -= delta
		if GameState.heat >= bounty_heat and _bounty_timer <= 0.0:
			var over := GameState.heat - bounty_heat
			_bounty_timer = maxf(bounty_interval - over * 8.0, 30.0)
			_spawn_bounty_hunters(bounty_wave + over)
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
	car.relocations_left = pursuit_relocations
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
	var route := _city.get_route(taxi_pos, destination, true)
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
	# 1) hidden points on the route (nearest first): park across the road.
	for spot in hidden:
		if out.size() >= count:
			return out
		if _near_used(spot["pos"]):
			continue
		out.append(_across_road(spot["pos"], spot["dir"]))
		_used_spawns.append(spot["pos"])
	# 2) side streets next to visible route points: wait there, nose towards the route.
	for spot in in_view:
		var spot_pos: Vector3 = spot["pos"]
		var spot_dir: Vector3 = spot["dir"]
		var lateral := spot_dir.cross(Vector3.UP).normalized()
		for offset: float in [24.0, -24.0, 40.0, -40.0]:
			if out.size() >= count:
				return out
			var side := spot_pos + lateral * offset
			if not _city.can_reach(side, taxi_pos) or not _city.is_free(spot_pos + lateral * offset * 0.5) \
					or _near_used(side) or _is_visible_from_taxi(side):
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


## A street point the taxi can drive to, roughly `distance` metres ahead of its nose: the
## stand-in destination for ambushes while no fare is aboard (StreetEncounters).
func point_ahead(distance: float = 240.0) -> Vector3:
	var taxi_pos := _taxi.global_position
	var fwd := -_taxi.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	var best := taxi_pos + fwd * distance
	if _city == null:
		return best
	var best_score := -INF
	for p in _city.road_points_reachable(taxi_pos):
		var to := p - taxi_pos
		to.y = 0.0
		var d := to.length()
		if d < distance * 0.5:
			continue
		var score := to.normalized().dot(fwd) * 2.0 - absf(d - distance) / distance
		if score > best_score:
			best_score = score
			best = p
	return best


## True if another car of this spawn call already took a spot close to `pos`.
func _near_used(pos: Vector3) -> bool:
	for used in _used_spawns:
		if used.distance_to(pos) < 20.0:
			return true
	return false


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


## Every car still waiting in ambush starts chasing. Returns how many enemies are alive.
func release_ambushes() -> int:
	var alive := 0
	for car in enemies:
		if is_instance_valid(car) and not car.is_destroyed:
			alive += 1
			car.ai.release_ambush()
	return alive


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
	var fallback := Vector3.ZERO
	var has_fallback := false
	if _city != null:
		var best_score := -INF
		var nearest_far := INF
		# Only streets the car can actually drive out of: never a courtyard walled in by
		# buildings (playtest 2026-11-13: "enemies can appear inside the buildings with no way out").
		for p in _city.road_points_reachable(taxi_pos):
			var d := Vector2(p.x - taxi_pos.x, p.z - taxi_pos.z).length()
			if d < spawn_min_distance or d > spawn_max_distance or _used_spawns.has(p):
				# Small maps / dead ends: the closest street beyond the ring is the fallback.
				if d > spawn_max_distance and d < nearest_far and not _used_spawns.has(p):
					nearest_far = d
					fallback = p
					has_fallback = true
				continue
			# Prefer behind the player and out of sight, add randomness so cars don't stack.
			var score := -(p - taxi_pos).normalized().dot(taxi_fwd) + _rng.randf() * 0.8
			if _is_visible_from_taxi(p):
				score -= 2.0
			if on_screen(p):
				score -= 4.0   # D-104: never pop up where the player is looking, at any range
			if score > best_score:
				best_score = score
				pos = p
				found = true
	if not found and has_fallback:
		pos = fallback
		found = true
	if found:
		_used_spawns.append(pos)
	else:
		pos = taxi_pos - taxi_fwd * spawn_min_distance + taxi_fwd.cross(Vector3.UP) * (index * 6.0 - 3.0)
		var limit := _city.map.half() - Vector2(6.0, 6.0) if _city != null else Vector2(280.0, 280.0)
		pos.x = clampf(pos.x, -limit.x, limit.x)
		pos.z = clampf(pos.z, -limit.y, limit.y)
		if _city != null and not _city.can_reach(pos, taxi_pos):
			# Last resort (tiny map): right behind the taxi beats inside a building.
			pos = taxi_pos - taxi_fwd * 14.0
	pos += Vector3(index * 4.0, 1.2, 0.0)
	var face := taxi_pos - pos
	face.y = 0.0
	var basis := Basis.looking_at(face.normalized(), Vector3.UP) if face.length() > 0.5 else Basis.IDENTITY
	return Transform3D(basis, pos)


func _cleanup() -> void:
	# A freed car cannot be erase()d from a typed array (it errors and stays): rebuild instead.
	enemies.assign(enemies.filter(func(c: Variant) -> bool: return is_instance_valid(c)))
	for car in enemies.duplicate():
		var dist: float = car.global_position.distance_to(_taxi.global_position)
		var fell: bool = car.global_position.y < -20.0
		# Waiting ambushers and badly damaged cars running away are left alone.
		var hunting: bool = car.ai != null and car.ai.mode != EnemyDriverAI.Mode.AMBUSH \
				and car.ai.mode != EnemyDriverAI.Mode.RETREAT
		if Engine.get_physics_frames() - car.relocated_frame < 120:
			continue   # its teleport is still being applied
		if (fell or (hunting and dist > lose_distance)) and car.relocations_left > 0 and not car.is_destroyed:
			# Outrun: it knows the city too. Back on the tail, out of sight. While the player
			# can still see it (a long street), it waits and keeps driving (D-104).
			if fell or (not on_screen(car.global_position)
					and Engine.get_physics_frames() - car.relocated_frame >= RELOCATE_COOLDOWN):
				car.relocations_left -= 1
				_relocate(car, "fell" if fell else "outrun")
		elif dist > despawn_distance or fell:
			enemies.erase(car)
			car.queue_free()


func _on_enemy_destroyed(enemy: Node, bounty: int) -> void:
	var car := enemy as EnemyCar
	if car == null:
		return
	_heat_timer = 0.0
	GameState.set_heat(GameState.heat + car.data.heat_on_kill)
	bounty = roundi(bounty * BOUNTY_SCALE)
	if bounty > 0:
		GameState.add_cash(bounty)
		var shift := get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
		if shift != null:
			shift.register_bonus_cash(bounty)
	var parts := car.data.parts
	if parts > 0:   # spare parts for the cab (D-106)
		GameState.add_parts(parts)
	EventBus.hud_message.emit("%s DOWN%s%s" % [car.data.display_name.to_upper(), "  +$%d" % bounty if bounty > 0 else "",
			"  +%d PART%s" % [parts, "" if parts == 1 else "S"] if parts > 0 else ""], &"good")
	enemies.erase(car)  # the car frees itself (explodes instantly)


## Somebody put a price on the driver's head: a gang crew comes to collect, out of sight
## (half of them waiting ahead when there is a fare aboard).
func _spawn_bounty_hunters(count: int) -> Array[EnemyCar]:
	var room := max_enemies - enemies.size()
	if room <= 0 or _taxi == null:
		return []
	count = mini(count, room)
	var rides := get_tree().get_first_node_in_group(&"ride_manager") as RideManager
	var cars: Array[EnemyCar] = []
	if rides != null and rides.state == RideManager.State.RIDING and rides.ride != null:
		cars = spawn_on_route(rides.ride.destination.global_position, &"pincer", count, _gang)
	else:
		cars = spawn_on_route(point_ahead(), &"pincer", count, _gang)
	if not cars.is_empty():
		EventBus.hud_message.emit("THERE'S A PRICE ON YOUR HEAD! GANGS ARE HUNTING YOU", &"bad")
	return cars


func _civilian_crime(heat: int, message: String) -> void:
	if not _gameplay_active() or GameState.tutorial_active:
		return
	_heat_timer = 0.0
	GameState.set_heat(GameState.heat + heat)
	_police_timer = minf(_police_timer, crime_response_time)
	EventBus.hud_message.emit(message, &"bad")


func _on_heat_changed(heat: int) -> void:
	# Crossing into bounty territory: the first crew is quick to show up.
	if heat >= bounty_heat and _bounty_timer > 8.0:
		_bounty_timer = 8.0
	elif heat < bounty_heat:
		_bounty_timer = 8.0


func _gameplay_active() -> bool:
	var shift := get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
	return shift == null or shift.is_active
