class_name RearMirror
extends Node3D
## Working rear-view mirror: a low-res SubViewport camera near the rear window looking back,
## shown (flipped, like a real mirror) on a quad in the cab. Shares the world, so pursuers show.

@export var resolution: Vector2i = Vector2i(192, 64)
@export var mirror_size: Vector2 = Vector2(0.46, 0.15)
@export var camera_offset: Vector3 = Vector3(0.0, 1.05, 1.45)   # taxi-local, behind the rear bench
@export var camera_fov: float = 60.0
@export var camera_far: float = 160.0

var _viewport: SubViewport
var _camera: Camera3D
var _vehicle: Node3D


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_vehicle = owner as Node3D if owner is Node3D else get_parent().get_parent() as Node3D
	_viewport = SubViewport.new()
	_viewport.size = resolution
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = camera_fov
	_camera.far = camera_far
	_camera.near = 0.3
	_camera.current = true
	_viewport.add_child(_camera)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _viewport.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(-1.0, 1.0, 1.0)   # mirror image
	mat.uv1_offset = Vector3(1.0, 0.0, 0.0)
	var quad := QuadMesh.new()
	quad.size = mirror_size
	var glass := MeshInstance3D.new()
	glass.name = "Glass"
	glass.mesh = quad
	glass.material_override = mat
	glass.rotation = Vector3(0.0, 0.0, 0.0)   # quad faces +Z = towards the driver
	glass.position = Vector3(0.0, 0.0, 0.011)
	add_child(glass)
	var frame := BoxMesh.new()
	frame.size = Vector3(mirror_size.x + 0.04, mirror_size.y + 0.04, 0.02)
	Blockout.add_mesh(self, frame, Vector3.ZERO, load("res://assets/materials/taxi_black.tres"))


func _process(_delta: float) -> void:
	if _vehicle == null:
		return
	# Looking backwards from behind the rear bench (rotated 180° about the car's up axis).
	var xform := _vehicle.global_transform
	_camera.global_transform = Transform3D(xform.basis * Basis(Vector3.UP, PI), xform * camera_offset)
