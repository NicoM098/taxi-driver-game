class_name HealthComponent
extends Node
## Hit points for anything that can be damaged (targets, enemy cars, later the taxi/driver/passenger).

signal damaged(amount: float, hp_left: float)
signal died
signal healed(amount: float, hp_now: float)

@export var max_hp: float = 100.0

var hp: float = 0.0
var is_dead: bool = false


func _ready() -> void:
	hp = max_hp


func apply_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	damaged.emit(amount, hp)
	if hp <= 0.0:
		is_dead = true
		died.emit()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0 or hp >= max_hp:
		return
	var before := hp
	hp = minf(hp + amount, max_hp)
	healed.emit(hp - before, hp)


func revive() -> void:
	hp = max_hp
	is_dead = false
