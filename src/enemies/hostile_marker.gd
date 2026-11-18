class_name HostileMarker
extends Node3D
## Red down-pointing marker floating over every hostile car (user request 2026-11-15: enemy cars
## "can be confused with the civil ones" since civilian traffic is destructible too).
## Unshaded so it reads at night, bobs and spins so it reads as UI and not as part of the car,
## and grows with distance so it is still a few pixels tall at the PS1 240p resolution.
## Civilian TrafficCars never get one.
## Bosses (D-102, user: "clearer markers for the bosses") get a bigger gold cone, a gold beam
## into the sky that shows over the buildings, and a "BOSS" tag with the car's name that is
## drawn on top of everything at a fixed screen size.

const HEIGHT: float = 2.5
const NEAR: float = 12.0        # full size up to here...
const MAX_SCALE: float = 4.0    # ...then grows up to this
const COLOR := Color(1.0, 0.12, 0.08)
const BOSS_COLOR := Color(1.0, 0.78, 0.1)
const BOSS_SCALE := 1.7
const BEAM_HEIGHT := 60.0

static var _mat: StandardMaterial3D
static var _boss_mat: StandardMaterial3D
static var _beam_mat: StandardMaterial3D

## Set before it enters the tree (EnemyCar does it from EnemyCarData.is_boss).
var boss: bool = false
var boss_name: String = ""

var _t: float = 0.0
var _mesh: MeshInstance3D
var _beam: MeshInstance3D
var _tag: Label3D


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
	if boss:
		_build_boss()


## Turns an ordinary marker into a boss one (D-106: the stage-2 gang bosses in their fight).
func make_boss(display_name: String) -> void:
	if boss and _tag != null:
		return
	boss = true
	boss_name = display_name
	if _mesh != null:
		_build_boss()


func _build_boss() -> void:
	if _boss_mat == null:
		_boss_mat = StandardMaterial3D.new()
		_boss_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_boss_mat.albedo_color = BOSS_COLOR
		_boss_mat.disable_fog = true
		_beam_mat = StandardMaterial3D.new()
		_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_beam_mat.albedo_color = Color(BOSS_COLOR, 0.45)
		_beam_mat.disable_fog = true
		_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = _boss_mat
	var beam := CylinderMesh.new()
	beam.top_radius = 0.5
	beam.bottom_radius = 0.5
	beam.height = BEAM_HEIGHT
	beam.radial_segments = 6
	beam.rings = 1
	_beam = MeshInstance3D.new()
	_beam.mesh = beam
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position.y = 1.0 + BEAM_HEIGHT * 0.5
	add_child(_beam)
	_tag = Label3D.new()
	_tag.text = "BOSS" if boss_name == "" else "BOSS\n%s" % boss_name.to_upper()
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = true
	_tag.pixel_size = 0.0018
	_tag.font_size = 30
	_tag.outline_size = 10
	_tag.modulate = BOSS_COLOR
	_tag.outline_modulate = Color(0, 0, 0, 0.95)
	_tag.render_priority = 10
	_tag.outline_render_priority = 9
	_tag.position.y = 1.6
	add_child(_tag)


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
	_mesh.scale = Vector3.ONE * s * (BOSS_SCALE if boss else 1.0)
	if _tag != null:
		_tag.position.y = 1.0 + 0.9 * s * BOSS_SCALE
		# Thin the beam out up close, where it would fill the windscreen.
		_beam.visible = cam == null or cam.global_position.distance_to(global_position) > 18.0
