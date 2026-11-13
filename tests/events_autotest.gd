extends Node
## Headless Phase 07 test through Main: ride events, archetypes and strategic hitman spawns.
##  A. spawn_on_route: an ambusher waits AHEAD on the route (out of sight, parked) and wakes up
##     when the taxi gets close; pincer = some ahead + some behind.
##  B. Businessman: hitmen spawn mid-ride (at least one ahead); delivery still pays; the
##     hitmen are still there after the delivery and none keeps waiting in ambush; an outrun
##     hitman is put back on the taxi's tail.
##  C. Burglar: not thrown out in time -> robbed (30 %) and he bails; thrown out in the counter
##     window (kick_out input) -> nothing stolen, loot dropped. A normal fare can NOT be
##     ended with kick_out.
##  D. Hijacker: destination forced to the docks, no fare, shoots when you stop, robs you on
##     arrival; kicking is unlocked once hijacked.
##  E. Old lady: gift on arrival; "help with her bags" costs ride time and gives a better gift.
##  (There is no shift clock any more.)
##  F. TimerModifierEvent changes the ride clock.  G. Spawner respects min_shift.
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/events_autotest.tscn
## Windowed + `-- --shot-dir=<dir>` saves HUD screenshots (thief alert, hijack, gift).

const MAIN := preload("res://src/main/main.tscn")
const TIMEOUT := 150.0

var _taxi: Taxi
var _rides: RideManager
var _shift: ShiftManager
var _spawner: PassengerSpawner
var _dossier: Dossier
var _city: City
var _director: EnemyDirector
var _damage: TaxiDamage
var _t: float = 0.0
var _errors: PackedStringArray = []
var _payout: int = -1
var _failed: StringName = &""
var _rewards: Array[StringName] = []
var _barks: int = 0
var _shot_dir: String = ""
var _done: bool = false


func _ready() -> void:
	MapData.use_builtin()   # never the user's edited map
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep testing while the file pauses the world
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			_shot_dir = arg.get_slice("=", 1)
	add_child(MAIN.instantiate())
	EventBus.ride_completed.connect(func(_r: RefCounted, p: int) -> void: _payout = p)
	EventBus.ride_failed.connect(func(_r: RefCounted, reason: StringName) -> void: _failed = reason)
	EventBus.ride_reward.connect(func(kind: StringName, _a: float) -> void: _rewards.append(kind))
	EventBus.passenger_bark.connect(func(who: String, text: String) -> void:
		_barks += 1
		print("[EventsTest]   bark  %s: %s" % [who, text]))
	EventBus.hud_message.connect(func(text: String, kind: StringName) -> void: print("[EventsTest]   HUD(%s): %s" % [kind, text]))
	_run()


func _physics_process(delta: float) -> void:
	_t += delta
	if not _shot_dir.is_empty():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _t > TIMEOUT and not _done:
		_errors.append("timeout")
		_finish()


func _run() -> void:
	await _until(func() -> bool: return get_tree().get_first_node_in_group(&"player_vehicle") != null, 5.0)
	_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
	_rides = get_tree().get_first_node_in_group(&"ride_manager") as RideManager
	_shift = get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
	_spawner = get_tree().get_first_node_in_group(&"passenger_spawner") as PassengerSpawner
	_dossier = get_tree().get_first_node_in_group(&"dossier") as Dossier
	_city = get_tree().get_first_node_in_group(&"city") as City
	_director = get_tree().get_first_node_in_group(&"enemy_director") as EnemyDirector
	_damage = _taxi.get_node("TaxiDamage") as TaxiDamage
	await _until(func() -> bool: return _shift.is_active, 5.0)
	await _wait(1.0)
	# Keep the taxi alive while hitmen shoot at it; damage is measured as a difference.
	_damage.taxi_health.max_hp = 100000.0
	_damage.taxi_health.revive()
	_damage.driver_health.max_hp = 100000.0
	_damage.driver_health.revive()

	await _test_strategic_spawns()
	await _test_businessman()
	await _test_burglar()
	await _test_hijacker()
	await _test_old_lady()
	await _test_blocks_and_spawner()
	_finish()


# --- A ----------------------------------------------------------------------------------

func _test_strategic_spawns() -> void:
	var dest := _far_stop()
	var route := _city.get_route(_taxi.global_position, dest.global_position)
	var cars := _director.spawn_on_route(dest.global_position, &"ambush_ahead", 1)
	if cars.size() != 1:
		_errors.append("A: ambush spawned %d cars" % cars.size())
		return
	var car := cars[0]
	var info := _route_info(route, car.global_position)
	var visible := _director._is_visible_from_taxi(car.global_position)
	print("[EventsTest] A ambusher at %s: %.0f m off the route, %.0f m ahead along it (route %.0f m), visible=%s, mode %s" % [
		car.global_position.round(), info["off"], info["along"], info["total"], visible, EnemyDriverAI.Mode.keys()[car.ai.mode]])
	if car.ai.mode != EnemyDriverAI.Mode.AMBUSH:
		_errors.append("A: ambusher is not waiting (mode %s)" % EnemyDriverAI.Mode.keys()[car.ai.mode])
	if info["off"] > City.PITCH + 4.0:
		_errors.append("A: ambusher is not on / next to the route (%.0f m off)" % info["off"])
	if info["along"] < 40.0 or info["along"] > info["total"] - 20.0:
		_errors.append("A: ambusher is not between the taxi and the destination (%.0f of %.0f m)" % [info["along"], info["total"]])
	if visible:
		_errors.append("A: ambusher spawned in view")
	await _wait(2.0)
	if not is_instance_valid(car):
		_errors.append("A: ambusher vanished")
		return
	print("[EventsTest] A after 2 s: speed %.1f m/s, mode %s" % [car.linear_velocity.length(), EnemyDriverAI.Mode.keys()[car.ai.mode]])
	if car.linear_velocity.length() > 1.5 or car.ai.mode != EnemyDriverAI.Mode.AMBUSH:
		_errors.append("A: ambusher did not hold its position")
	# Drive up to it: the ambush springs.
	var away := (_taxi.global_position - car.global_position)
	away.y = 0.0
	_teleport(car.global_position + away.normalized() * 30.0, car.global_position)
	await _wait(1.0)
	if is_instance_valid(car):
		print("[EventsTest] A taxi 30 m away: mode %s" % EnemyDriverAI.Mode.keys()[car.ai.mode])
		if car.ai.mode == EnemyDriverAI.Mode.AMBUSH:
			_errors.append("A: ambush did not spring when the taxi came close")
	_director.clear_all()
	await _wait(0.3)

	# Pincer from the city centre.
	_teleport(Vector3.ZERO, Vector3(0, 0, -50))
	await _wait(0.5)
	dest = _far_stop()
	cars = _director.spawn_on_route(dest.global_position, &"pincer", 3)
	var waiting := 0
	for c in cars:
		if c.ai.mode == EnemyDriverAI.Mode.AMBUSH:
			waiting += 1
	print("[EventsTest] A pincer: %d cars, %d waiting ahead, %d coming from behind" % [cars.size(), waiting, cars.size() - waiting])
	if cars.size() != 3 or waiting < 1 or waiting == cars.size():
		_errors.append("A: pincer should mix ahead + behind (%d cars, %d ahead)" % [cars.size(), waiting])
	_director.clear_all()
	await _wait(0.3)


# --- B ----------------------------------------------------------------------------------

func _test_businessman() -> void:
	if not await _start_ride("businessman", &"drive"):
		return
	var before := _director.enemies.size()
	_rides.events.debug_fire_pending()
	await _wait(0.2)
	var ahead := 0
	for c in _director.enemies:
		if is_instance_valid(c) and c.ai.mode == EnemyDriverAI.Mode.AMBUSH:
			ahead += 1
	print("[EventsTest] B businessman: hitmen %d -> %d (%d waiting ahead)" % [before, _director.enemies.size(), ahead])
	if _director.enemies.size() < 2:
		_errors.append("B: businessman did not bring hitmen")
	if ahead < 1:
		_errors.append("B: no hitman ahead on the route")
	await _deliver()
	print("[EventsTest] B delivered: payout $%d" % _payout)
	if _payout < 100:
		_errors.append("B: businessman payout too low ($%d)" % _payout)
	# The fare is delivered, the hitmen are not done: nobody vanishes, nobody keeps waiting.
	await _wait(0.3)
	var alive := 0
	var still_waiting := 0
	for c in _director.enemies:
		if is_instance_valid(c):
			alive += 1
			if c.ai.mode == EnemyDriverAI.Mode.AMBUSH:
				still_waiting += 1
	print("[EventsTest] B after the delivery: %d hitmen alive, %d still waiting in ambush" % [alive, still_waiting])
	if alive < 2:
		_errors.append("B: hitmen gave up when the fare was delivered")
	if still_waiting > 0:
		_errors.append("B: an ambusher kept waiting after the ride ended")
	# Outrun them (teleport to the far corner): they come back on the tail.
	var corner := Vector3.ZERO
	var corner_d := 0.0
	for s in _city.stops:
		var nearest := INF
		for c in _director.enemies:
			if is_instance_valid(c):
				nearest = minf(nearest, c.global_position.distance_to(s.global_position))
		if nearest > corner_d and nearest < INF:
			corner_d = nearest
			corner = s.global_position
	if corner_d > _director.lose_distance + 30.0:
		_teleport(corner, Vector3.ZERO)
		await _wait(1.5)
		var close := 0
		for c in _director.enemies:
			if is_instance_valid(c) and c.global_position.distance_to(_taxi.global_position) < _director.lose_distance:
				close += 1
		print("[EventsTest] B outran them by %.0f m: %d of %d back within %.0f m" % [corner_d, close, _director.enemies.size(), _director.lose_distance])
		if close < 1:
			_errors.append("B: outrun hitmen did not come back")
	else:
		print("[EventsTest] B (no stop far enough to outrun them: %.0f m)" % corner_d)
	_director.clear_all()
	await _idle()


# --- C ----------------------------------------------------------------------------------

func _test_burglar() -> void:
	GameState.add_cash(200 - GameState.cash)
	# C1: too slow -> robbed.
	if not await _start_ride("burglar", &"drive"):
		return
	_rides.events.debug_fire_pending()
	if not _rides.events.is_active(StealCashEvent):
		_errors.append("C1: theft attempt did not start")
	await _wait(1.0)
	_shot("thief_alert.png")
	if GameState.cash != 200:
		_errors.append("C1: cash taken before the counter window ran out")
	await _until(func() -> bool: return _failed != &"", 5.0)
	print("[EventsTest] C1 not thrown out: cash 200 -> %d, ride ended as '%s', stolen stat %d" % [GameState.cash, _failed, _shift.cash_stolen])
	if GameState.cash != 140 or _failed != &"robbed" or _shift.cash_stolen != 60:
		_errors.append("C1: robbery outcome wrong")
	await _idle()

	# C2: thrown out inside the window -> nothing stolen, loot.
	if not await _start_ride("burglar", &"drive"):
		return
	if _rides.can_kick_mid_ride():
		_errors.append("C2: kick allowed before the thief makes his move")
	_rides.events.debug_fire_pending()
	await _wait(0.6)
	if not _rides.can_kick_mid_ride():
		_errors.append("C2: kick not allowed during the theft window")
	Input.action_press(&"kick_out")
	await _wait(0.15)
	Input.action_release(&"kick_out")
	await _wait(0.2)
	print("[EventsTest] C2 thrown out in time: cash 140 -> %d, ride ended as '%s', kicked stat %d" % [GameState.cash, _failed, _shift.passengers_kicked])
	if GameState.cash != 165 or _failed != &"kicked_out":
		_errors.append("C2: catching the thief did not work")
	await _idle()

	# C3: a normal fare cannot be ended by the driver (input and API both refused).
	var kicked0 := _shift.passengers_kicked
	if not await _start_ride("commuter", &"drive"):
		return
	Input.action_press(&"kick_out")
	await _wait(0.15)
	Input.action_release(&"kick_out")
	_rides.kick_out_mid_ride()
	await _wait(0.2)
	print("[EventsTest] C3 kick_out on a normal fare: state %s, ended as '%s', kicked %d -> %d" % [
		RideManager.State.keys()[_rides.state], _failed, kicked0, _shift.passengers_kicked])
	if _rides.state != RideManager.State.RIDING or _failed != &"" or _shift.passengers_kicked != kicked0:
		_errors.append("C3: a normal fare could be ended with kick_out")
	await _deliver()
	await _idle()


# --- D ----------------------------------------------------------------------------------

func _test_hijacker() -> void:
	if not await _start_ride("hijacker", &"drive"):
		return
	var original := _rides.ride.destination
	_rides.events.debug_fire_pending()
	await _wait(0.2)
	var ride := _rides.ride
	print("[EventsTest] D hijacked: %s -> %s (%s), fare x%.1f, %.0f m, %.0f s" % [
		original.stop_name, ride.destination.stop_name, ride.destination.district, ride.fare_mult, ride.distance, ride.time_limit])
	if ride.destination == original or ride.destination.district != &"docks" or ride.fare_mult != 0.0:
		_errors.append("D: detour not applied")
	if original.occupied:
		_errors.append("D: old destination still reserved")
	if not _rides.can_kick_mid_ride():
		_errors.append("D: kicking the hijacker out is not unlocked")
	if not _rides.events.is_active(PassengerAttackEvent):
		_errors.append("D: hijacker is not holding the driver at gunpoint")
	var hp0 := _damage.driver_health.hp
	await _wait(1.5)
	_shot("hijacked.png")
	await _wait(2.6)
	print("[EventsTest] D parked for 4 s: driver hp %.0f -> %.0f" % [hp0, _damage.driver_health.hp])
	if hp0 - _damage.driver_health.hp < 9.0:
		_errors.append("D: hijacker did not shoot a stopped driver")
	var cash0 := GameState.cash
	await _deliver()
	print("[EventsTest] D delivered to the docks: payout $%d, cash %d -> %d" % [_payout, cash0, GameState.cash])
	if _payout != 0:
		_errors.append("D: hijacker paid a fare")
	if GameState.cash >= cash0:
		_errors.append("D: hijacker did not take cash on arrival")
	await _idle()


# --- E ----------------------------------------------------------------------------------

func _test_old_lady() -> void:
	_damage.driver_health.apply_damage(30.0)
	_rewards.clear()
	if not await _start_ride("old_lady", &"drive"):
		return
	await _deliver()
	await _wait(0.4)
	_shot("gift.png")
	print("[EventsTest] E old lady: payout $%d, gift %s" % [_payout, _rewards])
	if _rewards.size() != 1:
		_errors.append("E: old lady gave %d gifts" % _rewards.size())
	await _idle()

	_rewards.clear()
	await _board("old_lady")
	await _until(func() -> bool: return _dossier.is_open, 5.0)
	if _dossier.available_action_ids().has(&"help"):
		_errors.append("E2: help available before examining the bag")
	var lady := _dossier.passenger
	var dist := _rides._flat_distance(_taxi.global_position, lady.destination.global_position)
	var clock0 := _rides.planned_time(lady, dist)
	_dossier.examine(&"bag")
	_dossier.choose(&"help")
	await _until(func() -> bool: return _rides.state == RideManager.State.RIDING, 3.0)
	print("[EventsTest] E2 help with bags: ride clock %.1f -> %.1f" % [clock0, _rides.ride.time_limit])
	if absf((clock0 - _rides.ride.time_limit) - 9.0) > 0.2:
		_errors.append("E2: examining + helping did not cost 9 s of ride time")
	await _deliver()
	await _wait(0.3)
	print("[EventsTest] E2 gift %s" % [_rewards])
	if _rewards.size() != 1 or _rewards[0] == &"ammo":
		_errors.append("E2: wrong gift for helping (%s)" % [_rewards])
	await _idle()


# --- F / G ------------------------------------------------------------------------------

func _test_blocks_and_spawner() -> void:
	if not await _start_ride("expectant_mother", &"drive"):
		return
	var ride := _rides.ride
	var normal := (_rides.ride_base_time + ride.distance / _rides.expected_speed)
	print("[EventsTest] F expectant mother: %.0f m, %.1f s (a relaxed ride would get %.1f s)" % [ride.distance, ride.time_limit, normal])
	if ride.time_limit > normal * 0.75:
		_errors.append("F: expectant mother is not in a hurry")
	var ev := TimerModifierEvent.new()
	ev.add_seconds = -4.0
	var t0 := ride.time_left
	ev.start(_rides.events.ctx, {})
	if absf((t0 - ride.time_left) - 4.0) > 0.2:
		_errors.append("F: TimerModifierEvent did not take 4 s")
	var heat := HeatChangeEvent.new()
	heat.amount = 2
	var h0 := GameState.heat
	heat.start(_rides.events.ctx, {})
	if GameState.heat != mini(h0 + 2, 5):
		_errors.append("F: HeatChangeEvent did not raise heat")
	GameState.set_heat(0)
	var barks0 := _barks
	_rides.events.debug_fire_pending()
	if _barks <= barks0:
		_errors.append("F: no barks from the expectant mother")
	await _deliver()
	await _idle()

	var shift_number := GameState.shift_number
	var seen := {}
	GameState.shift_number = 1
	for i in 400:
		seen[_spawner._pick_profile().id] = true
	var early := seen.has(&"hijacker")
	GameState.shift_number = 2
	for i in 400:
		seen[_spawner._pick_profile().id] = true
	GameState.shift_number = shift_number
	print("[EventsTest] G archetypes rolled: %s (hijacker in shift 1: %s)" % [seen.keys(), early])
	if early:
		_errors.append("G: hijacker (min_shift 2) appeared in shift 1")
	if seen.size() < 8:
		_errors.append("G: only %d archetypes in the pool" % seen.size())


# --- Helpers ----------------------------------------------------------------------------

## Boards `profile_id`, picks `action` in the file and waits until the ride is running.
func _start_ride(profile_id: String, action: StringName) -> bool:
	await _board(profile_id)
	if not await _until(func() -> bool: return _dossier.is_open, 5.0):
		_errors.append("%s: file never opened (state %d)" % [profile_id, _rides.state])
		return false
	_dossier.choose(action)
	if not await _until(func() -> bool: return _rides.state == RideManager.State.RIDING, 3.0):
		_errors.append("%s: ride did not start" % profile_id)
		return false
	_payout = -1
	_failed = &""
	return true


func _board(profile_id: String) -> void:
	_payout = -1
	_failed = &""
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
	print("[EventsTest] boarding: %s at %s" % [profile.display_name, best.stop_name])
	await _wait(0.1)


func _deliver() -> void:
	_payout = -1
	_teleport(_rides.ride.destination.global_position, Vector3.ZERO)
	if not await _until(func() -> bool: return _payout >= 0, 6.0):
		_errors.append("delivery never completed (state %d)" % _rides.state)


func _idle() -> void:
	await _until(func() -> bool: return _rides.state == RideManager.State.IDLE, 4.0)
	await _wait(0.3)


## A stop far from the taxi that needs at least one turn to reach.
func _far_stop() -> TaxiStop:
	var best: TaxiStop = null
	var best_d := 0.0
	for s in _city.stops:
		var d := s.global_position - _taxi.global_position
		if absf(d.x) < 80.0 or absf(d.z) < 80.0:
			continue
		if d.length() > best_d and d.length() < 330.0:
			best_d = d.length()
			best = s
	return best


## Where `pos` sits relative to the route: distance off the polyline, distance along it.
func _route_info(route: PackedVector3Array, pos: Vector3) -> Dictionary:
	var pts := PackedVector3Array([_taxi.global_position])
	pts.append_array(route)
	var best_off := INF
	var best_along := 0.0
	var walked := 0.0
	for i in pts.size() - 1:
		var a := Vector2(pts[i].x, pts[i].z)
		var b := Vector2(pts[i + 1].x, pts[i + 1].z)
		var p := Vector2(pos.x, pos.z)
		var closest := Geometry2D.get_closest_point_to_segment(p, a, b)
		var off := closest.distance_to(p)
		if off < best_off:
			best_off = off
			best_along = walked + a.distance_to(closest)
		walked += a.distance_to(b)
	return {"off": best_off, "along": best_along, "total": walked}


func _teleport(street_point: Vector3, look_at_point: Vector3) -> void:
	var basis := Basis.IDENTITY
	var to := look_at_point - street_point
	to.y = 0.0
	if to.length() > 12.0:
		basis = Basis.looking_at(to.normalized(), Vector3.UP)
	elif to.length() > 0.1:
		basis = Basis.looking_at(to.normalized().cross(Vector3.UP), Vector3.UP)
	_taxi.teleport(Transform3D(basis, street_point + Vector3(0, 1.0, 0)))


func _wait(seconds: float) -> void:
	var until := _t + seconds
	while _t < until and not _done:
		await get_tree().physics_frame


func _until(cond: Callable, timeout: float) -> bool:
	var until := _t + timeout
	while _t < until and not _done:
		if cond.call():
			return true
		await get_tree().physics_frame
	return bool(cond.call())


func _shot(file: String) -> void:
	if _shot_dir.is_empty():
		return
	get_viewport().get_texture().get_image().save_png(_shot_dir.path_join(file))
	print("[EventsTest] screenshot ", file)


func _finish() -> void:
	if _done:
		return
	_done = true
	set_physics_process(false)
	get_tree().paused = false
	if _errors.is_empty():
		print("[EventsTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[EventsTest] FAIL: ", e)
		get_tree().quit(1)
