class_name TaxiWheel
extends RayCast3D
## One raycast wheel: ground probe + per-wheel state + visual. Forces are computed by Taxi.

@export var is_front: bool = false
@export var is_driven: bool = true
@export var visual: Node3D

var is_grounded: bool = false
var suspension_length: float = 0.0  # mount -> wheel centre (m)
var load_force: float = 0.0          # suspension force this tick (N)
var lateral_slip: float = 0.0        # sideways speed at contact (m/s)
var steer_angle: float = 0.0         # rad, + = left

var _spin: float = 0.0


func setup(body: CollisionObject3D, rest_length: float, radius: float) -> void:
	add_exception(body)
	target_position = Vector3(0.0, -(rest_length + radius), 0.0)
	suspension_length = rest_length
	enabled = true


func update_visual(delta: float, rest_length: float, radius: float, forward_speed: float) -> void:
	if visual == null:
		return
	var length := suspension_length if is_grounded else rest_length
	visual.position = Vector3(0.0, -length, 0.0)
	# Rolling forward (-Z) = negative rotation about X.
	_spin = wrapf(_spin - forward_speed / radius * delta, 0.0, TAU)
	visual.rotation = Vector3(_spin, steer_angle, 0.0)
