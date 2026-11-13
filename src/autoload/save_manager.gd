extends Node
## Saves/loads GameState as JSON in user://. Versioned so the format can evolve (Phase 10).

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[Save] cannot write %s: %s" % [SAVE_PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify({"version": SAVE_VERSION, "game_state": GameState.to_dict()}, "\t"))
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[Save] corrupt save file")
		return false
	GameState.from_dict((data as Dictionary).get("game_state", {}))
	return true
