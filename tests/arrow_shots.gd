extends Node
## Visual check (windowed): screenshots of the guide arrow at fixed relative angles.
## Run: Godot_console.exe --path <project> res://tests/arrow_shots.tscn -- --shot-dir=<dir>

const MAIN := preload("res://src/main/main.tscn")
const ANGLES := [0.0, 45.0, 90.0, 180.0, -135.0]

var _dir: String = ""
var _t: float = 0.0
var _idx: int = -1


func _ready() -> void:
	MapData.use_builtin()   # never the user's edited map
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			_dir = arg.get_slice("=", 1)
	add_child(MAIN.instantiate())


func _process(delta: float) -> void:
	_t += delta
	var arrow := get_tree().get_first_node_in_group(&"player_vehicle")
	if arrow == null or _t < 1.5:
		return
	var guide := arrow.get_node("HeadPivot/Camera3D/GuideArrow")
	var slot := int((_t - 1.5) / 0.4)
	if slot != _idx:
		if _idx >= 0 and _idx < ANGLES.size():
			var img := get_viewport().get_texture().get_image()
			img.save_png(_dir.path_join("arrow_%d.png" % int(ANGLES[_idx])))
		_idx = slot
		if _idx >= ANGLES.size():
			print("[ArrowShots] done")
			get_tree().quit()
			return
		guide.set(&"debug_angle_deg", ANGLES[_idx])
