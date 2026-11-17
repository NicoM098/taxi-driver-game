extends Node
## Headless test of the open-world map base (MapData / MapBuilder / City / map editor):
##  A. the built-in city is valid; a map survives save -> load unchanged
##  B. every piece type and shape builds
##  C. a hand-made map: the road graph routes AROUND a building and a sheer platform, stops
##     get the district of their zone, validation reports a stop inside a building
##  D. physics: the taxi rests on top of a stepped plaza, a flat platform and a flight of
##     stairs (the collision is where the geometry is)
##  E. the map editor scene: place / select / edit / move / delete / undo / redo / save
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/map_autotest.tscn
## Windowed + `-- --shot-dir=<dir>` saves a screenshot of the editor.

const TAXI := preload("res://src/vehicle/taxi.tscn")
const EDITOR := preload("res://src/editor/map_editor.tscn")
const TEST_NAME := "_autotest_map"

var _errors: PackedStringArray = []
var _t: float = 0.0
var _shot_dir: String = ""


func _ready() -> void:
	ShopMenu.enabled = false   # shops in the city (D-089 keeps them, switched off)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			_shot_dir = arg.get_slice("=", 1)
	_run()


func _physics_process(delta: float) -> void:
	_t += delta


func _run() -> void:
	_test_data()
	_test_builder()
	var map := _custom_map()
	_test_custom_map(map)
	await _test_physics(map)
	await _test_editor()
	if FileAccess.file_exists(MapData.path_for(TEST_NAME)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MapData.path_for(TEST_NAME)))
	if _errors.is_empty():
		print("[MapTest] PASS")
		get_tree().quit(0)
	else:
		for e in _errors:
			print("[MapTest] FAIL: ", e)
		get_tree().quit(1)


# --- A ----------------------------------------------------------------------------------

func _test_data() -> void:
	var city := MapData.make_default()
	var issues := city.validate()
	print("[MapTest] A built-in city: %d x %d cells, %d pieces, %d stops, %d repair shops, issues %s" % [
		city.width, city.depth, city.pieces.size(), city.count("stop"), city.count("repair"), issues])
	if not issues.is_empty():
		_errors.append("A: the built-in city has issues: %s" % [issues])
	if city.count("stop") != 128 or city.count("repair") != 3 or city.count("spawn") != 1:
		_errors.append("A: built-in city content changed unexpectedly")
	city.name = TEST_NAME
	var err := city.save()
	var back := MapData.load_map(TEST_NAME)
	if err != OK or back == null:
		_errors.append("A: save / load failed (%s)" % error_string(err))
		return
	var same := JSON.stringify(back.to_dict()) == JSON.stringify(city.to_dict())
	print("[MapTest] A save -> load: identical=%s, listed=%s" % [same, MapData.list_maps().has(TEST_NAME)])
	if not same:
		_errors.append("A: the map changed in a save -> load round trip")
	if not MapData.list_maps().has(TEST_NAME):
		_errors.append("A: saved map is not listed")


# --- B ----------------------------------------------------------------------------------

func _test_builder() -> void:
	var map := MapData.make_empty("builder", 40, 40)
	var built := 0
	for type: String in MapData.TYPES:
		for shape: String in MapData.TYPES[type]["shapes"]:
			for rot in 4:
				var p := MapData.make_piece(type, 4, 4, 3, 2)
				p["shape"] = shape
				p["rot"] = rot
				for editor: bool in [false, true]:
					var node := MapBuilder.build_piece(map, p, editor)
					if node == null:
						_errors.append("B: %s/%s did not build" % [type, shape])
					else:
						built += 1
						node.free()
	print("[MapTest] B built %d piece variants" % built)


# --- C ----------------------------------------------------------------------------------

## 24 x 24 cells: a long building wall across the middle with one gap, a sheer platform, a
## stepped plaza, stairs, zones and stops.
func _custom_map() -> MapData:
	var map := MapData.make_empty("custom", 24, 24)
	var north := MapData.make_piece("zone", 0, 0, 24, 12)
	north["id"] = "oldtown"
	north["name"] = "Old Town"
	map.pieces.append(north)
	var south := MapData.make_piece("zone", 0, 12, 24, 12)
	south["id"] = "docks"
	map.pieces.append(south)
	# Wall of buildings at z = 11..12 from x = 0 to 19: the only way through is x = 20..23.
	var wall := MapData.make_piece("building", 0, 11, 20, 2)
	wall["shape"] = "l_shape"
	map.pieces.append(wall)
	var platform := MapData.make_piece("plaza", 3, 3, 3, 3)
	platform["shape"] = "flat"
	platform["h"] = 2.0
	map.pieces.append(platform)
	var stairs := MapData.make_piece("stairs", 4, 6, 1, 2)   # rises north, up to the platform
	stairs["h"] = 2.0
	map.pieces.append(stairs)
	var plaza := MapData.make_piece("plaza", 10, 2, 5, 5)
	plaza["h"] = 0.8
	map.pieces.append(plaza)
	map.pieces.append(MapData.make_piece("repair", 16, 16, 3, 3))
	for cell: Vector2i in [Vector2i(2, 9), Vector2i(21, 4), Vector2i(8, 16), Vector2i(21, 20)]:
		var stop := MapData.make_piece("stop", cell.x, cell.y)
		stop["rot"] = 2
		map.pieces.append(stop)
	var named := MapData.make_piece("stop", 12, 9)
	named["name"] = "Clock Tower"
	map.pieces.append(named)
	var spawn := MapData.make_piece("spawn", 1, 1)
	spawn["rot"] = 1
	map.pieces.append(spawn)
	return map


func _test_custom_map(map: MapData) -> void:
	if map.has_errors():
		_errors.append("C: the custom map is invalid: %s" % [map.validate()])
	var city := City.new()
	city.map = map
	add_child(city)
	var a := map.cell_center(2, 2)
	var b := map.cell_center(2, 20)
	var route := city.get_route(a, b, true)
	var length := 0.0
	var through_solid := 0
	for i in range(1, route.size()):
		length += route[i - 1].distance_to(route[i])
		if not city.is_free(route[i]):
			through_solid += 1
	var east_most := -INF
	for pt in route:
		east_most = maxf(east_most, pt.x)
	print("[MapTest] C route around the wall: %d points, %.0f m (straight %.0f m), eastmost x %.0f, points in solids %d" % [
		route.size(), length, a.distance_to(b), east_most, through_solid])
	if through_solid > 0 or length < a.distance_to(b) * 1.8 or east_most < map.cell_corner(20, 0).x:
		_errors.append("C: the route does not go round the building wall through the gap")
	if city.is_free(map.cell_center(4, 4)):
		_errors.append("C: a 2 m sheer platform is not solid for the road graph")
	if not city.is_free(map.cell_center(12, 4)):
		_errors.append("C: a stepped plaza should be drivable")
	var names: PackedStringArray = []
	var by_district := {}
	for s in city.stops:
		if s.curbside:
			continue   # generated along the kerbs, not part of the hand-made map
		names.append(s.stop_name)
		by_district[s.district] = int(by_district.get(s.district, 0)) + 1
	print("[MapTest] C stops %s, districts %s, repair shops %d" % [names, by_district, city.repair_shops.size()])
	if by_district.get(&"oldtown", 0) != 3 or by_district.get(&"docks", 0) != 2:
		_errors.append("C: stops did not get the district of their zone")
	if not names.has("Clock Tower") or not names[0].begins_with("Old Town"):
		_errors.append("C: stop names wrong (custom name / zone based name)")
	if city.repair_shops.size() != 1:
		_errors.append("C: repair shop missing")
	var bad := map.duplicate_map()
	bad.pieces.append(MapData.make_piece("stop", 5, 11))
	if not bad.has_errors():
		_errors.append("C: a stop inside a building was not reported")
	remove_child(city)
	city.free()


# --- D ----------------------------------------------------------------------------------

func _test_physics(map: MapData) -> void:
	var world := Node3D.new()
	add_child(world)
	var city := City.new()
	city.map = map
	world.add_child(city)
	var taxi := TAXI.instantiate() as Taxi
	taxi.position = map.cell_center(1, 1) + Vector3(0, 1.2, 0)
	world.add_child(taxi)
	await _wait(1.5)
	var start_cell := map.world_to_cell(taxi.global_position)
	var street_y := taxi.global_position.y
	print("[MapTest] D taxi starts in cell %s (spawn piece at 1,1), resting height on the street %.2f" % [start_cell, street_y])
	if start_cell != Vector2i(1, 1):
		_errors.append("D: the taxi is not at the map's player start")
	# [label, cell, expected surface height]
	for probe: Array in [["stepped plaza top", Vector2i(12, 4), 0.8], ["flat platform", Vector2i(4, 4), 2.0]]:
		var cell: Vector2i = probe[1]
		taxi.teleport(Transform3D(Basis.IDENTITY, map.cell_center(cell.x, cell.y) + Vector3(0, float(probe[2]) + 1.5, 0)))
		await _wait(1.5)
		var rise := taxi.global_position.y - street_y
		print("[MapTest] D on the %s: %.2f m above street level (expected %.2f)" % [probe[0], rise, probe[2]])
		if absf(rise - float(probe[2])) > 0.15:
			_errors.append("D: taxi does not rest on the %s (%.2f m)" % [probe[0], rise])
	# Stairs at cells (4,6)-(4,7), rising north to 2.0 m: the middle is about half way up.
	var mid := map.cell_corner(4, 7) + Vector3(MapData.CELL * 0.5, 0, 0)
	taxi.teleport(Transform3D(Basis.IDENTITY, mid + Vector3(0, 3.0, 0)))
	await _wait(0.6)
	var on_stairs := taxi.global_position.y - street_y
	print("[MapTest] D dropped on the middle of the stairs: %.2f m above street level after 0.6 s" % on_stairs)
	if on_stairs < 0.3:
		_errors.append("D: the stairs have no collision")
	remove_child(world)
	world.free()


# --- E ----------------------------------------------------------------------------------

func _test_editor() -> void:
	var editor := EDITOR.instantiate()
	add_child(editor)
	await _wait(0.2)
	editor.call(&"_set_map", MapData.make_empty(TEST_NAME, 30, 30))
	editor.call(&"_set_tool", "building")
	editor.call(&"_apply_prop", "shape", "tower")
	editor.call(&"_apply_prop", "h", 30.0)
	editor.call(&"_place", Rect2i(4, 4, 3, 4))
	editor.call(&"_set_tool", "plaza")
	editor.call(&"_place", Rect2i(10, 4, 5, 5))
	editor.call(&"_set_tool", "stairs")
	editor.call(&"_place", Rect2i(16, 5, 1, 2))
	editor.call(&"_set_tool", "ramp")
	editor.call(&"_place", Rect2i(20, 5, 1, 1))
	editor.call(&"_set_tool", "repair")
	editor.call(&"_place", Rect2i(4, 14, 3, 3))
	editor.call(&"_set_tool", "zone")
	editor.call(&"_apply_prop", "id", "harbour")
	editor.call(&"_place", Rect2i(0, 0, 30, 12))
	editor.call(&"_set_tool", "stop")
	editor.call(&"_place", Rect2i(8, 5, 1, 1))
	editor.call(&"_place", Rect2i(8, 20, 1, 1))
	editor.call(&"_set_tool", "spawn")
	editor.call(&"_place", Rect2i(2, 2, 1, 1))
	editor.call(&"_place", Rect2i(2, 3, 1, 1))   # replaces the first one
	var m: MapData = editor.get(&"map")
	print("[MapTest] E placed: %d pieces (%d spawn), building %s h %.0f, issues %s" % [
		m.pieces.size(), m.count("spawn"), m.pieces[0]["shape"], m.pieces[0]["h"], m.validate()])
	if m.pieces.size() != 9 or m.count("spawn") != 1 or m.pieces[0]["shape"] != "tower" or m.has_errors():
		_errors.append("E: placing pieces through the editor went wrong")
	if (editor.get(&"_nodes") as Array).size() != m.pieces.size():
		_errors.append("E: preview nodes out of sync with the pieces")
	# Select the building, change it, move it, undo twice, redo.
	editor.call(&"_set_tool", "select")
	editor.set(&"selected", 0)
	editor.call(&"_apply_prop", "h", 44.0)
	editor.call(&"_apply_prop", "w", 5)
	var after_edit: float = m.pieces[0]["h"]
	editor.call(&"_undo_step")
	editor.call(&"_undo_step")
	var after_undo: float = m.pieces[0]["h"]
	editor.call(&"_redo_step")
	var after_redo: float = m.pieces[0]["h"]
	print("[MapTest] E edit / undo / redo height: %.0f -> %.0f -> %.0f (width now %d)" % [after_edit, after_undo, after_redo, m.pieces[0]["w"]])
	if after_edit != 44.0 or after_undo != 30.0 or after_redo != 44.0:
		_errors.append("E: undo / redo wrong")
	editor.set(&"selected", 1)
	editor.call(&"_delete_selected")
	if m.pieces.size() != 8 or m.count("plaza") != 0:
		_errors.append("E: delete wrong")
	editor.call(&"_undo_step")
	if m.count("plaza") != 1:
		_errors.append("E: undo of a delete wrong")
	var saved: bool = editor.call(&"_save")
	var back := MapData.load_map(TEST_NAME)
	print("[MapTest] E saved=%s, reloaded pieces=%d" % [saved, back.pieces.size() if back != null else -1])
	if not saved or back == null or back.pieces.size() != m.pieces.size():
		_errors.append("E: saving from the editor failed")
	if not _shot_dir.is_empty():
		editor.call(&"_set_map", MapData.make_default())
		await _wait(0.5)
		get_viewport().get_texture().get_image().save_png(_shot_dir.path_join("editor_city.png"))
		editor.call(&"_set_map", back)
		editor.call(&"_set_tool", "building")
		editor.set(&"_zoom", 150.0)
		await _wait(0.5)
		get_viewport().get_texture().get_image().save_png(_shot_dir.path_join("editor_small.png"))
		print("[MapTest] screenshots saved")
	remove_child(editor)
	editor.free()


func _wait(seconds: float) -> void:
	var until := _t + seconds
	while _t < until:
		await get_tree().physics_frame
