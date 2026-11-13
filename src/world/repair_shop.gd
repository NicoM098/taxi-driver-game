class_name RepairShop
extends Node3D
## A garage in the city (map piece "repair"). Stop the taxi on the yellow pad to get it fixed:
## a wreck costs `wreck_fee`, damage costs per missing hit point. If you cannot pay, they take
## what you have (a wrecked cab must never be stuck for good).
## While the taxi is wrecked every shop shows a tall red beacon.

@export var wreck_fee: int = 60
@export var cost_per_taxi_hp: float = 0.8
@export var cost_per_driver_hp: float = 0.4
@export var max_speed: float = 2.5        # m/s: "stopped" on the pad
@export var work_time: float = 1.2        # s on the pad before the job is done

var pad_position: Vector3 = Vector3.ZERO  # global, y = 0
var pad_radius: float = 5.0

var _on_pad: float = 0.0
var _beacon: Node3D


func _ready() -> void:
	add_to_group(&"repair_shops")
	_beacon = Node3D.new()
	_beacon.visible = false
	add_child(_beacon)
	_beacon.global_position = pad_position
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.7
	pillar.bottom_radius = 0.7
	pillar.height = 40.0
	pillar.radial_segments = 6
	pillar.rings = 1
	Blockout.add_mesh(_beacon, pillar, Vector3(0, 20.0, 0), MapBuilder.mat("siren_red"))


func _physics_process(delta: float) -> void:
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
	var damage := taxi.get_node_or_null("TaxiDamage") as TaxiDamage if taxi != null else null
	if damage == null:
		return
	_beacon.visible = damage.is_wrecked
	var flat := Vector2(taxi.global_position.x - pad_position.x, taxi.global_position.z - pad_position.z)
	if flat.length() > pad_radius or taxi.linear_velocity.length() > max_speed or not needs_work(damage):
		_on_pad = 0.0
		return
	_on_pad += delta
	if _on_pad >= work_time:
		_on_pad = 0.0
		service(damage)


static func needs_work(damage: TaxiDamage) -> bool:
	return damage.is_wrecked or damage.taxi_health.hp < damage.taxi_health.max_hp - 0.5 \
			or damage.driver_health.hp < damage.driver_health.max_hp - 0.5


func quote(damage: TaxiDamage) -> int:
	var fee := wreck_fee if damage.is_wrecked else 0
	if not damage.is_wrecked:
		fee += ceili((damage.taxi_health.max_hp - damage.taxi_health.hp) * cost_per_taxi_hp
			+ (damage.driver_health.max_hp - damage.driver_health.hp) * cost_per_driver_hp)
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
