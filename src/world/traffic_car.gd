class_name TrafficCar
extends Taxi
## A civilian car cruising the streets (street life, D-065). Same raycast physics as the taxi,
## the AI cars' blockout body in a random civilian colour, physics layer 4 (traffic).
## Driven by TrafficAI: right-hand lane, keeps distance, stops after a crash. Spawned / recycled
## by StreetLife around the player.
## Destructible since 2026-11-15 (user request): shoot it (or ram it hard) enough and it blows
## up like an enemy car. If the player did it, EventBus.civilian_killed fires and the police
## hear about it (EnemyDirector raises the heat). Enemy stray bullets do not count against you.

const COLORS: Array[Color] = [
	Color(0.75, 0.75, 0.78), Color(0.15, 0.25, 0.55), Color(0.2, 0.45, 0.25), Color(0.55, 0.5, 0.42),
	Color(0.12, 0.12, 0.14), Color(0.6, 0.35, 0.15), Color(0.45, 0.15, 0.4), Color(0.85, 0.85, 0.82),
]

const HP: float = 90.0
## Ram damage: impacts above this (m/s) hurt the car.
const CRASH_THRESHOLD: float = 7.0

var ai: TrafficAI
var color: Color = Color.WHITE
var health: HealthComponent
var is_destroyed: bool = false
## Set when the player's taxi (gun or bumper) last damaged this car.
var hurt_by_player: bool = false

var _body: MeshInstance3D
var _body_mat: Material
var _smoke: CPUParticles3D

static var _mats: Dictionary = {}


func _ready() -> void:
	collision_layer = 1 << 3
	collision_mask = 1 | 2 | 4 | 8 | 16 | 256
	mass = 900.0
	gravity_scale = 1.3
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -0.2, 0.0)
	continuous_cd = true
	angular_damp = 0.3
	max_speed = 16.0
	engine_force = 6500.0
	if color == Color.WHITE:
		color = COLORS.pick_random()
	_body_mat = _material(color)
	_body = EnemyCar.build_body(self, _body_mat)
	EnemyCar.build_wheels(self)
	health = HealthComponent.new()
	health.max_hp = HP
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_add_hitbox(Vector3(1.95, 1.35, 4.45), Vector3(0, 0.45, 0), 1.0)
	_add_hitbox(Vector3(0.6, 0.55, 0.6), Vector3(-0.4, 1.0, -0.05), 2.0)
	_smoke = CombatFx.make_particles("res://assets/materials/fx_smoke.tres", 10, 1.2, 0.35, 2.0)
	_smoke.position = Vector3(0, 0.6, -1.7)
	add_child(_smoke)
	ai = TrafficAI.new()
	ai.name = "AI"
	ai.car = self
	add_child(ai)
	input_provider = ai
	super._ready()
	crashed.connect(ai.on_crash)
	crashed.connect(_on_crash)


func _add_hitbox(size: Vector3, pos: Vector3, mult: float) -> void:
	var hitbox := Hitbox.new()
	hitbox.health = health
	hitbox.damage_multiplier = mult
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	hitbox.add_child(col)
	add_child(hitbox)
	hitbox.hit.connect(func(_damage: float, source: Vector3) -> void:
		hurt_by_player = _player_near(source, 4.0))


## True if the player's taxi is within `radius` of `point` (shots come from the driver's eye).
func _player_near(point: Vector3, radius: float) -> bool:
	if point == Vector3.INF:
		return false
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Node3D
	return taxi != null and taxi.global_position.distance_to(point) < radius


func _on_crash(impact: float) -> void:
	if impact <= CRASH_THRESHOLD or is_destroyed:
		return
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Node3D
	if taxi != null and taxi.global_position.distance_to(global_position) < 7.0:
		hurt_by_player = true
	health.apply_damage((impact - CRASH_THRESHOLD) * 5.0)


func _on_damaged(_amount: float, hp_left: float) -> void:
	if is_destroyed:
		return
	_smoke.emitting = hp_left < HP * 0.5
	_body.material_override = load("res://assets/materials/target_hit.tres")
	var flash := create_tween()
	flash.tween_interval(0.06)
	flash.tween_callback(func() -> void: _body.material_override = _body_mat)


func _on_died() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	if hurt_by_player:
		EventBus.civilian_killed.emit(global_position, &"car")
	CombatFx.explosion(get_parent(), global_position)
	EventBus.explosion.emit(global_position, 1.0)
	queue_free()


static func _material(c: Color) -> Material:
	var key := c.to_html()
	if not _mats.has(key):
		var m := (load("res://assets/materials/enemy_red.tres") as ShaderMaterial).duplicate() as ShaderMaterial
		m.set_shader_parameter(&"albedo", c)
		_mats[key] = m
	return _mats[key]
