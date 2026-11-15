extends Node
## Boot scene. Owns:
##  - the low-res world SubViewport (PS1 look) + post-process dither material,
##  - the native-resolution UI layer (debug overlay, pause),
##  - pause and debug toggles (F1 PS1, F2 overlay, F4 physics interpolation, F6 time of day),
##  - M: leave the game for the map editor, src/editor/map_editor.tscn (not F9: Godot's
##    embedded game view uses F9 to suspend the running game, which froze the editor the
##    moment it opened).
## Command-line user args (after `--`): --screenshot=<png path> [--screenshot-frame=N] [--no-ps1]
##   [--world=res://...tscn] [--hold=action1,action2]  (debug: start world / hold input actions)

@export var start_scene: PackedScene
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


func _ready() -> void:
	_post_material = _container.material
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
	if event.is_action_pressed(&"pause"):
		_set_paused(not get_tree().paused)
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


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
