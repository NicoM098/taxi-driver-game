extends Node
## Requests a change of the world scene shown inside Main's low-res viewport.
## Main listens and swaps the scene (fade transitions come in Phase 10).

signal world_scene_requested(path: String)


func goto_world(path: String) -> void:
	world_scene_requested.emit(path)
