class_name GunShop
extends Node3D
## A gun store in the city (map piece "gunshop"). Stop the taxi on its green pad and the shop
## screen (GunShopUI, in Main's UI layer) opens. You have to drive off the pad before it can
## open again. Not while wrecked or while a passenger is boarding / reading their file.

@export var max_speed: float = 2.5        # m/s: "stopped" on the pad
@export var wait_time: float = 0.6        # s on the pad before the shop opens

var pad_position: Vector3 = Vector3.ZERO  # global, y = 0
var pad_radius: float = 5.0

var _on_pad: float = 0.0
var _armed: bool = true                   # false until the taxi leaves the pad after a visit


func _ready() -> void:
	add_to_group(&"gun_shops")


func _physics_process(delta: float) -> void:
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
	if taxi == null:
		return
	var flat := Vector2(taxi.global_position.x - pad_position.x, taxi.global_position.z - pad_position.z)
	if flat.length() > pad_radius:
		_armed = true
		_on_pad = 0.0
		return
	if not _armed or taxi.linear_velocity.length() > max_speed or not _can_open():
		_on_pad = 0.0
		return
	_on_pad += delta
	if _on_pad >= wait_time:
		_on_pad = 0.0
		_armed = false
		var ui := get_tree().get_first_node_in_group(&"gun_shop_ui") as GunShopUI
		if ui != null:
			ui.open(self)


func is_taxi_on_pad(taxi: Node3D) -> bool:
	return Vector2(taxi.global_position.x - pad_position.x, taxi.global_position.z - pad_position.z).length() <= pad_radius


func _can_open() -> bool:
	var damage := get_tree().get_first_node_in_group(&"taxi_damage") as TaxiDamage
	if damage != null and damage.is_wrecked:
		return false
	var rides := get_tree().get_first_node_in_group(&"ride_manager") as RideManager
	if rides != null and (rides.state == RideManager.State.ENTERING or rides.state == RideManager.State.DOSSIER):
		return false
	var dossier := get_tree().get_first_node_in_group(&"dossier") as Dossier
	return dossier == null or not dossier.is_open
