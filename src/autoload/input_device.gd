extends Node
## Tracks the last-used input device (keyboard/mouse vs gamepad) and accumulates mouse-look
## motion. Mouse look is read from here because the 3D world lives inside a SubViewport,
## which does not reliably receive captured-mouse motion events.
## Also owns the global F11 fullscreen toggle (works in every scene: menu, game, editor).

signal device_changed(using_gamepad: bool)

const AXIS_THRESHOLD := 0.35
const MOUSE_MOVE_THRESHOLD := 3.0

var using_gamepad: bool = false
var _mouse_delta: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo 			and (event as InputEventKey).physical_keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_mouse_delta += motion.screen_relative
		if motion.screen_relative.length() > MOUSE_MOVE_THRESHOLD:
			_set_gamepad(false)
	elif event is InputEventKey or event is InputEventMouseButton:
		_set_gamepad(false)
	elif event is InputEventJoypadButton:
		_set_gamepad(true)
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > AXIS_THRESHOLD:
		_set_gamepad(true)


func toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


## Returns mouse motion (screen pixels) since the last call, then clears it.
func consume_mouse_delta() -> Vector2:
	var delta := _mouse_delta
	_mouse_delta = Vector2.ZERO
	return delta


func _set_gamepad(value: bool) -> void:
	if value == using_gamepad:
		return
	using_gamepad = value
	device_changed.emit(using_gamepad)
