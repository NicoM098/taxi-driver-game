class_name EnemyCarData
extends Resource
## One enemy vehicle type (Phase 06). Files in res://data/enemies/<id>.tres.

@export var id: StringName = &""
@export var display_name: String = "Enemy"
@export_file("*.tres") var body_material: String = "res://assets/materials/enemy_red.tres"
@export var siren: bool = false

@export_group("Car")
@export var hp: float = 120.0
@export var max_speed: float = 31.0        # m/s
@export var engine_force: float = 8500.0
## kg. The taxi weighs 1000: lighter cars can be shoved aside, heavier ones shove YOU.
@export var mass: float = 800.0
## 0..1: how often it switches from flanking to ramming.
@export var aggression: float = 0.5

@export_group("Rewards")
@export var bounty: int = 40
@export var heat_on_kill: int = 1

@export_group("Gunman")
@export var shoots: bool = true
@export var damage: float = 5.0
@export var fire_rate: float = 6.0         # shots/s inside a burst
@export var burst: int = 4
@export var burst_pause: float = 1.3
@export var spread_deg: float = 3.0
@export var gun_range: float = 40.0
