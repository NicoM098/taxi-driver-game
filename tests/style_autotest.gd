extends Node
## Style meter (D-081). Headless:
##   <godot exe> --headless --path <project> --fixed-fps 60 res://tests/style_autotest.tscn
## No existing test ever brings another car near the player — the closest one gets in
## `streetlife_autotest` is 58 m — so the near-miss rule had no coverage at all. This drives the
## taxi past a parked civilian car three times:
##   A fast and close  -> exactly one NEAR MISS (one per car per cooldown, not one per frame)
##   B slow and close  -> nothing (crawling past a parked car is not a stunt)
##   C fast and wide   -> nothing

const TAXI := preload("res://src/vehicle/taxi.tscn")

var _errors: PackedStringArray = []
var _events: Array[Dictionary] = []
var _throttle: float = 0.0
var _steer: float = 0.0
var _closest: float = 999.0
var _car: Node3D = null
var _taxi: Node3D = null


func _ready() -> void:
	MapData.use_builtin()
	EventBus.style_earned.connect(func(kind: StringName, label: String, points: float) -> void:
		_events.append({"kind": kind, "label": label, "points": points}))
	_run()


## Input provider for the taxi.
func _physics_process(_delta: float) -> void:
	if _car != null and _taxi != null and is_instance_valid(_car) and is_instance_valid(_taxi):
		_closest = minf(_closest, _car.global_position.distance_to(_taxi.global_position))


## Input provider for the taxi.
func poll(input: VehicleInput) -> void:
	input.clear()
	input.throttle = _throttle
	input.steer = _steer


func _run() -> void:
	await _case(&"A fast and close", 3.2, 1.0, 40.0, 1)
	# Closer, or six seconds of crawling never reaches the car and the case proves nothing.
	await _case(&"B slow and close", 3.2, 0.12, 9.0, 0)
	await _case(&"C fast and wide", 11.0, 1.0, 40.0, 0)
	if _errors.is_empty():
		print("[StyleTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[StyleTest] FAIL: ", e)
		get_tree().quit(1)


## Drives the taxi down a straight line past one parked civilian car `offset` metres to the side.
func _case(name: StringName, offset: float, throttle: float, ahead: float, expected: int) -> void:
	var map := MapData.make_empty("style", 60, 60)
	map.pieces.append(MapData.make_piece("spawn", 30, 40))
	var world := Node3D.new()
	add_child(world)
	var city := City.new()
	city.map = map
	world.add_child(city)

	var start := map.cell_center(30, 45)
	var car := TrafficCar.new()
	car.position = start + Vector3(offset, 0.8, -ahead)
	world.add_child(car)
	car.freeze = true                      # parked: the taxi supplies all the closing speed

	var taxi := TAXI.instantiate() as Taxi
	taxi.input_provider = self
	_throttle = 0.0
	_steer = 0.0
	world.add_child(taxi)
	await _wait(0.4)
	taxi.teleport(Transform3D(Basis.IDENTITY, start + Vector3(0, 0.9, 0)))
	await _wait(0.6)

	_events.clear()
	_closest = 999.0
	_car = car
	_taxi = taxi
	_throttle = throttle
	await _wait(6.0)
	var speed := absf(taxi.forward_speed)
	_throttle = 0.0

	var misses := _events.filter(func(e: Dictionary) -> bool: return e["kind"] == &"near_miss")
	print("[StyleTest] %s: %.1f m/s, closest %.1f m, %d near miss(es), expected %d" % [
			name, speed, _closest, misses.size(), expected])
	if misses.size() != expected:
		_errors.append("%s: %d near misses, expected %d (speed %.1f m/s)" % [
				name, misses.size(), expected, speed])
	_car = null
	_taxi = null
	world.queue_free()
	await _wait(0.3)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
