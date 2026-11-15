class_name HostileMarker
extends Node3D
## Red down-pointing marker floating over every hostile car (user request 2026-11-15: enemy cars
## "can be confused with the civil ones" since civilian traffic is destructible too).
## Unshaded so it reads at night, bobs and spins so it reads as UI and not as part of the car,
## and grows with distance so it is still a few pixels tall at the PS1 240p resolution.
## Civilian TrafficCars never get one.

const HEIGHT: float = 2.5
const NEAR: float = 12.0        # full size up to here...
const MAX_SCALE: float = 4.0    # ...then grows up to this
const COLOR := Color(1.0, 0.12, 0.08)

static var _mat: StandardMaterial3D

var _t: float = 0.0
var _mesh: MeshInstance3D


func _ready() -> void:
	name = "HostileMarker"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	position = Vector3(0, HEIGHT, 0)
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.albedo_color = COLOR
		_mat.disable_fog = true
	var cone := CylinderMesh.new()
	cone.top_radius = 0.55
	cone.bottom_radius = 0.0      # point down at the car
	cone.height = 0.9
	cone.radial_segments = 4
	cone.rings = 1
	_mesh = MeshInstance3D.new()
	_mesh.mesh = cone
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	# Stay upright and above the car even when it rolls or flips.
	var car := get_parent() as Node3D
	if car != null:
		global_transform = Transform3D(Basis.IDENTITY, car.global_position + Vector3(0, HEIGHT + sin(_t * 3.0) * 0.18, 0))
	_mesh.rotation.y = _t * 2.2
	var cam := get_viewport().get_camera_3d()
	var s := 1.0
	if cam != null:
		s = clampf(cam.global_position.distance_to(global_position) / NEAR, 1.0, MAX_SCALE)
	_mesh.scale = Vector3.ONE * s
