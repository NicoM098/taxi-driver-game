class_name SpawnPursuersEvent
extends RideEvent
## Enemy cars come for the taxi. Patterns (see EnemyDirector.spawn_on_route):
## TAIL = from behind, AMBUSH_AHEAD = waiting on the route to the destination,
## PINCER = some ahead + some behind. Always spawned out of sight.

enum Pattern { TAIL, AMBUSH_AHEAD, PINCER }
const PATTERN_NAMES: Array[StringName] = [&"tail", &"ambush_ahead", &"pincer"]

@export var count: int = 2
## Extra cars per difficulty level after the first (0.5 = +1 every two levels).
@export var extra_per_shift: float = 0.0
@export var pattern: Pattern = Pattern.TAIL
## EnemyCarData file; empty = hitman sedan.
@export_file("*.tres") var enemy: String = ""
## Passenger bark when they show up.
@export var line: String = ""


func start(ctx: RideContext, _state: Dictionary) -> bool:
	if ctx.director == null:
		return false
	var n := count + floori(extra_per_shift * maxi(GameState.shift_number - 1, 0))
	var data: EnemyCarData = null
	if enemy != "":
		data = load(enemy) as EnemyCarData
	var cars := ctx.director.spawn_on_route(ctx.ride.destination.global_position, PATTERN_NAMES[pattern], n, data)
	if not cars.is_empty():
		ctx.say(line)
	return false
