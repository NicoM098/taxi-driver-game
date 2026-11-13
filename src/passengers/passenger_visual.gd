class_name PassengerVisual
extends RefCounted
## Builds the blockout body of a passenger (capsule torso + head), tinted per profile.

const BODY_MAT := "res://assets/materials/prop.tres"
const SKIN_MAT := "res://assets/materials/skin.tres"


## `seated` = short torso for the back seat (no vertex wobble: it sits right behind the camera).
static func build(color: Color, seated: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "PassengerVisual"
	var body_mat := (load(BODY_MAT) as ShaderMaterial).duplicate() as ShaderMaterial
	body_mat.set_shader_parameter(&"albedo", color)
	var skin_mat := load(SKIN_MAT) as ShaderMaterial
	if seated:
		body_mat.set_shader_parameter(&"snap_multiplier", 0.0)
		skin_mat = skin_mat.duplicate() as ShaderMaterial
		skin_mat.set_shader_parameter(&"snap_multiplier", 0.0)

	var torso := CapsuleMesh.new()
	torso.radius = 0.24 if seated else 0.28
	torso.height = 0.5 if seated else 1.3
	torso.radial_segments = 8
	torso.rings = 2
	Blockout.add_mesh(root, torso, Vector3(0.0, torso.height * 0.5, 0.0), body_mat)

	var head := SphereMesh.new()
	head.radius = 0.13 if seated else 0.17
	head.height = head.radius * 2.0
	head.radial_segments = 8
	head.rings = 4
	Blockout.add_mesh(root, head, Vector3(0.0, torso.height + head.radius * 0.9, 0.0), skin_mat)
	return root
