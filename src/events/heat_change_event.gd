class_name HeatChangeEvent
extends RideEvent
## Raises / lowers heat (police attention).

@export var amount: int = 1
@export var line: String = ""


func start(ctx: RideContext, _state: Dictionary) -> bool:
	GameState.set_heat(GameState.heat + amount)
	ctx.say(line)
	return false
