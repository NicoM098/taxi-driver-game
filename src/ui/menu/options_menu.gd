class_name OptionsMenu
extends PanelContainer
## Options panel (user request 2026-11-15): volume sliders (Audio.VOLUME_SLIDERS) + fullscreen.
## Shared by the main menu and the pause menu. Changes apply live and are saved to
## user://settings.cfg when the panel closes. Esc / B / BACK closes it (emits `closed`).
## Works with mouse and gamepad (d-pad up/down between rows, left/right moves a slider).

signal closed

const YELLOW := Color(1.0, 0.82, 0.1)

var _first: Control
var _sliders: Dictionary = {}   # bus -> HSlider


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # usable from the pause menu
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.05, 0.94)
	style.border_color = YELLOW
	style.border_width_top = 4
	style.set_content_margin_all(22)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(520, 0)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	var title := Label.new()
	title.text = "OPTIONS"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", YELLOW)
	col.add_child(title)

	for row: Array in Audio.VOLUME_SLIDERS:
		var bus: StringName = row[0]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		col.add_child(line)
		var name_label := Label.new()
		name_label.text = row[1]
		name_label.custom_minimum_size.x = 170
		name_label.add_theme_font_size_override("font_size", 20)
		line.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(230, 28)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_ALL
		line.add_child(slider)
		var pct := Label.new()
		pct.custom_minimum_size.x = 60
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pct.add_theme_font_size_override("font_size", 20)
		line.add_child(pct)
		slider.value_changed.connect(func(v: float) -> void:
			Audio.set_bus_volume(bus, v)
			pct.text = "%d%%" % roundi(v * 100.0))
		slider.mouse_entered.connect(slider.grab_focus)
		_sliders[bus] = slider
		if _first == null:
			_first = slider

	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen  (F11)"
	fullscreen.add_theme_font_size_override("font_size", 20)
	fullscreen.toggled.connect(func(on: bool) -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	fullscreen.visibility_changed.connect(func() -> void:
		fullscreen.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN))
	fullscreen.mouse_entered.connect(fullscreen.grab_focus)
	col.add_child(fullscreen)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 44)
	back.add_theme_font_size_override("font_size", 22)
	back.mouse_entered.connect(back.grab_focus)
	back.pressed.connect(close)
	col.add_child(back)


func open() -> void:
	for bus: StringName in _sliders:
		var slider: HSlider = _sliders[bus]
		slider.value = Audio.get_bus_volume(bus)
		slider.value_changed.emit(slider.value)   # refresh the % label
	visible = true
	if _first != null:
		_first.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	Audio.save_settings()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()
