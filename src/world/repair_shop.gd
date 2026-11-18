class_name RepairShop
extends Node3D
## A garage in the city (map piece "repair"). Stop the taxi on the yellow pad and press
## interact (E / D-pad up) to get it fixed: a wreck costs `wreck_fee`, damage costs per
## missing hit point. If you cannot pay, they take what you have (a wrecked cab must never be
## stuck for good).
## A ring and a beam mark the pad (ShopMarker); the beam turns red while the taxi is wrecked.

const COLOUR := Color(0.6, 0.8, 1.0)       # the minimap's repair square

@export var wreck_fee: int = 60
@export var cost_per_taxi_hp: float = 0.8
@export var cost_per_driver_hp: float = 0.4
@export var max_speed: float = 2.5        # m/s: "stopped" on the pad

var pad_position: Vector3 = Vector3.ZERO  # global, y = 0
var pad_radius: float = 5.0

var _marker: ShopMarker
var _prompt: String = ""


func _ready() -> void:
	add_to_group(&"repair_shops")
	_marker = ShopMarker.new()
	add_child(_marker)
	_marker.setup(pad_position, pad_radius, COLOUR)


func _physics_process(_delta: float) -> void:
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
	var damage := taxi.get_node_or_null("TaxiDamage") as TaxiDamage if taxi != null else null
	if damage == null:
		_set_prompt("")
		return
	var on_pad := is_taxi_on_pad(taxi)
	_marker.update(on_pad, damage.is_wrecked)
	if not on_pad or taxi.linear_velocity.length() > max_speed or damage.is_dead or not needs_work(damage):
		_set_prompt("")
		return
	_set_prompt("[%s]  REPAIR  -$%d" % [interact_key(), quote(damage)])
	if Input.is_action_just_pressed(&"interact"):
		service(damage)
		_set_prompt("")


func is_taxi_on_pad(taxi: Node3D) -> bool:
	return Vector2(taxi.global_position.x - pad_position.x, taxi.global_position.z - pad_position.z).length() <= pad_radius


static func interact_key() -> String:
	return "D-pad ↑" if InputDevice.using_gamepad else "E"


func _set_prompt(text: String) -> void:
	if text == _prompt:
		return
	_prompt = text
	EventBus.interact_prompt.emit(self, text)


func _exit_tree() -> void:
	_set_prompt("")


static func needs_work(damage: TaxiDamage) -> bool:
	return damage.is_wrecked or damage.taxi_health.hp < damage.taxi_health.max_hp - 0.5 \
			or damage.driver_health.hp < damage.driver_health.max_hp - 0.5


func quote(damage: TaxiDamage) -> int:
	var fee := wreck_fee if damage.is_wrecked else 0
	if not damage.is_wrecked:
		fee += ceili((damage.taxi_health.max_hp - damage.taxi_health.hp) * cost_per_taxi_hp
			+ ((damage.driver_health.max_hp - damage.driver_health.hp) if damage.has_driver_bar() else 0.0) * cost_per_driver_hp)
	return fee


## Repairs the taxi and charges for it. Returns what was paid.
func service(damage: TaxiDamage) -> int:
	var fee := quote(damage)
	var paid := mini(fee, GameState.cash)
	if paid > 0:
		GameState.add_cash(-paid)
	damage.repair()
	if paid < fee:
		EventBus.hud_message.emit("REPAIRED — they took all you had ($%d of $%d)" % [paid, fee], &"info")
	else:
		EventBus.hud_message.emit("REPAIRED  -$%d" % paid, &"good")
	return paid
