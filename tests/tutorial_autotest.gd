extends Node
## Headless test of the main-menu tutorial (src/ui/tutorial/tutorial.gd) through Main:
##  drive (real throttle) → drift (real handbrake + steer; the step gives up after a while,
##  reported but not a failure) → shoot (real aim + fire) → a calm fare is placed at a stop
##  → board → file → DRIVE → deliver → DONE, flag cleared. While it runs: only calm fares,
##  no street encounters.
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/tutorial_autotest.tscn

const MAIN := preload("res://src/main/main.tscn")

var _taxi: Taxi
var _rides: RideManager
var _spawner: PassengerSpawner
var _dossier: Dossier
var _tutorial: Tutorial
var _encounters: StreetEncounters
var _t: float = 0.0
var _step: int = 0
var _step_t: float = 0.0
var _errors: PackedStringArray = []
var _drifted: bool = false


func _ready() -> void:
	MapData.use_builtin()
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.reset_run()
	GameState.tutorial_active = true
	add_child(MAIN.instantiate())


func _physics_process(delta: float) -> void:
	_t += delta
	_step_t += delta
	if _taxi == null:
		_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
		_rides = get_tree().get_first_node_in_group(&"ride_manager") as RideManager
		_spawner = get_tree().get_first_node_in_group(&"passenger_spawner") as PassengerSpawner
		_dossier = get_tree().get_first_node_in_group(&"dossier") as Dossier
		_tutorial = get_tree().get_first_node_in_group(&"tutorial") as Tutorial
		_encounters = get_tree().get_first_node_in_group(&"street_encounters") as StreetEncounters
		if _tutorial != null:
			_tutorial.drift_give_up = 10.0
			_tutorial.done_seconds = 1.0
		return
	if _t > 90.0:
		_fail("timeout at test step %d (tutorial step %s)" % [_step, Tutorial.Step.keys()[_tutorial.step]])
		return
	for p in _spawner.waiting:
		if p.profile.id != &"commuter" and GameState.tutorial_active:
			_fail("non-tutorial fare spawned during the tutorial: %s" % p.profile.id)
			return
	match _step:
		0:
			if _tutorial.step == Tutorial.Step.DRIVE:
				print("[TutorialTest] step DRIVE shown: ", _tutorial._body.text.replace("\n", " / "))
				Input.action_press(&"accelerate")
				_next()
		1:
			if _tutorial.step == Tutorial.Step.DRIFT:
				print("[TutorialTest] drove at %.0f km/h -> DRIFT" % _taxi.get_speed_kmh())
				Input.action_press(&"steer_left")
				Input.action_press(&"handbrake")
				_next()
			elif _step_t > 15.0:
				_fail("driving step never passed (speed %.0f km/h)" % _taxi.get_speed_kmh())
		2:
			var chain := _taxi.get_node_or_null("DriftChain") as DriftChain
			if chain != null and chain.is_active:
				_drifted = true
			if _tutorial.step == Tutorial.Step.SHOOT:
				print("[TutorialTest] -> SHOOT (drift %s)" % ("detected" if _drifted else "NOT detected, step gave up"))
				for a in [&"accelerate", &"steer_left", &"handbrake"]:
					Input.action_release(a)
				Input.action_press(&"aim")
				_next()
		3:
			if _step_t > 0.6:
				Input.action_press(&"fire")
			if _tutorial.step == Tutorial.Step.PICKUP:
				Input.action_release(&"aim")
				Input.action_release(&"fire")
				print("[TutorialTest] fired -> PICKUP")
				_next()
			elif _step_t > 5.0:
				_fail("shooting step never passed")
		4:
			if _step_t > 0.5:
				var p := _spawner.get_nearest(_taxi.global_position)
				if p == null:
					_fail("no fare placed for the pickup step")
					return
				print("[TutorialTest] fare %s waiting %d m away at %s" % [p.profile.id,
						roundi(p.global_position.distance_to(_taxi.global_position)), p.stop.stop_name])
				_teleport(p.stop.global_position, p.global_position)
				_next()
		5:
			if _tutorial.step == Tutorial.Step.FILE and _dossier.is_open:
				print("[TutorialTest] file open -> FILE; choosing DRIVE")
				_dossier.choose(&"drive")
				_next()
			elif _step_t > 12.0:
				_fail("passenger never boarded / file never opened")
		6:
			if _tutorial.step == Tutorial.Step.DELIVER and _rides.state == RideManager.State.RIDING:
				print("[TutorialTest] -> DELIVER, teleporting to %s" % _rides.ride.destination.stop_name)
				_teleport(_rides.ride.destination.global_position, Vector3.ZERO)
				_next()
			elif _step_t > 5.0:
				_fail("ride did not start after DRIVE")
		7:
			if _tutorial.step == Tutorial.Step.DONE:
				print("[TutorialTest] delivered -> DONE, tutorial flag %s" % GameState.tutorial_active)
				if GameState.tutorial_active:
					_errors.append("tutorial flag still on after DONE")
				_next()
			elif _step_t > 8.0:
				_fail("delivery did not finish the tutorial")
		8:
			if _tutorial.step == Tutorial.Step.OFF:
				if _tutorial.visible:
					_errors.append("tutorial panel still visible after it ended")
				if _encounters != null and _encounters.fired > 0:
					_errors.append("a street encounter fired during the tutorial")
				_finish()
			elif _step_t > 4.0:
				_fail("DONE panel never went away")


func _teleport(street_point: Vector3, look_at_point: Vector3) -> void:
	var basis := Basis.IDENTITY
	var to := look_at_point - street_point
	to.y = 0.0
	if to.length() > 0.1:
		basis = Basis.looking_at(to.normalized().cross(Vector3.UP), Vector3.UP)
	_taxi.teleport(Transform3D(basis, street_point + Vector3(0, 1.0, 0)))


func _next() -> void:
	_step += 1
	_step_t = 0.0


func _fail(msg: String) -> void:
	_errors.append(msg)
	_finish()


func _finish() -> void:
	set_physics_process(false)
	for a in [&"accelerate", &"steer_left", &"handbrake", &"aim", &"fire"]:
		Input.action_release(a)
	get_tree().paused = false
	if _errors.is_empty():
		print("[TutorialTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[TutorialTest] FAIL: ", e)
		get_tree().quit(1)
