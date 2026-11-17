class_name WeaponController
extends Node3D
## First-person shooting from the cab (Half Grip-inspired, arcade controls).
## Child of the cab Camera3D. Hold AIM (RMB / LB) to raise the gun (zoom, tight spread);
## FIRE (LMB / RB) also raises it (hip fire, wider spread). Hitscan rays from the screen
## centre; spread grows with taxi speed, turning and sustained fire. Driving is never blocked.
## Weapons = WeaponData resources for every id in GameState.owned_weapons, kept in slot order
## Gun shops add weapons / upgrade / equip at runtime; ammo comes from enemy drops (AmmoPickup, D-094).
## Loadout (D-087): every gun bought is OWNED (`_arsenal`, ammo kept), but only up to
## LOADOUT_SIZE are EQUIPPED (`weapons`, GameState.loadout) on keys 1-4, in catalogue order.
## The rest wait at the gun shop. All of them are the UPGRADED copies (WeaponUpgrades.apply, D-085, D-093).

signal weapon_changed(weapon: WeaponData)

const WEAPON_DIR := "res://data/weapons/"
const LOADOUT_SIZE := 4
## world | enemy_vehicles | traffic | characters | hitboxes | props
const HIT_MASK := (1 << 0) | (1 << 2) | (1 << 3) | (1 << 4) | (1 << 5) | (1 << 8)

@export var taxi: Taxi
@export var raise_speed: float = 7.0           # raise amount per second (0..1)
@export var hip_linger: float = 0.8            # seconds the gun stays up after hip fire
@export var fire_buffer: float = 0.3           # semi-auto press remembered while raising
@export var switch_time: float = 0.3
@export var bloom_decay: float = 4.0           # degrees per second
@export var lowered_offset: Vector3 = Vector3(0.24, -0.55, -0.3)
@export var raised_offset: Vector3 = Vector3(0.15, -0.16, -0.42)

var weapons: Array[WeaponData] = []          # equipped, in key order
var _arsenal: Dictionary = {}                 # id -> WeaponData, every owned gun
var current_index: int = 0
var ammo: Dictionary = {}          # id -> {"mag": int, "reserve": int}
var raise_amount: float = 0.0      # 0 = lowered .. 1 = raised
var is_aiming: bool = false
var is_reloading: bool = false
var current_spread_deg: float = 0.0
var shots_fired: int = 0           # total, for tests/stats
## 0..1 while the minigun's barrels spin up (WeaponData.spin_up); fires only at 1.
var spin: float = 0.0

var _camera: Camera3D
var _cab: CabCamera
var _viewmodel: Node3D
var _gun: MeshInstance3D
var _gun_mat: ShaderMaterial
var _muzzle: Node3D
var _flash: Node3D
var _flash_light: OmniLight3D
var _flash_time: float = 0.0
var _cooldown: float = 0.0
var _reload_left: float = 0.0
var _switch_left: float = 0.0
var _linger: float = 0.0
var _buffer: float = 0.0
var _bloom: float = 0.0
var _kick: float = 0.0
var _rng := RandomNumberGenerator.new()
var _beam: MeshInstance3D           # the laser's beam, in world space (top_level)
var _beam_time: float = 0.0


func _ready() -> void:
	add_to_group(&"weapon_controller")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_rng.randomize()
	_camera = get_parent() as Camera3D
	_cab = _camera.get_parent() as CabCamera if _camera != null else null
	if taxi == null and _cab != null:
		taxi = _cab.vehicle
	for id: StringName in GameState.owned_weapons:
		_add(id)
	_build_viewmodel()
	# Fill free loadout places with owned guns (a fresh run: just the revolver).
	var loadout: Array[StringName] = []
	for id in GameState.loadout:
		if owns(id) and not loadout.has(id) and loadout.size() < LOADOUT_SIZE:
			loadout.append(id)
	for w in catalogue():
		if owns(w.id) and not loadout.has(w.id) and loadout.size() < LOADOUT_SIZE:
			loadout.append(w.id)
	GameState.loadout = loadout
	_rebuild_weapons()


## Every weapon that exists (res://data/weapons/), in slot order — owned or not.
static func catalogue() -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for file in ResourceLoader.list_directory(WEAPON_DIR):
		var data := load(WEAPON_DIR + file) as WeaponData
		if data != null:
			out.append(data)
	out.sort_custom(func(a: WeaponData, b: WeaponData) -> bool: return a.slot < b.slot)
	return out


func owns(id: StringName) -> bool:
	return _arsenal.has(id)


func is_equipped(id: StringName) -> bool:
	return GameState.loadout.has(id)


func loadout_full() -> bool:
	return GameState.loadout.size() >= LOADOUT_SIZE


## Gives the player a weapon (full mag + reserve) and records it in GameState; it goes straight
## into the loadout if there is room, else it waits at the gun shop. Returns false if it was
## already owned / does not exist.
func add_weapon(id: StringName) -> bool:
	if owns(id) or not _add(id):
		return false
	if not GameState.owned_weapons.has(id):
		GameState.owned_weapons.append(id)
	if not loadout_full():
		equip(id)
	return true


## Puts an owned gun on the hotbar. False if not owned, already equipped or the loadout is full.
func equip(id: StringName) -> bool:
	if not owns(id) or is_equipped(id) or loadout_full():
		return false
	GameState.loadout.append(id)
	_rebuild_weapons()
	return true


## Takes a gun off the hotbar (it stays owned, with its ammo). The last one cannot go.
func unequip(id: StringName) -> bool:
	if not is_equipped(id) or GameState.loadout.size() <= 1:
		return false
	GameState.loadout.erase(id)
	_rebuild_weapons()
	return true


## `weapons` = the loadout's guns in catalogue order. Keeps the gun in hand if it is still there.
func _rebuild_weapons() -> void:
	var keep := current_weapon()
	var keep_id := keep.id if keep != null else &""
	weapons.clear()
	for id in GameState.loadout:
		if _arsenal.has(id):
			weapons.append(_arsenal[id])
	weapons.sort_custom(func(a: WeaponData, b: WeaponData) -> bool: return a.slot < b.slot)
	if weapons.is_empty() or _gun == null:
		current_index = 0
		return
	var i := maxi(index_of_weapon(keep_id), 0)
	if keep == null or weapons[i] != keep:
		_equip(i)
	else:
		current_index = i


## Position of an equipped gun on the hotbar (0-3), or -1.
func index_of_weapon(id: StringName) -> int:
	for i in weapons.size():
		if weapons[i].id == id:
			return i
	return -1


## Index of the equipped weapon whose WeaponData.slot (catalogue order) is `slot`, or -1.
func index_of_slot(slot: int) -> int:
	for i in weapons.size():
		if weapons[i].slot == slot:
			return i
	return -1


## Raises one track (WeaponUpgrades.TRACKS) of an owned weapon by a level (the shop charges
## for it). Ammo is not refilled (it comes from kills, D-094): the rounds carried stay, plus
## the spare room an Ammo level adds. False if not owned or the track is maxed.
func upgrade(id: StringName, track: StringName) -> bool:
	var old := _find(id)
	var lv := WeaponUpgrades.level(id, track)
	if old == null or not track in WeaponUpgrades.TRACKS or WeaponUpgrades.is_capped(track, lv):
		return false
	var levels: Dictionary = GameState.weapon_levels.get(id, {})
	levels[track] = lv + 1
	GameState.weapon_levels[id] = levels
	var w := WeaponUpgrades.apply(_base(id))
	_arsenal[id] = w
	var a: Dictionary = ammo[id]
	a["mag"] = mini(int(a["mag"]), w.mag_size)
	a["reserve"] = mini(int(a["reserve"]) + maxi(w.reserve_max - old.reserve_max, 0), w.reserve_max)
	var i := weapons.find(old)
	if i >= 0:
		weapons[i] = w
		if i == current_index:
			_equip(i)
	return true


func select(index: int) -> void:
	if index >= 0 and index < weapons.size() and index != current_index:
		_equip(index)


func _add(id: StringName) -> bool:
	var base := _base(id)
	if base == null:
		return false
	var data := WeaponUpgrades.apply(base)
	_arsenal[data.id] = data
	ammo[data.id] = {"mag": data.mag_size, "reserve": data.reserve_max}
	return true


static func _base(id: StringName) -> WeaponData:
	return load(WEAPON_DIR + String(id) + ".tres") as WeaponData


func _find(id: StringName) -> WeaponData:
	return _arsenal.get(id) as WeaponData


## The weapon as the player carries it (upgrades applied), or null if not owned.
func get_weapon(id: StringName) -> WeaponData:
	return _find(id)


func current_weapon() -> WeaponData:
	return weapons[current_index] if current_index < weapons.size() else null


func get_ammo(weapon: WeaponData = null) -> Dictionary:
	var w := weapon if weapon != null else current_weapon()
	return ammo.get(w.id, {"mag": 0, "reserve": 0}) if w != null else {"mag": 0, "reserve": 0}


func get_reload_progress() -> float:
	var w := current_weapon()
	return 1.0 - _reload_left / w.reload_time if is_reloading and w != null else 0.0


# --- Main loop -----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var w := current_weapon()
	if w == null or _camera == null:
		return
	_cooldown -= delta
	_bloom = maxf(_bloom - bloom_decay * delta, 0.0)
	_switch_left = maxf(_switch_left - delta, 0.0)

	var aim_held := Input.is_action_pressed(&"aim")
	var fire_held := Input.is_action_pressed(&"fire")
	if Input.is_action_just_pressed(&"fire"):
		_buffer = fire_buffer
	else:
		_buffer -= delta
	_linger = hip_linger if fire_held else _linger - delta

	var want_raise := (aim_held or _linger > 0.0) and _switch_left <= 0.0 and not is_reloading
	raise_amount = move_toward(raise_amount, 1.0 if want_raise else 0.0, raise_speed * delta)
	is_aiming = aim_held and raise_amount > 0.9

	_handle_switch_input()
	_handle_reload(delta, w)
	_update_spread(w)

	var wants_fire := fire_held if w.automatic else _buffer > 0.0
	# Minigun: holding fire with the gun up spins the barrels; it only shoots once they are at
	# speed, and they wind down when you let go (D-086).
	if w.spin_up > 0.0:
		var spinning := fire_held and raise_amount >= 0.85 and not is_reloading and _switch_left <= 0.0
		spin = clampf(spin + (delta / w.spin_up if spinning else -delta * 2.0), 0.0, 1.0)
		if spin < 1.0:
			wants_fire = false
	else:
		spin = 1.0
	if wants_fire and raise_amount >= 0.85 and _cooldown <= 0.0 and not is_reloading and _switch_left <= 0.0:
		var a: Dictionary = ammo[w.id]
		_buffer = 0.0
		if a["mag"] > 0:
			_fire(w)
		elif a["reserve"] > 0:
			_start_reload(w)
		else:
			EventBus.weapon_empty.emit(w)

	if _cab != null:
		_cab.hold_look = raise_amount > 0.5
		_cab.aim_zoom = 1.0 if is_aiming else 0.0


func _process(delta: float) -> void:
	_kick = maxf(_kick - delta * 8.0, 0.0)
	_flash_time -= delta
	_beam_time -= delta
	if _beam != null:
		_beam.visible = _beam_time > 0.0
	if _flash != null:
		_flash.visible = _flash_time > 0.0
		_flash_light.visible = _flash_time > 0.0
	if _viewmodel == null:
		return
	var t := ease(raise_amount, -1.8)  # in-out
	_viewmodel.visible = raise_amount > 0.02
	var pos := lowered_offset.lerp(raised_offset, t)
	var rot := Vector3(lerpf(-0.9, 0.0, t), lerpf(0.25, 0.0, t), 0.0)
	pos.z += 0.07 * _kick
	rot.x += 0.3 * _kick
	if is_reloading:
		var p := get_reload_progress()
		var dip := sin(p * PI)
		pos.y -= 0.12 * dip
		rot.z += 0.7 * dip
	_viewmodel.position = pos
	_viewmodel.rotation = rot


# --- Firing --------------------------------------------------------------------------

func _fire(w: WeaponData) -> void:
	ammo[w.id]["mag"] -= 1
	shots_fired += 1
	_cooldown = 1.0 / w.fire_rate
	match w.kind:
		&"rocket":
			_fire_rocket(w)
		&"mine":
			_drop_mine(w)
		_:
			_fire_hitscan(w)
	_bloom += w.spread_per_shot
	_flash_time = 0.0 if w.beam or w.kind == &"mine" else 0.05
	_kick = 0.25 if w.beam else 1.0
	if _cab != null:
		_cab.add_recoil(w.recoil_pitch, _rng.randf_range(-w.recoil_yaw, w.recoil_yaw))
	EventBus.weapon_fired.emit(w)
	if ammo[w.id]["mag"] <= 0:
		_start_reload(w)  # arcade: reload as soon as the mag runs dry


## Rocket launcher (D-086): a projectile from the muzzle along the aim, slightly spread.
## Mk IV twin tubes: two of them, side by side.
func _fire_rocket(w: WeaponData) -> void:
	var fx_parent := taxi.get_parent() if taxi != null else get_tree().current_scene
	var forward := -_camera.global_basis.z
	var right := _camera.global_basis.x
	var count := 2 if WeaponUpgrades.has_special(w, &"twin") else 1
	for i in count:
		var dir := _spread_dir(forward, current_spread_deg)
		var rocket := Rocket.new()
		rocket.velocity = dir * w.projectile_speed
		rocket.damage = w.damage
		rocket.radius = w.blast_radius
		rocket.max_distance = w.weapon_range
		rocket.exclude = _own_rids()
		fx_parent.add_child(rocket)
		var side := 0.0 if count == 1 else (-0.35 if i == 0 else 0.35)
		# Start from the camera (inside the cab, so it never clips the bonnet) a little ahead.
		rocket.global_position = _camera.global_position + forward * 1.2 + right * side
		rocket.look_at(rocket.global_position + dir, Vector3.UP)


## Mines (D-086): dropped on the road behind the taxi.
func _drop_mine(w: WeaponData) -> void:
	var fx_parent := (taxi.get_parent() if taxi != null else get_tree().current_scene) as Node3D
	var behind := taxi.global_position + taxi.global_basis.z * 3.4 if taxi != null else global_position
	Mine.drop(fx_parent, behind, w.damage, w.blast_radius)


func _fire_hitscan(w: WeaponData) -> void:
	var space := get_world_3d().direct_space_state
	var origin := _camera.global_position
	var forward := -_camera.global_basis.z
	var exclude := _own_rids()
	var fx_parent := taxi.get_parent() if taxi != null else get_tree().current_scene
	var hit_any := false
	var killed_any := false
	# Mk IV specials (D-085).
	var damage := w.damage
	if is_aiming and WeaponUpgrades.has_special(w, &"deadeye"):
		damage *= WeaponUpgrades.DEADEYE_MULT
	var burns := WeaponUpgrades.has_special(w, &"incendiary")
	var targets := WeaponUpgrades.PIERCE_TARGETS if WeaponUpgrades.has_special(w, &"piercing") else 1
	for i in w.pellets:
		var dir := _spread_dir(forward, current_spread_deg)
		var from := origin
		var end := origin + dir * w.weapon_range
		var skip := exclude.duplicate()
		var hits_left := targets
		# One ray per target: a piercing round carries on past a car it hit (its whole body is
		# excluded), anything else stops at the first thing in the way.
		while hits_left > 0:
			var query := PhysicsRayQueryParameters3D.create(from, origin + dir * w.weapon_range, HIT_MASK, skip)
			query.collide_with_areas = true
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				end = origin + dir * w.weapon_range
				break
			end = hit["position"]
			var collider: Object = hit["collider"]
			var went_through := false
			if collider is Hitbox:
				var box := collider as Hitbox
				hit_any = true
				if box.take_hit(damage, origin):
					killed_any = true
				if burns and box.health != null:
					Burning.ignite(box.health, WeaponUpgrades.BURN_DPS
							* WeaponUpgrades.damage_scale(w, _base(w.id)), WeaponUpgrades.BURN_TIME)
				hits_left -= 1
				went_through = hits_left > 0
				if went_through:
					skip.append_array(_body_rids(box))
			elif collider is RigidBody3D:
				var body := collider as RigidBody3D
				body.apply_impulse(dir * w.impact_force, end - body.global_position)
			CombatFx.impact(fx_parent, end, hit["normal"])
			if not went_through:
				break
			from = end
		if w.beam:
			_show_beam(_muzzle.global_position, end)
		elif i % 2 == 0:
			CombatFx.tracer(fx_parent, _muzzle.global_position, end)
	if hit_any:
		EventBus.hit_confirmed.emit(killed_any)


## The laser: one stretched box from the muzzle to where the beam stops, kept alive by every tick.
func _show_beam(from: Vector3, to: Vector3) -> void:
	if _beam == null:
		_beam = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.05, 1.0)
		_beam.mesh = box
		var mat := (load("res://assets/materials/beacon_green.tres") as ShaderMaterial).duplicate() as ShaderMaterial
		mat.set_shader_parameter(&"albedo", Color(1.0, 0.15, 0.2))
		mat.set_shader_parameter(&"emission_strength", 2.5)
		_beam.material_override = mat
		_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beam.top_level = true
		_beam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(_beam)
	var length := from.distance_to(to)
	if length < 0.05:
		return
	_beam.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), (from + to) * 0.5)
	_beam.scale = Vector3(1.0, 1.0, length)
	_beam_time = 0.07


## RIDs of the taxi body and every hitbox/collider on it, so shots never hit our own car.
func _own_rids() -> Array[RID]:
	var rids: Array[RID] = []
	if taxi == null:
		return rids
	rids.append(taxi.get_rid())
	for node in taxi.find_children("*", "CollisionObject3D", true, false):
		rids.append((node as CollisionObject3D).get_rid())
	return rids


## Every collider of the vehicle (or whatever) a hitbox belongs to, so a piercing round leaves
## it behind instead of hitting its body or its other hitboxes.
func _body_rids(box: Hitbox) -> Array[RID]:
	var rids: Array[RID] = [box.get_rid()]
	var owner_body: Node = box.get_parent()
	while owner_body != null and not (owner_body is CollisionObject3D and not owner_body is Area3D):
		owner_body = owner_body.get_parent()
	if owner_body == null:
		return rids
	rids.append((owner_body as CollisionObject3D).get_rid())
	for node in owner_body.find_children("*", "CollisionObject3D", true, false):
		rids.append((node as CollisionObject3D).get_rid())
	return rids


func _spread_dir(forward: Vector3, spread_deg: float) -> Vector3:
	if spread_deg <= 0.0:
		return forward
	var angle := deg_to_rad(spread_deg) * sqrt(_rng.randf())  # uniform over the cone's disc
	var roll := _rng.randf() * TAU
	var right := forward.cross(Vector3.UP)
	right = right.normalized() if right.length() > 0.01 else Vector3.RIGHT
	var up := right.cross(forward).normalized()
	return (forward * cos(angle) + (right * cos(roll) + up * sin(roll)) * sin(angle)).normalized()


func _update_spread(w: WeaponData) -> void:
	var speed := taxi.linear_velocity.length() if taxi != null else 0.0
	var yaw_rate := absf(taxi.angular_velocity.y) if taxi != null else 0.0
	current_spread_deg = w.spread_aimed + (0.0 if is_aiming else w.spread_hip) \
		+ speed * w.spread_per_speed + yaw_rate * w.spread_per_turn + _bloom


# --- Reload / switch -----------------------------------------------------------------

func _handle_reload(delta: float, w: WeaponData) -> void:
	if is_reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			var a: Dictionary = ammo[w.id]
			var take := mini(w.mag_size - int(a["mag"]), int(a["reserve"]))
			a["mag"] += take
			a["reserve"] -= take
			is_reloading = false
	elif Input.is_action_just_pressed(&"reload"):
		_start_reload(w)


func _start_reload(w: WeaponData) -> void:
	var a: Dictionary = ammo[w.id]
	if is_reloading or a["mag"] >= w.mag_size or a["reserve"] <= 0:
		return
	is_reloading = true
	_reload_left = w.reload_time
	EventBus.weapon_reloading.emit(w)


func _handle_switch_input() -> void:
	if weapons.size() < 2:
		return
	var target := current_index
	if Input.is_action_just_pressed(&"weapon_next"):
		target = (current_index + 1) % weapons.size()
	elif Input.is_action_just_pressed(&"weapon_prev"):
		target = (current_index - 1 + weapons.size()) % weapons.size()
	for n in LOADOUT_SIZE:
		if Input.is_action_just_pressed(StringName("weapon_%d" % (n + 1))) and n < weapons.size():
			target = n
	if target != current_index:
		_equip(target)


func _equip(index: int) -> void:
	current_index = index
	is_reloading = false
	_switch_left = switch_time
	raise_amount = minf(raise_amount, 0.3)
	_bloom = 0.0
	var w := current_weapon()
	var box := _gun.mesh as BoxMesh
	box.size = w.gun_size
	_gun.position = Vector3(0.0, 0.03 + w.gun_size.y * 0.3, -w.gun_size.z * 0.5 + 0.04)
	_gun_mat.set_shader_parameter(&"albedo", w.gun_color)
	_muzzle.position = Vector3(0.0, _gun.position.y + w.gun_size.y * 0.2, _gun.position.z - w.gun_size.z * 0.5 - 0.03)
	weapon_changed.emit(w)


# --- Viewmodel -----------------------------------------------------------------------

func _build_viewmodel() -> void:
	_viewmodel = Node3D.new()
	_viewmodel.name = "Viewmodel"
	add_child(_viewmodel)
	var sleeve_mesh := BoxMesh.new()
	sleeve_mesh.size = Vector3(0.09, 0.09, 0.45)
	Blockout.add_mesh(_viewmodel, sleeve_mesh, Vector3(0.02, -0.03, 0.24), load("res://assets/materials/viewmodel_sleeve.tres"))
	var hand_mesh := BoxMesh.new()
	hand_mesh.size = Vector3(0.075, 0.09, 0.1)
	Blockout.add_mesh(_viewmodel, hand_mesh, Vector3(0.0, -0.01, 0.0), load("res://assets/materials/viewmodel_skin.tres"))
	_gun_mat = (load("res://assets/materials/viewmodel_gun.tres") as ShaderMaterial).duplicate() as ShaderMaterial
	_gun = Blockout.add_mesh(_viewmodel, BoxMesh.new(), Vector3.ZERO, _gun_mat)
	_muzzle = Node3D.new()
	_viewmodel.add_child(_muzzle)
	_flash = Node3D.new()
	_flash.visible = false
	_muzzle.add_child(_flash)
	var flash_mesh := PrismMesh.new()
	flash_mesh.size = Vector3(0.14, 0.2, 0.14)
	var flash := Blockout.add_mesh(_flash, flash_mesh, Vector3(0, 0, -0.08), load("res://assets/materials/fx_flash.tres"))
	flash.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.8, 0.4)
	_flash_light.light_energy = 1.4
	_flash_light.omni_range = 3.0
	_flash_light.visible = false
	_muzzle.add_child(_flash_light)
