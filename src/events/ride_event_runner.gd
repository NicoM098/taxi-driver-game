class_name RideEventRunner
extends RefCounted
## Evaluates the RideEvents of the current ride (owned by RideManager while RIDING).

var ctx: RideContext

var _pending: Array[Dictionary] = []   # {event: RideEvent, threshold: float}
var _active: Array[Dictionary] = []    # {event: RideEvent, state: Dictionary}
var _ended: bool = false


func begin(p_ctx: RideContext) -> void:
	ctx = p_ctx
	var action := ctx.ride.action_id
	for e in ctx.ride.profile.ride_events:
		if e == null:
			continue
		if e.requires_action != &"" and e.requires_action != action:
			continue
		if e.unless_action != &"" and e.unless_action == action:
			continue
		if e.chance < 1.0 and ctx.rng.randf() > e.chance:
			continue
		_pending.append({"event": e, "threshold": e.trigger_value + ctx.rng.randf() * e.trigger_random})
	_fire_all(RideEvent.Trigger.ON_START)


func update(delta: float) -> void:
	if _ended:
		return
	ctx.elapsed += delta
	var v := ctx.taxi.linear_velocity
	ctx.driven += Vector2(v.x, v.z).length() * delta
	for p in _pending.duplicate():
		if _ended:
			return
		var e: RideEvent = p["event"]
		var value := 0.0
		match e.trigger:
			RideEvent.Trigger.AFTER_SECONDS:
				value = ctx.elapsed
			RideEvent.Trigger.AFTER_DISTANCE:
				value = ctx.driven
			RideEvent.Trigger.AFTER_PROGRESS:
				value = ctx.progress()
			_:
				continue
		if value >= p["threshold"] and _flag_ok(e):
			_fire(p)
	for a in _active.duplicate():
		if _ended:
			return
		var ev: RideEvent = a["event"]
		if not ev.tick(ctx, a["state"], delta):
			_active.erase(a)


## Passenger delivered: fire ON_ARRIVAL events (they may still change the payout).
func arrival() -> void:
	_fire_all(RideEvent.Trigger.ON_ARRIVAL)


## Player kicked the passenger out mid-ride. True if an active event handled the outcome.
func kicked() -> bool:
	var handled := false
	for a in _active.duplicate():
		var ev: RideEvent = a["event"]
		if ev.on_kick(ctx, a["state"]):
			handled = true
			_active.erase(a)
	_fire_all(RideEvent.Trigger.ON_KICKED_OUT)
	return handled


func end() -> void:
	_ended = true
	_pending.clear()
	_active.clear()


func is_active(event_script: Script) -> bool:
	for a in _active:
		if (a["event"] as RideEvent).get_script() == event_script:
			return true
	return false


## Tests / debug: fire everything that is still waiting on time / distance / progress.
func debug_fire_pending() -> void:
	for p in _pending.duplicate():
		var e: RideEvent = p["event"]
		if e.trigger in [RideEvent.Trigger.AFTER_SECONDS, RideEvent.Trigger.AFTER_DISTANCE, RideEvent.Trigger.AFTER_PROGRESS] and _flag_ok(e):
			_fire(p)


func _fire_all(trigger: RideEvent.Trigger) -> void:
	for p in _pending.duplicate():
		if _ended:
			return
		var e: RideEvent = p["event"]
		if e.trigger == trigger and _flag_ok(e):
			_fire(p)


func _flag_ok(e: RideEvent) -> bool:
	return e.requires_flag == &"" or ctx.has_flag(e.requires_flag)


func _fire(p: Dictionary) -> void:
	_pending.erase(p)
	var e: RideEvent = p["event"]
	var state := {}
	ctx.set_flag(e.sets_flag)
	if e.start(ctx, state) and not _ended:
		_active.append({"event": e, "state": state})
