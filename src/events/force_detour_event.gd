class_name ForceDetourEvent
extends RideEvent
## Hijack: the passenger changes the destination (farthest free stop in `district`),
## the ride clock restarts and the fare is multiplied (0 = they don't pay). From then on the
## driver may throw them out mid-ride (kick_out; the profile's kick reaction applies).

@export var district: StringName = &"docks"
@export var fare_mult: float = 0.0
## Applied to the freshly computed time limit for the new destination.
@export var time_mult: float = 1.0
@export var line: String = "Change of plans."
## HUD message when delivered (replaces the payout line when nothing is paid).
@export var completion_text: String = "They bolt without paying."


func start(ctx: RideContext, _state: Dictionary) -> bool:
	var stop := ctx.rides.pick_destination_in(district, ctx.taxi.global_position)
	if stop == null:
		return false
	ctx.rides.change_destination(stop, time_mult)
	ctx.ride.fare_mult = fare_mult
	ctx.ride.completion_text = completion_text
	ctx.kick_unlocked = true   # a hijacked driver may throw them out (at the profile's price)
	ctx.say(line)
	ctx.message("HIJACKED!  New destination: %s" % stop.stop_name, &"bad")
	return false
