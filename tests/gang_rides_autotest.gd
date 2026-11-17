extends Node
## Headless Iteration 17 test through Main: the gang-rides mode (D-088).
##  A. Zones: three gangs, each owns a district of the built-in city (every stop has a gang).
##  B. Members: spawn_member puts a gang member at a stop of their own zone, wearing their colour.
##  C. Boarding: no passenger file; the ride starts at once with a random difficulty that
##     changes the clock and the pay, and a ride card is announced.
##  D. Rivals: a gang member on a DEADLY ride brings the OTHER gangs (their own cars, never his
##     gang's); a planned crew fires by itself once the ride gets far enough.
##  E. Auto-delivery: driving through the green ring at speed delivers the fare.
##  F. Old lady: still gives her gift; her card says so. An ordinary EASY fare has no crews.
##  G. Difficulty: all four come up over many rolls.
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/gang_rides_autotest.tscn
## Windowed + `-- --shot-dir=<dir>` saves screenshots of the ride card and a rival crew.

const MAIN := preload("res://src/main/main.tscn")
const TIMEOUT := 120.0

var _taxi: Taxi
var _rides: RideManager
var _shift: ShiftManager
var _spawner: PassengerSpawner
var _dossier: Dossier
var _city: City
var _director: EnemyDirector
var _gangs: GangRides
var _damage: TaxiDamage
var _t: float = 0.0
var _errors: PackedStringArray = []
var _payout: int = -1
var _speed_at_delivery: float = -1.0
var _cards: Array[Dictionary] = []
var _rewards: Array[StringName] = []
var _alerts: PackedStringArray = []
var _shot_dir: String = ""
var _done: bool = false


func _ready() -> void:
	GangRides.enabled = true
	MapData.use_builtin()   # never the user's edited map
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			_shot_dir = arg.get_slice("=", 1)
	add_child(MAIN.instantiate())
	EventBus.ride_completed.connect(func(_r: RefCounted, p: int) -> void:
		_payout = p
		_speed_at_delivery = _taxi.linear_velocity.length())
	EventBus.ride_reward.connect(func(kind: StringName, _a: float) -> void: _rewards.append(kind))
	EventBus.ride_announced.connect(func(title: String, lines: PackedStringArray, _c: Color) -> void:
		_cards.append({"title": title, "lines": lines})
		print("[GangTest]   CARD %s | %s" % [title, " | ".join(lines)]))
	EventBus.ride_alert.connect(func(text: String, _s: float) -> void:
		if text != "":
			_alerts.append(text))
	EventBus.passenger_bark.connect(func(who: String, text: String) -> void: print("[GangTest]   bark  %s: %s" % [who, text]))
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
	_gangs = get_tree().get_first_node_in_group(&"gang_rides") as GangRides
	if _gangs == null:
		_errors.append("no GangRides node in the game")
		_finish()
		return
	_damage = _taxi.get_node("TaxiDamage") as TaxiDamage
	await _until(func() -> bool: return _shift.is_active, 5.0)
	GameState.tutorial_active = false
	var tutorial := get_tree().get_first_node_in_group(&"tutorial") as Tutorial
	if tutorial != null:
		tutorial.skip()
	await _wait(0.5)
	_damage.taxi_health.max_hp = 100000.0
	_damage.taxi_health.revive()
	_damage.driver_health.max_hp = 100000.0
	_damage.driver_health.revive()

	_test_zones()
	var member := _test_member()
	if member != null:
		await _test_boarding(member)
		await _test_rivals()
		await _test_auto_delivery()
	await _test_old_lady()
	_test_difficulty()
	_finish()


# --- A ----------------------------------------------------------------------------------

func _test_zones() -> void:
	if _gangs.gangs.size() != 3:
		_errors.append("A: %d gangs (want red, purple, orange)" % _gangs.gangs.size())
	var total := 0
	for g in _gangs.gangs:
		var stops: Array = _gangs.zones.get(g.id, [])
		var districts := {}
		for s: TaxiStop in stops:
			districts[s.district] = true
		print("[GangTest] A %s (%s): %d stops in %s" % [g.display_name, g.id, stops.size(), districts.keys()])
		if stops.is_empty():
			_errors.append("A: %s has no zone" % g.id)
		if districts.size() > 1:
			_errors.append("A: %s's zone spans several districts" % g.id)
		total += stops.size()
	if total != _city.stops.size():
		_errors.append("A: %d of %d stops belong to a gang" % [total, _city.stops.size()])


# --- B ----------------------------------------------------------------------------------

func _test_member() -> WaitingPassenger:
	var red := _gangs.gang_by_id(&"red")
	var p := _gangs.spawn_member(red)
	if p == null:
		# Nothing free near the taxi: move next to a red stop and try again.
		var stops: Array = _gangs.zones.get(&"red", [])
		_teleport((stops[0] as TaxiStop).global_position + Vector3(90, 0, 0), Vector3.ZERO)
		p = _gangs.spawn_member(red)
	if p == null:
		_errors.append("B: could not place a red member")
		return null
	var gang := _gangs.gang_of_stop(p.stop)
	print("[GangTest] B %s waiting at %s (%s zone), colour %s" % [p.instance.display_name, p.stop.stop_name,
			gang.id if gang != null else "none", p.profile.color])
	if gang != red:
		_errors.append("B: red member waits outside the red zone")
	if GangRides.gang_id_of(p.profile) != &"red":
		_errors.append("B: member profile is not tagged red")
	if p.profile.color != red.color:
		_errors.append("B: member does not wear the gang colour")
	return p


# --- C ----------------------------------------------------------------------------------

func _test_boarding(member: WaitingPassenger) -> void:
	_cards.clear()
	_teleport(member.stop.global_position, member.global_position)
	if not await _until(func() -> bool: return _rides.state == RideManager.State.RIDING, 6.0):
		_errors.append("C: the gang member never got in (state %s)" % RideManager.State.keys()[_rides.state])
		return
	if _dossier.is_open:
		_errors.append("C: the passenger file opened")
	if get_tree().paused:
		_errors.append("C: the world is paused")
	var ride := _rides.ride
	var diff: int = ride.get_meta(&"difficulty", -1)
	if diff < 0:
		_errors.append("C: the ride has no difficulty")
		return
	var d: Dictionary = GangRides.DIFFICULTY[diff]
	var plain := _rides.planned_time(ride.passenger, ride.distance)
	print("[GangTest] C riding: %s, %s, clock %.1f s (plain %.1f), fare x%.2f" % [ride.passenger.display_name,
			d["name"], ride.time_limit, plain, ride.fare_mult])
	if absf(ride.time_limit - plain * float(d["time"])) > 0.05:
		_errors.append("C: clock %.1f is not plain %.1f x %.2f" % [ride.time_limit, plain, float(d["time"])])
	if absf(ride.fare_mult - float(d["pay"])) > 0.001:
		_errors.append("C: fare x%.2f is not the difficulty's x%.2f" % [ride.fare_mult, float(d["pay"])])
	if _cards.is_empty():
		_errors.append("C: no ride card")
	else:
		var card: Dictionary = _cards.back()
		var text := String(card["title"]) + " ".join(card["lines"])
		if not text.contains("RED FANGS") or not text.contains(String(d["name"])) or not text.contains("other gangs"):
			_errors.append("C: ride card misses the gang / difficulty / warning: %s" % text)
	await _wait(0.3)
	_shot("gang_card.png")


# --- D ----------------------------------------------------------------------------------

func _test_rivals() -> void:
	var planned: Array[Dictionary] = []
	for i in 10:   # 75 % per rival on DEADLY: a few tries make "nobody came" impossible in practice
		planned = _gangs.plan_threats(_rides.ride.profile, GangRides.Difficulty.DEADLY)
		if not planned.is_empty():
			break
	var ids: Array[StringName] = []
	for th in planned:
		ids.append((th["gang"] as GangData).id)
	print("[GangTest] D DEADLY plan for a red member: %s" % [ids])
	if ids.has(&"red"):
		_errors.append("D: a red member's own gang came for him")
	if planned.is_empty():
		_errors.append("D: nobody came on ten DEADLY rides")
		return
	# Let the first crew fire by itself (progress already reached), keep the rest for later.
	_director.clear_all()
	_alerts.clear()
	var first: Dictionary = planned[0]
	first["progress"] = 0.0
	_gangs.threats = [first]
	await _wait(0.3)
	if not _gangs.threats.is_empty():
		_errors.append("D: the crew did not fire once its progress was reached")
	var rival := first["gang"] as GangData
	var mine := 0
	for car in _director.enemies:
		if is_instance_valid(car) and car.data.id == StringName("gang_%s" % rival.id):
			mine += 1
		elif is_instance_valid(car) and car.data.id == &"gang_red":
			_errors.append("D: a red car came for a red member")
	print("[GangTest] D %s fired: %d of their cars, alerts %s" % [rival.display_name, mine, _alerts])
	if mine == 0:
		_errors.append("D: no %s car spawned" % rival.id)
	if _alerts.is_empty() or not _alerts[0].contains(rival.display_name.to_upper()):
		_errors.append("D: no alert naming the crew")
	await _wait(1.0)
	_shot("gang_rivals.png")
	_director.clear_all()


# --- E ----------------------------------------------------------------------------------

func _test_auto_delivery() -> void:
	_payout = -1
	_speed_at_delivery = -1.0
	var dest := _rides.ride.destination.global_position
	_teleport(dest, Vector3.ZERO)
	await get_tree().physics_frame
	_taxi.linear_velocity = -_taxi.global_basis.z * 14.0
	if not await _until(func() -> bool: return _payout >= 0, 3.0):
		_errors.append("E: driving through the ring did not deliver")
		return
	print("[GangTest] E delivered at %.1f m/s (old rule: under %.1f), payout $%d" % [_speed_at_delivery,
			_rides.arrival_max_speed, _payout])
	if _speed_at_delivery <= _rides.arrival_max_speed:
		_errors.append("E: the taxi had stopped anyway (%.1f m/s): auto-delivery not proven" % _speed_at_delivery)
	if not _gangs.threats.is_empty():
		_errors.append("E: crews still planned after the delivery")
	await _until(func() -> bool: return _rides.state == RideManager.State.IDLE, 3.0)


# --- F ----------------------------------------------------------------------------------

func _test_old_lady() -> void:
	_cards.clear()
	_rewards.clear()
	var profile := load("res://data/passengers/old_lady.tres") as PassengerProfile
	var best: TaxiStop = null
	var best_d := INF
	for s in _city.stops:
		var d := s.global_position.distance_to(_taxi.global_position)
		if not s.occupied and d > 10.0 and d < best_d:
			best_d = d
			best = s
	var p := _spawner.spawn_at(profile, best)
	_teleport(best.global_position, p.global_position)
	if not await _until(func() -> bool: return _rides.state == RideManager.State.RIDING, 6.0):
		_errors.append("F: the old lady never got in")
		return
	var card_text := " ".join((_cards.back() as Dictionary)["lines"]) if not _cards.is_empty() else ""
	if not card_text.contains("little something"):
		_errors.append("F: her card does not mention the gift: %s" % card_text)
	_director.clear_all()
	_gangs.threats.clear()
	_payout = -1
	_teleport(_rides.ride.destination.global_position, Vector3.ZERO)
	if not await _until(func() -> bool: return _payout >= 0, 4.0):
		_errors.append("F: the old lady was not delivered")
		return
	print("[GangTest] F old lady delivered, payout $%d, rewards %s" % [_payout, _rewards])
	if _rewards.is_empty():
		_errors.append("F: the old lady gave no gift")
	# An ordinary fare on an EASY ride never draws a crew.
	for i in 50:
		if not _gangs.plan_threats(profile, GangRides.Difficulty.EASY).is_empty():
			_errors.append("F: a crew came for an ordinary EASY fare")
			break


# --- G ----------------------------------------------------------------------------------

func _test_difficulty() -> void:
	var counts := [0, 0, 0, 0]
	for i in 2000:
		counts[_gangs.roll_difficulty()] += 1
	print("[GangTest] G 2000 rolls: EASY %d, NORMAL %d, HARD %d, DEADLY %d" % counts)
	for i in counts.size():
		if counts[i] == 0:
			_errors.append("G: %s never rolled" % GangRides.DIFFICULTY[i]["name"])


# --- helpers ----------------------------------------------------------------------------

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
	print("[GangTest] screenshot ", file)


func _finish() -> void:
	if _done:
		return
	_done = true
	set_physics_process(false)
	get_tree().paused = false
	if _errors.is_empty():
		print("[GangTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[GangTest] FAIL: ", e)
		get_tree().quit(1)
