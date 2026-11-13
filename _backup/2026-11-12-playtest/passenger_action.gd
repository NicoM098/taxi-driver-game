class_name PassengerAction
extends Resource
## A choice in the passenger file. Data-driven: "special" options are just actions with
## modifiers (fare/time multipliers, destination district, cash, heat, message).
## DRIVE and KICK_OUT exist for every passenger by default (ids &"drive", &"kick_out");
## a profile can override them by using the same id.

enum Outcome { DRIVE, KICK_OUT, KILL }

@export var id: StringName = &""
@export var label: String = "Drive"
@export var outcome: Outcome = Outcome.DRIVE
@export var requires_examined: Array[StringName] = []   # all of these must be examined
@export var requires_traits: Array[StringName] = []     # all of these must be revealed
@export_group("Effects")
@export var fare_mult: float = 1.0
@export var time_mult: float = 1.0
@export var destination_district: StringName = &""      # override (DRIVE)
@export var cash_delta: int = 0                          # paid now (bribe, bounty)
@export var heat_delta: int = 0
@export var shift_time_delta: float = 0.0                # shift seconds gained (+) / spent (-) now
@export_multiline var result_text: String = ""           # HUD message when chosen


static func make(p_id: StringName, p_label: String, p_outcome: Outcome) -> PassengerAction:
	var a := PassengerAction.new()
	a.id = p_id
	a.label = p_label
	a.outcome = p_outcome
	return a
