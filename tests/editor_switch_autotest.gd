extends Node
## Game -> M -> map editor -> real input events (keys, mouse) -> P -> game.
## Run WINDOWED (real input pipeline):
##   <console exe> --path <project> res://tests/editor_switch_autotest.tscn
## The driver lives under the root so it survives the scene changes. Saves nothing unless the
## editor's PLAY step runs (it writes the map `_autotest_map`).

const MAIN_SCENE := "res://src/main/main.tscn"


func _ready() -> void:
	var driver := Driver.new()
	driver.name = "EditorSwitchDriver"
	driver.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(driver)
	get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)


class Driver:
	extends Node

	var _failed: bool = false

	func _ready() -> void:
		_run.call_deferred()

	func _frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame

	func _check(ok: bool, what: String) -> void:
		if not ok:
			_failed = true
			print("[EditorSwitchTest] FAIL: %s" % what)

	func _key(code: Key, pressed: bool, ctrl: bool = false) -> void:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = pressed
		e.ctrl_pressed = ctrl
		Input.parse_input_event(e)

	func _tap(code: Key) -> void:
		_key(code, true)
		await _frames(3)
		_key(code, false)
		await _frames(3)

	func _move(pos: Vector2) -> void:
		var e := InputEventMouseMotion.new()
		e.position = pos
		e.global_position = pos
		Input.parse_input_event(e)

	func _button(pos: Vector2, pressed: bool, index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
		var e := InputEventMouseButton.new()
		e.position = pos
		e.global_position = pos
		e.button_index = index
		e.pressed = pressed
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and index == MOUSE_BUTTON_LEFT else 0
		Input.parse_input_event(e)

	func _click(pos: Vector2) -> void:
		_move(pos)
		await _frames(3)
		_button(pos, true)
		await _frames(3)
		_button(pos, false)
		await _frames(3)

	func _run() -> void:
		await _frames(90)
		if "--direct" in OS.get_cmdline_user_args():
			get_tree().change_scene_to_file("res://src/editor/map_editor.tscn")
			await _frames(30)
			await _editor_checks()
			return _finish()
		var scene := get_tree().current_scene
		print("[EditorSwitchTest] in the game: scene %s, mouse_mode %d" % [scene.name, Input.mouse_mode])
		# The player clicks into the game first (captures the mouse), then presses M.
		await _click(Vector2(640, 360))
		print("[EditorSwitchTest] after a click in the game: mouse_mode %d" % Input.mouse_mode)
		await _tap(KEY_M)
		await _frames(30)
		var editor := get_tree().current_scene
		_check(editor != null and editor.name == "MapEditor", "M did not open the editor")
		if _failed:
			return _finish()
		await _editor_checks()
		_finish()

	func _editor_checks() -> void:
		var editor := get_tree().current_scene
		print("[EditorSwitchTest] editor open: paused=%s mouse_mode=%d (0 = visible) pieces=%d" % [
			get_tree().paused, Input.mouse_mode, editor.map.pieces.size()])
		_check(not get_tree().paused, "tree paused in the editor")
		_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "mouse not visible in the editor")

		# Keyboard pan.
		var focus_before: Vector3 = editor._focus
		_key(KEY_D, true)
		await _frames(20)
		_key(KEY_D, false)
		await _frames(3)
		print("[EditorSwitchTest] pan with D: focus x %.1f -> %.1f" % [focus_before.x, editor._focus.x])
		_check(editor._focus.x > focus_before.x + 1.0, "D did not pan the view")

		# Wheel zoom over the map.
		var zoom_before: float = editor._zoom
		_move(Vector2(640, 380))
		await _frames(3)
		_button(Vector2(640, 380), true, MOUSE_BUTTON_WHEEL_UP)
		await _frames(3)
		print("[EditorSwitchTest] wheel: zoom %.0f -> %.0f" % [zoom_before, editor._zoom])
		_check(editor._zoom < zoom_before, "wheel did not zoom")

		# Click a tool button in the left panel.
		var tool_button: Button = editor._tool_buttons["pillar"]
		await _click(tool_button.get_global_rect().get_center())
		var hovered := get_viewport().gui_get_hovered_control()
		print("[EditorSwitchTest] clicked the Pillar tool: tool = %s (button rect %s, hovered %s, viewport mouse %s, window %s)" % [
			editor.tool, tool_button.get_global_rect(), hovered.get_path() if hovered != null else "none",
			get_viewport().get_mouse_position(), get_window().size])
		_check(editor.tool == "pillar", "clicking a tool button did not select the tool")

		# Place it with a click on the map, then select it, then delete it.
		var count_before: int = editor.map.pieces.size()
		var spot := Vector2(640, 380)
		await _click(spot)
		print("[EditorSwitchTest] click on the map (cell %s): pieces %d -> %d" % [
			editor._hover, count_before, editor.map.pieces.size()])
		_check(editor.map.pieces.size() == count_before + 1, "clicking the map did not place a piece")
		_button(spot, true, MOUSE_BUTTON_RIGHT)
		await _frames(2)
		_button(spot, false, MOUSE_BUTTON_RIGHT)
		await _frames(3)
		_check(editor.tool == "select", "right click did not go back to Select")
		await _click(spot)
		print("[EditorSwitchTest] select tool, click the same cell: selected index %d" % editor.selected)
		_check(editor.selected >= 0, "clicking a piece did not select it")
		await _tap(KEY_DELETE)
		_check(editor.map.pieces.size() == count_before, "Del did not delete the selection")

		# Back to the game with F5 (saves under a throw-away name).
		editor._name_edit.text = "_autotest_map"
		await _tap(KEY_P)
		await _frames(60)
		var game := get_tree().current_scene
		print("[EditorSwitchTest] after P: scene %s" % (game.name if game != null else "null"))
		_check(game != null and game.name != "MapEditor", "P did not start the game")

	func _finish() -> void:
		# Do not leave the throw-away map as the game's map.
		if FileAccess.file_exists("user://active_map.txt"):
			if FileAccess.get_file_as_string("user://active_map.txt").strip_edges() == "_autotest_map":
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://active_map.txt"))
		print("[EditorSwitchTest] %s" % ("FAIL" if _failed else "PASS"))
		get_tree().quit(1 if _failed else 0)
