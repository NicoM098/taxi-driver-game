extends Node3D
## Classic top-centre guide arrow. Child of the Camera3D, so it stays at the top centre of the
## screen whatever you look at. The arrow is a flat plate tilted to face the viewer and rotated
## within that plate by the target's direction relative to the view:
## ahead = tip recedes up/away, right = right, behind = tip comes down/towards you.
## Two-tone (bright head, dark tail) so the pointing end is obvious even when foreshortened.
## Yellow = nearest waiting passenger, green = destination. Hidden when there is no target.

@export var green_material: Material
@export var yellow_material: Material
@export var green_dark_material: Material
@export var yellow_dark_material: Material
## How much the arrow plate is tilted up towards the viewer (0 = lying flat, 90 = facing the
## screen). Low values give a clear 3D "on the ground" read of forward vs backward.
@export var tilt_view_deg: float = 40.0
## Debug/screenshot override: if not NAN, point at this relative angle (deg, + = left).
var debug_angle_deg: float = NAN

var _head: MeshInstance3D
var _shaft: MeshInstance3D
var _kind: StringName = &""


func _ready() -> void:
	# Re-aimed every rendered frame together with the head camera.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_head = get_node_or_null("Head") as MeshInstance3D
	_shaft = get_node_or_null("Shaft") as MeshInstance3D
	visible = false


func _process(_delta: float) -> void:
	var view := get_parent() as Node3D
	if not is_nan(debug_angle_deg):
		visible = true
		_set_kind(&"destination")
		_orient(deg_to_rad(debug_angle_deg))
		return
	var manager := get_tree().get_first_node_in_group(&"ride_manager") as RideManager
	var target: Dictionary = manager.get_guide_target() if manager != null else {}
	if target.is_empty() or view == null:
		visible = false
		return
	visible = true
	_set_kind(target["kind"])

	var view_fwd := -view.global_basis.z
	view_fwd.y = 0.0
	var to_target: Vector3 = (target["pos"] as Vector3) - view.global_position
	to_target.y = 0.0
	if view_fwd.length() < 0.01 or to_target.length() < 0.5:
		return
	_orient(view_fwd.normalized().signed_angle_to(to_target.normalized(), Vector3.UP))  # + = left


func _orient(relative: float) -> void:
	quaternion = Quaternion(Basis(Vector3.RIGHT, deg_to_rad(tilt_view_deg)) * Basis(Vector3.UP, relative))


func _set_kind(kind: StringName) -> void:
	if kind == _kind:
		return
	_kind = kind
	var dest := kind == &"destination"
	if _head != null:
		_head.material_override = green_material if dest else yellow_material
	if _shaft != null:
		_shaft.material_override = green_dark_material if dest else yellow_dark_material
