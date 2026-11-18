class_name WaitingPassenger
extends Node3D
## A passenger waiting on the sidewalk at a TaxiStop, with a tall marker beam so it can be
## spotted from a distance. Also used (without a stop) for passengers walking away after a ride.

var profile: PassengerProfile
var stop: TaxiStop
var instance: PassengerInstance   # generated identity (name, age) for the file

var _marker: Node3D
## Rolling Pickup perk (D-100): a ring on the road at the stop; driving through it picks the
## fare up at any speed (RideManager), like the drop-off ring.
const ROLLING_RADIUS := 6.0
const ROLLING_COLOR := Color(1.0, 0.82, 0.1)
var _rolling_ring: PickupRing
var _perk_check: float = 0.0


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


## Where the rolling pickup ring sits: the stop's point on the street (or the passenger).
func pickup_point() -> Vector3:
	return stop.global_position if stop != null else global_position


func _process(delta: float) -> void:
	_perk_check -= delta
	if _perk_check > 0.0:
		return
	_perk_check = 0.5
	var on := CarUpgrades.has_perk(&"rolling_pickup") and _marker != null and _marker.visible
	if on and _rolling_ring == null:
		_rolling_ring = PickupRing.build(self, ROLLING_COLOR, ROLLING_RADIUS)
		_rolling_ring.global_position = pickup_point()
	if _rolling_ring != null:
		_rolling_ring.visible = on


## Frees the stop so other passengers can use it.
func release_stop() -> void:
	if stop != null:
		stop.occupied = false
		stop = null


func walk_to(target: Vector3, duration: float) -> Tween:
	if _marker != null:
		_marker.visible = false
	if _rolling_ring != null:
		_rolling_ring.visible = false
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)  # physics interpolation is on
	tween.tween_property(self, "global_position", target, duration)
	return tween
