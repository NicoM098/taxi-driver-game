class_name RideContext
extends RefCounted
## What a RideEvent can see and do: the ride, the taxi, the managers, per-ride flags and
## counters, plus helpers for passenger barks and HUD messages.

var ride: Ride
var rides: RideManager
var taxi: Taxi
var city: City
var shift: ShiftManager
var director: EnemyDirector
var damage: TaxiDamage
var rng := RandomNumberGenerator.new()
var flags: Dictionary = {}
var elapsed: float = 0.0   # seconds since the ride started
var driven: float = 0.0    # metres driven since the ride started


func _init() -> void:
	rng.randomize()


func speaker() -> String:
	return ride.passenger.display_name if ride != null and ride.passenger != null else "Passenger"


## Subtitle line from the passenger.
func say(text: String) -> void:
	if text != "":
		EventBus.passenger_bark.emit(speaker(), text)


func message(text: String, kind: StringName = &"info") -> void:
	if text != "":
		EventBus.hud_message.emit(text, kind)


func progress() -> float:
	return driven / maxf(ride.distance, 1.0)


func has_flag(flag: StringName) -> bool:
	return flags.has(flag)


func set_flag(flag: StringName) -> void:
	if flag != &"":
		flags[flag] = true
