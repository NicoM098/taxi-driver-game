class_name TargetCar
extends AnimatableBody3D
## Moving range target: a red blockout car driving in a circle. Body hitbox + small "driver"
## hitbox (x2.5 damage). Stops and goes black when destroyed, then respawns.
## Physics layer 3 (enemy_vehicles) so the taxi can ram it.

@export var center: Vector3 = Vector3.ZERO
@export var radius: float = 22.0
@export var speed: float = 12.0           # m/s along the circle
@export var start_angle: float = 0.0
@export var max_hp: float = 120.0
@export var respawn_time: float = 5.0

var health: HealthComponent

var _angle: float = 0.0
var _body_mesh: MeshInstance3D
var _mat_normal: Material
var _mat_dead: Material
var _mat_hit: Material


func _ready() -> void:
	collision_layer = 1 << 2
	collision_mask = 0
	sync_to_physics = true
	_angle = start_angle
	_mat_normal = load("res://assets/materials/enemy_red.tres")
	_mat_dead = load("res://assets/materials/target_dead.tres")
	_mat_hit = load("res://assets/materials/target_hit.tres")
	health = HealthComponent.new()
	health.max_hp = max_hp
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 1.2, 4.2)
	col.shape = shape
	col.position.y = 0.6
	add_child(col)
	var body := BoxMesh.new()
	body.size = Vector3(1.8, 0.8, 4.2)
	_body_mesh = Blockout.add_mesh(self, body, Vector3(0, 0.4, 0), _mat_normal)
	var cabin := BoxMesh.new()
	cabin.size = Vector3(1.6, 0.6, 2.0)
	Blockout.add_mesh(self, cabin, Vector3(0, 1.1, 0.3), load("res://assets/materials/taxi_black.tres"))

	_add_hitbox(Vector3(1.9, 1.5, 4.3), Vector3(0, 0.7, 0), 1.0)
	var head := _add_hitbox(Vector3(0.5, 0.5, 0.5), Vector3(-0.4, 1.25, -0.1), 2.5)
	head.name = "DriverHitbox"
	_place()


func _physics_process(delta: float) -> void:
	if health.is_dead:
		return
	_angle += speed / radius * delta
	_place()


func _place() -> void:
	var pos := center + Vector3(cos(_angle), 0.0, sin(_angle)) * radius
	var tangent := Vector3(-sin(_angle), 0.0, cos(_angle))  # direction of travel
	global_transform = Transform3D(Basis.looking_at(tangent, Vector3.UP), pos)


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


func _on_damaged(_amount: float, _hp_left: float) -> void:
	if health.is_dead:
		return
	_body_mesh.material_override = _mat_hit
	get_tree().create_timer(0.07, false, true).timeout.connect(func() -> void:
		if not health.is_dead:
			_body_mesh.material_override = _mat_normal)


func _on_died() -> void:
	_body_mesh.material_override = _mat_dead
	get_tree().create_timer(respawn_time, false, true).timeout.connect(func() -> void:
		health.revive()
		_body_mesh.material_override = _mat_normal)
