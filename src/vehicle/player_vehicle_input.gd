class_name PlayerVehicleInput
extends Node
## Input provider for the player's taxi: reads the Input Map (KB+M and gamepad).
## Any node with `poll(input: VehicleInput)` can drive a Taxi (AI cars in Phase 06).

@export var enabled: bool = true


func _ready() -> void:
	get_parent().add_to_group(&"player_vehicle")


func poll(input: VehicleInput) -> void:
	if not enabled:
		input.clear()
		return
	input.throttle = Input.get_action_strength(&"accelerate")
	input.brake = Input.get_action_strength(&"brake")
	input.steer = Input.get_axis(&"steer_left", &"steer_right")
	input.handbrake = Input.is_action_pressed(&"handbrake")
	input.boost = Input.is_action_pressed(&"boost")
	input.reset = Input.is_action_just_pressed(&"reset_vehicle")
