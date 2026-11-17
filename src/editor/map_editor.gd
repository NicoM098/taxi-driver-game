extends Node3D
## In-game MAP EDITOR (run this scene directly, or press M in the game).
## Edits a MapData on a grid of 8 m cells and saves it to res://data/maps/<name>.json.
## The preview uses the same MapBuilder geometry as the game.
##
##   Left panel   tools: Select / Erase / one button per piece type
##   Right panel  properties of the brush (placing) or of the selected piece
##   Top bar      map name, load, save, new / resize, starter city, main menu, PLAY
##
##   Mouse  LMB place (drag a rectangle for area pieces) / select / drag the selection to move
##          RMB back to Select / deselect      wheel zoom      MMB or RMB drag: pan
##   Keys   WASD / arrows pan   T tilt view   R rotate   [ ] height   Del delete
##          Ctrl+Z / Ctrl+Y undo / redo   Ctrl+S save   P / F5 play   Esc Select tool

const TOOL_SELECT := "select"
const TOOL_ERASE := "erase"
const ROTATABLE: Array[String] = ["building", "stairs", "ramp", "containers", "repair", "gunshop", "stop", "spawn"]
const ZONE_PRESETS: Array[String] = ["downtown", "suburbs", "docks"]
const MAX_UNDO := 100
const MAIN_SCENE := "res://src/main/main.tscn"
const MENU_SCENE := "res://src/ui/menu/main_menu.tscn"

var map: MapData
var tool: String = TOOL_SELECT
var selected: int = -1

var _cam: Camera3D
var _focus: Vector3 = Vector3.ZERO
var _zoom: float = 260.0
var _tilted: bool = true
var _world: Node3D            # ground + grid
var _pieces_root: Node3D
var _nodes: Array[Node3D] = []
var _ghost: MeshInstance3D
var _select_box: MeshInstance3D
var _brushes: Dictionary = {}   # type -> piece template (remembers the last settings)
var _undo: Array[String] = []
var _redo: Array[String] = []
var _dirty: bool = false

var _hover: Vector2i = Vector2i(-1, -1)
var _drag_from: Vector2i = Vector2i(-1, -1)   # placing an area piece
var _moving: bool = false                     # dragging the selection
var _move_grab: Vector2i = Vector2i.ZERO
var _move_origin: Vector2i = Vector2i.ZERO
var _panning: bool = false
var _pan_moved: float = 0.0

# UI
var _name_edit: LineEdit
var _maps_option: OptionButton
var _w_spin: SpinBox
var _d_spin: SpinBox
var _status: Label
var _hint: Label
var _info: Label
var _problems: Label
var _tool_buttons: Dictionary = {}
var _panel_title: Label
var _rows: Dictionary = {}       # key -> row Control
var _shape_option: OptionButton
var _mat_option: OptionButton
var _h_spin: SpinBox
var _rot_button: Button
var _pw_spin: SpinBox
var _pd_spin: SpinBox
var _piece_name: LineEdit
var _zone_id: LineEdit
var _updating: bool = false


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Full-resolution, steady view: no PS1 vertex snapping / affine warping in the editor.
	RenderingServer.global_shader_parameter_set(&"ps1_snap_strength", 0.0)
	RenderingServer.global_shader_parameter_set(&"ps1_affine_strength", 0.0)
	_build_scene()
	_build_ui()
	var loaded := MapData.load_map(MapData.active_name())
	_set_map(loaded if loaded != null else MapData.make_default())
	if loaded == null:
		_say("Starter city loaded (not saved yet). Edit it, or use New for an empty map.")
	_set_tool(TOOL_SELECT)


# --- Scene ------------------------------------------------------------------------------

func _build_scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.14, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.76, 0.85)
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.0
	add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.near = 1.0
	_cam.far = 4000.0
	add_child(_cam)
	_cam.make_current()
	_world = Node3D.new()
	add_child(_world)
	_pieces_root = Node3D.new()
	add_child(_pieces_root)
	_ghost = _overlay_box(Color(1.0, 0.9, 0.2, 0.35))
	_select_box = _overlay_box(Color(0.2, 0.9, 1.0, 0.28))


func _overlay_box(color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = true
	m.material_override = material
	m.visible = false
	add_child(m)
	return m


## Ground plane + cell grid for the current map size.
func _build_world() -> void:
	for c in _world.get_children():
		c.queue_free()
	var half := map.half()
	var ground := PlaneMesh.new()
	ground.size = half * 2.0
	Blockout.add_mesh(_world, ground, Vector3(0, -0.02, 0), MapBuilder.flat_mat(Color(0.27, 0.28, 0.31)))
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for x in map.width + 1:
		var major := x % 5 == 0
		lines.surface_set_color(Color(1, 1, 1, 0.28 if major else 0.1))
		lines.surface_add_vertex(Vector3(-half.x + x * MapData.CELL, 0.02, -half.y))
		lines.surface_add_vertex(Vector3(-half.x + x * MapData.CELL, 0.02, half.y))
	for z in map.depth + 1:
		var major := z % 5 == 0
		lines.surface_set_color(Color(1, 1, 1, 0.28 if major else 0.1))
		lines.surface_add_vertex(Vector3(-half.x, 0.02, -half.y + z * MapData.CELL))
		lines.surface_add_vertex(Vector3(half.x, 0.02, -half.y + z * MapData.CELL))
	lines.surface_end()
	var grid := MeshInstance3D.new()
	grid.mesh = lines
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid.material_override = material
	_world.add_child(grid)


func _rebuild_all() -> void:
	for n in _nodes:
		n.queue_free()
	_nodes.clear()
	for p in map.pieces:
		var node := MapBuilder.build_piece(map, p, true)
		_pieces_root.add_child(node)
		_nodes.append(node)
	_refresh_overlays()


func _rebuild_piece(index: int) -> void:
	_nodes[index].queue_free()
	var node := MapBuilder.build_piece(map, map.pieces[index], true)
	_pieces_root.add_child(node)
	_nodes[index] = node
	_refresh_overlays()


# --- UI ---------------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Top bar.
	var top := PanelContainer.new()
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	top.add_child(bar)
	bar.add_child(_text("MAP"))
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = 150
	_name_edit.text_submitted.connect(func(_t: String) -> void: _name_edit.release_focus())
	bar.add_child(_name_edit)
	bar.add_child(_button("Save", _save, "Ctrl+S"))
	bar.add_child(VSeparator.new())
	_maps_option = OptionButton.new()
	_maps_option.custom_minimum_size.x = 130
	bar.add_child(_maps_option)
	bar.add_child(_button("Load", _load_selected))
	bar.add_child(VSeparator.new())
	bar.add_child(_text("Size (cells of 8 m)"))
	_w_spin = _spin(MapData.MIN_SIZE, MapData.MAX_SIZE, 1.0, 50.0)
	bar.add_child(_w_spin)
	bar.add_child(_text("x"))
	_d_spin = _spin(MapData.MIN_SIZE, MapData.MAX_SIZE, 1.0, 50.0)
	bar.add_child(_d_spin)
	bar.add_child(_button("Resize", _resize, "Keep the pieces, change the map size"))
	bar.add_child(_button("New empty", _new_empty, "Empty map of this size"))
	bar.add_child(_button("Starter city", _starter_city, "Replace everything with the generated 8 x 8 block city"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	bar.add_child(_button("Main menu", _to_menu, "Back to the title screen (unsaved changes are lost)"))
	var play := _button("PLAY THIS MAP  (P)", _play, "Save, make it the game's map and drive it. M in the game comes back here.")
	play.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	bar.add_child(play)

	# Left: tools.
	var left := PanelContainer.new()
	root.add_child(left)
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_top = 44
	left.offset_bottom = -92
	var tools := VBoxContainer.new()
	tools.add_theme_constant_override("separation", 3)
	left.add_child(tools)
	tools.add_child(_text("TOOLS"))
	_add_tool(tools, TOOL_SELECT, "Select / move")
	_add_tool(tools, TOOL_ERASE, "Erase")
	tools.add_child(HSeparator.new())
	tools.add_child(_text("PLACE"))
	for type: String in MapData.TYPES:
		_add_tool(tools, type, String(MapData.TYPES[type]["label"]))

	# Right: properties.
	var right := PanelContainer.new()
	root.add_child(right)
	right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_top = 44
	right.offset_bottom = -92
	right.custom_minimum_size.x = 250
	var props := VBoxContainer.new()
	props.add_theme_constant_override("separation", 6)
	right.add_child(props)
	_panel_title = _text("")
	_panel_title.add_theme_font_size_override("font_size", 17)
	props.add_child(_panel_title)
	_shape_option = OptionButton.new()
	_shape_option.item_selected.connect(func(_i: int) -> void: _apply_prop("shape", _shape_option.get_item_text(_shape_option.selected)))
	_row(props, "shape", "Shape", _shape_option)
	_mat_option = OptionButton.new()
	for m in MapData.BUILDING_MATS:
		_mat_option.add_item(m)
	_mat_option.item_selected.connect(func(_i: int) -> void: _apply_prop("mat", _mat_option.get_item_text(_mat_option.selected)))
	_row(props, "mat", "Material", _mat_option)
	_h_spin = _spin(0.0, 120.0, 0.1, 10.0)
	_h_spin.value_changed.connect(func(v: float) -> void: _apply_prop("h", v))
	_row(props, "h", "Height (m)", _h_spin)
	_rot_button = _button("north", _rotate, "R")
	_row(props, "rot", "Facing", _rot_button)
	_pw_spin = _spin(1, MapData.MAX_SIZE, 1.0, 1.0)
	_pw_spin.value_changed.connect(func(v: float) -> void: _apply_prop("w", int(v)))
	_row(props, "w", "Width (cells)", _pw_spin)
	_pd_spin = _spin(1, MapData.MAX_SIZE, 1.0, 1.0)
	_pd_spin.value_changed.connect(func(v: float) -> void: _apply_prop("d", int(v)))
	_row(props, "d", "Depth (cells)", _pd_spin)
	_piece_name = LineEdit.new()
	_piece_name.placeholder_text = "(automatic)"
	_piece_name.text_changed.connect(func(t: String) -> void: _apply_prop("name", t))
	_piece_name.text_submitted.connect(func(_t: String) -> void: _piece_name.release_focus())
	_row(props, "name", "Name", _piece_name)
	_zone_id = LineEdit.new()
	_zone_id.placeholder_text = "e.g. docks"
	_zone_id.text_changed.connect(func(t: String) -> void: _apply_prop("id", t.strip_edges().to_lower()))
	_zone_id.text_submitted.connect(func(_t: String) -> void: _zone_id.release_focus())
	_row(props, "id", "Zone id", _zone_id)
	var presets := HBoxContainer.new()
	for preset in ZONE_PRESETS:
		presets.add_child(_button(preset, func() -> void:
			_zone_id.text = preset
			_apply_prop("id", preset)))
	_row(props, "presets", "Presets", presets)
	var actions := HBoxContainer.new()
	actions.add_child(_button("Delete", _delete_selected, "Del"))
	actions.add_child(_button("Duplicate", _duplicate_selected, "Ctrl+D"))
	_row(props, "actions", "", actions)
	_info = _text("")
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	_info.add_theme_font_size_override("font_size", 13)
	props.add_child(_info)

	# Bottom: status + problems.
	var bottom := PanelContainer.new()
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -88
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	bottom.add_child(lines)
	_status = _text("")
	_status.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	lines.add_child(_status)
	_hint = _text("")
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	lines.add_child(_hint)
	_problems = _text("")
	_problems.add_theme_font_size_override("font_size", 13)
	lines.add_child(_problems)


func _text(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _button(text: String, action: Callable, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b


func _spin(min_v: float, max_v: float, step: float, value: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size.x = 90
	s.get_line_edit().text_submitted.connect(func(_t: String) -> void: s.get_line_edit().release_focus())
	return s


func _row(parent: Container, key: String, label: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var l := _text(label)
	l.custom_minimum_size.x = 100
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	parent.add_child(row)
	_rows[key] = row


func _add_tool(parent: Container, id: String, label: String) -> void:
	var b := _button(label, _set_tool.bind(id))
	b.toggle_mode = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.x = 170
	parent.add_child(b)
	_tool_buttons[id] = b


func _say(text: String) -> void:
	_status.text = text


# --- Map / files ------------------------------------------------------------------------

func _set_map(new_map: MapData) -> void:
	map = new_map
	selected = -1
	_undo.clear()
	_redo.clear()
	_dirty = false
	_name_edit.text = map.name
	_w_spin.value = map.width
	_d_spin.value = map.depth
	_focus = Vector3.ZERO
	_zoom = maxf(map.half().x, map.half().y) * 2.6
	_build_world()
	_rebuild_all()
	_refresh_maps()
	_refresh_panel()
	_refresh_problems()


func _refresh_maps() -> void:
	_maps_option.clear()
	for m in MapData.list_maps():
		_maps_option.add_item(m)
		if m == map.name:
			_maps_option.select(_maps_option.item_count - 1)


func _save() -> bool:
	var wanted := _name_edit.text.strip_edges()
	if wanted == "":
		_say("Give the map a name first.")
		return false
	map.name = wanted
	var err := map.save()
	if err != OK:
		_say("Could not save: %s" % error_string(err))
		return false
	_dirty = false
	_refresh_maps()
	_say("Saved %s  (%d pieces)" % [MapData.path_for(map.name), map.pieces.size()])
	return true


func _load_selected() -> void:
	if _maps_option.selected < 0:
		_say("No saved maps yet.")
		return
	var loaded := MapData.load_map(_maps_option.get_item_text(_maps_option.selected))
	if loaded == null:
		_say("Could not load that map.")
		return
	_set_map(loaded)
	_say("Loaded '%s'" % map.name)


func _new_empty() -> void:
	var wanted := _name_edit.text.strip_edges()
	_set_map(MapData.make_empty(wanted if wanted != "" and wanted != map.name else "new_map", int(_w_spin.value), int(_d_spin.value)))
	_say("Empty map. Place buildings to shape the streets, then taxi stops, a repair shop and a player start.")


func _starter_city() -> void:
	var wanted := _name_edit.text.strip_edges()
	var city := MapData.make_default()
	city.name = wanted if wanted != "" else MapData.DEFAULT_NAME
	_set_map(city)
	_say("Starter city generated (not saved yet).")


func _resize() -> void:
	_push_undo()
	map.width = int(_w_spin.value)
	map.depth = int(_d_spin.value)
	_build_world()
	_rebuild_all()
	_refresh_problems()
	_say("Map is now %d x %d cells (%d x %d m)." % [map.width, map.depth, map.width * 8, map.depth * 8])


func _play() -> void:
	if map.has_errors():
		_refresh_problems()
		_say("Fix the ERRORS below before playing.")
		return
	if not _save():
		return
	MapData.set_active(map.name)
	MapData.override = null
	# The world is rebuilt from scratch: that is a new run (cash, guns, heat back to the
	# start), the same as PLAY in the main menu.
	GameState.reset_run()
	GameState.tutorial_active = false
	get_tree().change_scene_to_file(MAIN_SCENE)


func _to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


# --- Undo -------------------------------------------------------------------------------

func _snapshot() -> String:
	return JSON.stringify({"w": map.width, "d": map.depth, "pieces": map.pieces})


func _push_undo() -> void:
	_undo.append(_snapshot())
	if _undo.size() > MAX_UNDO:
		_undo.remove_at(0)
	_redo.clear()
	_dirty = true


func _restore(snapshot: String) -> void:
	var data: Dictionary = JSON.parse_string(snapshot)
	var size_changed := int(data["w"]) != map.width or int(data["d"]) != map.depth
	map.width = int(data["w"])
	map.depth = int(data["d"])
	map.pieces.clear()
	for raw: Variant in data["pieces"]:
		var p := MapData.sanitize(raw)
		if not p.is_empty():
			map.pieces.append(p)
	selected = -1
	if size_changed:
		_w_spin.value = map.width
		_d_spin.value = map.depth
		_build_world()
	_rebuild_all()
	_refresh_panel()
	_refresh_problems()


func _undo_step() -> void:
	if _undo.is_empty():
		return
	_redo.append(_snapshot())
	_restore(_undo.pop_back())
	_say("Undo")


func _redo_step() -> void:
	if _redo.is_empty():
		return
	_undo.append(_snapshot())
	_restore(_redo.pop_back())
	_say("Redo")


# --- Tools ------------------------------------------------------------------------------

func _set_tool(id: String) -> void:
	tool = id
	_drag_from = Vector2i(-1, -1)
	_moving = false
	for key: String in _tool_buttons:
		(_tool_buttons[key] as Button).set_pressed_no_signal(key == id)
	if id != TOOL_SELECT:
		selected = -1
	_refresh_panel()
	_refresh_overlays()


## The piece the properties panel edits: the selection, or the brush of the placing tool.
func _target() -> Dictionary:
	if tool == TOOL_SELECT:
		return map.pieces[selected] if selected >= 0 and selected < map.pieces.size() else {}
	if tool == TOOL_ERASE:
		return {}
	if not _brushes.has(tool):
		_brushes[tool] = MapData.make_piece(tool, 0, 0)
	return _brushes[tool]


func _apply_prop(key: String, value: Variant) -> void:
	if _updating:
		return
	var p := _target()
	if p.is_empty() or p.get(key) == value:
		return
	var editing_piece := tool == TOOL_SELECT
	if editing_piece:
		_push_undo()
	p[key] = value
	if editing_piece:
		_rebuild_piece(selected)
		_refresh_problems()
	_refresh_panel()


func _rotate() -> void:
	var p := _target()
	if p.is_empty() or not ROTATABLE.has(String(p["type"])):
		return
	_apply_prop("rot", (int(p["rot"]) + 1) % 4)


func _change_height(direction: float) -> void:
	var p := _target()
	if p.is_empty():
		return
	var info: Dictionary = MapData.TYPES[String(p["type"])]
	if float(info["max_h"]) <= 0.0:
		return
	var step := 2.0 if float(p["h"]) >= 12.0 else (1.0 if float(p["h"]) >= 3.0 else 0.2)
	_apply_prop("h", clampf(snappedf(float(p["h"]) + direction * step, 0.1), float(info["min_h"]), float(info["max_h"])))


func _place(rect: Rect2i) -> void:
	var brush := _target()
	if brush.is_empty():
		return
	var info: Dictionary = MapData.TYPES[tool]
	var p := brush.duplicate(true)
	p["x"] = rect.position.x
	p["z"] = rect.position.y
	p["w"] = rect.size.x if bool(info["area"]) else 1
	p["d"] = rect.size.y if bool(info["area"]) else 1
	if not map.in_bounds(p):
		_say("That is outside the map.")
		return
	if tool == "spawn":   # only one player start
		for i in range(map.pieces.size() - 1, -1, -1):
			if String(map.pieces[i]["type"]) == "spawn":
				_push_undo()
				map.pieces.remove_at(i)
				_rebuild_all()
				break
	for other in map.pieces:
		if other["type"] == p["type"] and MapData.rect_of(other) == MapData.rect_of(p):
			_say("There is already a %s exactly there." % String(info["label"]).to_lower())
			return
	_push_undo()
	map.pieces.append(p)
	var node := MapBuilder.build_piece(map, p, true)
	_pieces_root.add_child(node)
	_nodes.append(node)
	_refresh_problems()
	_say("%s placed at %d,%d (%d x %d cells)" % [info["label"], p["x"], p["z"], p["w"], p["d"]])


func _delete(index: int) -> void:
	if index < 0 or index >= map.pieces.size():
		return
	_push_undo()
	map.pieces.remove_at(index)
	_nodes[index].queue_free()
	_nodes.remove_at(index)
	selected = -1
	_refresh_panel()
	_refresh_overlays()
	_refresh_problems()


func _delete_selected() -> void:
	if tool == TOOL_SELECT:
		_delete(selected)


func _duplicate_selected() -> void:
	if tool != TOOL_SELECT or selected < 0:
		return
	var p: Dictionary = map.pieces[selected].duplicate(true)
	p["x"] = int(p["x"]) + int(p["w"])
	if not map.in_bounds(p):
		p["x"] = int(map.pieces[selected]["x"])
		p["z"] = int(p["z"]) + int(p["d"])
	if not map.in_bounds(p):
		_say("No room next to it for a copy.")
		return
	_push_undo()
	map.pieces.append(p)
	var node := MapBuilder.build_piece(map, p, true)
	_pieces_root.add_child(node)
	_nodes.append(node)
	selected = map.pieces.size() - 1
	_refresh_panel()
	_refresh_overlays()
	_refresh_problems()


# --- Input ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	if not typing and not Input.is_key_pressed(KEY_CTRL):
		var pan := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			pan.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			pan.x += 1.0
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			pan.z -= 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			pan.z += 1.0
		_focus += pan * _zoom * 0.9 * delta
	var half := map.half()
	_focus.x = clampf(_focus.x, -half.x, half.x)
	_focus.z = clampf(_focus.z, -half.y, half.y)
	var tilt := deg_to_rad(38.0 if _tilted else 0.5)
	_cam.position = _focus + Vector3(0.0, cos(tilt), sin(tilt)) * _zoom
	_cam.look_at(_focus, Vector3.UP if _tilted else Vector3.FORWARD)

	var over_ui := get_viewport().gui_get_hovered_control() != null
	var cell := _cell_under_mouse()
	if cell != _hover or over_ui:
		_hover = cell if not over_ui else Vector2i(-1, -1)
		if _moving and _hover.x >= 0:
			_drag_move()
		_refresh_overlays()
	if tool == TOOL_ERASE and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _hover.x >= 0:
		var idx := map.piece_at(_hover)
		if idx >= 0:
			_delete(idx)


func _cell_under_mouse() -> Vector2i:
	var mouse := get_viewport().get_mouse_position()
	var origin := _cam.project_ray_origin(mouse)
	var dir := _cam.project_ray_normal(mouse)
	if dir.y > -0.001:
		return Vector2i(-1, -1)
	var hit := origin + dir * (-origin.y / dir.y)
	var cell := map.world_to_cell(hit)
	if cell.x < 0 or cell.y < 0 or cell.x >= map.width or cell.y >= map.depth:
		return Vector2i(-1, -1)
	return cell


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_mouse_button(event)
	elif event is InputEventMouseMotion and _panning:
		var motion := event as InputEventMouseMotion
		_pan_moved += motion.relative.length()
		var scale_px := _zoom * 2.0 * tan(deg_to_rad(_cam.fov * 0.5)) / get_viewport().get_visible_rect().size.y
		_focus -= Vector3(motion.relative.x, 0.0, motion.relative.y) * scale_px
	elif event is InputEventKey and event.pressed:
		_key(event)


func _mouse_button(event: InputEventMouseButton) -> void:
	get_viewport().gui_release_focus()
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(_zoom * 0.88, 25.0)
		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(_zoom * 1.14, 2600.0)
		MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_panning = true
				_pan_moved = 0.0
			else:
				_panning = false
				# A right CLICK (no drag): leave the placing tool / drop the selection.
				if event.button_index == MOUSE_BUTTON_RIGHT and _pan_moved < 6.0:
					if tool != TOOL_SELECT:
						_set_tool(TOOL_SELECT)
					else:
						selected = -1
						_refresh_panel()
						_refresh_overlays()
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_left_down()
			else:
				_left_up()


func _left_down() -> void:
	if _hover.x < 0:
		return
	if tool == TOOL_SELECT:
		var idx := map.piece_at(_hover)
		# Clicking the selected zone's area picks what is under it instead of the zone again.
		selected = idx
		if selected >= 0:
			_moving = true
			_move_grab = _hover
			_move_origin = Vector2i(int(map.pieces[selected]["x"]), int(map.pieces[selected]["z"]))
			_undo.append(_snapshot())   # dropped again if the piece is not moved
		_refresh_panel()
		_refresh_overlays()
	elif tool != TOOL_ERASE:
		if bool(MapData.TYPES[tool]["area"]):
			_drag_from = _hover
		else:
			_place(Rect2i(_hover, Vector2i.ONE))
		_refresh_overlays()


func _left_up() -> void:
	if _moving:
		_moving = false
		var p: Dictionary = map.pieces[selected] if selected >= 0 else {}
		if p.is_empty() or Vector2i(int(p["x"]), int(p["z"])) == _move_origin:
			_undo.pop_back()
		else:
			_redo.clear()
			_dirty = true
			_refresh_problems()
	elif _drag_from.x >= 0:
		var to := _hover if _hover.x >= 0 else _drag_from
		_place(_rect_between(_drag_from, to))
		_drag_from = Vector2i(-1, -1)
	_refresh_overlays()


func _drag_move() -> void:
	var p: Dictionary = map.pieces[selected]
	var wanted := _move_origin + (_hover - _move_grab)
	wanted.x = clampi(wanted.x, 0, map.width - int(p["w"]))
	wanted.y = clampi(wanted.y, 0, map.depth - int(p["d"]))
	if wanted == Vector2i(int(p["x"]), int(p["z"])):
		return
	p["x"] = wanted.x
	p["z"] = wanted.y
	_nodes[selected].position = map.piece_center(p)


static func _rect_between(a: Vector2i, b: Vector2i) -> Rect2i:
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


func _key(event: InputEventKey) -> void:
	var ctrl := event.ctrl_pressed
	match event.physical_keycode:
		KEY_Z:
			if ctrl:
				_undo_step()
		KEY_Y:
			if ctrl:
				_redo_step()
		KEY_S:
			if ctrl and not event.echo:
				_save()
		KEY_D:
			if ctrl and not event.echo:
				_duplicate_selected()
		KEY_F5, KEY_P:
			if not event.echo:
				# _play() changes scene, which takes this node out of the tree at once.
				get_viewport().set_input_as_handled()
				_play()
				return
		KEY_R:
			if not event.echo:
				_rotate()
		KEY_T:
			if not event.echo:
				_tilted = not _tilted
		KEY_BRACKETLEFT:
			_change_height(-1.0)
		KEY_BRACKETRIGHT:
			_change_height(1.0)
		KEY_DELETE, KEY_BACKSPACE:
			_delete_selected()
		KEY_ESCAPE:
			_set_tool(TOOL_SELECT)
		_:
			return
	get_viewport().set_input_as_handled()


# --- Feedback ---------------------------------------------------------------------------

func _fit_box(box: MeshInstance3D, rect: Rect2i, height: float) -> void:
	var size := Vector3(rect.size.x * MapData.CELL, maxf(height, 0.4), rect.size.y * MapData.CELL)
	(box.mesh as BoxMesh).size = size
	box.position = map.cell_corner(rect.position.x, rect.position.y) + Vector3(size.x * 0.5, size.y * 0.5, size.z * 0.5)
	box.visible = true


func _refresh_overlays() -> void:
	_ghost.visible = false
	_select_box.visible = false
	if map == null:
		return
	if tool == TOOL_SELECT:
		if selected >= 0 and selected < map.pieces.size():
			var p := map.pieces[selected]
			_fit_box(_select_box, MapData.rect_of(p), float(p["h"]) + 0.6)
		elif _hover.x >= 0:
			_fit_box(_ghost, Rect2i(_hover, Vector2i.ONE), 0.4)
	elif tool == TOOL_ERASE:
		if _hover.x >= 0:
			_fit_box(_ghost, Rect2i(_hover, Vector2i.ONE), 0.4)
	elif _hover.x >= 0 or _drag_from.x >= 0:
		var brush := _target()
		var rect := Rect2i(_hover, Vector2i.ONE)
		if _drag_from.x >= 0:
			rect = _rect_between(_drag_from, _hover if _hover.x >= 0 else _drag_from)
		_fit_box(_ghost, rect, float(brush["h"]))
	_refresh_hint()


func _refresh_hint() -> void:
	var where := ""
	if _hover.x >= 0:
		var zone := map.zone_name_at(_hover)
		where = "cell %d,%d%s   ·   " % [_hover.x, _hover.y, ("  (" + zone + ")") if zone != "" else ""]
	if _drag_from.x >= 0 and _hover.x >= 0:
		var r := _rect_between(_drag_from, _hover)
		where += "%d x %d cells = %d x %d m   ·   " % [r.size.x, r.size.y, r.size.x * 8, r.size.y * 8]
	_hint.text = where + "LMB place / select · drag: rectangle / move · RMB: Select tool · wheel: zoom · RMB or MMB drag, WASD: pan · T tilt · R rotate · [ ] height · Del · Ctrl+Z / Y · Ctrl+S · P play"


func _refresh_problems() -> void:
	var issues := map.validate()
	var summary := "%d x %d cells (%d x %d m)   ·   %d pieces   ·   %d stops   ·   %d repair shops   ·   " % [
		map.width, map.depth, map.width * 8, map.depth * 8, map.pieces.size(), map.count("stop"), map.count("repair")]
	if issues.is_empty():
		_problems.text = summary + "map OK"
		_problems.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	else:
		_problems.text = summary + "   |   ".join(issues)
		var bad := map.has_errors()
		_problems.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if bad else Color(1.0, 0.85, 0.4))


func _refresh_panel() -> void:
	_updating = true
	var p := _target()
	for key: String in _rows:
		(_rows[key] as Control).visible = false
	if p.is_empty():
		if tool == TOOL_ERASE:
			_panel_title.text = "ERASE"
			_info.text = "Click or drag over pieces to remove them."
		else:
			_panel_title.text = "SELECT"
			_info.text = "Click a piece to edit it here. Drag it to move it. Pick a piece type on the left to build.\n\nEverything you do not cover with a solid piece is road: streets are simply the gaps you leave between buildings (2 cells = a 16 m street with a centre line)."
		_updating = false
		return
	var type := String(p["type"])
	var info: Dictionary = MapData.TYPES[type]
	var editing := tool == TOOL_SELECT
	_panel_title.text = ("EDIT: " if editing else "PLACE: ") + String(info["label"]).to_upper()
	var shapes: Array = info["shapes"]
	if shapes.size() > 1:
		(_rows["shape"] as Control).visible = true
		_shape_option.clear()
		for s: String in shapes:
			_shape_option.add_item(s)
			if s == String(p["shape"]):
				_shape_option.select(_shape_option.item_count - 1)
	if type == "building":
		(_rows["mat"] as Control).visible = true
		var mat_index := MapData.BUILDING_MATS.find(String(p["mat"]))
		_mat_option.select(maxi(mat_index, 0))
	if float(info["max_h"]) > 0.0:
		(_rows["h"] as Control).visible = true
		_h_spin.min_value = float(info["min_h"])
		_h_spin.max_value = float(info["max_h"])
		_h_spin.step = 1.0 if type == "containers" else 0.1
		_h_spin.value = float(p["h"])
	if ROTATABLE.has(type):
		(_rows["rot"] as Control).visible = true
		_rot_button.text = MapData.DIR_NAMES[int(p["rot"])] + "  (R)"
	if editing and bool(info["area"]):
		(_rows["w"] as Control).visible = true
		(_rows["d"] as Control).visible = true
		_pw_spin.value = int(p["w"])
		_pd_spin.value = int(p["d"])
	if type == "stop" or type == "zone":
		(_rows["name"] as Control).visible = true
		if _piece_name.text != String(p["name"]):
			_piece_name.text = String(p["name"])
	if type == "zone":
		(_rows["id"] as Control).visible = true
		(_rows["presets"] as Control).visible = true
		if _zone_id.text != String(p["id"]):
			_zone_id.text = String(p["id"])
	(_rows["actions"] as Control).visible = editing
	_info.text = _help_for(type, p)
	_updating = false


func _help_for(type: String, p: Dictionary) -> String:
	match type:
		"building":
			return "Drag a rectangle. Shapes: box, tower (setback top), stepped (3 tiers), l_shape, round, house (pitched roof). It stands on its own sidewalk. Solid: cars route around it."
		"plaza":
			if String(p["shape"]) == "flat":
				return "A sheer platform. Put low stairs or wedge ramps against it to get on top."
			return "A raised plaza with low stairs all the way round: you can drive up from any side. Height / 0.2 m = number of steps."
		"stairs":
			return "A flight of low steps (0.2 m each) rising towards 'Facing'. Drivable. Put it against a platform, or use it as a bump."
		"ramp":
			return "kicker: a jump ramp, open at the high end. At 3 m or more it throws you over ONE level of containers placed right behind it (2.8 m); give it a few cells of run-up.\nwedge: a solid ramp up to a platform.\nRises towards 'Facing'."
		"sidewalk":
			return "A raised curb slab. Cars prefer the street but can drive over it."
		"containers":
			return "Rows of shipping containers. Height 1 = one level everywhere (2.8 m: a 3 m kicker ramp jumps it). Height 2-3 = stacks of mixed height up to that many levels."
		"pillar":
			return "A single post in the middle of the cell."
		"repair":
			return "Garage with a yellow pad on the 'Facing' side. Stop on the pad and press E to repair (a ring and a light-blue beam mark it). Put a few around the map and keep the pad reachable from the street."
		"gunshop":
			return "Gun store with a green pad on the 'Facing' side. Stop on the pad and press E to buy guns (SMG, sawed-off, rifle) and ammo. One or two per map; keep the pad reachable from the street."
		"stop":
			return "Where passengers wait and get dropped off. Place it on a STREET cell next to a sidewalk; 'Facing' is the side the passenger stands on. Name it, or leave it empty for an automatic name. More stops = more variety (12+)."
		"drink":
			return "A floating energy drink: drive through it to heal."
		"zone":
			return "A neighbourhood. The zone id is the district of every stop inside it: passengers and their stories are tied to districts (downtown, suburbs, docks exist today; new ids are for the neighbourhoods to come). Invisible in the game."
		"spawn":
			return "Where the taxi starts, looking towards 'Facing'. Only one."
	return ""
