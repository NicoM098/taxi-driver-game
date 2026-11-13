class_name WeaponData
extends Resource
## One weapon type (hitscan). Files live in res://data/weapons/<id>.tres.

@export var id: StringName = &""
@export var display_name: String = "Weapon"

@export_group("Damage")
@export var damage: float = 25.0          # per pellet
@export var pellets: int = 1
@export var weapon_range: float = 150.0
@export var impact_force: float = 4.0     # impulse on physics props (N·s)

@export_group("Handling")
@export var fire_rate: float = 3.0        # shots per second
@export var automatic: bool = false       # hold to fire
@export var mag_size: int = 6
@export var reserve_max: int = 36
@export var reload_time: float = 1.4

@export_group("Accuracy (degrees)")
@export var spread_aimed: float = 0.4     # base cone half-angle when aiming
@export var spread_hip: float = 3.0       # extra when firing without aiming
@export var spread_per_speed: float = 0.06    # extra per m/s of taxi speed
@export var spread_per_turn: float = 2.0      # extra per rad/s of taxi yaw rate
@export var spread_per_shot: float = 0.0      # bloom added per shot (decays)

@export_group("Recoil (degrees)")
@export var recoil_pitch: float = 2.5
@export var recoil_yaw: float = 0.6

@export_group("Look")
@export var gun_size: Vector3 = Vector3(0.05, 0.09, 0.26)
@export var gun_color: Color = Color(0.2, 0.2, 0.22)

@export_group("Economy (Phase 09)")
@export var price: int = 0
@export var ammo_price: int = 0
