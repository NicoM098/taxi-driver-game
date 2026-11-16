class_name SkidMarks
extends Node
## Rubber left on the road while the rear wheels slide (D-081). A child of `taxi.tscn`, so only
## the player leaves marks — `TrafficCar extends Taxi`, and thirteen civilians each laying trails
## would cost more than it is worth.
##
## One `MultiMeshInstance3D` lives in the world (the marks stay where they were laid, not with the
## car) and is a fixed ring buffer: the oldest stamp is overwritten rather than freed, which is
## both how the era this game copies did it and why it cannot leak.

@export var taxi: Taxi
## Rear sideways slip (m/s) at which rubber starts coming off.
@export var slip_threshold: float = 2.0
@export var capacity: int = 480
## Metres between stamps: closer and it is a solid smear, farther and it is dashes.
@export var spacing: float = 0.3
## Above the contact point. The asphalt z-fights easily (KI-017), so the marks sit clear of it.
@export var lift: float = 0.035

var _mmi: MultiMeshInstance3D
var _next: int = 0
var _last_at: Dictionary = {}    # wheel -> last stamp position
var _rear: Array[TaxiWheel] = []


func _ready() -> void:
	if taxi == null:
		taxi = get_parent() as Taxi
	if taxi == null:
		return
	await taxi.ready
	for wheel in taxi.wheels:
		if not wheel.is_front:
			_rear.append(wheel)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.85)
	quad.orientation = PlaneMesh.FACE_Y
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = capacity
	# A zero basis makes an instance degenerate, i.e. invisible: MultiMesh has no per-instance
	# visibility flag.
	for i in capacity:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "SkidMarks"
	_mmi.multimesh = mm
	_mmi.material_override = load("res://assets/materials/skid.tres")
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var world := taxi.get_parent()
	if world != null:
		# Deferred: when the taxi is spawned as part of the world scene loading, that parent is
		# still setting up its own children and a direct add_child() is refused.
		world.add_child.call_deferred(_mmi)


func _physics_process(_delta: float) -> void:
	if _mmi == null or not is_instance_valid(_mmi) or taxi == null:
		return
	for wheel in _rear:
		if not wheel.is_grounded or absf(wheel.lateral_slip) < slip_threshold:
			continue
		var point := wheel.get_collision_point() + Vector3.UP * lift
		var last: Variant = _last_at.get(wheel)
		if last != null and point.distance_to(last) < spacing:
			continue
		_last_at[wheel] = point
		_stamp(point)


func _stamp(point: Vector3) -> void:
	var basis := Basis(Vector3.UP, taxi.global_rotation.y)
	_mmi.multimesh.set_instance_transform(_next, Transform3D(basis, point))
	_next = (_next + 1) % capacity
