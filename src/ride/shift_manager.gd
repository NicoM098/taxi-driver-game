class_name ShiftManager
extends Node
## The current run on the streets. There is NO shift clock (removed 2026-11-12, user: "was
## never part of the game") and nothing ends the run: a wrecked taxi limps to a repair shop
## (TaxiDamage / RepairShop). `end_shift()` + the summary are kept for a future game-over.
## Also keeps the run statistics and the difficulty level: GameState.shift_number goes up by
## one every `rides_per_level` delivered passengers (min_shift of profiles, extra hitmen).

@export var auto_start_delay: float = 1.0
## Delivered passengers per difficulty level (GameState.shift_number).
@export var rides_per_level: int = 4

var is_active: bool = false
var has_ended: bool = false
var rides_completed: int = 0
var rides_failed: int = 0
var cash_earned: int = 0
var best_drift_links: int = 0
var passengers_kicked: int = 0
var passengers_killed: int = 0
var enemies_destroyed: int = 0
var cash_stolen: int = 0
var wrecks: int = 0
var pedestrians_hit: int = 0
## Delivered passengers since the game started (not reset by a wreck).
var total_rides: int = 0

var _start_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"shift_manager")
	_start_timer = auto_start_delay
	EventBus.ride_completed.connect(_on_ride_completed)
	EventBus.ride_failed.connect(_on_ride_failed)
	EventBus.passenger_kicked_out.connect(func(_p: RefCounted) -> void: passengers_kicked += 1)
	EventBus.passenger_executed.connect(func(_p: RefCounted) -> void: passengers_killed += 1)
	EventBus.enemy_destroyed.connect(func(_e: Node, _b: int) -> void: enemies_destroyed += 1)
	EventBus.taxi_wrecked.connect(func(_reason: StringName) -> void: wrecks += 1)
	EventBus.pedestrian_hit.connect(func(_p: Vector3) -> void: pedestrians_hit += 1)


func _physics_process(delta: float) -> void:
	if not is_active and _start_timer > 0.0:
		_start_timer -= delta
		if _start_timer <= 0.0:
			start_shift()


func _process(_delta: float) -> void:
	# Polled (not _unhandled_input): this node lives inside the world SubViewport.
	if has_ended and not is_active and (Input.is_action_just_pressed(&"interact")
			or Input.is_action_just_pressed(&"ui_accept")):
		start_shift()


## Starts (or, after a wreck, restarts) the run.
func start_shift() -> void:
	var back := has_ended
	GameState.shift_number = maxi(GameState.shift_number, 1)
	rides_completed = 0
	rides_failed = 0
	cash_earned = 0
	best_drift_links = 0
	passengers_kicked = 0
	passengers_killed = 0
	enemies_destroyed = 0
	cash_stolen = 0
	is_active = true
	has_ended = false
	_set_player_control(true)
	EventBus.shift_started.emit(GameState.shift_number)
	EventBus.hud_message.emit("BACK ON THE ROAD" if back else "ON DUTY — FIND A FARE", &"good")


## reason: &"taxi_destroyed", &"driver_killed".
func end_shift(reason: StringName = &"taxi_destroyed") -> void:
	is_active = false
	has_ended = true
	_set_player_control(false)
	EventBus.shift_ended.emit({
		"shift_number": GameState.shift_number,
		"rides_completed": rides_completed,
		"rides_failed": rides_failed,
		"cash_earned": cash_earned,
		"best_drift_links": best_drift_links,
		"passengers_kicked": passengers_kicked,
		"passengers_killed": passengers_killed,
		"enemies_destroyed": enemies_destroyed,
		"cash_stolen": cash_stolen,
		"total_cash": GameState.cash,
		"reason": reason,
	})


## Cash earned outside a fare (e.g. drift style bonus with an empty cab).
func register_bonus_cash(amount: int) -> void:
	cash_earned += amount


## Cash a passenger took from the driver (ride events).
func register_stolen(amount: int) -> void:
	cash_stolen += amount


func register_drift_links(links: int) -> void:
	best_drift_links = maxi(best_drift_links, links)


func _on_ride_completed(_ride: RefCounted, payout: int) -> void:
	rides_completed += 1
	cash_earned += payout
	total_rides += 1
	if rides_per_level > 0 and total_rides % rides_per_level == 0:
		GameState.shift_number += 1


func _on_ride_failed(_ride: RefCounted, reason: StringName) -> void:
	if reason != &"kicked_out":   # your own decision, counted as "kicked out" instead
		rides_failed += 1


func _set_player_control(enabled: bool) -> void:
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle")
	if taxi == null:
		return
	var player_input := taxi.get_node_or_null("PlayerInput") as PlayerVehicleInput
	if player_input != null:
		player_input.enabled = enabled
