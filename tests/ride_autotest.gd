extends Node
## Headless ride-loop integration test (teleports the taxi; no driving skill needed):
##  1. the run auto-starts (no shift clock), passengers spawn
##  2. stop next to a passenger -> ride starts
##  3. stop in the destination ring -> paid, cash > 0
##  4. second ride runs out of time -> ride_failed
##  5. a damaged taxi is repaired for a fee on a repair shop's pad
##  6. taxi body at 0 HP = dead: explosion + game over (no limping since 2026-11-15)
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/ride_autotest.tscn
## Visual check (no --headless): add `-- --shot-dir=<folder>` to save PNGs mid-ride.

const MAIN := preload("res://src/main/main.tscn")
const TIMEOUT := 40.0

var _taxi: Taxi
var _rides: RideManager
var _shift: ShiftManager
var _spawner: PassengerSpawner
var _t: float = 0.0
var _step: int = 0
var _step_t: float = 0.0
var _errors: PackedStringArray = []
var _completed_payout: int = -1
var _failed_reason: StringName = &""
var _shift_ended: bool = false
var _cash_before: int = 0
var _shot_dir: String = ""


func _ready() -> void:
	ShopMenu.enabled = false   # part 6 repairs at a repair garage (D-089 keeps them, switched off)
	MapData.use_builtin()   # never the user's edited map
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep running while the passenger file pauses the world
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			_shot_dir = arg.get_slice("=", 1)
	add_child(MAIN.instantiate())
	EventBus.ride_completed.connect(func(_r: RefCounted, payout: int) -> void: _completed_payout = payout)
	EventBus.ride_failed.connect(func(_r: RefCounted, reason: StringName) -> void: _failed_reason = reason)
	EventBus.shift_ended.connect(func(_s: Dictionary) -> void: _shift_ended = true)
	EventBus.hud_message.connect(func(text: String, kind: StringName) -> void: print("[RideTest]   HUD(%s): %s" % [kind, text]))


func _physics_process(delta: float) -> void:
	_release_tap()
	_t += delta
	_step_t += delta
	if _taxi == null:
		_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
		_rides = get_tree().get_first_node_in_group(&"ride_manager") as RideManager
		_shift = get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
		_spawner = get_tree().get_first_node_in_group(&"passenger_spawner") as PassengerSpawner
		return
	if _t > TIMEOUT:
		_fail("timed out at step %d" % _step)
		return
	# Phase 04: every pickup opens the passenger file -> just drive them.
	var dossier := get_tree().get_first_node_in_group(&"dossier") as Dossier
	if dossier != null and dossier.is_open:
		dossier.choose(&"drive")
		return
	match _step:
		0:  # wait for shift + some passengers
			if _shift.is_active and _spawner.waiting.size() >= 3 and _step_t > 1.0:
				print("[RideTest] shift %d active, %d passengers waiting, %d stops" % [
					GameState.shift_number, _spawner.waiting.size(), (get_tree().get_first_node_in_group(&"city") as City).stops.size()])
				_go_to_passenger()
		1:  # wait for ride to start
			if _rides.state == RideManager.State.RIDING:
				var ride := _rides.ride
				print("[RideTest] ride started: %s -> %s, %.0f m, %.1f s" % [ride.profile.display_name, ride.destination.stop_name, ride.distance, ride.time_limit])
				if ride.distance < ride.profile.min_distance - 1.0 and _step == 1:
					_errors.append("ride shorter than profile minimum (%.0f < %.0f m)" % [ride.distance, ride.profile.min_distance])
				if not _shot_dir.is_empty() and not _shot_taken:
					_shoot("ride_started.png")
					return
				var d := ride.destination
				# Approach from 25 m down the street (along it, never into a block), facing the stop.
				var normal := d.global_position - d.sidewalk_point
				normal.y = 0.0
				var along := normal.normalized().cross(Vector3.UP)
				_teleport_near(d.global_position + along * 25.0, d.global_position)
				_next()
			elif _step_t > 6.0:
				_fail("ride never started (state %d)" % _rides.state)
		2:  # wait for delivery
			if not _shot_dir.is_empty() and is_equal_approx(snappedf(_step_t, 1.0 / 60.0), 0.5):
				_shoot("arriving.png")
			if is_equal_approx(snappedf(_step_t, 1.0 / 60.0), 0.8):
				_teleport_near(_rides.ride.destination.global_position, Vector3.ZERO)
			if _completed_payout >= 0:
				print("[RideTest] delivered: payout $%d, cash $%d" % [_completed_payout, GameState.cash])
				if _completed_payout <= 0 or GameState.cash <= 0:
					_errors.append("no money paid")
				_next()
			elif _step_t > 6.0:
				_fail("delivery never completed (state %d)" % _rides.state)
		3:  # second ride, let it time out
			if _rides.state == RideManager.State.IDLE and _step_t > 1.0:
				_go_to_passenger()
		4:
			if _rides.state == RideManager.State.RIDING:
				_rides.ride.time_left = 0.2
				_next()
			elif _step_t > 6.0:
				_fail("second ride never started")
		5:
			if _failed_reason != &"":
				print("[RideTest] second ride failed as expected: %s" % _failed_reason)
				GameState.add_cash(100)
				_cash_before = GameState.cash
				(_taxi.get_node("TaxiDamage") as TaxiDamage).taxi_health.apply_damage(50.0)
				_next()
			elif _step_t > 3.0:
				_fail("ride did not fail on timeout")
		6:  # damaged (not dead): a repair shop fixes it for a fee
			if _step_t > 0.5:
				var city := get_tree().get_first_node_in_group(&"city") as City
				var shop := city.nearest_repair_shop(_taxi.global_position)
				if shop == null:
					_fail("the built-in city has no repair shop")
					return
				_taxi.teleport(Transform3D(Basis.IDENTITY, shop.pad_position + Vector3(0, 1.0, 0)))
				_next()
		7:
			var dmg := _taxi.get_node("TaxiDamage") as TaxiDamage
			# Parking alone does nothing: the repair waits for interact (E).
			if _step_t > 1.5 and _step_t - get_physics_process_delta_time() <= 1.5:
				if dmg.taxi_health.hp >= dmg.taxi_health.max_hp - 0.5:
					_errors.append("the shop repaired without pressing interact")
				_tap_interact()
			if dmg.taxi_health.hp >= dmg.taxi_health.max_hp - 0.5:
				print("[RideTest] repaired at the shop after %.1f s, cash %d -> %d" % [_step_t, _cash_before, GameState.cash])
				if GameState.cash >= _cash_before:
					_errors.append("the repair was free")
				# Taxi body at 0 = dead too (user 2026-11-15): explosion + game over, no limping.
				dmg.taxi_health.apply_damage(999999.0)
				_next()
			elif _step_t > 5.0:
				_fail("pressing interact on the repair pad did not repair the taxi")
		8:
			if _step_t > 3.5:
				var dmg := _taxi.get_node("TaxiDamage") as TaxiDamage
				var main := get_child(0)
				print("[RideTest] taxi destroyed: dead=%s limp=%s game over=%s" % [dmg.is_dead, _taxi.limp, main.is_game_over])
				if not dmg.is_dead or _taxi.limp or not main.is_game_over:
					_errors.append("a destroyed taxi did not end the run")
				get_tree().paused = false
				_finish()


var _shot_taken: bool = false


func _shoot(file: String) -> void:
	_shot_taken = true
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot_dir.path_join(file))
	print("[RideTest] screenshot ", file)


func _go_to_passenger() -> void:
	# A plain commuter at the nearest free stop: this test is about the basic ride loop, the
	# Phase 07 archetypes (thieves, hijackers...) have their own test (events_autotest).
	var city := get_tree().get_first_node_in_group(&"city") as City
	var best: TaxiStop = null
	var best_d := INF
	for s in city.stops:
		var d := s.global_position.distance_to(_taxi.global_position)
		if not s.occupied and d < best_d:
			best_d = d
			best = s
	var p := _spawner.spawn_at(load("res://data/passengers/commuter.tres") as PassengerProfile, best)
	_teleport_near(p.stop.global_position, p.global_position)
	print("[RideTest] teleported next to waiting %s at %s" % [p.profile.display_name, p.stop.stop_name])
	_next()


## Teleports to `street_point`; faces `look_at_point` if far, else parks sideways to it.
func _teleport_near(street_point: Vector3, look_at_point: Vector3) -> void:
	var pos := street_point + Vector3(0, 1.0, 0)
	var basis := Basis.IDENTITY
	var to_target := look_at_point - street_point
	to_target.y = 0.0
	if to_target.length() > 5.0:
		basis = Basis.looking_at(to_target.normalized(), Vector3.UP)
	elif to_target.length() > 0.1:
		basis = Basis.looking_at(to_target.normalized().cross(Vector3.UP), Vector3.UP)
	_taxi.teleport(Transform3D(basis, pos))


func _next() -> void:
	_step += 1
	_step_t = 0.0


func _fail(msg: String) -> void:
	_errors.append(msg)
	_finish()


func _finish() -> void:
	set_physics_process(false)
	if _errors.is_empty():
		print("[RideTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[RideTest] FAIL: ", e)
		get_tree().quit(1)


## Presses interact for one physics frame. This node is the parent of Main, so it runs before
## the shops in the same frame and they see `is_action_just_pressed`.
var _release_interact: bool = false


func _tap_interact() -> void:
	Input.action_press(&"interact")
	_release_interact = true


func _release_tap() -> void:
	if _release_interact and not Input.is_action_just_pressed(&"interact"):
		Input.action_release(&"interact")
		_release_interact = false
