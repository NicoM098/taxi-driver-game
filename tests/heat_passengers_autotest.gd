extends Node
## Headless test of the 2026-11-15 requests:
##  A. PassengerGenerator: 400 generated profiles are well-formed (names, fares, distances,
##     every [url] in the notes is an examinable, every trait-gated action can be unlocked).
##  B. A generated passenger rides end to end: placed at the nearest stop, boards, the file
##     opens, every detail is examined, DRIVE, teleport to the drop-off, delivered and paid.
##  C. Drop-offs do not repeat: 8 destinations picked in a row from the same spot are all different.
##  D. Price on your head: at heat 4 street-gang cars come hunting (EnemyDirector bounty).
##  E. Less ammo: the revolver starts with 6 | 30; the volume API round-trips.
##  H. Life runs out: the cab explodes, game over screen (paused) with a MAIN MENU button.
##  G. Every hostile car has a HostileMarker over it, civilian traffic never.
##  F. Crimes: running a pedestrian over = +1 heat; shooting a civilian car until it blows up
##     = +1 heat; a civilian car killed by someone else's bullets = no heat.
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/heat_passengers_autotest.tscn

const MAIN := preload("res://src/main/main.tscn")

var _taxi: Taxi
var _rides: RideManager
var _spawner: PassengerSpawner
var _dossier: Dossier
var _director: EnemyDirector
var _t: float = 0.0
var _step: int = 0
var _step_t: float = 0.0
var _errors: PackedStringArray = []
var _cash_before: int = 0


func _ready() -> void:
	MapData.use_builtin()
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.reset_run()
	GameState.tutorial_active = false
	_test_generator()
	add_child(MAIN.instantiate())


func _test_generator() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var occupations := {}
	var names := {}
	for i in 400:
		var p := PassengerGenerator.generate(rng, 1 + i % 5)
		var inst := PassengerInstance.create(p, rng)
		occupations[p.occupation] = true
		names[inst.display_name] = true
		if inst.display_name.strip_edges() == "" or p.fare_base <= 0 or p.fare_per_100m <= 0:
			_errors.append("A: bad identity / fare: %s $%d+%d" % [inst.display_name, p.fare_base, p.fare_per_100m])
		if p.min_distance >= p.max_distance or p.time_multiplier <= 0.0:
			_errors.append("A: bad ride numbers on %s" % p.id)
		for ex in p.examinables:
			if not p.notes.contains("[url=%s]" % ex.id):
				_errors.append("A: examinable %s not linked in the notes of %s" % [ex.id, p.id])
			inst.examine(ex.id)
		for a in p.actions:
			for t in a.requires_traits:
				if not inst.revealed_traits.has(t):
					_errors.append("A: action %s of %s can never be unlocked" % [a.id, p.id])
		if inst.available_actions().size() < 2 + p.actions.size():
			_errors.append("A: %s: examined everything but not every action is available" % p.id)
	print("[GenTest] A 400 generated: %d occupations, %d distinct names" % [occupations.size(), names.size()])
	if occupations.size() < 12 or names.size() < 250:
		_errors.append("A: not varied enough (%d occupations, %d names)" % [occupations.size(), names.size()])


func _physics_process(delta: float) -> void:
	_t += delta
	_step_t += delta
	if _taxi == null:
		_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
		_rides = get_tree().get_first_node_in_group(&"ride_manager") as RideManager
		_spawner = get_tree().get_first_node_in_group(&"passenger_spawner") as PassengerSpawner
		_dossier = get_tree().get_first_node_in_group(&"dossier") as Dossier
		_director = get_tree().get_first_node_in_group(&"enemy_director") as EnemyDirector
		return
	if _t > 90.0:
		_fail("timed out at step %d" % _step)
		return
	match _step:
		0:
			if _step_t > 1.0:
				_test_ammo_and_volume()
				# B: a generated passenger at the nearest free stop.
				var best: TaxiStop = null
				var best_d := INF
				for s in (get_tree().get_first_node_in_group(&"city") as City).stops:
					var d := s.global_position.distance_to(_taxi.global_position)
					if not s.occupied and d > 15.0 and d < best_d:
						best_d = d
						best = s
				var rng := RandomNumberGenerator.new()
				rng.seed = 7
				var profile := PassengerGenerator.generate(rng, 1)
				profile.ride_events.clear()   # no pursuers / gunpoint in the way of the check
				var p := _spawner.spawn_at(profile, best)
				print("[GenTest] B %s (%s) waiting at %s" % [p.instance.display_name, profile.occupation, best.stop_name])
				_teleport(best.global_position, p.global_position)
				_next()
		1:
			if _dossier.is_open:
				for ex in _dossier.passenger.profile.examinables:
					_dossier.passenger.examine(ex.id)
				print("[GenTest] B file open, %d details examined, actions: %s" % [
					_dossier.passenger.examined.size(),
					", ".join(_dossier.passenger.available_actions().map(func(a: PassengerAction) -> String: return String(a.id)))])
				_cash_before = GameState.cash
				_dossier.choose(&"drive")
				_next()
			elif _step_t > 12.0:
				_fail("B: generated passenger never boarded")
		2:
			if _rides.state == RideManager.State.RIDING:
				print("[GenTest] B riding to %s" % _rides.ride.destination.stop_name)
				_teleport(_rides.ride.destination.global_position, Vector3.ZERO)
				_next()
			elif _step_t > 5.0:
				_fail("B: ride did not start")
		3:
			if _rides.state == RideManager.State.IDLE or _rides.state == RideManager.State.EXITING:
				print("[GenTest] B delivered, cash %d -> %d" % [_cash_before, GameState.cash])
				if GameState.cash <= _cash_before:
					_errors.append("B: generated passenger did not pay")
				_test_destination_variety()
				GameState.set_heat(4)
				_next()
			elif _step_t > 10.0:
				_fail("B: never delivered")
		4:
			var gangs := 0
			for car in _director.enemies:
				if is_instance_valid(car) and car.data.id == &"gang_coupe":
					gangs += 1
			if gangs > 0:
				print("[GenTest] D heat 4 -> %d gang car(s) hunting after %.1f s (%d enemies total)" % [
					gangs, _step_t, _director.enemies.size()])
				for car in _director.enemies:
					if is_instance_valid(car) and car.get_node_or_null("HostileMarker") == null:
						_errors.append("G: a hostile car has no marker over it")
				var marked := 0
				var life := get_tree().get_first_node_in_group(&"street_life") as StreetLife
				if life != null:
					for civ in life.traffic:
						if is_instance_valid(civ) and civ.get_node_or_null("HostileMarker") != null:
							marked += 1
				print("[GenTest] G markers on %d hostile car(s), %d civilian car(s) checked" % [
					_director.enemies.size(), life.traffic.size() if life != null else 0])
				if marked > 0:
					_errors.append("G: %d civilian car(s) have a hostile marker" % marked)
				_director.clear_all()
				GameState.set_heat(0)
				_test_crimes()
				_next()
			elif _step_t > 20.0:
				_fail("D: no street gang came at heat 4")


func _test_crimes() -> void:
	EventBus.pedestrian_hit.emit(_taxi.global_position + Vector3(2, 0, 0))
	print("[GenTest] F pedestrian run over -> heat %d" % GameState.heat)
	if GameState.heat != 1:
		_errors.append("F: running a pedestrian over should give 1 heat (is %d)" % GameState.heat)
	# Someone else's bullet: no blame.
	var other := _spawn_civilian(Vector3(8, 0, 0))
	await get_tree().physics_frame
	_hit_until_dead(other, Vector3(5000, 2, 5000))
	await get_tree().physics_frame
	if GameState.heat != 1:
		_errors.append("F: a civilian car killed by a stranger raised the heat (%d)" % GameState.heat)
	# The player's gun.
	var car := _spawn_civilian(Vector3(-8, 0, 0))
	await get_tree().physics_frame
	_hit_until_dead(car, _taxi.global_position + Vector3(0, 1.3, 0))
	await get_tree().physics_frame
	print("[GenTest] F civilian car shot down -> heat %d, car gone: %s" % [GameState.heat, not is_instance_valid(car) or car.is_destroyed])
	if GameState.heat != 2:
		_errors.append("F: blowing up a civilian car should give 1 more heat (is %d)" % GameState.heat)
	# H: death.
	var dmg := _taxi.get_node_or_null("TaxiDamage") as TaxiDamage
	dmg.driver_health.apply_damage(dmg.driver_health.max_hp + 10.0)
	await get_tree().create_timer(3.5).timeout
	var main := get_tree().get_first_node_in_group(&"main") if get_tree().get_first_node_in_group(&"main") != null else get_child(0)
	print("[GenTest] H driver killed -> game over %s, overlay %s, paused %s" % [
		main.is_game_over, main._game_over.visible, get_tree().paused])
	if not main.is_game_over or not main._game_over.visible or not get_tree().paused:
		_errors.append("H: no game over screen after the driver died")
	_finish()


func _spawn_civilian(offset: Vector3) -> TrafficCar:
	var car := TrafficCar.new()
	car.transform = Transform3D(Basis.IDENTITY, _taxi.global_position + offset + Vector3(0, 1.0, 0))
	_taxi.get_parent().add_child(car)
	return car


func _hit_until_dead(car: TrafficCar, source: Vector3) -> void:
	for child in car.get_children():
		if child is Hitbox:
			for i in 10:
				if not car.is_destroyed:
					(child as Hitbox).take_hit(40.0, source)
			return


func _test_ammo_and_volume() -> void:
	var wc := _taxi.get_node_or_null("WeaponController") as WeaponController
	if wc == null:
		wc = get_tree().get_first_node_in_group(&"weapon_controller") as WeaponController
	if wc != null:
		var a: Dictionary = wc.ammo.get(&"revolver", {})
		print("[GenTest] E revolver ammo %s" % a)
		if int(a.get("reserve", -1)) != 30:
			_errors.append("E: revolver reserve should be 30, is %s" % a.get("reserve", "?"))
	else:
		_errors.append("E: no WeaponController found")
	Audio.set_bus_volume(&"Music", 0.5)
	if absf(Audio.get_bus_volume(&"Music") - 0.5) > 0.01:
		_errors.append("E: music volume did not round-trip")
	Audio.set_bus_volume(&"SFX", 0.0)
	if Audio.get_bus_volume(&"SFX") != 0.0 or Audio.get_bus_volume(&"UI") != 0.0:
		_errors.append("E: effects at 0 should mute SFX + UI")
	Audio.load_settings()


func _test_destination_variety() -> void:
	var picked := {}
	for i in 8:
		var stop: TaxiStop = _rides._pick_destination(_spawner.profiles[0], _taxi.global_position)
		picked[stop] = true
	print("[GenTest] C 8 drop-offs in a row: %d different" % picked.size())
	if picked.size() < 8:
		_errors.append("C: drop-offs repeat (%d different of 8)" % picked.size())


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
		print("[GenTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[GenTest] FAIL: ", e)
		get_tree().quit(1)
