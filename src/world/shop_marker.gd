class_name ShopMarker
extends Node3D
## The ring on the ground and the tall beam that mark a shop's pad (repair shop, gun shop), so a
## shop reads from across the city like a taxi stop does. Same colours as the minimap's shop
## squares. Visual only: no collision.
##
## The beam hides while the taxi is inside the ring, or it would fill the windshield.

const BEAM_HEIGHT := 40.0
const BEAM_RADIUS := 0.55
const RING_THICKNESS := 0.9

var _beam: MeshInstance3D
var _ring: MeshInstance3D
var _colour: Color
var _mat: ShaderMaterial
var _alerting: bool = false


## `pos` is the pad centre (global, y = 0), `radius` how close the taxi has to be.
func setup(pos: Vector3, radius: float, colour: Color) -> void:
	_colour = colour
	_mat = (MapBuilder.mat("beacon_green") as ShaderMaterial).duplicate() as ShaderMaterial
	_mat.set_shader_parameter(&"albedo", colour)

	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = BEAM_RADIUS
	beam_mesh.bottom_radius = BEAM_RADIUS
	beam_mesh.height = BEAM_HEIGHT
	beam_mesh.radial_segments = 6
	beam_mesh.rings = 1
	_beam = MeshInstance3D.new()
	_beam.mesh = beam_mesh
	_beam.material_override = _mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position = Vector3(0, BEAM_HEIGHT * 0.5, 0)
	add_child(_beam)

	var ring_mesh := TorusMesh.new()
	ring_mesh.outer_radius = radius
	ring_mesh.inner_radius = radius - RING_THICKNESS
	ring_mesh.rings = 40
	ring_mesh.ring_segments = 4
	_ring = MeshInstance3D.new()
	_ring.mesh = ring_mesh
	_ring.material_override = _mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Flattened so it lies on the asphalt as a painted circle, just above the pad's markings.
	_ring.scale = Vector3(1, 0.3, 1)
	_ring.position = Vector3(0, 0.16, 0)
	add_child(_ring)

	global_position = pos


## Called by the shop every physics frame.
func update(taxi_on_pad: bool, alert: bool = false, alert_colour: Color = Color(1.0, 0.2, 0.15)) -> void:
	if _beam == null:
		return
	_beam.visible = not taxi_on_pad
	if alert != _alerting:
		_alerting = alert
		_mat.set_shader_parameter(&"albedo", alert_colour if alert else _colour)
