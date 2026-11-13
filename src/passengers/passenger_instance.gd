class_name PassengerInstance
extends RefCounted
## One concrete passenger: a profile + generated identity + what the player found out.

var profile: PassengerProfile
var display_name: String = ""
var age: int = 30
var examined: Array[StringName] = []
var revealed_traits: Array[StringName] = []
var destination: TaxiStop
## Seconds spent looking closer at the file: taken off this passenger's ride clock.
var time_spent: float = 0.0


static func create(p: PassengerProfile, rng: RandomNumberGenerator) -> PassengerInstance:
	var inst := PassengerInstance.new()
	inst.profile = p
	inst.display_name = p.name_pool[rng.randi() % p.name_pool.size()] if not p.name_pool.is_empty() else p.display_name
	inst.age = rng.randi_range(p.age_min, maxi(p.age_min, p.age_max))
	return inst


func is_examined(id: StringName) -> bool:
	return examined.has(id)


func get_examinable(id: StringName) -> Examinable:
	for e in profile.examinables:
		if e.id == id:
			return e
	return null


## Marks an examinable as examined; returns it (null if unknown / already done).
func examine(id: StringName) -> Examinable:
	var e := get_examinable(id)
	if e == null or examined.has(id):
		return null
	examined.append(id)
	time_spent += e.time_cost
	for t in e.reveals_traits:
		if not revealed_traits.has(t):
			revealed_traits.append(t)
	return e


## Every action the player can pick right now (defaults + unlocked profile actions).
func available_actions() -> Array[PassengerAction]:
	var by_id := {}
	var order: Array[StringName] = []
	for a in [PassengerAction.make(&"drive", "Drive", PassengerAction.Outcome.DRIVE),
			PassengerAction.make(&"kick_out", "Kick them out", PassengerAction.Outcome.KICK_OUT)]:
		by_id[a.id] = a
		order.append(a.id)
	for a in profile.actions:
		if not _unlocked(a):
			continue
		if not by_id.has(a.id):
			order.append(a.id)
		by_id[a.id] = a
	var out: Array[PassengerAction] = []
	for id in order:
		out.append(by_id[id])
	return out


func _unlocked(a: PassengerAction) -> bool:
	for id in a.requires_examined:
		if not examined.has(id):
			return false
	for t in a.requires_traits:
		if not revealed_traits.has(t):
			return false
	return true
