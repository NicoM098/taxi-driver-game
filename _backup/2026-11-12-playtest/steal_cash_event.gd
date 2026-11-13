class_name StealCashEvent
extends RideEvent
## The passenger goes for your cash. With a counter window the player gets a warning and
## `counter_window` seconds to throw them out (kick_out); too late = robbed.

@export_range(0.0, 1.0) var percent: float = 0.3
@export var min_amount: int = 20
@export var max_amount: int = 300
## Seconds to react. 0 = no warning, the cash is just taken.
@export var counter_window: float = 3.5
@export var warning_line: String = "(A hand slides between the seats...)"
## Cash the thief drops when thrown out in time.
@export var caught_loot: int = 25
## After stealing they jump out (the ride fails as &"robbed"). False = they stay aboard.
@export var bails_out: bool = true
@export var robbed_line: String = ""


func start(ctx: RideContext, state: Dictionary) -> bool:
	if counter_window <= 0.0:
		_steal(ctx)
		return false
	state["left"] = counter_window
	ctx.say(warning_line)
	EventBus.ride_alert.emit("THIEF!  {kick}: THROW THEM OUT", counter_window)
	return true


func tick(ctx: RideContext, state: Dictionary, delta: float) -> bool:
	state["left"] -= delta
	if state["left"] > 0.0:
		return true
	EventBus.ride_alert.emit("", 0.0)
	_steal(ctx)
	return false


func on_kick(ctx: RideContext, _state: Dictionary) -> bool:
	EventBus.ride_alert.emit("", 0.0)
	if caught_loot > 0:
		GameState.add_cash(caught_loot)
		if ctx.shift != null:
			ctx.shift.register_bonus_cash(caught_loot)
		ctx.message("THIEF THROWN OUT!  They dropped $%d" % caught_loot, &"good")
	else:
		ctx.message("THIEF THROWN OUT!", &"good")
	return true


func _steal(ctx: RideContext) -> void:
	var amount := mini(GameState.cash, clampi(roundi(GameState.cash * percent), min_amount, max_amount))
	if amount > 0:
		GameState.add_cash(-amount)
		if ctx.shift != null:
			ctx.shift.register_stolen(amount)
	ctx.say(robbed_line)
	var text := "They found nothing to steal"
	if amount > 0:
		text = "ROBBED!  -$%d" % amount
	if bails_out:
		ctx.rides.fail_ride(&"robbed", text + " — and they jump out")
	elif trigger == Trigger.ON_ARRIVAL and amount > 0:
		# The delivery line is about to be shown: put the robbery in it instead of racing it.
		ctx.ride.completion_text = (text + "  " + ctx.ride.completion_text).strip_edges()
	else:
		ctx.message(text, &"bad")
