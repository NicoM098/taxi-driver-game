extends Node
## The heavy weapons (D-086), headless on the test course, with real shots:
##  A. the catalogue: 9 guns (The Devastator, D-107), slots 1-9 unique, the new ones expensive and unlocked late
##  B. minigun: nothing while the barrels spin up, then a stream; Mk IV fires at once
##  C. laser: continuous damage on a board while held, the beam is drawn, no spread
##  D. rocket: not instant, explodes and hurts every board around the impact; Mk IV fires two
##  E. mines: dropped behind the taxi, ignore a car before arming, blow up under it after
##  F. none of it ever hurts the player's own taxi
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/arsenal_autotest.tscn

const COURSE := preload("res://src/vehicle/test_drive.tscn")

var _taxi: Taxi
var _wc: WeaponController
var _cam: Camera3D
var _errors: PackedStringArray = []


func _ready() -> void:
	MapData.use_builtin()
	GameState.reset_run()
	GameState.owned_weapons = [&"mines", &"minigun", &"rocket", &"laser"]   # a full loadout of four (D-087)
	var course := COURSE.instantiate()
	add_child(course)
	_taxi = course.get_node("Taxi") as Taxi
	_run()


func _check(ok: bool, what: String) -> void:
	print("[ArsenalTest] %s %s" % ["OK  " if ok else "FAIL", what])
	if not ok:
		_errors.append(what)


func _run() -> void:
	await _wait(1.0)
	_wc = get_tree().get_first_node_in_group(&"weapon_controller") as WeaponController
	_cam = _wc.get_parent() as Camera3D
	var damage := _taxi.get_node("TaxiDamage") as TaxiDamage
	var taxi_hp := damage.taxi_health.hp
	var driver_hp := damage.driver_health.hp

	# --- A. catalogue -------------------------------------------------------------------
	var cat := WeaponController.catalogue()
	var slots := {}
	for w in cat:
		slots[w.slot] = true
	_check(cat.size() == 9 and slots.size() == 9, "9 guns on 9 different slots (%d guns)" % cat.size())
	var rifle := load("res://data/weapons/rifle.tres") as WeaponData
	for id: String in ["mines", "minigun", "rocket", "laser"]:
		var w := load("res://data/weapons/%s.tres" % id) as WeaponData
		_check(w.price >= 1500 and w.unlock_rides >= 12 and w.price > rifle.price,
				"%s: $%d after %d fares" % [w.display_name, w.price, w.unlock_rides])

	# --- B. minigun ---------------------------------------------------------------------
	_wc.select(_wc.index_of_slot(6))
	await _wait(0.5)
	Input.action_press(&"aim")
	await _wait(0.6)
	var before := _wc.shots_fired
	Input.action_press(&"fire")
	await _wait(0.3)
	var during_spin := _wc.shots_fired - before
	await _wait(1.2)
	var stream := _wc.shots_fired - before
	Input.action_release(&"fire")
	_check(during_spin == 0 and stream >= 12, "minigun: %d shots while spinning up, %d after 1.5 s" % [during_spin, stream])
	GameState.weapon_levels[&"minigun"] = {&"damage": WeaponUpgrades.SPECIAL_AT - 1}
	_wc.upgrade(&"minigun", &"rate")
	await _wait(1.0)
	before = _wc.shots_fired
	Input.action_press(&"fire")
	await _wait(0.15)
	Input.action_release(&"fire")
	_check(_wc.shots_fired - before >= 1, "minigun Mk IV fires without spinning up (%d shots in 0.15 s)" % (_wc.shots_fired - before))
	Input.action_release(&"aim")

	# --- C. laser ------------------------------------------------------------------------
	var boards := _boards([Vector3(0, 0, 15)])
	_wc.select(_wc.index_of_slot(8))
	await _wait(0.5)
	Input.action_press(&"aim")
	await _wait(0.6)
	_check(_wc.current_spread_deg < 0.01, "laser has no spread (%.3f deg)" % _wc.current_spread_deg)
	Input.action_press(&"fire")
	await _wait(0.5)
	var beam_on := false
	for c in _wc.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).top_level and (c as MeshInstance3D).visible:
			beam_on = true
	await _wait(0.5)
	Input.action_release(&"fire")
	var burnt := boards[0].max_hp - boards[0].health.hp
	_check(beam_on, "the beam is drawn while firing")
	_check(burnt > 100.0, "laser held 1 s deals %.0f damage" % burnt)
	Input.action_release(&"aim")
	_clear(boards)

	# --- D. rocket -----------------------------------------------------------------------
	# Part of every shot's recoil stays in the aim (CabCamera.recoil_permanent): after the
	# minigun burst the view points ~2 deg up and the rocket can sail over the boards. Level it.
	var cab: Node = _cam
	while cab != null and not cab is CabCamera:
		cab = cab.get_parent()
	if cab != null:
		cab.set(&"_pitch", 0.0)
		cab.set(&"_yaw", 0.0)
	# A cluster 22 m ahead: one in the line of fire, two beside it.
	boards = _boards([Vector3(0, 0, 22), Vector3(2.5, 0, 22.5), Vector3(-2.5, 0, 22.5)])
	_wc.select(_wc.index_of_slot(7))
	await _wait(0.5)
	Input.action_press(&"aim")
	await _wait(0.6)
	Input.action_press(&"fire")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"fire")
	var flying := get_tree().get_nodes_in_group(&"rockets").size()
	var hurt_now := _hurt(boards)
	await _wait(1.5)
	_check(flying == 1 and hurt_now == 0, "a rocket is in the air, nothing hurt yet (%d rockets, %d hurt)" % [flying, hurt_now])
	_check(_hurt(boards) == 3, "the explosion hurt all %d boards of the cluster (%d)" % [boards.size(), _hurt(boards)])
	_clear(boards)
	GameState.weapon_levels[&"rocket"] = {&"damage": WeaponUpgrades.SPECIAL_AT - 1}
	_wc.upgrade(&"rocket", &"rate")
	_wc.ammo[&"rocket"]["mag"] = 1   # upgrades no longer reload (D-094): load the tube by hand
	await _wait(0.4)
	Input.action_press(&"fire")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"fire")
	_check(get_tree().get_nodes_in_group(&"rockets").size() == 2, "rocket Mk IV fires two rockets")
	Input.action_release(&"aim")
	await _wait(2.0)

	# --- E. mines -------------------------------------------------------------------------
	_wc.select(_wc.index_of_slot(5))
	await _wait(0.5)
	Input.action_press(&"aim")
	await _wait(0.6)
	Input.action_press(&"fire")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"fire")
	Input.action_release(&"aim")
	var mines := get_tree().get_nodes_in_group(&"mines")
	_check(mines.size() == 1, "one mine dropped (%d)" % mines.size())
	if mines.size() == 1:
		var mine := mines[0] as Mine
		var behind := (mine.global_position - _taxi.global_position).dot(_taxi.global_basis.z)
		_check(behind > 1.5, "the mine lies behind the taxi (%.1f m)" % behind)
		# A car parked on it straight away: the mine is still arming.
		var car := _dummy_car(mine.global_position + Vector3(0, 0.8, 0))
		await _wait(0.4)
		_check(is_instance_valid(mine) and car.health.hp >= car.health.max_hp,
				"an arming mine ignores the car on it")
		await _wait(1.0)
		_check(not is_instance_valid(mine) and car.health.hp < car.health.max_hp - 50.0,
				"once armed it blows up under the car (hp %.0f / %.0f)" % [car.health.hp, car.health.max_hp])

	# --- F. own taxi untouched ------------------------------------------------------------
	_check(damage.taxi_health.hp >= taxi_hp - 0.5 and damage.driver_health.hp >= driver_hp - 0.5,
			"the taxi took no damage from its own explosions (taxi %.0f -> %.0f, driver %.0f -> %.0f)" % [
			taxi_hp, damage.taxi_health.hp, driver_hp, damage.driver_health.hp])

	if _errors.is_empty():
		print("[ArsenalTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[ArsenalTest] FAIL: ", e)
		get_tree().quit(1)


## Boards relative to the camera: x = metres to the right, z = metres ahead, at eye height.
func _boards(offsets: Array) -> Array[ShootingTarget]:
	var ahead := -_cam.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var right := ahead.cross(Vector3.UP)
	var out: Array[ShootingTarget] = []
	for o: Vector3 in offsets:
		var b := ShootingTarget.new()
		b.board_height = 1.6
		b.max_hp = 1000.0
		add_child(b)
		var at := _cam.global_position + ahead * o.z + right * o.x
		b.global_position = Vector3(at.x, _cam.global_position.y - 1.6, at.z)
		b.look_at(Vector3(_cam.global_position.x, b.global_position.y, _cam.global_position.z), Vector3.UP)
		out.append(b)
	return out


## A frozen box on the traffic layer with health and a hitbox: what a mine reacts to.
func _dummy_car(at: Vector3) -> ShootingTarget:
	var holder := ShootingTarget.new()
	holder.max_hp = 400.0
	add_child(holder)
	holder.global_position = at + Vector3(0, -0.8, 0)
	var body := StaticBody3D.new()
	body.collision_layer = 1 << 3
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 1.2, 4.0)
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = at
	return holder


func _hurt(boards: Array[ShootingTarget]) -> int:
	var n := 0
	for b in boards:
		if b.health.hp < b.max_hp - 0.5:
			n += 1
	return n


func _clear(boards: Array[ShootingTarget]) -> void:
	for b in boards:
		b.queue_free()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout
