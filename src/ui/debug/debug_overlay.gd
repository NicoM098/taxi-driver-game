extends Label
## F2 debug overlay: FPS, vehicle telemetry, render/input state and controls.

const CONTROLS := """
[KB+M] W/S throttle-brake/reverse  A/D steer  Space handbrake  Shift boost
       Mouse look  C look behind  T reset car  Esc pause
[Pad]  RT/LT throttle/brake  L-stick steer  B handbrake  A boost
       R-stick look  R3 look behind  L3 reset car  Start pause
[KB+M] RMB aim  LMB fire  R reload  1-3 / wheel switch weapon
[Pad]  LB aim  RB fire  X reload  Y / D-pad switch weapon
[Debug] F1 PS1 look  F2 this overlay  F3 next world (city / shooting range)  F4 interpolation
        F7 spawn 2 hitmen"""


func _process(_delta: float) -> void:
	if not visible:
		return
	var lines := PackedStringArray()
	lines.append("FPS %d" % Engine.get_frames_per_second())
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
	if taxi != null:
		lines.append("Speed %3.0f km/h   wheels %d/%d" % [taxi.get_speed_kmh(), taxi.grounded_wheel_count, taxi.wheels.size()])
		var states := PackedStringArray()
		if taxi.is_drifting:
			states.append("DRIFT")
		if taxi.is_boosting:
			states.append("BOOST")
		if not taxi.is_grounded():
			states.append("AIR")
		lines.append("State " + (" ".join(states) if not states.is_empty() else "-"))
	var main := owner
	var res_text := ""
	if main != null and main.has_method(&"get_world_resolution"):
		var res: Vector2i = main.call(&"get_world_resolution")
		res_text = " %dx%d" % [res.x, res.y]
	var ps1_on: bool = main != null and bool(main.get(&"ps1_enabled"))
	lines.append("PS1 %s%s   interp %s" % ["ON" if ps1_on else "OFF", res_text,
		"ON" if get_tree().physics_interpolation else "OFF"])
	lines.append("Input " + ("Gamepad" if InputDevice.using_gamepad else "Keyboard/Mouse"))
	text = "\n".join(lines) + "\n" + CONTROLS
