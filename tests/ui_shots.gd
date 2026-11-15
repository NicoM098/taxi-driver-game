extends Node
## Windowed screenshot tool for the menus (Iteration 09): main menu, controls panel,
## the tutorial's first prompt in the game, the pause menu.
## Run: Godot_console.exe --path <project> res://tests/ui_shots.tscn -- --shot-dir=<dir>

const MENU := preload("res://src/ui/menu/main_menu.tscn")
const MAIN := preload("res://src/main/main.tscn")

var _dir: String = "user://"
var _frame: int = 0
var _menu: Node
var _main: Node


func _ready() -> void:
	MapData.use_builtin()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			_dir = arg.get_slice("=", 1)
	_menu = MENU.instantiate()
	add_child(_menu)


func _process(_delta: float) -> void:
	_frame += 1
	match _frame:
		30:
			_shot("menu.png")
			_menu.call("_toggle_controls")
		40:
			_shot("menu_controls.png")
			_menu.queue_free()
			GameState.reset_run()
			GameState.tutorial_active = true
			_main = MAIN.instantiate()
			add_child(_main)
		200:
			_shot("tutorial.png")
			_main.call("_set_paused", true)
		210:
			_shot("pause.png")
			get_tree().paused = false
			GameState.tutorial_active = false
			get_tree().quit(0)


func _shot(file: String) -> void:
	var err := get_viewport().get_texture().get_image().save_png(_dir.path_join(file))
	print("[UiShots] %s -> %s" % [file, error_string(err)])
