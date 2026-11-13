class_name WaitingPassenger
extends Node3D
## A passenger waiting on the sidewalk at a TaxiStop, with a tall marker beam so it can be
## spotted from a distance. Also used (without a stop) for passengers walking away after a ride.

var profile: PassengerProfile
var stop: TaxiStop
var instance: PassengerInstance   # generated identity (name, age) for the file

var _marker: Node3D


func setup(p_profile: PassengerProfile, p_stop: TaxiStop, beam_mat: Material) -> void:
	profile = p_profile
	stop = p_stop
	if stop != null:
		stop.occupied = true
		global_position = stop.sidewalk_point
	add_child(PassengerVisual.build(profile.color))
	if beam_mat != null:
		_marker = Node3D.new()
		add_child(_marker)
		var beam := CylinderMesh.new()
		beam.top_radius = 0.45
		beam.bottom_radius = 0.45
		beam.height = 25.0
		beam.radial_segments = 6
		beam.rings = 1
		Blockout.add_mesh(_marker, beam, Vector3(0.0, 14.5, 0.0), beam_mat)
		var diamond := BoxMesh.new()
		diamond.size = Vector3(0.35, 0.35, 0.35)
		var gem := Blockout.add_mesh(_marker, diamond, Vector3(0.0, 2.2, 0.0), beam_mat)
		gem.rotation = Vector3(PI * 0.25, 0.0, PI * 0.25)


## Frees the stop so other passengers can use it.
func release_stop() -> void:
	if stop != null:
		stop.occupied = false
		stop = null


func walk_to(target: Vector3, duration: float) -> Tween:
	if _marker != null:
		_marker.visible = false
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)  # physics interpolation is on
	tween.tween_property(self, "global_position", target, duration)
	return tween
