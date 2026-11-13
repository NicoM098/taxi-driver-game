extends SceneTree
## One-shot project configuration tool. Writes project.godot through ProjectSettings so the
## format is always valid. Safe to re-run (it overwrites the same keys).
## Run (headless):
##   Godot_console.exe --headless --path <project> --script res://tools/setup_project.gd


func _init() -> void:
	_application()
	_display()
	_physics()
	_autoloads()
	_layers()
	_shader_globals()
	_input_map()
	var err := ProjectSettings.save()
	print("[Setup] ProjectSettings.save() -> ", error_string(err))
	quit(0 if err == OK else 1)


func _application() -> void:
	ProjectSettings.set_setting("application/config/name", "TaxiDriver")
	ProjectSettings.set_setting("application/run/main_scene", "res://src/main/main.tscn")


func _display() -> void:
	ProjectSettings.set_setting("display/window/size/viewport_width", 1280)
	ProjectSettings.set_setting("display/window/size/viewport_height", 720)
	ProjectSettings.set_setting("display/window/stretch/mode", "canvas_items")
	ProjectSettings.set_setting("display/window/stretch/aspect", "expand")


func _physics() -> void:
	# Smooth rendering on high-refresh monitors while physics runs at a fixed 60 Hz.
	ProjectSettings.set_setting("physics/common/physics_interpolation", true)


func _autoloads() -> void:
	var autoloads := {
		"EventBus": "res://src/autoload/event_bus.gd",
		"GameState": "res://src/autoload/game_state.gd",
		"PlayerStats": "res://src/autoload/player_stats.gd",
		"SaveManager": "res://src/autoload/save_manager.gd",
		"SceneLoader": "res://src/autoload/scene_loader.gd",
		"InputDevice": "res://src/autoload/input_device.gd",
	}
	for key: String in autoloads:
		ProjectSettings.set_setting("autoload/" + key, "*" + String(autoloads[key]))


func _layers() -> void:
	var names := ["world", "player_taxi", "enemy_vehicles", "traffic", "characters",
		"hitboxes", "projectiles", "triggers", "props"]
	for i in names.size():
		ProjectSettings.set_setting("layer_names/3d_physics/layer_%d" % (i + 1), names[i])


func _shader_globals() -> void:
	ProjectSettings.set_setting("shader_globals/ps1_snap_strength", {"type": "float", "value": 1.0})
	ProjectSettings.set_setting("shader_globals/ps1_affine_strength", {"type": "float", "value": 1.0})
	ProjectSettings.set_setting("shader_globals/ps1_snap_resolution", {"type": "vec2", "value": Vector2(426, 240)})


# --- Input -------------------------------------------------------------------

func _input_map() -> void:
	_action("accelerate", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)], 0.1)
	_action("brake", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)], 0.1)
	_action("steer_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_action("steer_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_action("handbrake", [_key(KEY_SPACE), _btn(JOY_BUTTON_B)])
	_action("boost", [_key(KEY_SHIFT), _btn(JOY_BUTTON_A)])
	_action("reset_vehicle", [_key(KEY_T), _btn(JOY_BUTTON_LEFT_STICK)])

	_action("look_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_action("look_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_action("look_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_action("look_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_action("look_behind", [_key(KEY_C), _btn(JOY_BUTTON_RIGHT_STICK)])

	_action("aim", [_mouse(MOUSE_BUTTON_RIGHT), _btn(JOY_BUTTON_LEFT_SHOULDER)])
	_action("fire", [_mouse(MOUSE_BUTTON_LEFT), _btn(JOY_BUTTON_RIGHT_SHOULDER)])
	_action("reload", [_key(KEY_R), _btn(JOY_BUTTON_X)])
	_action("weapon_next", [_mouse(MOUSE_BUTTON_WHEEL_DOWN), _btn(JOY_BUTTON_Y), _btn(JOY_BUTTON_DPAD_RIGHT)])
	_action("weapon_prev", [_mouse(MOUSE_BUTTON_WHEEL_UP), _btn(JOY_BUTTON_DPAD_LEFT)])
	_action("weapon_1", [_key(KEY_1)])
	_action("weapon_2", [_key(KEY_2)])
	_action("weapon_3", [_key(KEY_3)])
	_action("weapon_4", [_key(KEY_4)])

	_action("interact", [_key(KEY_E), _key(KEY_TAB), _btn(JOY_BUTTON_DPAD_UP)])
	_action("kick_out", [_key(KEY_Q), _btn(JOY_BUTTON_DPAD_DOWN)])
	_action("pause", [_key(KEY_ESCAPE), _btn(JOY_BUTTON_START)])

	_action("debug_toggle_ps1", [_key(KEY_F1)])
	_action("debug_toggle_overlay", [_key(KEY_F2)])
	_action("debug_next_world", [_key(KEY_F3)])
	_action("debug_spawn_pursuers", [_key(KEY_F7)])
	_action("debug_toggle_interpolation", [_key(KEY_F4)])


func _action(action_name: String, events: Array, deadzone: float = 0.2) -> void:
	ProjectSettings.set_setting("input/" + action_name, {"deadzone": deadzone, "events": events})


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.device = -1
	e.physical_keycode = code
	return e


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.device = -1
	e.button_index = button
	return e


func _btn(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1
	e.button_index = button
	return e


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = -1
	e.axis = axis
	e.axis_value = value
	return e
