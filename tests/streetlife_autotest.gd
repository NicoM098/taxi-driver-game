extends Node
## Headless street-life test (D-065) through Main on the built-in city, StreetLife forced on:
##  A. pedestrians and traffic spawn around the taxi (never in view when close)
##  B. over 30 s the traffic actually drives (distance covered), few cars give up, none falls
##     out of the world; cars keep to the right of their direction of travel on 2-lane streets
##  C. gunfire makes nearby pedestrians run
##  D. driving at a pedestrian: they dodge or get knocked down (EventBus.pedestrian_hit)
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/streetlife_autotest.tscn
## (-- --shot-dir=<dir> windowed: a street screenshot)

const MAIN := preload("res://src/main/main.tscn")

var _taxi: Taxi
var _life: StreetLife
var _t: float = 0.0
var _step: int = 0
var _step_t: float = 0.0
var _errors: PackedStringArray = []
var _travel: Dictionary = {}        # car -> metres
var _lane_ok: int = 0
var _lane_bad: int = 0
var _target: Pedestrian
var _reacted: bool = false
var _shot_dir: String = ""


func _ready() -> void:
	MapData.use_builtin()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			_shot_dir = arg.get_slice("=", 1)
	add_child(MAIN.instantiate())


func _physics_process(delta: float) -> void:
	_t += delta
	_step_t += delta
	if _taxi == null:
		_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
		_life = get_tree().get_first_node_in_group(&"street_life") as StreetLife
		if _life != null:
			_life.run_in_tests = true
		return
	if _t > 90.0:
		_fail("timeout at step %d" % _step)
		return
	match _step:
		0:
			if _step_t > 12.0:
				print("[StreetTest] A after 12 s: %d pedestrians, %d traffic cars" % [_life.pedestrians.size(), _life.traffic.size()])
				if _life.pedestrians.size() < 10:
					_errors.append("too few pedestrians (%d)" % _life.pedestrians.size())
				if _life.traffic.size() < 3:
					_errors.append("too few traffic cars (%d)" % _life.traffic.size())
				for c in _life.traffic:
					_travel[c] = 0.0
				_next()
		1:
			for key: Variant in _travel.keys():
				if is_instance_valid(key):
					var car := key as TrafficCar
					_travel[key] = float(_travel[key]) + car.linear_velocity.length() * delta
					_check_lane(car)
			if _step_t > 30.0:
				var moved := 0
				var total := 0.0
				var gave_up := 0
				for key: Variant in _travel.keys():
					total += float(_travel[key])
					if float(_travel[key]) > 40.0:
						moved += 1
					if not is_instance_valid(key):
						continue   # recycled (drove out of range): it was moving
					var car := key as TrafficCar
					if car.ai.gave_up:
						gave_up += 1
					if car.global_position.y < -5.0:
						_errors.append("a traffic car fell out of the world")
				print("[StreetTest] B 30 s: %d / %d cars drove > 40 m (avg %.0f m), %d gave up; lane samples right %d / wrong %d" % [
					moved, _travel.size(), total / maxf(_travel.size(), 1), gave_up, _lane_ok, _lane_bad])
				if moved < ceili(_travel.size() * 0.6):
					_errors.append("traffic is not moving")
				if _lane_ok + _lane_bad > 50 and _lane_bad > (_lane_ok + _lane_bad) * 0.25:
					_errors.append("traffic drives on the wrong side too often")
				_next()
		2:
			_life.panic_radius = 150.0   # the ring around a parked taxi starts at 35 m
			var near := 0
			for p in _life.pedestrians:
				if p.global_position.distance_to(_taxi.global_position) < _life.panic_radius:
					near += 1
			EventBus.weapon_fired.emit(null)
			var fleeing := 0
			for p in _life.pedestrians:
				if p.state == Pedestrian.State.FLEE:
					fleeing += 1
			print("[StreetTest] C gunfire: %d pedestrians within %.0f m, %d fleeing" % [near, _life.panic_radius, fleeing])
			if near > 0 and fleeing < near:
				_errors.append("not every nearby pedestrian ran from gunfire")
			_next()
		3:
			# Put the taxi 14 m behind a walking pedestrian, on their line, and floor it.
			if _step_t < 6.0:   # let the panic wear off
				return
			for p in _life.pedestrians:
				if p.state == Pedestrian.State.WALK:
					_target = p
					break
			if _target == null:
				_fail("no walking pedestrian to test with")
				return
			var fwd := -_target.global_basis.z
			fwd.y = 0.0
			var start := _target.global_position - fwd.normalized() * 14.0
			_taxi.teleport(Transform3D(Basis.looking_at(fwd.normalized(), Vector3.UP), start + Vector3(0, 1.0, 0)))
			Input.action_press(&"accelerate")
			_next()
		4:
			if is_instance_valid(_target) and _target.state != Pedestrian.State.WALK:
				_reacted = true
			if _step_t > 4.0:
				Input.action_release(&"accelerate")
				print("[StreetTest] D pedestrian reaction: %s (state %s), hits counted %d" % [
					_reacted, Pedestrian.State.keys()[_target.state] if is_instance_valid(_target) else "freed", _life.pedestrians_hit])
				if not _reacted:
					_errors.append("the pedestrian neither dodged nor got hit")
				# The knock-down path, forced: thrown, counted, lies down, then recycled.
				var hits0 := _life.pedestrians_hit
				for p in _life.pedestrians:
					if p.state == Pedestrian.State.WALK and p != _target:
						p._knock(Vector3(9, 0, 0))
						break
				if _life.pedestrians_hit != hits0 + 1:
					_errors.append("a knocked-down pedestrian was not counted")
				if not _shot_dir.is_empty():
					_taxi.teleport(Transform3D(Basis.IDENTITY, _taxi.global_position + Vector3(0, 1, 0)))
					_next()
				else:
					_finish()
		5:
			if _step_t > 3.0:
				get_viewport().get_texture().get_image().save_png(_shot_dir.path_join("street.png"))
				print("[StreetTest] screenshot street.png")
				_finish()


## Samples whether a moving car is right of the centre of a straight 2-cell street.
func _check_lane(c: TrafficCar) -> void:
	if c.linear_velocity.length() < 6.0 or Engine.get_physics_frames() % 20 != 0:
		return
	var city := get_tree().get_first_node_in_group(&"city") as City
	var dir := c.linear_velocity
	dir.y = 0.0
	dir = dir.normalized()
	var right := dir.cross(Vector3.UP)
	var r := 0.0
	var l := 0.0
	while r < 16.0 and city.is_plain_street(c.global_position + right * (r + 1.0)):
		r += 1.0
	while l < 16.0 and city.is_plain_street(c.global_position - right * (l + 1.0)):
		l += 1.0
	if r + l < 12.0 or r + l > 18.0:
		return   # not a plain 2-cell street here
	if r < l:
		_lane_ok += 1
	else:
		_lane_bad += 1


func _next() -> void:
	_step += 1
	_step_t = 0.0


func _fail(msg: String) -> void:
	_errors.append(msg)
	_finish()


func _finish() -> void:
	set_physics_process(false)
	Input.action_release(&"accelerate")
	if _errors.is_empty():
		print("[StreetTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[StreetTest] FAIL: ", e)
		get_tree().quit(1)
