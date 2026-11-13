extends Node
## Windowed visual check: screenshots from fixed spots in the city (down long avenues),
## for rendering artifacts (z-fighting etc.). Run: Godot_console.exe --path <project>
## res://tests/view_shots.tscn -- --shot-dir=<dir> [--tag=name]

const MAIN := preload("res://src/main/main.tscn")
## (position, look direction) pairs: down the long N-S avenue, an E-W street, a diagonal-ish view.
const VIEWS := [
	[Vector3(0, 1.2, 180), Vector3(0, 0, -1)],
	[Vector3(-180, 1.2, 0), Vector3(1, 0, 0)],
	[Vector3(-138, 1.2, 160), Vector3(0.35, 0, -1)],
]

var _dir: String = ""
var _tag: String = "view"
var _t: float = 0.0
var _idx: int = -1


func _ready() -> void:
	MapData.use_builtin()   # never the user's edited map
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--tag="):
			_tag = arg.get_slice("=", 1)
	add_child(MAIN.instantiate())


func _physics_process(delta: float) -> void:
	_t += delta
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
	if taxi == null or _t < 1.0:
		return
	var slot := int((_t - 1.0) / 1.2)
	if slot != _idx:
		if _idx >= 0 and _idx < VIEWS.size():
			get_viewport().get_texture().get_image().save_png(_dir.path_join("%s_%d.png" % [_tag, _idx]))
		_idx = slot
		if _idx >= VIEWS.size():
			print("[ViewShots] done")
			get_tree().quit()
			return
		var v: Array = VIEWS[_idx]
		taxi.teleport(Transform3D(Basis.looking_at((v[1] as Vector3).normalized(), Vector3.UP), v[0]))
