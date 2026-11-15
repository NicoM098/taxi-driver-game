class_name RideManager
extends Node
## Ride state machine:  IDLE -> ENTERING -> DOSSIER -> RIDING -> EXITING -> IDLE
##   IDLE:     stop (slow) next to a waiting passenger to pick them up
##   ENTERING: passenger walks to the cab (cancelled if you drive off)
##   DOSSIER:  passenger is seated, their file is open (world paused by the Dossier UI);
##             waits for EventBus.dossier_action_chosen -> DRIVE / KICK_OUT / KILL
##   RIDING:   ride clock runs; stop inside the destination ring to deliver. The passenger's
##             RideEvents run here (RideEventRunner). kick_out throws the passenger out, but
##             only while a ride event allows it (thief caught in the act, hijack): a normal
##             fare cannot be ended by the driver (user feedback 2026-11-12)
##   EXITING:  short pause while the passenger gets out

enum State { IDLE, ENTERING, DOSSIER, RIDING, EXITING }

@export_group("Pickup / arrival")
@export var pickup_radius: float = 7.0
@export var pickup_max_speed: float = 2.5     # m/s (~9 km/h)
@export var arrival_radius: float = 8.0       # = TaxiStop ring
@export var arrival_max_speed: float = 3.0    # m/s (~11 km/h)
@export var enter_time: float = 0.8
@export var exit_time: float = 0.6

@export_group("Ride clock")
@export var ride_base_time: float = 8.0
@export var expected_speed: float = 11.0      # m/s over straight-line distance (streets are longer)
## Time spent on the file (examining, carrying bags...) can never cut the clock below this
## share of the untouched limit.
@export var min_time_share: float = 0.5

@export_group("Payout")
@export var speedy_ratio: float = 0.5         # time left ratio for "SPEEDY!"
@export var speedy_mult: float = 1.5
@export var good_ratio: float = 0.25
@export var good_mult: float = 1.2
@export var dollars_per_drift_point: float = 0.5

@export_group("Decisions")
@export var angry_kick_damage: float = 8.0   # parting shot from an ANGRY kicked passenger

var state: State = State.IDLE
var ride: Ride
## Ride events of the current ride (null outside RIDING).
var events: RideEventRunner

var _state_time: float = 0.0
var _boarding: WaitingPassenger
var _passenger: PassengerInstance     # seated passenger whose file is open (DOSSIER)
var _seated_visual: Node3D
var _taxi: Taxi
var _city: City
var _spawner: PassengerSpawner
var _shift: ShiftManager
## Drop-offs used lately (oldest first): skipped while there is another choice.
const RECENT_DESTINATIONS: int = 8
var _recent_destinations: Array[TaxiStop] = []


func _ready() -> void:
	add_to_group(&"ride_manager")
	EventBus.shift_ended.connect(_on_shift_ended)
	EventBus.taxi_wrecked.connect(_on_taxi_wrecked)
	EventBus.passenger_killed.connect(func() -> void:
		if state == State.RIDING and ride != null:
			_fail_ride(&"passenger_killed", "Your passenger was shot!"))
	EventBus.dossier_action_chosen.connect(_on_action_chosen)


func _physics_process(delta: float) -> void:
	if not _resolve():
		return
	_state_time += delta
	match state:
		State.IDLE:
			if _shift.is_active and not is_wrecked() and _taxi.linear_velocity.length() < pickup_max_speed:
				var p := _spawner.get_passenger_near(_taxi.global_position, pickup_radius)
				if p != null:
					_begin_boarding(p)
		State.ENTERING:
			if _flat_distance(_taxi.global_position, _boarding.global_position) > pickup_radius * 2.0:
				_cancel_boarding()
			elif _state_time >= enter_time:
				_open_file()
		State.RIDING:
			events.update(delta)
			if state != State.RIDING:
				return   # an event ended the ride
			if Input.is_action_just_pressed(&"kick_out") and can_kick_mid_ride():
				kick_out_mid_ride()
				return
			ride.time_left -= delta
			var d := _flat_distance(_taxi.global_position, ride.destination.global_position)
			if d < arrival_radius and _taxi.linear_velocity.length() < arrival_max_speed:
				_complete_ride()
			elif ride.time_left <= 0.0:
				_fail_ride(&"too_slow", "TOO SLOW! The passenger stormed out")
		State.EXITING:
			if _state_time >= exit_time:
				_set_state(State.IDLE)


## Nobody gets into (or stays in) a burning cab.
func is_wrecked() -> bool:
	var dmg := _taxi.get_node_or_null("TaxiDamage") as TaxiDamage if _taxi != null else null
	return dmg != null and dmg.is_wrecked


func is_dead() -> bool:
	var dmg := _taxi.get_node_or_null("TaxiDamage") as TaxiDamage if _taxi != null else null
	return dmg != null and dmg.is_dead


## What the dashboard arrow should point at:
## {pos: Vector3, kind: &"destination" / &"passenger" / &"repair"}.
func get_guide_target() -> Dictionary:
	if is_dead():
		return {}
	if is_wrecked() and _city != null:
		var shop := _city.nearest_repair_shop(_taxi.global_position)
		return {"pos": shop.pad_position, "kind": &"repair"} if shop != null else {}
	if state == State.RIDING and ride != null:
		return {"pos": ride.destination.global_position, "kind": &"destination"}
	if state == State.IDLE and _shift != null and _shift.is_active and _spawner != null and _taxi != null:
		var p := _spawner.get_nearest(_taxi.global_position)
		if p != null:
			return {"pos": p.global_position, "kind": &"passenger"}
	return {}


# --- Transitions -------------------------------------------------------------------

func _begin_boarding(p: WaitingPassenger) -> void:
	_boarding = p
	_spawner.take(p)
	var door := _taxi.global_transform * Vector3(1.2, -0.4, 0.9)
	p.walk_to(door, enter_time)
	_set_state(State.ENTERING)


func _cancel_boarding() -> void:
	# Taxi drove off: the passenger gives up and leaves (the spawner refills over time).
	if _boarding != null:
		_boarding.release_stop()
		_boarding.queue_free()
	_boarding = null
	EventBus.hud_message.emit("The passenger gave up on you", &"bad")
	_set_state(State.IDLE)


## Passenger is in: seat them, pick (and reserve) their destination, open their file.
func _open_file() -> void:
	_passenger = _boarding.instance
	if _passenger == null:
		_passenger = PassengerInstance.create(_boarding.profile, RandomNumberGenerator.new())
	var pickup := _boarding.stop
	_boarding.release_stop()
	_boarding.queue_free()
	_boarding = null
	_passenger.destination = _pick_destination(_passenger.profile, _taxi.global_position)
	if _passenger.destination == null:
		push_warning("[Ride] no destination available")
		_passenger = null
		_set_state(State.IDLE)
		return
	_passenger.destination.occupied = true   # reserved while deciding
	_passenger.set_meta(&"pickup", pickup)
	_seated_visual = PassengerVisual.build(_passenger.profile.color, true)
	var seat := _taxi.get_node_or_null("Interior/PassengerSeat") as Node3D
	(seat if seat != null else _taxi as Node3D).add_child(_seated_visual)
	_set_state(State.DOSSIER)
	EventBus.passenger_entered.emit(_passenger.profile)
	EventBus.dossier_opened.emit(_passenger)


func _on_action_chosen(passenger: RefCounted, action: Resource) -> void:
	if state != State.DOSSIER or passenger != _passenger:
		return
	var a := action as PassengerAction
	_apply_effects(a)
	match a.outcome:
		PassengerAction.Outcome.DRIVE:
			_start_ride(a)
		PassengerAction.Outcome.KICK_OUT:
			_kick_out()
		PassengerAction.Outcome.KILL:
			_execute(a)


func _apply_effects(a: PassengerAction) -> void:
	if a.cash_delta != 0:
		GameState.add_cash(a.cash_delta)
		if _shift != null and a.cash_delta > 0:
			_shift.register_bonus_cash(a.cash_delta)
	if a.heat_delta != 0:
		GameState.set_heat(GameState.heat + a.heat_delta)


func _start_ride(a: PassengerAction) -> void:
	var p := _passenger
	_passenger = null
	var destination := p.destination
	if a.destination_district != &"":
		destination.occupied = false
		var override := _pick_destination_in(a.destination_district, _taxi.global_position)
		destination = override if override != null else destination
		destination.occupied = true
	ride = Ride.new()
	ride.profile = p.profile
	ride.passenger = p
	ride.pickup = p.get_meta(&"pickup", null)
	ride.destination = destination
	ride.fare_mult = a.fare_mult
	ride.action_id = a.id
	ride.distance = _flat_distance(_taxi.global_position, destination.global_position)
	ride.time_limit = planned_time(p, ride.distance, a)
	ride.time_left = ride.time_limit
	destination.set_destination_highlight(true)
	EventBus.ride_started.emit(ride)
	var line := a.result_text if a.result_text != "" else "%s: \"%s, please!\"" % [p.display_name, destination.stop_name]
	EventBus.hud_message.emit(line, &"good" if a.cash_delta > 0 else &"info")
	_set_state(State.RIDING)
	_begin_events()


func _kick_out() -> void:
	var p := _passenger
	_passenger = null
	p.destination.occupied = false
	_remove_seated()
	_spawn_walker(p.profile, _taxi.global_position + _taxi.global_basis.x * 7.0)
	_kick_reaction(p)
	EventBus.passenger_kicked_out.emit(p)
	_set_state(State.EXITING)


## Parting words (and, for ANGRY passengers, a parting shot) of someone thrown out.
func _kick_reaction(p: PassengerInstance) -> void:
	var line := p.profile.kick_line if p.profile.kick_line != "" else "Fine. I'll walk."
	match p.profile.kick_reaction:
		PassengerProfile.KickReaction.ANGRY:
			var amount := p.profile.kick_damage if p.profile.kick_damage >= 0.0 else angry_kick_damage
			EventBus.hud_message.emit("%s: \"%s\" %s" % [p.display_name, line, "*BANG*" if amount >= 8.0 else "*WHACK*"], &"bad")
			var dmg := _taxi.get_node_or_null("TaxiDamage") as TaxiDamage
			if dmg != null:
				dmg.driver_health.apply_damage(amount)
				EventBus.player_hit.emit(amount, _taxi.global_transform * Vector3(0, 1, 1.5))
		_:
			EventBus.hud_message.emit("%s: \"%s\"" % [p.display_name, line], &"info")


## True while a ride event lets the driver throw the passenger out (thief with a hand in
## your pocket, hijacker). A normal fare cannot be ended mid-ride.
func can_kick_mid_ride() -> bool:
	return state == State.RIDING and ride != null and events != null and events.ctx != null and events.ctx.can_kick()


## Seconds on the ride clock for this passenger over `distance` metres: the base limit and
## the chosen file action, minus the time spent looking closer at the file.
func planned_time(p: PassengerInstance, distance: float, a: PassengerAction = null) -> float:
	var limit := (ride_base_time + distance / expected_speed) * p.profile.time_multiplier
	var spent := p.time_spent
	if a != null:
		limit *= a.time_mult
		spent -= a.ride_time_delta
	return maxf(limit - spent, limit * min_time_share)


## Throw the passenger out during the ride (kick_out action; also called by tests).
## Only while can_kick_mid_ride(). No fare. Active ride events can take over the outcome
## (e.g. a thief caught in the act).
func kick_out_mid_ride() -> void:
	if not can_kick_mid_ride():
		return
	var p := ride.passenger
	var handled := events != null and events.kicked()
	if state != State.RIDING:
		return
	if not handled and p != null:
		_kick_reaction(p)
	EventBus.passenger_kicked_out.emit(p)
	_fail_ride(&"kicked_out", "")


func _execute(a: PassengerAction) -> void:
	var p := _passenger
	_passenger = null
	p.destination.occupied = false
	EventBus.passenger_executed.emit(p)
	EventBus.hud_message.emit(a.result_text if a.result_text != "" else "BANG.", &"bad")
	# The passenger slumps out of view a moment after the shot (camera turns back meanwhile).
	var visual := _seated_visual
	_seated_visual = null
	if visual != null:
		var tw := visual.create_tween()
		tw.tween_interval(0.35)
		tw.tween_property(visual, "position:y", -0.6, 0.25)
		tw.tween_callback(visual.queue_free)
	_set_state(State.EXITING)


func _complete_ride() -> void:
	events.arrival()   # arrival events may still change the payout / hand out rewards
	if state != State.RIDING or ride == null:
		return
	var ratio := ride.time_ratio()
	var mult := 1.0
	var rating := "OK"
	if ratio >= speedy_ratio:
		mult = speedy_mult
		rating = "SPEEDY!"
	elif ratio >= good_ratio:
		mult = good_mult
		rating = "GOOD"
	var fare := roundi((ride.profile.fare_base + ride.profile.fare_per_100m * ride.distance / 100.0) * mult * ride.fare_mult)
	var tip := roundi(ride.tip * ride.profile.tip_multiplier)
	var payout := fare + tip
	GameState.add_cash(payout)
	var tip_text := "  (tip $%d)" % tip if tip > 0 else ""
	if payout <= 0 and ride.completion_text != "":
		EventBus.hud_message.emit(ride.completion_text, &"bad")
	else:
		EventBus.hud_message.emit("+$%d %s%s" % [payout, rating, tip_text], &"good")
	var finished := ride
	_end_ride(true)
	EventBus.ride_completed.emit(finished, payout)


## Ends the current ride without payment (ride events use this, e.g. &"robbed").
func fail_ride(reason: StringName, message: String) -> void:
	if state == State.RIDING and ride != null:
		_fail_ride(reason, message)


## Ride events: send the ride somewhere else. The ride clock restarts for the new distance.
func change_destination(stop: TaxiStop, time_mult: float = 1.0) -> void:
	if state != State.RIDING or ride == null or stop == null:
		return
	ride.destination.set_destination_highlight(false)
	ride.destination.occupied = false
	ride.destination = stop
	stop.occupied = true
	stop.set_destination_highlight(true)
	ride.distance = _flat_distance(_taxi.global_position, stop.global_position)
	ride.time_limit = (ride_base_time + ride.distance / expected_speed) * ride.profile.time_multiplier * time_mult
	ride.time_left = ride.time_limit


## Farthest free stop of a district (ride events / file actions).
func pick_destination_in(district: StringName, from: Vector3) -> TaxiStop:
	return _pick_destination_in(district, from)


func _begin_events() -> void:
	var ctx := RideContext.new()
	ctx.ride = ride
	ctx.rides = self
	ctx.taxi = _taxi
	ctx.city = _city
	ctx.shift = _shift
	ctx.director = get_tree().get_first_node_in_group(&"enemy_director") as EnemyDirector
	ctx.damage = _taxi.get_node_or_null("TaxiDamage") as TaxiDamage
	events = RideEventRunner.new()
	events.begin(ctx)


func _fail_ride(reason: StringName, message: String) -> void:
	if message != "":
		EventBus.hud_message.emit(message, &"bad")
	var failed := ride
	_end_ride(false)
	EventBus.ride_failed.emit(failed, reason)


func _end_ride(delivered: bool) -> void:
	if events != null:
		events.end()
		events = null
	EventBus.ride_alert.emit("", 0.0)
	ride.destination.set_destination_highlight(false)
	ride.destination.occupied = false
	_remove_seated()
	# Passenger gets out and walks away (to the destination sidewalk if delivered).
	var target := ride.destination.sidewalk_point if delivered else _taxi.global_position + _taxi.global_basis.x * 7.0
	_spawn_walker(ride.profile, target)
	ride = null
	_set_state(State.EXITING)


func _remove_seated() -> void:
	if _seated_visual != null:
		_seated_visual.queue_free()
		_seated_visual = null


func _spawn_walker(profile: PassengerProfile, target: Vector3) -> void:
	var walker := WaitingPassenger.new()
	_spawner.add_child(walker)
	walker.setup(profile, null, null)
	walker.global_position = _taxi.global_transform * Vector3(1.4, -0.6, 0.9)
	target.y = walker.global_position.y
	walker.walk_to(target, 1.5).finished.connect(walker.queue_free)


func _on_taxi_wrecked(_reason: StringName) -> void:
	if state == State.RIDING and ride != null:
		_fail_ride(&"wrecked", "Your fare bails out of the wreck")
	else:
		_on_shift_ended({})


func _on_shift_ended(_summary: Dictionary) -> void:
	if state == State.RIDING and ride != null:
		_fail_ride(&"shift_over", "")
	elif state == State.ENTERING:
		_cancel_boarding()
	elif state == State.DOSSIER and _passenger != null:
		# Shift over while reading the file: the passenger just gets out.
		_passenger.destination.occupied = false
		_passenger = null
		_remove_seated()
		_set_state(State.IDLE)


func _on_chain_banked(points: float, links: int) -> void:
	var dollars := roundi(points * dollars_per_drift_point)
	if _shift != null:
		_shift.register_drift_links(links)
	if dollars <= 0:
		return
	if state == State.RIDING and ride != null:
		ride.tip += dollars
		EventBus.hud_message.emit("DRIFT TIP +$%d" % dollars, &"drift")
	elif _shift != null and _shift.is_active:
		GameState.add_cash(dollars)
		_shift.register_bonus_cash(dollars)
		EventBus.hud_message.emit("STYLE +$%d" % dollars, &"drift")


func _on_chain_broken(_points: float) -> void:
	EventBus.hud_message.emit("DRIFT CHAIN LOST!", &"bad")


# --- Helpers -----------------------------------------------------------------------

## Preference: in distance range AND preferred district > in distance range (any district)
## > farthest free stop. Never silently picks a short ride. The last few drop-offs are skipped
## while there is any other choice (playtest 2026-11-15: "they are always the same").
func _pick_destination(profile: PassengerProfile, from: Vector3) -> TaxiStop:
	var stop := _pick_destination_from(profile, from, true)
	if stop == null:
		stop = _pick_destination_from(profile, from, false)
	if stop != null:
		_recent_destinations.append(stop)
		while _recent_destinations.size() > RECENT_DESTINATIONS:
			_recent_destinations.pop_front()
	return stop


func _pick_destination_from(profile: PassengerProfile, from: Vector3, skip_recent: bool) -> TaxiStop:
	var preferred: Array[TaxiStop] = []
	var in_range: Array[TaxiStop] = []
	var farthest: TaxiStop = null
	var farthest_d := 0.0
	for stop in _city.stops:
		if stop.occupied or (skip_recent and _recent_destinations.has(stop)):
			continue
		var d := _flat_distance(stop.global_position, from)
		if d > farthest_d:
			farthest_d = d
			farthest = stop
		if d < profile.min_distance or d > profile.max_distance:
			continue
		in_range.append(stop)
		if profile.destination_districts.is_empty() or profile.destination_districts.has(stop.district):
			preferred.append(stop)
	if not preferred.is_empty():
		return preferred.pick_random()
	if not in_range.is_empty():
		return in_range.pick_random()
	return null if skip_recent else farthest


func _pick_destination_in(district: StringName, from: Vector3) -> TaxiStop:
	var best: TaxiStop = null
	var best_d := 0.0
	for stop in _city.stops:
		if stop.occupied or stop.district != district:
			continue
		var d := _flat_distance(stop.global_position, from)
		if d > best_d:
			best_d = d
			best = stop
	return best


func _resolve() -> bool:
	if _taxi == null:
		_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
		if _taxi != null:
			var chain := _taxi.get_node_or_null("DriftChain") as DriftChain
			if chain != null:
				chain.chain_banked.connect(_on_chain_banked)
				chain.chain_broken.connect(_on_chain_broken)
	if _city == null:
		_city = get_tree().get_first_node_in_group(&"city") as City
	if _spawner == null:
		_spawner = get_tree().get_first_node_in_group(&"passenger_spawner") as PassengerSpawner
	if _shift == null:
		_shift = get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
	return _taxi != null and _city != null and _spawner != null and _shift != null


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
