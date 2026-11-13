class_name VehicleInput
extends RefCounted
## Driving commands for one physics tick. Filled by an input provider (player, AI, autotest).

var throttle: float = 0.0   # 0..1
var brake: float = 0.0      # 0..1 (brakes, then reverses when slow)
var steer: float = 0.0      # -1 (left) .. 1 (right)
var handbrake: bool = false
var boost: bool = false
var reset: bool = false     # request flip recovery


func clear() -> void:
	throttle = 0.0
	brake = 0.0
	steer = 0.0
	handbrake = false
	boost = false
	reset = false
