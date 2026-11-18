class_name AmmoPickup
extends Area3D
## Ammo for ONE gun, dropped by a destroyed enemy (D-094; ammo is no longer sold). A floating,
## spinning ammo box in the gun's colour with its name over it and a glowing circle on the road,
## like the Monstrous Energy can. Drive through it to take the rounds. It waits LIFETIME seconds
## (blinking at the end) and stays put if that gun is already full.
## Physics layer 8 (triggers), detects layer 2 (player taxi).

## Off = enemies drop nothing (tests that count nodes).
static var enabled: bool = true
## Share of the gun's (upgraded) reserve one box holds; never less than one magazine.
const RESERVE_SHARE := 0.3
## Seconds before an untouched box goes; it blinks for the last BLINK_TIME.
const LIFETIME := 30.0
const BLINK_TIME := 6.0
## Boxes per kill: 1, plus one for every HP_PER_BOX of the car's base health (bosses), at most MAX_BOXES.
const HP_PER_BOX := 400.0
const MAX_BOXES := 5
## Even a full gun gets a share of the drops (weight next to 0..1 for how empty a gun is).
const FULL_WEIGHT := 0.08
## One colour per hotbar slot (WeaponData.slot 1-8).
const SLOT_COLORS: Array[Color] = [
	Color(0.95, 0.85, 0.35), Color(0.4, 0.85, 1.0), Color(1.0, 0.5, 0.25), Color(0.55, 1.0, 0.45),
	Color(1.0, 0.35, 0.35), Color(0.75, 0.55, 1.0), Color(1.0, 0.65, 0.85), Color(0.35, 1.0, 0.9)]

var weapon_id: StringName = &""
var _visual: Node3D
var _light: OmniLight3D
var _ring: PickupRing
var _label: Label3D
var _time: float = 0.0
var _taken: bool = false


## The drops of a destroyed enemy with `base_hp` (its .tres health) at `pos`, under `world`.
## Returns the boxes made (empty when off or the player has no guns).
static func drop_for_kill(world: Node, pos: Vector3, base_hp: float) -> Array[AmmoPickup]:
	var made: Array[AmmoPickup] = []
	if not enabled or world == null or not world.is_inside_tree():
		return made
	var wc := world.get_tree().get_first_node_in_group(&"weapon_controller") as WeaponController
	if wc == null or wc.weapons.is_empty():
		return made
	var ground := _ground_at(world, pos)
	var n := clampi(1 + floori(base_hp / HP_PER_BOX), 1, MAX_BOXES)
	for i in n:
		var w := pick_weapon(wc)
		if w == null:
			break
		var box := AmmoPickup.new()
		box.weapon_id = w.id
		var off := Vector3.ZERO
		if n > 1:
			var a := TAU * float(i) / float(n)
			off = Vector3(cos(a), 0.0, sin(a)) * 3.0
		world.add_child(box)
		box.global_position = ground + off
		made.append(box)
	return made


## Which equipped gun a box is for: random, weighted to the emptiest. Null with no guns.
static func pick_weapon(wc: WeaponController) -> WeaponData:
	var total := 0.0
	var weights: Array[float] = []
	for w in wc.weapons:
		var weight := FULL_WEIGHT + (1.0 - fill(wc, w))
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return null
	var roll := randf() * total
	for i in wc.weapons.size():
		roll -= weights[i]
		if roll <= 0.0:
			return wc.weapons[i]
	return wc.weapons.back()


## How full a gun is, 0..1 (magazine + reserve).
static func fill(wc: WeaponController, w: WeaponData) -> float:
	var a := wc.get_ammo(w)
	var cap := w.mag_size + w.reserve_max
	return clampf(float(int(a["mag"]) + int(a["reserve"])) / float(cap), 0.0, 1.0) if cap > 0 else 1.0


## Rounds one box gives gun `w` (as carried, upgrades applied).
static func amount_for(w: WeaponData) -> int:
	if not w.reloads():   # the mines: a share of what they carry (D-099)
		return maxi(ceili(w.mag_size * RESERVE_SHARE), 1)
	return maxi(ceili(w.reserve_max * RESERVE_SHARE), w.mag_size)


static func color_for(id: StringName) -> Color:
	var base := load("res://data/weapons/%s.tres" % id) as WeaponData
	var slot := base.slot if base != null else 1
	return SLOT_COLORS[clampi(slot - 1, 0, SLOT_COLORS.size() - 1)]


static func _ground_at(world: Node, pos: Vector3) -> Vector3:
	var space := (world as Node3D).get_world_3d().direct_space_state if world is Node3D else null
	if space == null:
		return Vector3(pos.x, pos.y - 0.5, pos.z)
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 1.0, pos + Vector3.DOWN * 30.0, 1)
	var hit := space.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else Vector3(pos.x, pos.y - 0.5, pos.z)


func _ready() -> void:
	add_to_group(&"ammo_pickups")
	collision_layer = 1 << 7
	collision_mask = 1 << 1
	monitorable = false
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.4
	col.shape = sphere
	col.position.y = 1.0
	add_child(col)
	var color := color_for(weapon_id)
	_visual = Node3D.new()
	_visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_visual)
	_build_box(_visual, color)
	_ring = PickupRing.build(self, color, 1.7)
	var base := load("res://data/weapons/%s.tres" % weapon_id) as WeaponData
	_label = Label3D.new()
	_label.text = "%s AMMO" % (base.display_name.to_upper() if base != null else String(weapon_id).to_upper())
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = false
	_label.pixel_size = 0.018
	_label.font_size = 48
	_label.outline_size = 12
	_label.modulate = color
	_label.position.y = 2.6
	add_child(_label)
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = 1.0
	_light.omni_range = 4.5
	_light.position.y = 1.4
	add_child(_light)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	_visual.rotation.y = _time * 1.8
	_visual.position.y = 1.3 + sin(_time * 2.5) * 0.15
	var left := LIFETIME - _time
	if left <= 0.0:
		queue_free()
		return
	if left < BLINK_TIME:
		var on := fmod(_time, 0.3) < 0.18
		_visual.visible = on
		_ring.visible = on
		_label.visible = on


func _physics_process(_delta: float) -> void:
	# A box dropped onto the taxi (or one that was full) is taken when the taxi is still in it.
	if _taken or not monitoring:
		return
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node) -> void:
	if _taken or not body.is_in_group(&"player_vehicle"):
		return
	var wc := get_tree().get_first_node_in_group(&"weapon_controller") as WeaponController
	if wc == null or not collect(wc):
		return


## Gives the rounds to `wc` (also used by tests). False (and the box stays) if that gun is not
## owned or already full.
func collect(wc: WeaponController) -> bool:
	if _taken:
		return false
	var w := wc.get_weapon(weapon_id)
	if w == null or not wc.ammo.has(weapon_id):
		return false
	var a: Dictionary = wc.ammo[weapon_id]
	var pool := "reserve" if w.reloads() else "mag"   # mines never reload: straight in (D-099)
	var room := (w.reserve_max if w.reloads() else w.mag_size) - int(a[pool])
	if room <= 0:
		return false
	var got := mini(amount_for(w), room)
	a[pool] = int(a[pool]) + got
	_taken = true
	EventBus.ammo_picked_up.emit(weapon_id, got)
	EventBus.hud_message.emit("+%d  %s AMMO" % [got, w.display_name.to_upper()], &"good")
	queue_free()
	return true


static func _build_box(parent: Node3D, color: Color) -> void:
	var olive := StandardMaterial3D.new()
	olive.albedo_color = Color(0.3, 0.34, 0.2)
	olive.roughness = 0.8
	var band := StandardMaterial3D.new()
	band.albedo_color = color
	band.emission_enabled = true
	band.emission = color
	band.emission_energy_multiplier = 0.8
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.85, 0.65, 0.25)
	brass.metallic = 0.8
	brass.roughness = 0.35
	var box := BoxMesh.new()
	box.size = Vector3(0.95, 0.55, 0.6)
	Blockout.add_mesh(parent, box, Vector3.ZERO, olive)
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.97, 0.16, 0.62)
	Blockout.add_mesh(parent, stripe, Vector3(0, 0.05, 0), band)
	var shell := CylinderMesh.new()
	shell.top_radius = 0.045
	shell.bottom_radius = 0.06
	shell.height = 0.32
	shell.radial_segments = 8
	shell.rings = 1
	for i in 4:
		Blockout.add_mesh(parent, shell, Vector3(-0.3 + 0.2 * i, 0.43, 0), brass)
