class_name ShiftManager
extends Node
## Endless shifts: countdown timer (rides add bonus time), stats, summary, next shift.
## The first shift starts automatically; after a shift ends the player presses
## interact / ui_accept to start the next one.

@export var shift_duration: float = 150.0
@export var auto_start_delay: float = 1.0

var is_active: bool = false
var has_ended: bool = false
var time_left: float = 0.0
var rides_completed: int = 0
var rides_failed: int = 0
var cash_earned: int = 0
var best_drift_links: int = 0

var _start_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"shift_manager")
	_start_timer = auto_start_delay
	EventBus.ride_completed.connect(_on_ride_completed)
	EventBus.ride_failed.connect(_on_ride_failed)
	EventBus.taxi_wrecked.connect(func(reason: StringName) -> void:
		if is_active:
			end_shift(reason))


func _physics_process(delta: float) -> void:
	if is_active:
		time_left = maxf(time_left - delta, 0.0)
		EventBus.shift_time_changed.emit(time_left)
		if time_left <= 0.0:
			end_shift()
	elif _start_timer > 0.0:
		_start_timer -= delta
		if _start_timer <= 0.0:
			start_shift()


func _process(_delta: float) -> void:
	# Polled (not _unhandled_input): this node lives inside the world SubViewport.
	if has_ended and not is_active and (Input.is_action_just_pressed(&"interact")
			or Input.is_action_just_pressed(&"ui_accept")):
		start_shift()


func start_shift() -> void:
	GameState.shift_number += 1
	time_left = shift_duration
	rides_completed = 0
	rides_failed = 0
	cash_earned = 0
	best_drift_links = 0
	is_active = true
	has_ended = false
	_set_player_control(true)
	EventBus.shift_started.emit(GameState.shift_number)
	EventBus.hud_message.emit("SHIFT %d — GO!" % GameState.shift_number, &"good")


## reason: &"time_up", &"taxi_destroyed", &"driver_killed".
func end_shift(reason: StringName = &"time_up") -> void:
	is_active = false
	has_ended = true
	_set_player_control(false)
	EventBus.shift_ended.emit({
		"shift_number": GameState.shift_number,
		"rides_completed": rides_completed,
		"rides_failed": rides_failed,
		"cash_earned": cash_earned,
		"best_drift_links": best_drift_links,
		"total_cash": GameState.cash,
		"reason": reason,
	})


func add_time(seconds: float) -> void:
	if is_active:
		time_left += seconds


## Cash earned outside a fare (e.g. drift style bonus with an empty cab).
func register_bonus_cash(amount: int) -> void:
	cash_earned += amount


func register_drift_links(links: int) -> void:
	best_drift_links = maxi(best_drift_links, links)


func _on_ride_completed(_ride: RefCounted, payout: int) -> void:
	rides_completed += 1
	cash_earned += payout


func _on_ride_failed(_ride: RefCounted, _reason: StringName) -> void:
	rides_failed += 1


func _set_player_control(enabled: bool) -> void:
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle")
	if taxi == null:
		return
	var player_input := taxi.get_node_or_null("PlayerInput") as PlayerVehicleInput
	if player_input != null:
		player_input.enabled = enabled
