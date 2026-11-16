class_name StyleMeter
extends Node
## The player's stunt meter (D-081): air time and near misses. A child of `taxi.tscn`, the way
## [DriftChain] is, and for the same reason — `TrafficCar extends Taxi`, so anything put on the
## Taxi script itself would fire for every civilian car on the street.
##
## Both stunts announce themselves through `EventBus.style_earned`; [RideManager] turns the points
## into money and the HUD shows the popup. Nothing here knows about cash or UI.

@export var taxi: Taxi

@export_group("Air time")
## Below this a jump is just a bump in the road.
@export var min_air_time: float = 0.45
@export var min_air_speed: float = 8.0          # m/s on take-off
@export var air_points_per_second: float = 30.0
## A long jump is worth more than two short ones: time counts a little more than linearly.
@export var air_time_exponent: float = 1.3

@export_group("Near miss")
@export var near_miss_radius: float = 3.1       # from the taxi's centre to theirs
## Crawling past a parked car is not a near miss.
@export var min_relative_speed: float = 9.0     # m/s
@export var near_miss_points: float = 40.0
## Per car, so one long overtake cannot machine-gun popups.
@export var near_miss_cooldown: float = 2.5
@export var scan_interval: float = 0.12

## traffic | enemy cars
const CAR_MASK: int = (1 << 2) | (1 << 3)

var _air_time: float = 0.0
var _air_speed: float = 0.0
var _was_airborne: bool = false
var _scan_left: float = 0.0
var _recent: Dictionary = {}    # car RID -> seconds left before it can score again
var _query := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	if taxi == null:
		taxi = get_parent() as Taxi
	var sphere := SphereShape3D.new()
	sphere.radius = near_miss_radius
	_query.shape = sphere
	_query.collision_mask = CAR_MASK
	_query.collide_with_areas = false


func _physics_process(delta: float) -> void:
	if taxi == null or not taxi.is_inside_tree():
		return
	_update_air_time(delta)
	_update_near_misses(delta)


# --- Air time ------------------------------------------------------------------------

func _update_air_time(delta: float) -> void:
	var airborne := taxi.grounded_wheel_count == 0
	if airborne:
		if not _was_airborne:
			_air_speed = absf(taxi.forward_speed)
		_air_time += delta
		_was_airborne = true
		return
	if not _was_airborne:
		return
	# Landed.
	_was_airborne = false
	var flight := _air_time
	_air_time = 0.0
	if flight < min_air_time or _air_speed < min_air_speed:
		return
	var points := air_points_per_second * pow(flight, air_time_exponent)
	var label := "CRAZY JUMP" if flight < 1.2 else "HUGE AIR"
	EventBus.style_earned.emit(&"air", "%s  %.1fs" % [label, flight], points)
	var shift := get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
	if shift != null:
		shift.register_air_time(flight)


# --- Near misses ---------------------------------------------------------------------

func _update_near_misses(delta: float) -> void:
	for rid: RID in _recent.keys():
		_recent[rid] -= delta
		if _recent[rid] <= 0.0:
			_recent.erase(rid)
	_scan_left -= delta
	if _scan_left > 0.0:
		return
	_scan_left = scan_interval
	if absf(taxi.forward_speed) < min_relative_speed * 0.5:
		return
	_query.transform = Transform3D(Basis.IDENTITY, taxi.global_position)
	_query.exclude = [taxi.get_rid()]
	for hit: Dictionary in taxi.get_world_3d().direct_space_state.intersect_shape(_query, 8):
		var body := hit["collider"] as RigidBody3D
		if body == null or _recent.has(body.get_rid()):
			continue
		# Scraping past at the same speed is not a near miss; the closing speed is the thrill.
		# Scraping past at the same speed is not a near miss; the closing speed is the thrill.
		if (body.linear_velocity - taxi.linear_velocity).length() < min_relative_speed:
			continue
		_recent[body.get_rid()] = near_miss_cooldown
		EventBus.style_earned.emit(&"near_miss", "NEAR MISS", near_miss_points)
