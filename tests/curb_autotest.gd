extends Node
## Sidewalks must not hurt the taxi (user report 2026-11-13: "i think the sidewalks are
## damaging the car"). Headless:
##   <console exe> --headless --path <project> --fixed-fps 60 res://tests/curb_autotest.tscn
## One big sidewalk slab on an empty map; the taxi drives onto it, across it and off the far
## side at several speeds and angles, also braking / handbraking over the edge and landing a
## jump just before it. Every `Taxi.crashed` emission is logged; any that costs HP, and any
## landing that slams into the curb, is a FAIL.
## `-- --explore` only prints the table (never fails).

const TAXI := preload("res://src/vehicle/taxi.tscn")
const SLAB_X := 5
const SLAB_Z := 20
const SLAB_W := 50
const SLAB_D := 4

var _errors: PackedStringArray = []
var _t: float = 0.0
var _throttle: float = 0.0
var _brake: float = 0.0
var _handbrake: bool = false
var _boost: bool = false
var _steer: float = 0.0
var _crashes: Array[float] = []
var _drop_lift: float = 0.0
var _drop_at: float = 0.0


func _ready() -> void:
	MapData.use_builtin()
	_run()


func _physics_process(delta: float) -> void:
	_t += delta


## Input provider for the taxi.
func poll(input: VehicleInput) -> void:
	input.clear()
	input.throttle = _throttle
	input.brake = _brake
	input.handbrake = _handbrake
	input.boost = _boost
	input.steer = _steer


func _run() -> void:
	var explore := OS.get_cmdline_user_args().has("--explore")
	var heights: Array[float] = [float(MapData.TYPES["sidewalk"]["h"]), float(MapData.TYPES["sidewalk"]["max_h"])]
	for h in heights:
		for angle: float in [0.0, 30.0, 60.0, 80.0]:
			for run_up: float in [12.0, 40.0, 140.0]:
				await _case(h, angle, run_up, &"drive")
		await _case(h, 0.0, 140.0, &"boost")
		await _case(h, 0.0, 140.0, &"brake")
		await _case(h, 45.0, 140.0, &"brake")
		await _case(h, 30.0, 140.0, &"handbrake")
		await _case(h, 70.0, 140.0, &"handbrake")
	# Landing a jump just before the edge: the suspension is compressed when the curb arrives
	# (this is what stopped the taxi dead and hurt it before D-060).
	for lift: float in [0.6, 1.2, 2.0]:
		for d: float in [6.0, 9.0, 12.0, 15.0, 18.0, 21.0, 24.0, 27.0]:
			_drop_lift = lift
			_drop_at = d
			await _case(heights[0], 0.0, 140.0, &"drop")
			await _case(heights[0], 35.0, 140.0, &"drop")
	if _errors.is_empty() or explore:
		print("[CurbTest] PASS" if _errors.is_empty() else "[CurbTest] explore: %d damaging case(s)" % _errors.size())
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[CurbTest] FAIL: ", e)
		get_tree().quit(1)


## Drives at the slab's south edge, `angle` degrees off straight-on, from `run_up` metres away.
func _case(slab_h: float, angle: float, run_up: float, mode: StringName) -> void:
	var map := MapData.make_empty("curb", 60, 60)
	var slab := MapData.make_piece("sidewalk", SLAB_X, SLAB_Z, SLAB_W, SLAB_D)
	slab["h"] = slab_h
	map.pieces.append(slab)
	map.pieces.append(MapData.make_piece("spawn", 30, 40))
	var world := Node3D.new()
	add_child(world)
	var city := City.new()
	city.map = map
	world.add_child(city)

	var edge_z := map.cell_center(SLAB_X, SLAB_Z + SLAB_D - 1).z + MapData.CELL * 0.5
	var far_z := map.cell_center(SLAB_X, SLAB_Z).z - MapData.CELL * 0.5
	var hit := Vector3(map.cell_center(30, 0).x, 0.0, edge_z)
	var facing := Basis(Vector3.UP, deg_to_rad(angle))
	var dir := facing * Vector3.FORWARD
	var taxi := TAXI.instantiate() as Taxi
	taxi.input_provider = self
	_throttle = 0.0
	_brake = 0.0
	_handbrake = false
	_boost = false
	_steer = 0.0
	taxi.transform = Transform3D(facing, hit - dir * run_up + Vector3(0, 1.0, 0))
	world.add_child(taxi)
	await _wait(0.3)
	# The city moves the taxi to the map's player start: put it on this case's line.
	taxi.teleport(Transform3D(facing, hit - dir * run_up + Vector3(0, 0.9, 0)))
	await _wait(1.0)
	var damage := taxi.get_node_or_null("TaxiDamage") as TaxiDamage
	if damage == null:
		for child in taxi.find_children("*", "TaxiDamage", true, false):
			damage = child as TaxiDamage
	var hp_before := damage.taxi_health.hp if damage != null else 0.0
	_crashes.clear()
	taxi.crashed.connect(_on_crashed)

	_throttle = 1.0
	_boost = mode == &"boost"
	var entry_kmh := 0.0
	var entered := false
	var left := false
	var dropped := false
	var min_up := 1.0
	var until := _t + 16.0
	while _t < until:
		await get_tree().physics_frame
		var pos := taxi.global_position
		min_up = minf(min_up, taxi.global_basis.y.y)
		if mode == &"drop" and not dropped and pos.z <= edge_z + _drop_at:
			dropped = true
			taxi.global_position.y += _drop_lift
		if not entered and pos.z <= edge_z + 3.0:
			entered = true
			entry_kmh = taxi.linear_velocity.length() * 3.6
			if mode == &"brake":
				_throttle = 0.0
				_brake = 1.0
			elif mode == &"handbrake":
				_handbrake = true
				_steer = 1.0
		if entered and mode == &"brake" and taxi.linear_velocity.length() < 3.0:
			_brake = 0.0
			_throttle = 1.0   # do not reverse back off: carry on across
		if entered and mode == &"handbrake" and pos.z < edge_z - 6.0:
			_handbrake = false
			_steer = 0.0
		if pos.z < far_z - 8.0:
			left = true
			break
	var worst := 0.0
	for c in _crashes:
		worst = maxf(worst, c)
	var lost := hp_before - damage.taxi_health.hp if damage != null else 0.0
	print("[CurbTest] slab %.2f m, %2.0f deg, run-up %3.0f m, %-9s: entry %3.0f km/h, %d bump(s) over the crash threshold, worst dv %.1f m/s, HP lost %.1f, min up %.2f%s" % [
		slab_h, angle, run_up, mode, entry_kmh, _crashes.size(), worst, lost, min_up,
		("" if left else "  (did not get across)") + ("  [lift %.1f m, %.0f m before the edge]" % [_drop_lift, _drop_at] if mode == &"drop" else "")])
	if lost > 0.0:
		_errors.append("slab %.2f m, %.0f deg, run-up %.0f m, %s: lost %.1f HP (worst dv %.1f m/s)" % [slab_h, angle, run_up, mode, lost, worst])
	# The landing grace hides the HP loss in the drop cases: judge the hit itself.
	if mode == &"drop" and (worst > 8.0 or not left):
		_errors.append("landing %.1f m high, %.0f m before a %.2f m curb, %.0f deg: hit it (worst dv %.1f m/s%s)" % [
			_drop_lift, _drop_at, slab_h, angle, worst, "" if left else ", stopped"])
	if min_up < 0.5:
		_errors.append("slab %.2f m, %.0f deg, run-up %.0f m, %s: the taxi rolled over" % [slab_h, angle, run_up, mode])
	world.queue_free()
	await _wait(0.2)


func _on_crashed(impact: float) -> void:
	_crashes.append(impact)


func _wait(seconds: float) -> void:
	var until := _t + seconds
	while _t < until:
		await get_tree().physics_frame
