class_name PassengerAttackEvent
extends RideEvent
## An armed passenger holds the driver at gunpoint for the rest of the ride: drive slower than
## `min_speed` for `grace` seconds and they shoot (then again every `interval` s).
## No threat close to the destination — you have to stop there.

@export var min_speed: float = 7.0            # m/s (~25 km/h)
@export var grace: float = 3.0
@export var interval: float = 2.5
@export var damage: float = 10.0
@export var safe_radius: float = 28.0         # around the destination
@export var warning_line: String = "Keep moving, or I shoot!"
@export var shot_line: String = "I warned you!"


func start(_ctx: RideContext, state: Dictionary) -> bool:
	state["slow"] = 0.0
	state["warned"] = false
	return true


func tick(ctx: RideContext, state: Dictionary, delta: float) -> bool:
	var to_dest := ctx.ride.destination.global_position - ctx.taxi.global_position
	var near := Vector2(to_dest.x, to_dest.z).length() < safe_radius
	if ctx.taxi.linear_velocity.length() >= min_speed or near:
		state["slow"] = maxf(state["slow"] - delta * 2.0, 0.0)
		if state["slow"] <= 0.0:
			state["warned"] = false
		return true
	state["slow"] += delta
	if not state["warned"] and state["slow"] > grace * 0.4:
		state["warned"] = true
		ctx.say(warning_line)
	if state["slow"] >= grace:
		state["slow"] = grace - interval
		ctx.say(shot_line)
		if ctx.damage != null:
			ctx.damage.driver_health.apply_damage(damage)
		# From the back seat: the damage wedge points behind you.
		EventBus.player_hit.emit(damage, ctx.taxi.global_transform * Vector3(0.3, 1.0, 1.5))
	return true
