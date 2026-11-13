extends SceneTree
func _init() -> void:
	for f in ["commuter", "tourist", "rushed_executive"]:
		var p := load("res://data/passengers/%s.tres" % f) as PassengerProfile
		print("%s: examinables=%d actions=%d names=%d notes=%d chars" % [f, p.examinables.size(), p.actions.size(), p.name_pool.size(), p.notes.length()])
		var inst := PassengerInstance.create(p, RandomNumberGenerator.new())
		var ids := []
		for a in inst.available_actions():
			ids.append(a.id)
		print("   before examine: ", ids)
		for e in p.examinables:
			inst.examine(e.id)
		ids = []
		for a in inst.available_actions():
			ids.append(a.id)
		print("   after examine all: ", ids, " traits ", inst.revealed_traits)
	quit()
