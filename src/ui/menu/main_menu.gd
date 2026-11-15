extends Control
## Title screen (the project's main scene). PLAY / TUTORIAL / MAP EDITOR / CONTROLS / QUIT.
## Built in code like the HUD. Works with mouse and gamepad (focus starts on PLAY).
## Command-line tooling args meant for the game (--screenshot, --world, --hold, --map) skip
## the menu so the old screenshot / map commands keep working.

const GAME_SCENE := "res://src/main/main.tscn"
const EDITOR_SCENE := "res://src/editor/map_editor.tscn"
const SKIP_ARGS: Array[String] = ["--screenshot", "--world=", "--hold=", "--map="]

const YELLOW := Color(1.0, 0.82, 0.1)
const BG_TOP := Color(0.07, 0.06, 0.12)
const BG_BOTTOM := Color(0.16, 0.08, 0.16)
const CONTROLS := [
	["Accelerate / brake-reverse", "W / S", "RT / LT"],
	["Steer", "A / D", "Left stick"],
	["Handbrake (drift)", "Space", "B"],
	["Boost", "Shift", "A"],
	["Look around / look behind", "Mouse / C", "Right stick / R3"],
	["Raise gun / fire", "RMB / LMB", "LB / RB"],
	["Reload / switch weapon", "R / 1-3, wheel", "X / Y, d-pad"],
	["Passenger file", "Mouse", "D-pad + A"],
	["Throw passenger out (when offered)", "Q", "D-pad down"],
	["Reset car", "T", "L3"],
	["Pause menu", "Esc", "Start"],
	["Fullscreen", "F11", "-"],
	["Map editor (in game)", "M", "-"],
]

var _buttons: VBoxContainer
var _controls: PanelContainer
var _play: Button
var _time: float = 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		for prefix in SKIP_ARGS:
			if arg.begins_with(prefix):
				get_tree().change_scene_to_file.call_deferred(GAME_SCENE)
				return
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_play.grab_focus.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# Esc / B closes the controls panel.
	if _controls.visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		_toggle_controls()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var s := size
	# Vertical gradient.
	var bands := 24
	for i in bands:
		var t := float(i) / bands
		draw_rect(Rect2(0, s.y * t, s.x, s.y / bands + 1.0), BG_TOP.lerp(BG_BOTTOM, t))
	# Taxi checker stripe, scrolling slowly.
	var cell := 22.0
	var y := s.y * 0.30
	var shift := fmod(_time * 30.0, cell * 2.0)
	var x := -cell * 2.0 + shift
	var i := 0
	while x < s.x:
		for row in 2:
			var on := (i + row) % 2 == 0
			draw_rect(Rect2(x, y + row * cell, cell, cell), YELLOW if on else Color(0.05, 0.05, 0.05))
		x += cell
		i += 1
	# Street lines at the bottom.
	var road_y := s.y * 0.86
	draw_rect(Rect2(0, road_y, s.x, s.y - road_y), Color(0.09, 0.09, 0.1))
	var dash := 70.0
	var dx := -fmod(_time * 260.0, dash * 2.0)
	while dx < s.x:
		draw_rect(Rect2(dx, road_y + (s.y - road_y) * 0.5 - 3.0, dash, 6.0), Color(0.85, 0.8, 0.6))
		dx += dash * 2.0


func _build() -> void:
	var title := Label.new()
	title.text = "TAXIDRIVER"
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", YELLOW)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 16)
	var bold := FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 1.0
	title.add_theme_font_override("font", bold)
	add_child(title)
	title.position = Vector2(64, 48)

	var tag := Label.new()
	tag.text = "Drive fast.  Read the file.  Shoot your way out."
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_color_override("font_color", Color(0.9, 0.88, 0.95))
	add_child(tag)
	tag.position = Vector2(70, 156)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	add_child(_buttons)
	_buttons.anchor_top = 0.42
	_buttons.offset_left = 70
	_buttons.offset_top = 0
	_buttons.custom_minimum_size.x = 300
	_play = _button("PLAY", _on_play)
	_button("TUTORIAL  (2 min)", _on_tutorial)
	_button("MAP EDITOR", _on_editor)
	_button("CONTROLS", _toggle_controls)
	_button("QUIT", func() -> void: get_tree().quit())

	var version := Label.new()
	version.text = "proof of concept · %s" % ProjectSettings.get_setting("application/config/version", "dev")
	version.add_theme_font_size_override("font_size", 14)
	version.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	add_child(version)
	version.anchor_left = 1.0
	version.anchor_right = 1.0
	version.offset_left = -300
	version.offset_right = -16
	version.offset_top = 12
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_build_controls()


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(300, 52)
	b.add_theme_font_size_override("font_size", 26)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0.45)
	normal.content_margin_left = 18
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = YELLOW
	hover.border_width_left = 8
	hover.border_color = Color.BLACK
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_hover_color", Color.BLACK)
	b.add_theme_color_override("font_focus_color", Color.BLACK)
	b.add_theme_color_override("font_pressed_color", Color.BLACK)
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(action)
	_buttons.add_child(b)
	return b


func _build_controls() -> void:
	_controls = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.05, 0.92)
	style.border_color = YELLOW
	style.border_width_top = 4
	style.set_content_margin_all(18)
	_controls.add_theme_stylebox_override("panel", style)
	_controls.visible = false
	add_child(_controls)
	_controls.anchor_left = 1.0
	_controls.anchor_right = 1.0
	_controls.anchor_top = 0.42
	_controls.offset_left = -660
	_controls.offset_right = -40
	_controls.offset_top = -40
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 4)
	_controls.add_child(grid)
	for row: Array in [["", "Keyboard / mouse", "Gamepad"]] + CONTROLS:
		for c in 3:
			var l := Label.new()
			l.text = row[c]
			l.add_theme_font_size_override("font_size", 16)
			if row[0] == "":
				l.add_theme_color_override("font_color", YELLOW)
			grid.add_child(l)


func _toggle_controls() -> void:
	_controls.visible = not _controls.visible


func _on_play() -> void:
	_start(false)


func _on_tutorial() -> void:
	_start(true)


func _start(tutorial: bool) -> void:
	GameState.reset_run()
	GameState.tutorial_active = tutorial
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_editor() -> void:
	get_tree().change_scene_to_file(EDITOR_SCENE)
