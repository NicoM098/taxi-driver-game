class_name WeaponController
extends Node3D
## First-person shooting from the cab (Half Grip-inspired, arcade controls).
## Child of the cab Camera3D. Hold AIM (RMB / LB) to raise the gun (zoom, tight spread);
## FIRE (LMB / RB) also raises it (hip fire, wider spread). Hitscan rays from the screen
## centre; spread grows with taxi speed, turning and sustained fire. Driving is never blocked.
## Weapons = WeaponData resources for every id in GameState.owned_weapons, kept in slot order
## (WeaponData.slot = the number key). Gun shops add weapons / refill ammo at runtime.

signal weapon_changed(weapon: WeaponData)

const WEAPON_DIR := "res://data/weapons/"
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

var weapons: Array[WeaponData] = []
var current_index: int = 0
var ammo: Dictionary = {}          # id -> {"mag": int, "reserve": int}
var raise_amount: float = 0.0      # 0 = lowered .. 1 = raised
var is_aiming: bool = false
var is_reloading: bool = false
var current_spread_deg: float = 0.0
var shots_fired: int = 0           # total, for tests/stats

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
	if not weapons.is_empty():
		_equip(0)


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
	return ammo.has(id)


## Gives the player a weapon (full mag + reserve) and records it in GameState. Returns false
## if it was already owned / does not exist.
func add_weapon(id: StringName) -> bool:
	if owns(id) or not _add(id):
		return false
	if not GameState.owned_weapons.has(id):
		GameState.owned_weapons.append(id)
	var keep := current_weapon()
	if keep != null:
		current_index = weapons.find(keep)
	return true


## Fills the reserve (and the magazine) of an owned weapon. Returns false if already full.
func refill_ammo(id: StringName) -> bool:
	if not owns(id):
		return false
	var w := _find(id)
	var a: Dictionary = ammo[id]
	if int(a["reserve"]) >= w.reserve_max and int(a["mag"]) >= w.mag_size:
		return false
	a["mag"] = w.mag_size
	a["reserve"] = w.reserve_max
	return true


## Index of the weapon in `slot` (1-4), or -1.
func index_of_slot(slot: int) -> int:
	for i in weapons.size():
		if weapons[i].slot == slot:
			return i
	return -1


func select(index: int) -> void:
	if index >= 0 and index < weapons.size() and index != current_index:
		_equip(index)


func _add(id: StringName) -> bool:
	var data := load(WEAPON_DIR + String(id) + ".tres") as WeaponData
	if data == null:
		return false
	weapons.append(data)
	weapons.sort_custom(func(a: WeaponData, b: WeaponData) -> bool: return a.slot < b.slot)
	ammo[data.id] = {"mag": data.mag_size, "reserve": data.reserve_max}
	return true


func _find(id: StringName) -> WeaponData:
	for w in weapons:
		if w.id == id:
			return w
	return null


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
	var space := get_world_3d().direct_space_state
	var origin := _camera.global_position
	var forward := -_camera.global_basis.z
	var exclude := _own_rids()
	var fx_parent := taxi.get_parent() if taxi != null else get_tree().current_scene
	var hit_any := false
	var killed_any := false
	for i in w.pellets:
		var dir := _spread_dir(forward, current_spread_deg)
		var end := origin + dir * w.weapon_range
		var query := PhysicsRayQueryParameters3D.create(origin, end, HIT_MASK, exclude)
		query.collide_with_areas = true
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			end = hit["position"]
			var collider: Object = hit["collider"]
			if collider is Hitbox:
				hit_any = true
				if (collider as Hitbox).take_hit(w.damage, origin):
					killed_any = true
			elif collider is RigidBody3D:
				var body := collider as RigidBody3D
				body.apply_impulse(dir * w.impact_force, end - body.global_position)
			CombatFx.impact(fx_parent, end, hit["normal"])
		if i % 2 == 0:
			CombatFx.tracer(fx_parent, _muzzle.global_position, end)
	_bloom += w.spread_per_shot
	_flash_time = 0.05
	_kick = 1.0
	if _cab != null:
		_cab.add_recoil(w.recoil_pitch, _rng.randf_range(-w.recoil_yaw, w.recoil_yaw))
	if hit_any:
		EventBus.hit_confirmed.emit(killed_any)
	EventBus.weapon_fired.emit(w)
	if ammo[w.id]["mag"] <= 0:
		_start_reload(w)  # arcade: reload as soon as the mag runs dry


## RIDs of the taxi body and every hitbox/collider on it, so shots never hit our own car.
func _own_rids() -> Array[RID]:
	var rids: Array[RID] = []
	if taxi == null:
		return rids
	rids.append(taxi.get_rid())
	for node in taxi.find_children("*", "CollisionObject3D", true, false):
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
	for n in 4:
		if Input.is_action_just_pressed(StringName("weapon_%d" % (n + 1))):
			var i := index_of_slot(n + 1)
			if i >= 0:
				target = i
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
