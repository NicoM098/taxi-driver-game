class_name DialogueEvent
extends RideEvent
## Passenger bark (subtitle). With several lines one is picked at random.

@export var lines: PackedStringArray = []


func start(ctx: RideContext, _state: Dictionary) -> bool:
	if not lines.is_empty():
		ctx.say(lines[ctx.rng.randi() % lines.size()])
	return false
