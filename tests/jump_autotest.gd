extends Node
## Kicker ramp -> jump over a row of containers placed right behind it (user request
## 2026-11-13). Headless:
##   <console exe> --headless --path <project> --fixed-fps 60 res://tests/jump_autotest.tscn
## Builds a small map per case: a default kicker ramp at cell (8, 14) rising north, default
## containers in the cell north of it, a straight run-up from the south. Full throttle.
## `-- --explore` prints a table of ramp heights x run-ups instead of asserting.

const TAXI := preload("res://src/vehicle/taxi.tscn")
const RAMP_CELL := Vector2i(8, 14)

var _errors: PackedStringArray = []
var _t: float = 0.0
var _throttle: float = 1.0
var _boost: bool = false


func _ready() -> void:
	MapData.use_builtin()
	_run()


func _physics_process(delta: float) -> void:
	_t += delta


## Input provider for the taxi.
func poll(input: VehicleInput) -> void:
	input.clear()
	input.throttle = _throttle
	input.boost = _boost


func _run() -> void:
	var ramp_default := float(MapData.TYPES["ramp"]["h"])
	var box_default := float(MapData.TYPES["containers"]["h"])
	if OS.get_cmdline_user_args().has("--explore"):
		for h: float in [2.0, 2.6, 3.0, 3.2, 4.0]:
			for run_up: int in [2, 3, 5, 8, 20]:
				await _case(h, 1.0, run_up, false, 1)
		await _case(ramp_default, box_default, 20, true, 1)
		await _case(ramp_default, box_default, 20, true, 2)
		get_tree().quit(0)
		return
	print("[JumpTest] defaults: kicker %.1f m high, containers %d level(s)" % [ramp_default, int(box_default)])
	# From a decent run-up the default ramp clears the default containers...
	for run_up: int in [8, 12, 20]:
		var r := await _case(ramp_default, box_default, run_up, false, 1)
		if not r["cleared"]:
			_errors.append("run-up of %d cells (%.0f km/h): did not get over the containers" % [run_up, r["entry_kmh"]])
		if r["min_up"] < 0.5:
			_errors.append("run-up of %d cells: the taxi rolled over (up %.2f)" % [run_up, r["min_up"]])
	# ...with the boost held too, and over two rows of containers at full speed.
	var boosted := await _case(ramp_default, box_default, 20, true, 1)
	if not boosted["cleared"]:
		_errors.append("boosted jump did not clear the containers")
	var two_rows := await _case(ramp_default, box_default, 20, false, 2)
	if not two_rows["cleared"]:
		_errors.append("full-speed jump did not clear two rows of containers")
	if _errors.is_empty():
		print("[JumpTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[JumpTest] FAIL: ", e)
		get_tree().quit(1)


## One jump. Returns {entry_kmh, lip_y, max_y, cleared, min_up, landed_kmh}.
func _case(ramp_h: float, levels: float, run_up: int, boost: bool, rows: int) -> Dictionary:
	var map := MapData.make_empty("jump", 17, 60)
	var ramp := MapData.make_piece("ramp", RAMP_CELL.x, RAMP_CELL.y, 1, 1)
	ramp["h"] = ramp_h
	map.pieces.append(ramp)
	var boxes := MapData.make_piece("containers", RAMP_CELL.x - 1, RAMP_CELL.y - rows, 3, rows)
	boxes["h"] = levels
	map.pieces.append(boxes)
	# The city puts the taxi on the map's player start: that is the run-up.
	map.pieces.append(MapData.make_piece("spawn", RAMP_CELL.x, RAMP_CELL.y + run_up))
	var world := Node3D.new()
	add_child(world)
	var city := City.new()
	city.map = map
	world.add_child(city)
	var taxi := TAXI.instantiate() as Taxi
	taxi.input_provider = self
	_throttle = 0.0
	_boost = false
	var start := map.cell_center(RAMP_CELL.x, RAMP_CELL.y + run_up)
	taxi.position = start + Vector3(0, 1.2, 0)
	world.add_child(taxi)
	await _wait(1.0)
	var street_y := taxi.global_position.y
	var ramp_south := map.cell_center(RAMP_CELL.x, RAMP_CELL.y).z + MapData.CELL * 0.5
	var boxes_north := map.cell_center(RAMP_CELL.x, RAMP_CELL.y - rows).z - MapData.CELL * 0.5
	var result := {"entry_kmh": 0.0, "max_y": 0.0, "cleared": false, "min_up": 1.0, "landed_kmh": 0.0, "over_y": 0.0}
	_throttle = 1.0
	_boost = boost
	var until := _t + 14.0
	var entered := false
	while _t < until:
		await get_tree().physics_frame
		var pos := taxi.global_position
		result["min_up"] = minf(result["min_up"], taxi.global_basis.y.y)
		result["max_y"] = maxf(result["max_y"], pos.y - street_y)
		if not entered and pos.z <= ramp_south:
			entered = true
			result["entry_kmh"] = taxi.linear_velocity.length() * 3.6
		# Past the far side of the containers, back on the ground and still rolling.
		if pos.z < boxes_north - 3.0 and not result["cleared"]:
			result["over_y"] = pos.y - street_y
			result["cleared"] = true
		if result["cleared"] and taxi.is_grounded() and pos.y - street_y < 0.4:
			result["landed_kmh"] = taxi.linear_velocity.length() * 3.6
			break
	print("[JumpTest] ramp %.1f m, %d level(s) x %d row(s), run-up %2d cells%s: entry %3.0f km/h, peak %.1f m, %s, landed at %3.0f km/h, min up %.2f" % [
		ramp_h, int(levels), rows, run_up, " + boost" if boost else "", result["entry_kmh"], result["max_y"],
		"CLEARED (%.1f m up past them)" % result["over_y"] if result["cleared"] else "did NOT clear",
		result["landed_kmh"], result["min_up"]])
	world.queue_free()
	await _wait(0.2)
	return result


func _wait(seconds: float) -> void:
	var until := _t + seconds
	while _t < until:
		await get_tree().physics_frame
