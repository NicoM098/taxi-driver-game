extends Node
## Data check for every PassengerProfile in res://data/passengers/.
## Run: Godot_console.exe --headless --path <project> res://tools/check_profiles.tscn
## (a scene, not --script: the event scripts use autoloads, which --script compiles without).
## Prints what each file offers before / after examining everything and validates the wiring:
## clue links <-> examinables, action requirements <-> revealable traits, ride events.

func _ready() -> void:
	var dir := "res://data/passengers/"
	var errors := 0
	var count := 0
	for file in ResourceLoader.list_directory(dir):
		var p := load(dir + file) as PassengerProfile
		if p == null:
			print("FAIL %s: not a PassengerProfile" % file)
			errors += 1
			continue
		count += 1
		var events := PackedStringArray()
		for e in p.ride_events:
			if e == null:
				print("FAIL %s: null ride event" % file)
				errors += 1
				continue
			events.append("%s@%s" % [(e.get_script() as Script).get_global_name(), RideEvent.Trigger.keys()[e.trigger]])
		print("%s: examinables=%d actions=%d names=%d min_shift=%d weight=%.1f" % [
			p.id, p.examinables.size(), p.actions.size(), p.name_pool.size(), p.min_shift, p.spawn_weight])
		print("   events: ", events)
		var traits := {}
		for e in p.examinables:
			if not p.notes.contains("[url=%s]" % e.id):
				print("FAIL %s: examinable '%s' has no [url] clue in the notes" % [file, e.id])
				errors += 1
			for t in e.reveals_traits:
				traits[t] = true
		for a in p.actions:
			for t in a.requires_traits:
				if not traits.has(t):
					print("FAIL %s: action '%s' needs trait '%s' that nothing reveals" % [file, a.id, t])
					errors += 1
			for id in a.requires_examined:
				if p.examinables.filter(func(x: Examinable) -> bool: return x.id == id).is_empty():
					print("FAIL %s: action '%s' needs unknown examinable '%s'" % [file, a.id, id])
					errors += 1
		for e in p.ride_events:
			if e == null:
				continue
			for action_id: StringName in [e.requires_action, e.unless_action]:
				if action_id != &"" and action_id != &"drive" and p.actions.filter(func(x: PassengerAction) -> bool: return x.id == action_id).is_empty():
					print("FAIL %s: ride event refers to unknown action '%s'" % [file, action_id])
					errors += 1
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
	print("PROFILES OK (%d files)" % count if errors == 0 else "PROFILES FAIL (%d errors)" % errors)
	get_tree().quit(0 if errors == 0 else 1)
