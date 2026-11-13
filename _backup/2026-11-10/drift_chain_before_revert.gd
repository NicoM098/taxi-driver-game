class_name DriftChain
extends Node
## Side-to-side drift chain (GDD §3b). Child of a Taxi.
## - A drift = taxi.is_drifting; its direction = sign of the rear wheels' sideways slip.
## - A *link* = a drift in the opposite direction started within `chain_window` seconds of the
##   previous one (or a direct flick from one side to the other).
## - multiplier = 1 + links * step (capped). Style points accrue while drifting x multiplier.
## - Each link gives a forward speed kick + temporary top-speed bonus (keeps momentum).
## - Chain ends cleanly when the window runs out -> chain_banked. A hard crash -> chain_broken.

signal chain_link(links: int, multiplier: float)
signal chain_banked(points: float, links: int)
signal chain_broken(points: float)

@export var taxi: Taxi
@export var chain_window: float = 1.0
@export var multiplier_step: float = 0.25
@export var max_multiplier: float = 3.0
@export var points_per_second: float = 10.0
@export var min_drift_speed: float = 5.0        # m/s
@export var min_drift_time_for_link: float = 0.2
@export_group("Speed reward")
@export var boost_per_link: float = 2.5          # m/s forward kick
@export var boost_multiplier_scale: float = 0.5  # extra kick fraction per multiplier above x1
@export var top_speed_bonus: float = 5.0         # m/s
@export var top_speed_bonus_time: float = 1.5
@export_group("Breaking")
@export var break_impact: float = 6.0            # crash dv (m/s per tick) that breaks the chain

var links: int = 0
var multiplier: float = 1.0
var points: float = 0.0
var window_left: float = 0.0
var is_active: bool = false

var _current_dir: int = 0   # -1 / +1 while drifting, 0 otherwise
var _last_dir: int = 0
var _segment_time: float = 0.0
var _last_segment_time: float = 0.0


func _ready() -> void:
	if taxi == null:
		taxi = get_parent() as Taxi
	if taxi != null:
		taxi.crashed.connect(_on_crashed)
		taxi.reset_performed.connect(reset)


func _physics_process(delta: float) -> void:
	if taxi == null:
		return
	# Travel speed, not forward speed: a car sliding sideways has ~0 forward speed.
	var drifting := taxi.is_drifting and taxi.linear_velocity.length() > min_drift_speed
	if drifting:
		var dir := 1 if taxi.rear_slip_signed > 0.0 else -1
		if dir != _current_dir:
			if _current_dir != 0:
				_last_dir = _current_dir
				_last_segment_time = _segment_time
			_start_segment(dir)
		_segment_time += delta
		points += points_per_second * multiplier * delta
		window_left = chain_window
	else:
		if _current_dir != 0:
			_last_dir = _current_dir
			_last_segment_time = _segment_time
			_current_dir = 0
		if is_active:
			window_left -= delta
			if window_left <= 0.0:
				_bank()


func reset() -> void:
	links = 0
	multiplier = 1.0
	points = 0.0
	window_left = 0.0
	is_active = false
	_current_dir = 0
	_last_dir = 0
	_segment_time = 0.0
	_last_segment_time = 0.0


func _start_segment(dir: int) -> void:
	if is_active and _last_dir != 0 and dir != _last_dir and _last_segment_time >= min_drift_time_for_link:
		links += 1
		multiplier = minf(1.0 + links * multiplier_step, max_multiplier)
		var kick := boost_per_link * (1.0 + (multiplier - 1.0) * boost_multiplier_scale)
		taxi.add_speed_boost(kick, top_speed_bonus, top_speed_bonus_time)
		chain_link.emit(links, multiplier)
	is_active = true
	_current_dir = dir
	_segment_time = 0.0


func _bank() -> void:
	if points > 0.0:
		chain_banked.emit(points, links)
	reset()


func _on_crashed(impact: float) -> void:
	if is_active and impact >= break_impact:
		chain_broken.emit(points)
		reset()
