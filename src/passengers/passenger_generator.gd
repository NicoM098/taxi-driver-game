class_name PassengerGenerator
extends RefCounted
## Procedural passengers (user request 2026-11-15: "they become way too repetitive with fixed
## spawns"). Builds a one-off PassengerProfile at runtime from parts:
##   occupation (fare tier, ride length, look)  x  mood (time / tip)  x  1-2 file details
##   (examinables; some reveal a trait that unlocks a file action)  x  an optional twist
##   (a ride event: followed, generous, in a hurry, a thief...).
## The hand-made archetypes in res://data/passengers/ still spawn (PassengerSpawner mixes both);
## a generated passenger is a cheap, never-the-same everyday fare between them.

const FIRST_NAMES: PackedStringArray = [
	"Ana", "Ben", "Carla", "Dev", "Eli", "Fatima", "Gus", "Hana", "Ivan", "Jada", "Kofi", "Lena",
	"Marco", "Nadia", "Omar", "Priya", "Quinn", "Rosa", "Sam", "Tariq", "Uma", "Vic", "Wen", "Yusuf",
	"Zoe", "Bruno", "Celia", "Dmitri", "Esther", "Felix", "Gloria", "Hector", "Ines", "Jonah",
	"Kim", "Luis", "Mei", "Nico", "Olga", "Pablo", "Rita", "Stan", "Tess", "Walt", "Ximena", "Yara",
]
const LAST_NAMES: PackedStringArray = [
	"Abara", "Brandt", "Castillo", "Dorsey", "Eklund", "Fontaine", "Garza", "Holm", "Ibarra",
	"Jansen", "Kowalski", "Lindqvist", "Moreau", "Nakamura", "Okafor", "Petrov", "Quigley",
	"Rossi", "Santos", "Tanaka", "Ulrich", "Varga", "Whitlock", "Xu", "Yilmaz", "Zamora",
	"Baptiste", "Costa", "Delgado", "Finch", "Grady", "Huang", "Kaur", "Lombardi", "Mbeki",
	"Novak", "O'Hara", "Pereira", "Reyes", "Sorensen", "Thorne", "Valdez", "Weiss",
]

## [occupation, tier (0 cheap / 1 mid / 2 rich), look, age_min, age_max, color]
const OCCUPATIONS: Array = [
	["Student", 0, "Backpack full of books, headphones around the neck", 18, 26, Color(0.55, 0.3, 0.6)],
	["Waiter", 0, "Black vest, smells of fried onions, counting coins", 19, 45, Color(0.15, 0.15, 0.15)],
	["Mechanic", 0, "Oil-stained overalls, a wrench in the back pocket", 22, 60, Color(0.25, 0.35, 0.25)],
	["Cleaner", 0, "Rubber gloves sticking out of a coat pocket, very tired", 25, 65, Color(0.4, 0.5, 0.55)],
	["Courier", 0, "Bike helmet under one arm, out of breath", 18, 35, Color(0.85, 0.45, 0.1)],
	["Bartender", 0, "Rolled-up sleeves, a tattoo of a cocktail glass", 21, 45, Color(0.45, 0.1, 0.15)],
	["Teacher", 1, "Cardigan, a stack of papers to grade, red pen behind the ear", 26, 64, Color(0.5, 0.4, 0.25)],
	["Nurse", 1, "Scrubs under a raincoat, sneakers, a thermos", 23, 58, Color(0.3, 0.6, 0.6)],
	["Electrician", 1, "Tool belt, safety glasses pushed up on the forehead", 24, 60, Color(0.7, 0.6, 0.1)],
	["Journalist", 1, "Notebook, voice recorder, asks you three questions before sitting down", 24, 55, Color(0.3, 0.3, 0.45)],
	["Chef", 1, "Knife roll tucked under the arm, white jacket", 25, 55, Color(0.9, 0.9, 0.88)],
	["Musician", 1, "Guitar case, sunglasses at night", 20, 50, Color(0.2, 0.1, 0.3)],
	["Real-estate agent", 1, "Shiny teeth, a stack of business cards, talks on two phones", 28, 60, Color(0.6, 0.2, 0.2)],
	["Lawyer", 2, "Pinstripe suit, a leather folder, checks the meter constantly", 30, 65, Color(0.12, 0.12, 0.2)],
	["Surgeon", 2, "Expensive watch, hands that never stop moving", 35, 65, Color(0.2, 0.4, 0.5)],
	["Art dealer", 2, "Silk scarf, a wrapped canvas on the back seat", 30, 70, Color(0.55, 0.15, 0.4)],
	["Startup founder", 2, "Hoodie that costs more than your cab, pitching you an app", 22, 40, Color(0.2, 0.2, 0.2)],
	["Diplomat", 2, "Accent you can't place, a small flag pin, polite and distant", 40, 70, Color(0.15, 0.25, 0.4)],
]

## [label shown in the file text, examine label, reveal text, trait (or "")]
const DETAILS: Array = [
	["a thick envelope", "the envelope", "Cash. A LOT of it, in small bills.", "rich"],
	["a hospital wristband", "the wristband", "Discharged an hour ago. Against medical advice.", "sick"],
	["a bulge under the jacket", "the jacket", "A pistol grip. They catch you looking and smile.", "armed"],
	["the way they keep looking back", "the rear window", "A dark sedan, two cars back, takes every turn you take.", "followed"],
	["a police badge on the belt", "the badge", "Detective. Off duty, they say. Still has connections.", "cop"],
	["a dark stain on the cuff", "the cuff", "Not ketchup. They notice and pull the sleeve down.", "suspicious"],
	["a wedding ring in their hand", "the ring", "Engraved: 'Forever'. They are not wearing it.", ""],
	["a lottery ticket", "the ticket", "They check the numbers again. And again. Lips moving.", ""],
	["a shopping bag that ticks", "the bag", "An alarm clock. Probably. It is a very old alarm clock.", ""],
	["a sealed court summons", "the summons", "Due today. Ten minutes ago.", "late"],
	["a box of pastries", "the box", "Still warm. They offer you one.", "generous"],
	["a phone that won't stop buzzing", "the phone", "Seventeen missed calls from 'DO NOT ANSWER'.", "followed"],
]

## [mood text, time_multiplier, tip_multiplier]
const MOODS: Array = [
	["In a terrible hurry.", 0.75, 1.3],
	["Relaxed, enjoying the ride.", 1.3, 0.9],
	["Chatty. Very chatty.", 1.1, 1.1],
	["Grumpy, arms crossed.", 1.0, 0.6],
	["Nervous, drumming on the window.", 0.9, 1.0],
	["Polite and quiet.", 1.0, 1.2],
]

const BARKS: PackedStringArray = [
	"Nice cab. Smells like gunpowder.", "Do you take the long way on purpose?",
	"My horoscope said to take a taxi today.", "Is that a bullet hole in the door?",
	"Turn the music up, I love this one.", "You drive like my grandmother. She was a stunt driver.",
	"I used to live around here. Before the gangs.", "Don't mind me, just pretend I'm not here.",
]

const KICK_LINES: PackedStringArray = [
	"Fine! I'll walk!", "You'll hear from my lawyer!", "Worst. Taxi. Ever.", "Whatever, man.",
	"Rude!", "I'm giving you one star.",
]

static var _serial: int = 0


## A brand-new passenger type, used for exactly one passenger.
static func generate(rng: RandomNumberGenerator, level: int = 1) -> PassengerProfile:
	_serial += 1
	var occ: Array = OCCUPATIONS[rng.randi() % OCCUPATIONS.size()]
	var mood: Array = MOODS[rng.randi() % MOODS.size()]
	var tier: int = occ[1]
	var p := PassengerProfile.new()
	p.id = StringName("local_%d" % _serial)
	p.display_name = occ[0]
	p.occupation = occ[0]
	var base_color: Color = occ[5]
	p.color = base_color.lerp(Color(rng.randf(), rng.randf(), rng.randf()), 0.25)
	p.age_min = occ[3]
	p.age_max = occ[4]
	p.name_pool = PackedStringArray(["%s %s" % [FIRST_NAMES[rng.randi() % FIRST_NAMES.size()],
		LAST_NAMES[rng.randi() % LAST_NAMES.size()]]])

	# Fare: tier sets the price, a bit of noise so two nurses don't pay the same.
	p.fare_base = [18, 32, 60][tier] + rng.randi_range(-4, 8) + 3 * (level - 1)
	p.fare_per_100m = [7, 11, 18][tier] + rng.randi_range(-1, 3)
	p.time_multiplier = float(mood[1]) * rng.randf_range(0.92, 1.08)
	p.tip_multiplier = float(mood[2]) * rng.randf_range(0.9, 1.1)
	# Ride length: short hop, across town, or the other end of the map.
	match rng.randi() % 3:
		0:
			p.min_distance = 90.0
			p.max_distance = 230.0
		1:
			p.min_distance = 180.0
			p.max_distance = 380.0
		_:
			p.min_distance = 320.0
			p.max_distance = 620.0
			p.fare_base += 10

	# File: look + mood + 1-2 details (examinables).
	var detail_count := 1 + (1 if rng.randf() < 0.45 else 0)
	var picked: Array = []
	while picked.size() < detail_count:
		var d: Array = DETAILS[rng.randi() % DETAILS.size()]
		if not picked.has(d):
			picked.append(d)
	var notes := "%s. %s" % [occ[2], mood[0]]
	var traits: Array[StringName] = []
	for i in picked.size():
		var d: Array = picked[i]
		var ex := Examinable.new()
		ex.id = StringName("detail_%d" % i)
		ex.label = d[1]
		ex.reveal_text = d[2]
		ex.time_cost = rng.randf_range(2.0, 4.0)
		if d[3] != "":
			ex.reveals_traits = [StringName(d[3])]
			if not traits.has(StringName(d[3])):   # two details can point to the same thing
				traits.append(StringName(d[3]))
		p.examinables.append(ex)
		notes += " %s [url=%s]%s[/url]." % ["You notice" if i == 0 else "Also:", ex.id, d[0]]
	p.notes = notes
	p.hidden_traits = traits
	p.kick_reaction = (rng.randi() % 3) as PassengerProfile.KickReaction
	p.kick_line = KICK_LINES[rng.randi() % KICK_LINES.size()]

	_add_trait_consequences(p, traits, rng, level)
	if rng.randf() < 0.35:
		var bark := DialogueEvent.new()
		bark.trigger = RideEvent.Trigger.AFTER_PROGRESS
		bark.trigger_value = rng.randf_range(0.15, 0.6)
		bark.lines = PackedStringArray([BARKS[rng.randi() % BARKS.size()]])
		p.ride_events.append(bark)
	return p


## What a trait means in the file (an action it unlocks) and on the road (a ride event that
## happens whether or not the player looked: examining only warns you).
static func _add_trait_consequences(p: PassengerProfile, traits: Array[StringName],
		rng: RandomNumberGenerator, level: int) -> void:
	for t in traits:
		match t:
			&"rich":
				p.actions.append(_action(&"overcharge", "Charge them double", PassengerAction.Outcome.DRIVE,
					t, 2.0, "\"...Fine. Just drive.\""))
			&"sick":
				var a := _action(&"rush", "Floor it, no charge for the scenic route", PassengerAction.Outcome.DRIVE,
					t, 1.5, "\"Thank you. Please hurry.\"")
				a.time_mult = 0.75
				p.actions.append(a)
			&"armed":
				# Armed fares sometimes decide they are not paying.
				if rng.randf() < 0.35:
					var gun := PassengerAttackEvent.new()
					gun.trigger = RideEvent.Trigger.AFTER_PROGRESS
					gun.trigger_value = rng.randf_range(0.3, 0.6)
					p.ride_events.append(gun)
			&"followed":
				var chase := SpawnPursuersEvent.new()
				chase.trigger = RideEvent.Trigger.AFTER_PROGRESS
				chase.trigger_value = rng.randf_range(0.2, 0.5)
				chase.chance = 0.5
				chase.count = 1 + (1 if level >= 3 else 0)
				chase.pattern = SpawnPursuersEvent.Pattern.TAIL if rng.randf() < 0.6 else SpawnPursuersEvent.Pattern.PINCER
				chase.line = "That's them! Lose them, PLEASE!"
				p.ride_events.append(chase)
				var hazard := _action(&"hazard", "Demand hazard pay", PassengerAction.Outcome.DRIVE,
					t, 1.6, "\"Okay, okay! Just get me out of here!\"")
				p.actions.append(hazard)
			&"cop":
				var favour := _action(&"favour", "Ask them to make your record disappear", PassengerAction.Outcome.DRIVE,
					t, 0.5, "\"Consider it done. Half fare, though.\"")
				favour.heat_delta = -2
				p.actions.append(favour)
			&"suspicious":
				var turn_in := _action(&"turn_in", "Kick them out and call it in (+$50)", PassengerAction.Outcome.KICK_OUT,
					t, 1.0, "You tip off the police. $50 reward.")
				turn_in.cash_delta = 50
				p.actions.append(turn_in)
				if rng.randf() < 0.3:
					var steal := StealCashEvent.new()
					steal.trigger = RideEvent.Trigger.AFTER_PROGRESS
					steal.trigger_value = rng.randf_range(0.4, 0.7)
					steal.percent = 0.2
					p.ride_events.append(steal)
			&"late":
				p.time_multiplier *= 0.8
				p.tip_multiplier *= 1.4
			&"generous":
				var gift := RewardEvent.new()
				gift.trigger = RideEvent.Trigger.ON_ARRIVAL
				gift.kinds = [&"heal", &"cash", &"ammo"]
				gift.line = "Keep the change. And this."
				p.ride_events.append(gift)


static func _action(id: StringName, label: String, outcome: PassengerAction.Outcome,
		needs_trait: StringName, fare_mult: float, text: String) -> PassengerAction:
	var a := PassengerAction.make(id, label, outcome)
	a.requires_traits = [needs_trait]
	a.fare_mult = fare_mult
	a.result_text = text
	return a
