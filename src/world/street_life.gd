class_name StreetLife
extends Node3D
## Ambient life around the player (D-065): pedestrians walking laps on the curbs of buildings
## and sidewalk slabs, and civilian TrafficCars cruising the streets. Both are spawned out of
## sight within a ring around the taxi and recycled when far away, so the cost stays flat
## whatever the map size. Gunfire and explosions make nearby pedestrians run.
## Never in plain view (D-103, user: "pedestrians disappear and appear"): nothing spawns or is
## recycled while it is inside the camera's view (up to its far plane), at any distance. A
## pedestrian or car far behind you that is still on screen waits until you look away.
## Off in automated tests (MapData.override) unless `run_in_tests`.

@export var max_pedestrians: int = 28
@export var max_traffic: int = 8
@export var ped_spawn_range: Vector2 = Vector2(35.0, 140.0)
@export var ped_despawn: float = 170.0
@export var traffic_spawn_range: Vector2 = Vector2(80.0, 200.0)
@export var traffic_despawn: float = 240.0
## Hard limit: past this (beyond the camera's far plane) things go even if "on screen".
@export var hard_despawn: float = 300.0
@export var panic_radius: float = 50.0
@export var run_in_tests: bool = false

const CLOTHES: Array[Color] = [
	Color(0.55, 0.15, 0.15), Color(0.15, 0.3, 0.6), Color(0.2, 0.5, 0.3), Color(0.8, 0.7, 0.3),
	Color(0.35, 0.35, 0.38), Color(0.6, 0.4, 0.7), Color(0.9, 0.5, 0.2), Color(0.85, 0.85, 0.85),
	Color(0.1, 0.1, 0.12), Color(0.45, 0.3, 0.2),
]

var pedestrians: Array[Pedestrian] = []
var traffic: Array[TrafficCar] = []
var pedestrians_hit: int = 0

var _city: City
var _taxi: Taxi
var _loops: Array[Rect2] = []
var _loop_height: PackedFloat32Array = PackedFloat32Array()
var _near_loops: Array[int] = []
var _road: PackedVector3Array = PackedVector3Array()
var _tick: float = 0.0
var _slow_tick: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"street_life")
	_rng.randomize()
	EventBus.weapon_fired.connect(func(_w: Resource) -> void:
		if _taxi != null:
			panic_around(_taxi.global_position, panic_radius))
	EventBus.explosion.connect(func(pos: Vector3, _s: float) -> void: panic_around(pos, panic_radius * 1.3))
	EventBus.pedestrian_hit.connect(func(_p: Vector3) -> void: pedestrians_hit += 1)


func enabled() -> bool:
	return MapData.override == null or run_in_tests


func _physics_process(delta: float) -> void:
	if _city == null or _taxi == null:
		_city = get_tree().get_first_node_in_group(&"city") as City
		_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
		if _city != null and _city.map != null:
			_collect_loops()
		return
	if not enabled():
		return
	_slow_tick -= delta
	if _slow_tick <= 0.0:
		_slow_tick = 2.0
		_refresh_candidates()
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.2
	_recycle()
	if pedestrians.size() < max_pedestrians:
		_spawn_pedestrian()
	if traffic.size() < max_traffic and _rng.randf() < 0.35:
		_spawn_traffic()


## Pedestrians within `radius` of `pos` run for a few seconds.
func panic_around(pos: Vector3, radius: float) -> void:
	for p in pedestrians:
		if is_instance_valid(p) and p.global_position.distance_to(pos) < radius:
			p.panic()


# --- Pedestrians ----------------------------------------------------------------------

## Walkable curb loops: every building's sidewalk ring and every sidewalk slab, 0.6 m in.
func _collect_loops() -> void:
	var map := _city.map
	for p in map.pieces:
		var type := String(p["type"])
		if type != "building" and type != "sidewalk":
			continue
		var cells := MapData.rect_of(p)
		var corner := map.cell_corner(cells.position.x, cells.position.y)
		var rect := Rect2(Vector2(corner.x, corner.z), Vector2(cells.size) * MapData.CELL).grow(-0.6)
		if rect.size.x < 3.0 or rect.size.y < 3.0:
			continue
		_loops.append(rect)
		_loop_height.append(MapBuilder.CURB if type == "building" else float(p["h"]))


func _refresh_candidates() -> void:
	_near_loops.clear()
	var here := Vector2(_taxi.global_position.x, _taxi.global_position.z)
	for i in _loops.size():
		if _loops[i].get_center().distance_to(here) < ped_spawn_range.y + 20.0:
			_near_loops.append(i)
	_road = _city.road_points_reachable(_taxi.global_position)


func _spawn_pedestrian() -> void:
	if _near_loops.is_empty():
		return
	for attempt in 6:
		var i: int = _near_loops[_rng.randi() % _near_loops.size()]
		var ped := Pedestrian.new()
		ped.setup(_loops[i], _loop_height[i], CLOTHES[_rng.randi() % CLOTHES.size()])
		if _good_spawn(ped.position, ped_spawn_range):
			add_child(ped)
			pedestrians.append(ped)
			return
		ped.free()


# --- Traffic --------------------------------------------------------------------------

func _spawn_traffic() -> void:
	if _road.is_empty():
		return
	for attempt in 8:
		var p := _road[_rng.randi() % _road.size()]
		if not _good_spawn(p, traffic_spawn_range) or not _vehicle_free(p, 18.0):
			continue
		var dirs: Array[Vector3] = []
		for d: Vector3 in MapData.DIRS:
			if _city.is_plain_street(p + d * MapData.CELL):
				dirs.append(d)
		if dirs.is_empty():
			continue
		var dir: Vector3 = dirs[_rng.randi() % dirs.size()]
		var at := TrafficAI.lane_point(_city, p, dir)
		var car := TrafficCar.new()
		car.name = "Traffic%d" % _rng.randi()
		var xform := Transform3D(Basis.looking_at(dir, Vector3.UP), at + Vector3(0, 0.9, 0))
		car.transform = xform     # StreetLife sits at the origin: local = global
		add_child(car)
		car.teleport(xform)
		traffic.append(car)
		return


func _vehicle_free(p: Vector3, radius: float) -> bool:
	for car in traffic:
		if is_instance_valid(car) and car.global_position.distance_to(p) < radius:
			return false
	var director := get_tree().get_first_node_in_group(&"enemy_director") as EnemyDirector
	if director != null:
		for e in director.enemies:
			if is_instance_valid(e) and e.global_position.distance_to(p) < radius:
				return false
	return _taxi.global_position.distance_to(p) > radius


# --- Shared ---------------------------------------------------------------------------

## Within the ring around the taxi and not on screen (D-103).
func _good_spawn(p: Vector3, ring: Vector2) -> bool:
	var to := p - _taxi.global_position
	to.y = 0.0
	var d := to.length()
	if d < ring.x or d > ring.y:
		return false
	return not in_view(p)


## Whether something standing at `p` would be on screen: any of three points across a body
## (1.5 m wide, 1 m up) inside the camera's frustum, with a little margin at the edges.
## Buildings in the way are not checked: on the safe side.
func in_view(p: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var up := Vector3(0, 1.0, 0)
	var side := cam.global_basis.x * 1.5
	return cam.is_position_in_frustum(p + up) or cam.is_position_in_frustum(p + up + side) \
			or cam.is_position_in_frustum(p + up - side)


func _recycle() -> void:
	var here := _taxi.global_position
	for i in range(pedestrians.size() - 1, -1, -1):
		var p := pedestrians[i]
		var gone := not is_instance_valid(p) or p.done
		if not gone:
			var d := p.global_position.distance_to(here)
			gone = d > hard_despawn or (d > ped_despawn and not in_view(p.global_position))
		if gone:
			if is_instance_valid(p):
				p.queue_free()
			pedestrians.remove_at(i)
	for i in range(traffic.size() - 1, -1, -1):
		var c := traffic[i]
		if not is_instance_valid(c):
			traffic.remove_at(i)
			continue
		var d := c.global_position.distance_to(here)
		var far := d > hard_despawn or ((d > traffic_despawn or (c.ai.gave_up and d > 40.0))
				and not in_view(c.global_position))
		if far or c.global_position.y < -20.0:
			c.queue_free()
			traffic.remove_at(i)
