class_name Ride
extends RefCounted
## One fare in progress: who, from where, to where, and the clock.

var profile: PassengerProfile
var pickup: TaxiStop
var destination: TaxiStop
var distance: float = 0.0     # straight-line pickup -> destination (m)
var time_limit: float = 0.0
var time_left: float = 0.0
var tip: int = 0              # accumulated during the ride (drift tips), before tip_multiplier
var passenger: PassengerInstance
var fare_mult: float = 1.0    # from the chosen action (scenic route, bribe...) or ride events
var action_id: StringName = &"drive"   # file action the ride was started with
var completion_text: String = ""       # set by ride events: HUD line when nothing is paid


func time_ratio() -> float:
	return clampf(time_left / time_limit, 0.0, 1.0) if time_limit > 0.0 else 0.0
