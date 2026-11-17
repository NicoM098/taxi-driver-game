class_name GunShop
extends Node3D
## A gun store in the city (map piece "gunshop"). Stop the taxi on its green pad and press
## interact (E / Tab / D-pad up): the shop screen (GunShopUI, in Main's UI layer) opens.
## Not while wrecked or while a passenger is boarding / reading their file.
## A ring and a beam mark the pad (ShopMarker).

const COLOUR := Color(1.0, 0.6, 0.2)       # the minimap's gun-shop square

@export var max_speed: float = 2.5        # m/s: "stopped" on the pad

var pad_position: Vector3 = Vector3.ZERO  # global, y = 0
var pad_radius: float = 5.0

var _marker: ShopMarker
var _prompt: String = ""


func _ready() -> void:
	add_to_group(&"gun_shops")
	_marker = ShopMarker.new()
	add_child(_marker)
	_marker.setup(pad_position, pad_radius, COLOUR)


func _physics_process(_delta: float) -> void:
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
	if taxi == null:
		_set_prompt("")
		return
	var on_pad := is_taxi_on_pad(taxi)
	_marker.update(on_pad)
	var ui := get_tree().get_first_node_in_group(&"gun_shop_ui") as GunShopUI
	if not on_pad or taxi.linear_velocity.length() > max_speed or not _can_open() \
			or ui == null or ui.is_open:
		_set_prompt("")
		return
	_set_prompt("[%s]  GUN SHOP" % RepairShop.interact_key())
	if Input.is_action_just_pressed(&"interact"):
		_set_prompt("")
		ui.open(self)


func is_taxi_on_pad(taxi: Node3D) -> bool:
	return Vector2(taxi.global_position.x - pad_position.x, taxi.global_position.z - pad_position.z).length() <= pad_radius


func _set_prompt(text: String) -> void:
	if text == _prompt:
		return
	_prompt = text
	EventBus.interact_prompt.emit(self, text)


func _exit_tree() -> void:
	_set_prompt("")


func _can_open() -> bool:
	var damage := get_tree().get_first_node_in_group(&"taxi_damage") as TaxiDamage
	if damage != null and (damage.is_wrecked or damage.is_dead):
		return false
	var rides := get_tree().get_first_node_in_group(&"ride_manager") as RideManager
	if rides != null and (rides.state == RideManager.State.ENTERING or rides.state == RideManager.State.DOSSIER):
		return false
	var dossier := get_tree().get_first_node_in_group(&"dossier") as Dossier
	return dossier == null or not dossier.is_open
