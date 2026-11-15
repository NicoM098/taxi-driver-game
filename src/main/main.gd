extends Node
## Boot scene. Owns:
##  - the low-res world SubViewport (PS1 look) + post-process dither material,
##  - the native-resolution UI layer (debug overlay, pause menu with the run stats, tutorial),
##  - pause and debug toggles (F1 PS1, F2 overlay, F4 physics interpolation),
##  - M: leave the game for the map editor, src/editor/map_editor.tscn (not F9: Godot's
##    embedded game view uses F9 to suspend the running game, which froze the editor the
##    moment it opened).
## Command-line user args (after `--`): --screenshot=<png path> [--screenshot-frame=N] [--no-ps1]
##   [--world=res://...tscn] [--hold=action1,action2]  (debug: start world / hold input actions)

@export var start_scene: PackedScene
const MENU_SCENE := "res://src/ui/menu/main_menu.tscn"
## F3 cycles through these worlds (debug).
const DEBUG_WORLDS := ["res://src/main/game.tscn", "res://src/combat/shooting_range.tscn"]
@export var target_vertical_resolution: int = 240

var ps1_enabled: bool = true

@onready var _container: SubViewportContainer = %WorldContainer
@onready var _viewport: SubViewport = %WorldViewport
@onready var _debug_overlay: Control = %DebugOverlay
@onready var _pause_overlay: Control = %PauseOverlay

var _post_material: Material
var _world: Node
var _frame: int = 0
var _screenshot_path: String = ""
var _screenshot_frame: int = 120
var _debug_world_index: int = 0
var _held_actions: PackedStringArray = []
var _pause_stats: Label
var _pause_resume: Button
var _pause_skip_tutorial: Button


func _ready() -> void:
	_post_material = _container.material
	_build_pause_menu()
	_parse_cmdline()
	SceneLoader.world_scene_requested.connect(_on_world_scene_requested)
	get_viewport().size_changed.connect(_update_resolution)
	_viewport.size_changed.connect(_on_world_viewport_resized)
	if start_scene != null:
		_load_world(start_scene)
	_apply_ps1()
	_set_paused(false)


func _process(_delta: float) -> void:
	for action in _held_actions:
		Input.action_press(StringName(action))
	if _screenshot_path.is_empty():
		return
	_frame += 1
	if _frame == _screenshot_frame:
		var err := get_viewport().get_texture().get_image().save_png(_screenshot_path)
		print("[Main] screenshot -> %s (%s)" % [_screenshot_path, error_string(err)])
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	var dossier := get_tree().get_first_node_in_group(&"dossier") as Dossier
	if dossier != null and dossier.is_open:
		return   # the passenger file owns pause + mouse while it is open
	var shop := get_tree().get_first_node_in_group(&"gun_shop_ui") as GunShopUI
	if shop != null and shop.is_open:
		return   # so does the gun shop
	if event.is_action_pressed(&"pause"):
		_set_paused(not get_tree().paused)
	elif get_tree().paused and _pause_overlay.visible and event.is_action_pressed(&"ui_cancel"):
		_set_paused(false)
	elif event.is_action_pressed(&"debug_toggle_ps1"):
		ps1_enabled = not ps1_enabled
		_apply_ps1()
	elif event.is_action_pressed(&"debug_toggle_overlay"):
		_debug_overlay.visible = not _debug_overlay.visible
	elif event.is_action_pressed(&"debug_next_world"):
		_debug_world_index = (_debug_world_index + 1) % DEBUG_WORLDS.size()
		_on_world_scene_requested(DEBUG_WORLDS[_debug_world_index])
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Changing scene takes this node out of the tree at once: mark the input first, then leave.
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file("res://src/editor/map_editor.tscn")
		return
	elif event.is_action_pressed(&"debug_toggle_interpolation"):
		get_tree().physics_interpolation = not get_tree().physics_interpolation
	elif event is InputEventMouseButton and event.is_pressed() and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		return
	get_viewport().set_input_as_handled()


func get_world_resolution() -> Vector2i:
	return _viewport.size


func _load_world(packed: PackedScene) -> void:
	if _world != null:
		_world.queue_free()
	_world = packed.instantiate()
	_viewport.add_child(_world)


func _on_world_scene_requested(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("[Main] cannot load world scene: " + path)
		return
	_load_world(packed)


func _apply_ps1() -> void:
	var strength := 1.0 if ps1_enabled else 0.0
	RenderingServer.global_shader_parameter_set(&"ps1_snap_strength", strength)
	RenderingServer.global_shader_parameter_set(&"ps1_affine_strength", strength)
	_container.material = _post_material if ps1_enabled else null
	_update_resolution()


func _update_resolution() -> void:
	var height := get_viewport().get_visible_rect().size.y
	var shrink := maxi(1, roundi(height / float(target_vertical_resolution))) if ps1_enabled else 1
	_container.stretch_shrink = shrink
	_on_world_viewport_resized()


func _on_world_viewport_resized() -> void:
	RenderingServer.global_shader_parameter_set(&"ps1_snap_resolution", Vector2(_viewport.size))


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_pause_overlay.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	if paused:
		_pause_stats.text = _run_stats_text()
		var tutorial := get_tree().get_first_node_in_group(&"tutorial") as Tutorial
		_pause_skip_tutorial.visible = tutorial != null and tutorial.step != Tutorial.Step.OFF
		_pause_resume.grab_focus()


# --- Pause menu ---------------------------------------------------------------------------

func _build_pause_menu() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.1))
	col.add_child(title)
	_pause_stats = Label.new()
	_pause_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_stats.add_theme_font_size_override("font_size", 17)
	_pause_stats.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	col.add_child(_pause_stats)
	col.add_child(Control.new())
	_pause_resume = _pause_button(col, "RESUME", func() -> void: _set_paused(false))
	_pause_skip_tutorial = _pause_button(col, "SKIP TUTORIAL", func() -> void:
		var tutorial := get_tree().get_first_node_in_group(&"tutorial") as Tutorial
		if tutorial != null:
			tutorial.skip()
		_set_paused(false))
	_pause_button(col, "MAIN MENU", func() -> void:
		get_tree().paused = false
		GameState.tutorial_active = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file(MENU_SCENE))
	_pause_button(col, "QUIT GAME", func() -> void: get_tree().quit())


func _pause_button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 46)
	b.add_theme_font_size_override("font_size", 22)
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## The run so far (there is no end-of-run screen since a wreck stopped ending the run).
func _run_stats_text() -> String:
	var shift := get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
	if shift == null:
		return "Cash: $%d" % GameState.cash
	return "Cash: $%d    Level: %d
Fares delivered: %d   (failed %d)
Kicked out: %d   Shot: %d   Enemies down: %d
Wrecks: %d   Pedestrians hit: %d   Best drift chain: %d links" % [
		GameState.cash, maxi(GameState.shift_number, 1), shift.total_rides, shift.rides_failed,
		shift.passengers_kicked, shift.passengers_killed, shift.enemies_destroyed,
		shift.wrecks, shift.pedestrians_hit, shift.best_drift_links]


func _parse_cmdline() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_screenshot_path = arg.get_slice("=", 1)
		elif arg.begins_with("--screenshot-frame="):
			_screenshot_frame = arg.get_slice("=", 1).to_int()
		elif arg == "--no-ps1":
			ps1_enabled = false
		elif arg.begins_with("--hold="):
			_held_actions = arg.get_slice("=", 1).split(",")
		elif arg.begins_with("--world="):
			start_scene = load(arg.get_slice("=", 1)) as PackedScene
