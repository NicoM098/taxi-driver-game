extends Node3D
## First-person "crack and drink": when an energy drink is consumed, a can rises from the lower
## left, tilts to the mouth, chugs, and drops away. Child of the cab Camera3D.

const DURATION := 1.3

var _can: Node3D
var _tween: Tween


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_can = Node3D.new()
	add_child(_can)
	EnergyDrinkPickup.build_can(_can, 0.16, true)
	_can.visible = false
	EventBus.energy_drink_consumed.connect(play)


func play() -> void:
	if _tween != null:
		_tween.kill()
	_can.visible = true
	_can.position = Vector3(-0.32, -0.45, -0.5)
	_can.rotation = Vector3(0.0, 0.0, 0.3)
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Up into view and *crack*.
	_tween.tween_property(_can, "position", Vector3(-0.18, -0.16, -0.42), 0.25)
	_tween.tween_property(_can, "rotation", Vector3(0.0, 0.0, 0.15), 0.08)
	# To the mouth, tilt back and chug.
	_tween.tween_property(_can, "position", Vector3(-0.13, -0.11, -0.3), 0.2)
	_tween.parallel().tween_property(_can, "rotation", Vector3(1.9, 0.0, 0.1), 0.2)
	_tween.tween_property(_can, "rotation", Vector3(2.2, 0.0, 0.0), DURATION - 0.75)
	# Done: drop it.
	_tween.tween_property(_can, "position", Vector3(-0.35, -0.6, -0.4), 0.22).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void: _can.visible = false)
