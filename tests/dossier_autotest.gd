extends Node
## Headless Phase 04 test through Main (Dossier UI is part of Main):
##  A. Rushed Executive: file opens + world paused; only Drive/Kick at first; examining the
##     jacket costs ride time and unlocks Kill; Kill -> passenger gone, +$120 bounty, heat +1.
##  B. Commuter: Kick out -> no fare, back to IDLE, world unpaused.
##  C. Tourist: examine map -> "scenic" (x1.5 fare) -> deliver -> payout reflects x1.5.
##  D. Rushed Executive again: Kick out -> ANGRY parting shot damages the driver.
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/dossier_autotest.tscn

const MAIN := preload("res://src/main/main.tscn")

var _taxi: Taxi
var _rides: RideManager
var _shift: ShiftManager
var _spawner: PassengerSpawner
var _dossier: Dossier
var _city: City
var _t: float = 0.0
var _step: int = 0
var _step_t: float = 0.0
var _errors: PackedStringArray = []
var _cash0: int = 0
var _heat0: int = 0
var _clock0: float = 0.0
var _executed: bool = false
var _payout: int = -1
var _driver0: float = 0.0
var _shot_dir: String = ""
var _shots: int = 0
var _open_t: float = 0.0


func _ready() -> void:
	MapData.use_builtin()   # never the user's edited map
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep testing while the file pauses the world
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			_shot_dir = arg.get_slice("=", 1)
	add_child(MAIN.instantiate())
	EventBus.passenger_executed.connect(func(_p: RefCounted) -> void: _executed = true)
	EventBus.ride_completed.connect(func(_r: RefCounted, p: int) -> void: _payout = p)


func _physics_process(delta: float) -> void:
	_t += delta
	_step_t += delta
	if _taxi == null:
		_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
		_rides = get_tree().get_first_node_in_group(&"ride_manager") as RideManager
		_shift = get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
		_spawner = get_tree().get_first_node_in_group(&"passenger_spawner") as PassengerSpawner
		_dossier = get_tree().get_first_node_in_group(&"dossier") as Dossier
		_city = get_tree().get_first_node_in_group(&"city") as City
		return
	if _t > 70.0:
		_fail("timeout at step %d (ride state %d)" % [_step, _rides.state])
		return
	match _step:
		0:
			if _shift.is_active and _step_t > 1.5:
				_board("rushed_executive")
		1:  # A: file open, paused, examine, kill
			if _dossier.is_open and not _shot_dir.is_empty() and _shots < 3:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_open_t += delta   # time since the file opened (it slides in)
				if _shots == 0 and _open_t > 0.6:
					_shot("file_open.png")
					_dossier.examine(&"jacket")
				elif _shots == 1 and _open_t > 0.9:
					_shot("file_one_clue.png")
					_dossier.examine(&"phone")
				elif _shots == 2 and _open_t > 1.2:
					_shot("file_examined.png")
				return
			if _dossier.is_open:
				var ids := _dossier.available_action_ids()
				print("[DossierTest] A file open (%s, %d, paused=%s): actions %s" % [_dossier.passenger.display_name, _dossier.passenger.age, get_tree().paused, ids])
				if not get_tree().paused:
					_errors.append("world not paused while the file is open")
				if ids.has(&"kill") and _shot_dir.is_empty():   # screenshot mode examines first
					_errors.append("kill available before examining")
				var who := _dossier.passenger
				var dist := _rides._flat_distance(_taxi.global_position, who.destination.global_position)
				_clock0 = _rides.planned_time(who, dist)
				_dossier.examine(&"jacket")
				ids = _dossier.available_action_ids()
				var clock1 := _rides.planned_time(who, dist)
				print("[DossierTest] A examined jacket: ride clock %.1f -> %.1f, actions %s" % [_clock0, clock1, ids])
				if _clock0 - clock1 < 0.9 and _shot_dir.is_empty():
					_errors.append("examining did not cost ride time")
				if not ids.has(&"kill"):
					_errors.append("kill not unlocked by examining the jacket")
				_cash0 = GameState.cash
				_heat0 = GameState.heat
				_dossier.choose(&"kill")
				_next()
		2:
			if _step_t > 0.5:
				print("[DossierTest] A killed: executed=%s, cash %d -> %d, heat %d -> %d, state %s, paused=%s" % [
					_executed, _cash0, GameState.cash, _heat0, GameState.heat, RideManager.State.keys()[_rides.state], get_tree().paused])
				if not _executed or GameState.cash != _cash0 + 120 or GameState.heat != _heat0 + 1:
					_errors.append("kill outcome wrong")
				if get_tree().paused:
					_errors.append("world still paused after choosing")
				_next()
		3:
			if _rides.state == RideManager.State.IDLE and _step_t > 0.8:
				_board("commuter")
		4:  # B: kick out
			if _dossier.is_open:
				_cash0 = GameState.cash
				_dossier.choose(&"kick_out")
				_next()
		5:
			if _step_t > 1.0:
				print("[DossierTest] B kicked out commuter: cash %d -> %d, state %s" % [_cash0, GameState.cash, RideManager.State.keys()[_rides.state]])
				if GameState.cash != _cash0 or _rides.state != RideManager.State.IDLE:
					_errors.append("kick out outcome wrong")
				_board("tourist")
		6:  # C: scenic route
			if _dossier.is_open:
				if _dossier.available_action_ids().has(&"scenic"):
					_errors.append("scenic available before examining the map")
				_dossier.examine(&"map")
				_dossier.choose(&"scenic")
				_next()
		7:
			if _rides.state == RideManager.State.RIDING and _step_t > 0.3:
				var ride := _rides.ride
				print("[DossierTest] C scenic ride: fare_mult %.1f, time %.0f s, -> %s" % [ride.fare_mult, ride.time_limit, ride.destination.stop_name])
				if not is_equal_approx(ride.fare_mult, 1.5):
					_errors.append("scenic fare multiplier not applied")
				_teleport(ride.destination.global_position, Vector3.ZERO)
				_next()
		8:
			if _payout >= 0:
				print("[DossierTest] C delivered: payout $%d" % _payout)
				if _payout < 40:
					_errors.append("scenic payout suspiciously low ($%d)" % _payout)
				_next()
			elif _step_t > 6.0:
				_fail("scenic ride not delivered")
		9:
			if _rides.state == RideManager.State.IDLE and _step_t > 0.8:
				_board("rushed_executive")
		10:  # D: angry kick
			if _dossier.is_open:
				var dmg := _taxi.get_node("TaxiDamage") as TaxiDamage
				_driver0 = dmg.driver_health.hp
				_dossier.choose(&"kick_out")
				_next()
		11:
			if _step_t > 0.3:
				var dmg := _taxi.get_node("TaxiDamage") as TaxiDamage
				print("[DossierTest] D angry kick: driver %.0f -> %.0f" % [_driver0, dmg.driver_health.hp])
				if dmg.driver_health.hp >= _driver0:
					_errors.append("angry passenger's parting shot did no damage")
				_finish()


func _shot(file: String) -> void:
	_shots += 1
	get_viewport().get_texture().get_image().save_png(_shot_dir.path_join(file))
	print("[DossierTest] screenshot ", file)


## Spawns the given profile at a free stop next to the taxi and parks the taxi beside them.
func _board(profile_id: String) -> void:
	var profile := load("res://data/passengers/%s.tres" % profile_id) as PassengerProfile
	var best: TaxiStop = null
	var best_d := INF
	for s in _city.stops:
		if s.occupied:
			continue
		var d := s.global_position.distance_to(_taxi.global_position)
		if d < best_d:
			best_d = d
			best = s
	var p := _spawner.spawn_at(profile, best)
	_teleport(best.global_position, p.global_position)
	print("[DossierTest] boarding a %s at %s" % [profile.display_name, best.stop_name])
	_next()


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
	get_tree().paused = false
	if _errors.is_empty():
		print("[DossierTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[DossierTest] FAIL: ", e)
		get_tree().quit(1)
