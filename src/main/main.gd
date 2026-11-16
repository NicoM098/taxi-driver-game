extends Node
## Boot scene. Owns:
##  - the low-res world SubViewport (PS1 look) + post-process dither material,
##  - the native-resolution UI layer (debug overlay, pause menu with the run stats, tutorial),
##  - pause and debug toggles (F1 PS1, F2 overlay, F4 physics interpolation, F6 time of day),
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

## Hit-stop (D-081).
const HIT_STOP_SCALE: float = 0.15
const HIT_STOP_MS: int = 70

var _hit_stop_until: int = 0
var _headless: bool = DisplayServer.get_name() == "headless" or OS.has_feature("headless")

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
var _pause_column: VBoxContainer
var _options: OptionsMenu
var _game_over: Control
var _game_over_stats: Label
var _game_over_button: Button
var is_game_over: bool = false
## Seconds between the explosion and the game-over screen.
const GAME_OVER_DELAY: float = 2.5


func _ready() -> void:
	_post_material = _container.material
	_build_pause_menu()
	_build_game_over()
	EventBus.player_died.connect(_on_player_died)
	EventBus.enemy_destroyed.connect(_on_enemy_destroyed)
	_parse_cmdline()
	SceneLoader.world_scene_requested.connect(_on_world_scene_requested)
	get_viewport().size_changed.connect(_update_resolution)
	_viewport.size_changed.connect(_on_world_viewport_resized)
	if start_scene != null:
		_load_world(start_scene)
	_apply_ps1()
	_set_paused(false)
	Audio.play_music()


func _exit_tree() -> void:
	Audio.stop_music()


## Hit-stop (D-081): a kill freezes the world for a few real milliseconds, which is most of what
## makes a shot feel like it landed. `Engine.time_scale` is global and the autotests run at
## `--fixed-fps 60`, so it is off in headless runs exactly like the audio.
func _on_enemy_destroyed(enemy: Node, _bounty: int) -> void:
	if _headless or _hit_stop_until > 0:
		return
	Engine.time_scale = HIT_STOP_SCALE
	_hit_stop_until = Time.get_ticks_msec() + HIT_STOP_MS   # real time: time_scale cannot stretch it
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Node3D
	if taxi != null and enemy is Node3D:
		for cam in taxi.find_children("*", "CabCamera", true, false):
			(cam as CabCamera).add_trauma(0.45)


func _end_hit_stop() -> void:
	if _hit_stop_until <= 0:
		return
	_hit_stop_until = 0
	Engine.time_scale = 1.0


func _process(_delta: float) -> void:
	if _hit_stop_until > 0 and Time.get_ticks_msec() >= _hit_stop_until:
		_end_hit_stop()
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
	if is_game_over:
		return   # only the game-over buttons work now
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
	elif event.is_action_pressed(&"debug_cycle_mood"):
		var city := get_tree().get_first_node_in_group(&"city") as City
		if city != null:
			print("[Main] time of day: ", Lighting.mood_name(city.cycle_mood()))
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
	if not paused and _options != null and _options.visible:
		_options.close()
	if _pause_column != null:
		_pause_column.visible = true
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
	_pause_column = col
	_options = OptionsMenu.new()
	center.add_child(_options)
	_options.closed.connect(func() -> void:
		col.visible = true
		_pause_resume.grab_focus())
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
	_pause_button(col, "OPTIONS", func() -> void:
		col.visible = false
		_options.open())
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


# --- Game over ----------------------------------------------------------------------------

## Life ran out (user request 2026-11-15): the cab explodes, then this screen with the run's
## stats; the only way on is back to the main menu (a new run starts from there).
func _on_player_died() -> void:
	_end_hit_stop()   # dying mid-freeze must not leave the world in slow motion
	if is_game_over:
		return
	is_game_over = true
	await get_tree().create_timer(GAME_OVER_DELAY).timeout
	if not is_inside_tree():
		return
	var dossier := get_tree().get_first_node_in_group(&"dossier") as Dossier
	if dossier != null and dossier.is_open:
		dossier.visible = false
	_pause_overlay.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_game_over_stats.text = _run_stats_text()
	_game_over.visible = true
	_game_over_button.grab_focus()


func _build_game_over() -> void:
	_game_over = ColorRect.new()
	(_game_over as ColorRect).color = Color(0.25, 0.0, 0.0, 0.72)
	_game_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over.process_mode = Node.PROCESS_MODE_ALWAYS
	_game_over.visible = false
	_pause_overlay.get_parent().add_child(_game_over)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)
	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.25, 0.15))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 12)
	col.add_child(title)
	var sub := Label.new()
	sub.text = "Your cab went up in flames."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	col.add_child(sub)
	_game_over_stats = Label.new()
	_game_over_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_stats.add_theme_font_size_override("font_size", 17)
	_game_over_stats.add_theme_color_override("font_color", Color(0.9, 0.85, 0.85))
	col.add_child(_game_over_stats)
	col.add_child(Control.new())
	_game_over_button = _pause_button(col, "MAIN MENU", func() -> void:
		get_tree().paused = false
		GameState.tutorial_active = false
		GameState.reset_run()
		get_tree().change_scene_to_file(MENU_SCENE))
	_pause_button(col, "QUIT GAME", func() -> void: get_tree().quit())


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
