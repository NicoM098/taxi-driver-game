class_name PickupRing
extends Node3D
## The glowing circle on the ground under a floating pickup (energy can, ammo drops, D-094):
## a thin bright ring around a faint disc, slowly pulsing. Unshaded, so it reads at night too.

var _ring: MeshInstance3D
var _time: float = 0.0


## A ring of `radius` metres in `color`, added to `parent` at ground level (its local y = 0).
static func build(parent: Node3D, color: Color, radius: float = 1.8) -> PickupRing:
	var r := PickupRing.new()
	r.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(r)
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.22
	torus.outer_radius = radius
	torus.rings = 32
	torus.ring_segments = 4
	r._ring = MeshInstance3D.new()
	r._ring.mesh = torus
	r._ring.scale = Vector3(1.0, 0.2, 1.0)
	r._ring.position.y = 0.06
	r._ring.material_override = _mat(Color(color, 0.95))
	r._ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(r._ring)
	var disc := CylinderMesh.new()
	disc.top_radius = radius - 0.1
	disc.bottom_radius = radius - 0.1
	disc.height = 0.02
	disc.radial_segments = 32
	disc.rings = 1
	var d := MeshInstance3D.new()
	d.mesh = disc
	d.position.y = 0.04
	d.material_override = _mat(Color(color, 0.28))
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(d)
	return r


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m


func _process(delta: float) -> void:
	_time += delta
	var s := 1.0 + sin(_time * 3.0) * 0.06
	_ring.scale = Vector3(s, 0.2, s)
