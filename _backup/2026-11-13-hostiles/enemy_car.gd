class_name EnemyCar
extends Taxi
## AI-driven enemy vehicle (Phase 06). Reuses the Taxi raycast physics (same handling family)
## and builds its own blockout body, wheels, hitboxes, health, AI driver and gunman in code
## from an EnemyCarData. Physics layer 3 (enemy_vehicles).

signal destroyed(car: EnemyCar)

const WHEELS := [[-0.82, -1.35, true], [0.82, -1.35, true], [-0.82, 1.35, false], [0.82, 1.35, false]]

@export var data: EnemyCarData
var target: Taxi
var health: HealthComponent
var is_destroyed: bool = false
var ai: EnemyDriverAI
var gunner: EnemyGunner
## Times the EnemyDirector may still put this car back on the player's tail after it was
## outrun (pursuers do not give up when the fare is delivered).
var relocations_left: int = 0
var relocated_frame: int = -100000   # physics frame of the last relocation (teleports are deferred)

var _body: MeshInstance3D
var _body_mat: Material
var _fire: CPUParticles3D
var _smoke: CPUParticles3D


func _ready() -> void:
	if data == null:
		data = load("res://data/enemies/hitman_sedan.tres")
	collision_layer = 1 << 2
	collision_mask = 1 | 2 | 4 | 8 | 16 | 256
	mass = 800.0  # lighter than the taxi (1000): you can shove them instead of getting pinned
	gravity_scale = 1.3
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -0.2, 0.0)
	continuous_cd = true
	angular_damp = 0.3
	max_speed = data.max_speed
	engine_force = data.engine_force
	_build_body()
	_build_wheels()

	health = HealthComponent.new()
	health.max_hp = data.hp
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_add_hitbox(Vector3(1.95, 1.35, 4.45), Vector3(0, 0.45, 0), 1.0)
	_add_hitbox(Vector3(0.6, 0.55, 0.6), Vector3(-0.4, 1.0, -0.05), 2.5).name = "DriverHitbox"

	_smoke = CombatFx.make_particles("res://assets/materials/fx_smoke.tres", 12, 1.2, 0.35, 2.0)
	_smoke.position = Vector3(0, 0.6, -1.7)
	add_child(_smoke)
	_fire = CombatFx.make_particles("res://assets/materials/fx_fire.tres", 20, 0.7, 0.35, 3.0)
	_fire.position = Vector3(0, 0.7, 0)
	add_child(_fire)

	ai = EnemyDriverAI.new()
	ai.name = "AI"
	ai.car = self
	add_child(ai)
	input_provider = ai
	gunner = EnemyGunner.new()
	gunner.name = "Gunner"
	gunner.car = self
	add_child(gunner)
	super._ready()
	crashed.connect(_on_crash)


func _build_body() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.7, 0.8, 4.2)
	col.shape = shape
	col.position.y = 0.1
	add_child(col)
	var cabin_col := CollisionShape3D.new()
	var cabin_shape := BoxShape3D.new()
	cabin_shape.size = Vector3(1.5, 0.6, 2.0)
	cabin_col.shape = cabin_shape
	cabin_col.position = Vector3(0, 0.8, 0.3)
	add_child(cabin_col)

	_body_mat = load(data.body_material)
	var lower := BoxMesh.new()
	lower.size = Vector3(1.8, 0.8, 4.3)
	_body = Blockout.add_mesh(self, lower, Vector3(0, 0.1, 0), _body_mat)
	var cabin := BoxMesh.new()
	cabin.size = Vector3(1.6, 0.6, 2.0)
	Blockout.add_mesh(self, cabin, Vector3(0, 0.8, 0.3), load("res://assets/materials/taxi_black.tres"))
	if data.siren:
		var light := BoxMesh.new()
		light.size = Vector3(0.4, 0.15, 0.25)
		Blockout.add_mesh(self, light, Vector3(-0.25, 1.18, 0.3), load("res://assets/materials/siren_red.tres"))
		Blockout.add_mesh(self, light, Vector3(0.25, 1.18, 0.3), load("res://assets/materials/siren_blue.tres"))


func _build_wheels() -> void:
	var tyre := CylinderMesh.new()
	tyre.top_radius = 0.35
	tyre.bottom_radius = 0.35
	tyre.height = 0.25
	tyre.radial_segments = 8
	tyre.rings = 1
	var tyre_mat: Material = load("res://assets/materials/taxi_black.tres")
	var wheels_root := Node3D.new()
	wheels_root.name = "Wheels"
	add_child(wheels_root)
	for w: Array in WHEELS:
		var wheel := TaxiWheel.new()
		wheel.position = Vector3(w[0], 0.0, w[1])
		wheel.is_front = w[2]
		var visual := Node3D.new()
		wheel.add_child(visual)
		var mesh := Blockout.add_mesh(visual, tyre, Vector3.ZERO, tyre_mat)
		mesh.rotation = Vector3(0.0, 0.0, PI * 0.5)
		wheel.visual = visual
		wheels_root.add_child(wheel)


func _add_hitbox(size: Vector3, pos: Vector3, mult: float) -> Hitbox:
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
	return hitbox


func _on_crash(impact: float) -> void:
	if impact > 6.0:
		health.apply_damage((impact - 6.0) * 4.0)


func _on_damaged(_amount: float, hp_left: float) -> void:
	_smoke.emitting = hp_left < health.max_hp * 0.5 and not is_destroyed
	if is_destroyed:
		return
	_body.material_override = load("res://assets/materials/target_hit.tres")
	var flash := create_tween()  # bound to this car: dies with it (safe if it explodes)
	flash.tween_interval(0.06)
	flash.tween_callback(func() -> void: _body.material_override = _body_mat)


## Killed: explode and vanish instantly (user feedback: wrecks pinned the taxi).
func _on_died() -> void:
	is_destroyed = true
	EventBus.enemy_destroyed.emit(self, data.bounty)
	destroyed.emit(self)
	CombatFx.explosion(get_parent(), global_position)
	EventBus.explosion.emit(global_position, 1.0)
	queue_free()
