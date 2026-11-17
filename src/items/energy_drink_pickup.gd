class_name EnergyDrinkPickup
extends Area3D
## "Monstrous Energy" (fictional brand): a giant floating, spinning white can. Drive through it
## to crack one open: heals the driver (and a bit of the taxi) over a second, then respawns.
## Physics layer 8 (triggers), detects layer 2 (player taxi).

@export var driver_heal: float = 50.0
@export var body_heal: float = 30.0
@export var heal_duration: float = 1.2
@export var respawn_time: float = 30.0

var _visual: Node3D
var _light: OmniLight3D
var _respawn_left: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	add_to_group(&"energy_drinks")
	collision_layer = 1 << 7
	collision_mask = 1 << 1
	monitorable = false
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.4
	col.shape = sphere
	add_child(col)
	_visual = Node3D.new()
	_visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_visual)
	build_can(_visual, 1.0, false)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.6, 0.9, 1.0)
	_light.light_energy = 1.2
	_light.omni_range = 5.0
	add_child(_light)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	if _respawn_left > 0.0:
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			_set_available(true)
		return
	_visual.rotation.y = _time * 1.8
	_visual.position.y = 1.6 + sin(_time * 2.5) * 0.15


func is_available() -> bool:
	return _respawn_left <= 0.0


func _on_body_entered(body: Node) -> void:
	if not is_available() or not body.is_in_group(&"player_vehicle"):
		return
	var dmg := body.get_node_or_null("TaxiDamage") as TaxiDamage
	if dmg == null or dmg.is_wrecked:
		return
	var xl := CarUpgrades.can_mult() if ShopMenu.enabled else 1.0   # Monstrous XL (D-089)
	dmg.drink(driver_heal * xl, body_heal * xl, heal_duration)
	EventBus.energy_drink_consumed.emit()
	EventBus.hud_message.emit("*CRACK*  MONSTROUS ENERGY!", &"good")
	_set_available(false)
	_respawn_left = respawn_time


func _set_available(on: bool) -> void:
	_visual.visible = on
	_light.visible = on
	set_deferred(&"monitoring", on)


## Shared by the first-person drink animation (viewmodel = no vertex wobble).
static func build_can(parent: Node3D, scale_factor: float, viewmodel: bool) -> void:
	var suffix := "_vm" if viewmodel else ""
	var body := CylinderMesh.new()
	body.top_radius = 0.33 * scale_factor
	body.bottom_radius = 0.33 * scale_factor
	body.height = 1.0 * scale_factor
	body.radial_segments = 10
	body.rings = 1
	Blockout.add_mesh(parent, body, Vector3.ZERO, load("res://assets/materials/can_white%s.tres" % suffix))
	var band := CylinderMesh.new()
	band.top_radius = 0.34 * scale_factor
	band.bottom_radius = 0.34 * scale_factor
	band.height = 0.28 * scale_factor
	band.radial_segments = 10
	band.rings = 1
	Blockout.add_mesh(parent, band, Vector3(0, 0.05 * scale_factor, 0), load("res://assets/materials/can_band%s.tres" % suffix))
	var lid := CylinderMesh.new()
	lid.top_radius = 0.27 * scale_factor
	lid.bottom_radius = 0.31 * scale_factor
	lid.height = 0.07 * scale_factor
	lid.radial_segments = 10
	lid.rings = 1
	var lid_mat := "res://assets/materials/viewmodel_gun.tres" if viewmodel else "res://assets/materials/can_metal.tres"
	Blockout.add_mesh(parent, lid, Vector3(0, 0.53 * scale_factor, 0), load(lid_mat))
