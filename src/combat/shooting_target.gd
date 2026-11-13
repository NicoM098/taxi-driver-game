class_name ShootingTarget
extends Node3D
## Range target board on a post. Flashes on hit, falls over when killed, stands back up.

@export var max_hp: float = 40.0
@export var board_height: float = 1.6     # centre of the board above the node origin
@export var respawn_time: float = 3.0

var health: HealthComponent

var _board_pivot: Node3D
var _board: MeshInstance3D
var _mat_normal: Material
var _mat_hit: Material
var _mat_dead: Material


func _ready() -> void:
	_mat_normal = load("res://assets/materials/target_red.tres")
	_mat_hit = load("res://assets/materials/target_hit.tres")
	_mat_dead = load("res://assets/materials/target_dead.tres")
	health = HealthComponent.new()
	health.max_hp = max_hp
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)

	var post := Blockout.add_box(self, Vector3(0, board_height * 0.5 - 0.4, 0), Vector3(0.12, board_height - 0.8, 0.12),
		load("res://assets/materials/prop.tres"))
	post.name = "Post"
	# Board hinges at its bottom edge so it can fall backwards.
	_board_pivot = Node3D.new()
	_board_pivot.position = Vector3(0, board_height - 0.8, 0)
	add_child(_board_pivot)
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(1.2, 1.6, 0.08)
	_board = Blockout.add_mesh(_board_pivot, board_mesh, Vector3(0, 0.8, 0), _mat_normal)
	var bullseye := BoxMesh.new()
	bullseye.size = Vector3(0.4, 0.4, 0.1)
	Blockout.add_mesh(_board_pivot, bullseye, Vector3(0, 0.9, 0), load("res://assets/materials/target_white.tres"))

	var hitbox := Hitbox.new()
	hitbox.health = health
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 1.7, 0.3)
	shape.shape = box
	shape.position = Vector3(0, 0.8, 0)
	hitbox.add_child(shape)
	_board_pivot.add_child(hitbox)


func _on_damaged(_amount: float, _hp_left: float) -> void:
	if health.is_dead:
		return
	_board.material_override = _mat_hit
	get_tree().create_timer(0.07, false, true).timeout.connect(func() -> void:
		if not health.is_dead:
			_board.material_override = _mat_normal)


func _on_died() -> void:
	_board.material_override = _mat_dead
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_board_pivot, "rotation:x", deg_to_rad(-85.0), 0.25).set_ease(Tween.EASE_IN)
	tween.tween_interval(respawn_time)
	tween.tween_property(_board_pivot, "rotation:x", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		health.revive()
		_board.material_override = _mat_normal)
