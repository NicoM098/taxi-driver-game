class_name TimerModifierEvent
extends RideEvent
## Changes the ride clock: time_left = time_left * mult + add_seconds.

@export var add_seconds: float = 0.0
@export var mult: float = 1.0
@export var line: String = ""


func start(ctx: RideContext, _state: Dictionary) -> bool:
	var before := ctx.ride.time_left
	ctx.ride.time_left = maxf(ctx.ride.time_left * mult + add_seconds, 1.0)
	ctx.ride.time_limit = maxf(ctx.ride.time_limit, ctx.ride.time_left)
	ctx.say(line)
	var diff := roundi(ctx.ride.time_left - before)
	if diff != 0:
		ctx.message("RIDE CLOCK %+d s" % diff, &"bad" if diff < 0 else &"good")
	return false
