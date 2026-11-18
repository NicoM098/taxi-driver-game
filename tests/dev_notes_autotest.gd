extends Node
## Headless Iteration 23 test through Main: the user's dev notes (D-098 to D-103).
##  A. One health bar (D-098): the driver and the taxi share one HealthComponent of 1.3x the old
##     taxi health; a shot through the cabin takes it off that one bar.
##  B. Mines (D-099): their own tracks (capacity, damage, blast, drop rate), no Mag / Ammo; one
##     pool, never reload; Capacity adds mines carried, Blast the radius; an ammo box puts mines
##     straight into the pool.
##  C. Perks (D-100): a PERKS tab; Double Tap raises every gun's fire rate, Quick Hands cuts the
##     reload time; Rolling Pickup boards a fare at speed through the ring at the stop (without
##     it, nobody gets in at that speed).
##  D. Shooting backwards (D-101): holding look_behind turns the head out the back and raises
##     the gun.
##  E. Boss markers (D-102): a boss gets the BOSS tag and the beam, an ordinary enemy does not.
##  F. Street life (D-103): what is in front of the camera counts as in view (no spawning or
##     recycling there), behind it and past the far plane does not.
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/dev_notes_autotest.tscn

const MAIN := preload("res://src/main/main.tscn")
const TIMEOUT := 90.0

var _taxi: Taxi
var _damage: TaxiDamage
var _wc: WeaponController
var _menu: ShopMenu
var _rides: RideManager
var _shift: ShiftManager
var _spawner: PassengerSpawner
var _city: City
var _t: float = 0.0
var _errors: PackedStringArray = []
var _done: bool = false


func _ready() -> void:
	ShopMenu.enabled = true
	GangRides.enabled = true
	MapData.use_builtin()   # never the user's edited map
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.reset_run()
	add_child(MAIN.instantiate())
	_run()


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT and not _done:
		_errors.append("timeout")
		_finish()


func _check(ok: bool, what: String) -> void:
	print("[DevNotesTest] %s %s" % ["OK  " if ok else "FAIL", what])
	if not ok:
		_errors.append(what)


func _run() -> void:
	await _until(func() -> bool: return get_tree().get_first_node_in_group(&"player_vehicle") != null, 5.0)
	_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
	_damage = _taxi.get_node("TaxiDamage") as TaxiDamage
	_wc = get_tree().get_first_node_in_group(&"weapon_controller") as WeaponController
	_menu = get_tree().get_first_node_in_group(&"shop_menu") as ShopMenu
	_rides = get_tree().get_first_node_in_group(&"ride_manager") as RideManager
	_shift = get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
	_spawner = get_tree().get_first_node_in_group(&"passenger_spawner") as PassengerSpawner
	_city = get_tree().get_first_node_in_group(&"city") as City
	await _until(func() -> bool: return _shift.is_active, 5.0)
	GameState.tutorial_active = false
	var tutorial := get_tree().get_first_node_in_group(&"tutorial") as Tutorial
	if tutorial != null:
		tutorial.skip()
	await _wait(0.5)

	_test_health()
	_damage.taxi_health.max_hp = 100000.0   # nothing below may end the run
	_damage.taxi_health.revive()
	_test_mines()
	await _test_perks()
	await _test_look_back()
	await _test_boss_marker()
	_test_street_life()
	_finish()


# --- A ----------------------------------------------------------------------------------

func _test_health() -> void:
	_check(not _damage.has_driver_bar() and _damage.driver_health == _damage.taxi_health,
			"A: the driver and the taxi share one bar")
	var want := PlayerStats.get_stat(&"taxi_max_hp") * TaxiDamage.SINGLE_BAR_HP_MULT
	_check(is_equal_approx(_damage.taxi_health.max_hp, want), "A: one bar of %.0f hp (%.0f)" % [want, _damage.taxi_health.max_hp])
	var cabin := _damage.get_node("CabinHitbox") as Hitbox
	var before := _damage.taxi_health.hp
	cabin.take_hit(20.0)
	var lost := before - _damage.taxi_health.hp
	_check(is_equal_approx(lost, 20.0 * _damage.driver_damage_mult), "A: a cabin shot takes %.1f off the one bar" % lost)


# --- B ----------------------------------------------------------------------------------

func _test_mines() -> void:
	GameState.cash = 0
	_wc.add_weapon(&"mines")
	var w := _wc.get_weapon(&"mines")
	if w == null:
		_check(false, "B: could not give the mines")
		return
	var base := WeaponController._base(&"mines")
	_check(WeaponUpgrades.tracks_for(base) == WeaponUpgrades.MINE_TRACKS, "B: mines upgrade on %s" % [WeaponUpgrades.tracks_for(base)])
	_check(not w.reloads() and int(_wc.ammo[&"mines"]["mag"]) == w.mag_size and int(_wc.ammo[&"mines"]["reserve"]) == 0,
			"B: one pool of %d mines, no reserve" % w.mag_size)
	_check(not _wc.upgrade(&"mines", &"mag") and not _wc.upgrade(&"mines", &"reserve"), "B: no Mag / Ammo tracks on the mines")
	_wc.ammo[&"mines"]["mag"] = 5
	_check(_wc.upgrade(&"mines", &"capacity"), "B: Capacity bought")
	w = _wc.get_weapon(&"mines")
	_check(w.mag_size == base.mag_size + 2 and int(_wc.ammo[&"mines"]["mag"]) == 7,
			"B: Capacity 1: carries %d (5 carried -> %d)" % [w.mag_size, int(_wc.ammo[&"mines"]["mag"])])
	_check(_wc.upgrade(&"mines", &"blast") and is_equal_approx(_wc.get_weapon(&"mines").blast_radius, base.blast_radius * 1.15),
			"B: Blast 1: radius %.2f m" % _wc.get_weapon(&"mines").blast_radius)
	_check(WeaponUpgrades.track_name(base, &"rate") == "Drop rate", "B: the fire-rate track is called Drop rate")
	_wc.ammo[&"mines"]["mag"] = 0
	_wc._start_reload(_wc.get_weapon(&"mines"))
	_check(not _wc.is_reloading, "B: an empty mine pool does not reload")
	var box := AmmoPickup.new()
	box.weapon_id = &"mines"
	add_child(box)
	box.global_position = Vector3(0, -300, 0)
	var amount := AmmoPickup.amount_for(_wc.get_weapon(&"mines"))
	_check(box.collect(_wc) and int(_wc.ammo[&"mines"]["mag"]) == amount, "B: an ammo box drops %d mines straight in" % amount)
	_check(WeaponData.ammo_text(_wc.get_weapon(&"mines"), _wc.ammo[&"mines"]) == str(amount), "B: the hotbar shows just the count")


# --- C ----------------------------------------------------------------------------------

func _test_perks() -> void:
	_check(ShopMenu.active_tabs().has(&"perks"), "C: the shop has a perks (SLOTS) tab")
	var perks := 0
	for u in CarUpgrades.catalogue():
		if ShopMenu.tab_of(u) == &"perks":
			perks += 1
	_check(perks == 7, "C: seven perks on it (%d, D-107)" % perks)
	var revolver := WeaponController._base(&"revolver")
	GameState.cash = 100000
	_menu.open()
	_check(not _menu.activate(&"perk_double_tap"), "C: perks are not for sale any more (D-106: slot machine)")
	_menu.close()
	var bought_tap := CarUpgrades.grant_level(get_tree(), &"perk_double_tap")
	var bought_hands := CarUpgrades.grant_level(get_tree(), &"perk_fast_reload")
	var r := _wc.get_weapon(&"revolver")
	_check(bought_tap and is_equal_approx(r.fire_rate, revolver.fire_rate * 1.5),
			"C: Double Tap: revolver %.2f -> %.2f shots/s" % [revolver.fire_rate, r.fire_rate])
	_check(bought_hands and is_equal_approx(r.reload_time, revolver.reload_time * 0.5),
			"C: Quick Hands: reload %.2f -> %.2f s" % [revolver.reload_time, r.reload_time])

	# Rolling pickup: a fare at a free stop, the taxi through the ring at 12 m/s.
	var stop: TaxiStop = null
	for s in _city.stops:
		if not s.occupied:
			stop = s
			break
	if stop == null:
		_check(false, "C: no free stop")
		return
	var p := _spawner.spawn_at(_spawner.tutorial_profile(), stop)
	_check(not await _drive_through(p), "C: without the perk nobody gets in at 12 m/s")
	var bought_roll := CarUpgrades.grant_level(get_tree(), &"perk_rolling_pickup")
	await _wait(0.6)   # the ring shows up on its next check
	_check(bought_roll and p._rolling_ring != null and p._rolling_ring.visible, "C: Rolling Pickup bought, the ring is on the road")
	_check(await _drive_through(p), "C: with it the fare boards at speed")


## Drives the taxi along the street through the fare's stop at 12 m/s (from 30 m before it to
## 30 m past it); true if the passenger boarded. Afterwards the taxi goes back where it was,
## so it does not roll to a stop next to the fare.
func _drive_through(p: WaitingPassenger) -> bool:
	var home := _taxi.global_transform
	var point := p.pickup_point()
	var dir := Vector3.FORWARD
	for d: Vector3 in MapData.DIRS:   # the way the street runs through the stop
		if _city.is_plain_street(point - d * MapData.CELL) and _city.is_plain_street(point + d * MapData.CELL):
			dir = d
			break
	_taxi.teleport(Transform3D(Basis.looking_at(dir, Vector3.UP), point - dir * 20.0 + Vector3(0, 1.0, 0)))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var boarded := false
	var closest := INF
	for i in 200:   # 40 m at 12 m/s = 3.3 s
		_taxi.linear_velocity = dir * 12.0
		await get_tree().physics_frame
		closest = minf(closest, Vector2(_taxi.global_position.x - point.x, _taxi.global_position.z - point.z).length())
		if _rides.state != RideManager.State.IDLE:
			boarded = true
			break
	print("[DevNotesTest]   drove past the stop: closest %.1f m, %s, state %d, shift %s, waiting %s" % [
			closest, "boarded" if boarded else "not boarded", _rides.state, _shift.is_active, is_instance_valid(p)])
	_taxi.teleport(home)
	await get_tree().physics_frame
	return boarded


# --- D ----------------------------------------------------------------------------------

func _test_look_back() -> void:
	var cam := _taxi.get_node("HeadPivot/Camera3D") as Camera3D
	Input.action_press(&"look_behind")
	await _wait(0.6)
	var dot := (-cam.global_basis.z).dot(-_taxi.global_basis.z)
	var cab := cam.get_parent() as CabCamera
	_check(cab.is_looking_back() and dot < -0.7, "D: holding look_behind turns the head out the back (dot %.2f)" % dot)
	_check(_wc.raise_amount > 0.8, "D: ...and raises the gun (%.2f)" % _wc.raise_amount)
	Input.action_release(&"look_behind")
	await _wait(0.6)
	dot = (-cam.global_basis.z).dot(-_taxi.global_basis.z)
	_check(dot > 0.7, "D: letting go faces forward again (dot %.2f)" % dot)


# --- E ----------------------------------------------------------------------------------

func _test_boss_marker() -> void:
	var boss := EnemyCar.new()
	boss.data = load("res://data/enemies/boss_kingpin.tres") as EnemyCarData
	var grunt := EnemyCar.new()
	grunt.data = load("res://data/enemies/gang_red.tres") as EnemyCarData
	var world := _taxi.get_parent()
	world.add_child(boss)
	world.add_child(grunt)
	boss.global_position = Vector3(0, -200, 0)
	grunt.global_position = Vector3(20, -200, 0)
	await get_tree().process_frame
	var bm := boss.get_node("HostileMarker") as HostileMarker
	var gm := grunt.get_node("HostileMarker") as HostileMarker
	_check(bm.boss and bm._tag != null and bm._beam != null and bm._tag.text.begins_with("BOSS"),
			"E: the boss has a gold BOSS tag and a beam (%s)" % (bm._tag.text.replace("\n", " ") if bm._tag != null else "none"))
	_check(not gm.boss and gm._tag == null and gm._beam == null, "E: an ordinary enemy keeps the plain red cone")
	boss.queue_free()
	grunt.queue_free()


# --- F ----------------------------------------------------------------------------------

func _test_street_life() -> void:
	var life := get_tree().get_first_node_in_group(&"street_life") as StreetLife
	var cam := life.get_viewport().get_camera_3d() if life != null else null   # the game draws in a SubViewport
	if life == null or cam == null:
		_check(false, "F: no street life (%s) / camera (%s)" % [life, cam])
		return
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var ground := Vector3(cam.global_position.x, _taxi.global_position.y - 0.5, cam.global_position.z)
	_check(life.in_view(ground + fwd * 60.0), "F: 60 m ahead is in view")
	_check(life.in_view(ground + fwd * 160.0), "F: 160 m ahead is in view too (was a spawn spot)")
	_check(not life.in_view(ground - fwd * 60.0), "F: 60 m behind is not")
	_check(not life.in_view(ground + fwd * 400.0), "F: past the far plane is not")


# --- Helpers ----------------------------------------------------------------------------

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


func _finish() -> void:
	if _done:
		return
	_done = true
	set_physics_process(false)
	get_tree().paused = false
	Input.action_release(&"look_behind")
	if _errors.is_empty():
		print("[DevNotesTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[DevNotesTest] FAIL: ", e)
		get_tree().quit(1)
