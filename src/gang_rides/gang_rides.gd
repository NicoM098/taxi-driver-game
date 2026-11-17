class_name GangRides
extends Node
## Gang-rides mode (Iteration 17, D-088). A trial of the game WITHOUT the passenger file
## ("Papers, Please" screening): the Dossier is kept but switched off while `enabled` is true.
## Everything the mode adds lives here, so flipping `enabled` back to false gives the old game:
##
##  - No file: a passenger gets in and the ride starts at once (RideManager asks `enabled`).
##  - Auto-delivery: driving into the green ring delivers, no need to stop (RideManager).
##  - A ride card announces each fare in text: who, which gang, how hard the ride is, and what
##    their ride events may do (the file used to hide that behind "examine").
##  - Random difficulty per ride (EASY / NORMAL / HARD / DEADLY): ride clock, pay, and how hard
##    the gangs come at you.
##  - Three gangs (res://data/gangs/), each owning a zone of the city. Their members wait for a
##    cab in their zone; carrying one makes the rival gangs come for the taxi.
##  - Everything else about passengers is unchanged: the old lady still hands out her gift, the
##    hand-made archetypes and the generated fares still spawn and keep their ride events.

## The switch. false = the passenger file is back and nothing below runs.
static var enabled: bool = true

const GANG_DIR := "res://data/gangs/"

enum Difficulty { EASY, NORMAL, HARD, DEADLY }
## Per difficulty: roll weight, ride clock and pay multipliers, chance that EACH rival gang
## comes for a gang member, cars per rival crew, chance a random crew hits an ordinary fare.
const DIFFICULTY: Array[Dictionary] = [
	{"name": "EASY", "weight": 0.30, "time": 1.25, "pay": 0.8, "rival_chance": 0.25, "cars": 1, "ambush": 0.0,
		"color": Color(0.45, 1.0, 0.45)},
	{"name": "NORMAL", "weight": 0.35, "time": 1.0, "pay": 1.0, "rival_chance": 0.45, "cars": 1, "ambush": 0.1,
		"color": Color(1.0, 1.0, 1.0)},
	{"name": "HARD", "weight": 0.23, "time": 0.85, "pay": 1.4, "rival_chance": 0.7, "cars": 2, "ambush": 0.35,
		"color": Color(1.0, 0.7, 0.25)},
	{"name": "DEADLY", "weight": 0.12, "time": 0.75, "pay": 2.0, "rival_chance": 0.95, "cars": 3, "ambush": 0.7,
		"color": Color(1.0, 0.3, 0.3)},
]
const PATTERNS: Array[StringName] = [&"tail", &"ambush_ahead", &"pincer"]

@export_group("Gang members waiting for a cab")
## At most this many gang members wait at once (all gangs together).
@export var max_members_waiting: int = 3
## Seconds between two attempts to put a member at a stop of their zone.
@export var member_interval: float = 9.0

var gangs: Array[GangData] = []
## Gang id -> the TaxiStops of its zone.
var zones: Dictionary = {}
## Difficulty of the ride on now (-1 = none).
var difficulty: int = -1
## Rival crews still to show up on this ride: {gang: GangData, progress: float, cars: int, pattern: StringName}.
var threats: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _member_timer: float = 3.0
var _city: City
var _zones_built: bool = false
var _serial: int = 0


func _ready() -> void:
	add_to_group(&"gang_rides")
	_rng.randomize()
	for file in ResourceLoader.list_directory(GANG_DIR):
		var g := load(GANG_DIR + file) as GangData
		if g != null:
			gangs.append(g)
	gangs.sort_custom(func(a: GangData, b: GangData) -> bool: return String(a.id) < String(b.id))
	EventBus.ride_started.connect(_on_ride_started)
	EventBus.ride_completed.connect(func(_r: RefCounted, _p: int) -> void: _clear_ride())
	EventBus.ride_failed.connect(func(_r: RefCounted, _reason: StringName) -> void: _clear_ride())


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	if not _zones_built:
		_city = get_tree().get_first_node_in_group(&"city") as City
		if _city == null or _city.stops.is_empty():
			return
		_build_zones()
	_member_timer -= delta
	if _member_timer <= 0.0:
		_member_timer = member_interval
		spawn_member()
	_update_threats()


# --- Zones ---------------------------------------------------------------------------

## Each gang gets a district (sorted by name) when the map has at least as many districts as
## there are gangs; otherwise the map is cut into pie slices around the centre of its stops.
func _build_zones() -> void:
	_zones_built = true
	zones.clear()
	for g in gangs:
		zones[g.id] = [] as Array[TaxiStop]
	if gangs.is_empty():
		return
	var names: Array = _city.districts.keys()
	names.sort()
	var by_district := names.size() >= gangs.size()
	var centre := Vector3.ZERO
	for stop in _city.stops:
		centre += stop.global_position
	centre /= float(_city.stops.size())
	for stop in _city.stops:
		var i := -1
		if by_district:
			i = names.find(stop.district)
		else:
			var angle := atan2(stop.global_position.z - centre.z, stop.global_position.x - centre.x)
			i = clampi(floori((angle + PI) / TAU * gangs.size()), 0, gangs.size() - 1)
		if i >= 0 and i < gangs.size():
			(zones[gangs[i].id] as Array[TaxiStop]).append(stop)


## The gang whose zone holds `stop` (null = no man's land).
func gang_of_stop(stop: TaxiStop) -> GangData:
	for g in gangs:
		if (zones.get(g.id, []) as Array).has(stop):
			return g
	return null


func gang_by_id(id: StringName) -> GangData:
	for g in gangs:
		if g.id == id:
			return g
	return null


## The gang a passenger belongs to (null = not a gang member).
static func gang_id_of(profile: PassengerProfile) -> StringName:
	return profile.get_meta(&"gang", &"") if profile != null else &""


# --- Members ---------------------------------------------------------------------------

## Puts one member of a gang that has nobody waiting at a free stop of its zone, in the
## spawner's range around the taxi. Returns them (null when there is no room / no stop).
func spawn_member(only_gang: GangData = null) -> WaitingPassenger:
	var spawner := get_tree().get_first_node_in_group(&"passenger_spawner") as PassengerSpawner
	var taxi := get_tree().get_first_node_in_group(&"player_vehicle") as Node3D
	var shift := get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
	if spawner == null or taxi == null or GameState.tutorial_active or (shift != null and not shift.is_active):
		return null
	var waiting_gangs: Array[StringName] = []
	for p in spawner.waiting:
		var id := gang_id_of(p.profile)
		if id != &"":
			waiting_gangs.append(id)
	if only_gang == null and waiting_gangs.size() >= max_members_waiting:
		return null
	var options: Array[GangData] = []
	for g in gangs:
		if only_gang != null and g != only_gang:
			continue
		if only_gang == null and waiting_gangs.has(g.id):
			continue
		options.append(g)
	options.shuffle()
	for g in options:
		var stops: Array[TaxiStop] = []
		for stop: TaxiStop in zones.get(g.id, []):
			var d := stop.global_position.distance_to(taxi.global_position)
			if not stop.occupied and d >= spawner.min_spawn_distance and d <= spawner.max_spawn_distance:
				stops.append(stop)
		if stops.is_empty():
			continue
		return spawner.spawn_at(member_profile(g, _rng, maxi(GameState.shift_number, 1)), stops.pick_random())
	return null


## A one-off passenger profile for a member of `gang`. Pays well: it is a dangerous fare.
func member_profile(gang: GangData, rng: RandomNumberGenerator, level: int = 1) -> PassengerProfile:
	_serial += 1
	var p := PassengerProfile.new()
	p.id = StringName("gang_%s_%d" % [gang.id, _serial])
	p.display_name = gang.display_name
	p.occupation = gang.display_name
	p.color = gang.color
	var first := PassengerGenerator.FIRST_NAMES[rng.randi() % PassengerGenerator.FIRST_NAMES.size()]
	var last := PassengerGenerator.LAST_NAMES[rng.randi() % PassengerGenerator.LAST_NAMES.size()]
	var nick := gang.nicknames[rng.randi() % gang.nicknames.size()] if not gang.nicknames.is_empty() else ""
	p.name_pool = PackedStringArray(["%s \"%s\" %s" % [first, nick, last] if nick != "" else "%s %s" % [first, last]])
	p.age_min = 17
	p.age_max = 34
	p.fare_base = 55 + 4 * (level - 1) + rng.randi_range(0, 15)
	p.fare_per_100m = 14 + rng.randi_range(0, 4)
	p.tip_multiplier = 1.2
	p.min_distance = 220.0
	p.max_distance = 520.0
	p.hidden_traits = [&"gang"]
	p.kick_reaction = PassengerProfile.KickReaction.ANGRY
	p.set_meta(&"gang", gang.id)
	if not gang.greeting_lines.is_empty():
		var hello := DialogueEvent.new()
		hello.trigger = RideEvent.Trigger.ON_START
		hello.lines = PackedStringArray([gang.greeting_lines[rng.randi() % gang.greeting_lines.size()]])
		p.ride_events.append(hello)
	return p


# --- The ride ------------------------------------------------------------------------

func _on_ride_started(r: RefCounted) -> void:
	var ride := r as Ride
	if not enabled or ride == null:
		return
	difficulty = roll_difficulty()
	var d: Dictionary = DIFFICULTY[difficulty]
	ride.set_meta(&"difficulty", difficulty)
	ride.time_limit *= float(d["time"])
	ride.time_left = ride.time_limit
	ride.fare_mult *= float(d["pay"])
	threats = plan_threats(ride.profile, difficulty)
	_announce(ride)


## Weighted random difficulty (the tutorial fare is always EASY).
func roll_difficulty() -> int:
	if GameState.tutorial_active:
		return Difficulty.EASY
	var total := 0.0
	for d in DIFFICULTY:
		total += float(d["weight"])
	var roll := _rng.randf() * total
	for i in DIFFICULTY.size():
		roll -= float(DIFFICULTY[i]["weight"])
		if roll <= 0.0:
			return i
	return Difficulty.NORMAL


## Which crews will come during this ride. A gang member: each rival gang rolls. Anybody else:
## on the harder rides a random crew may still decide your cab looks like a target.
func plan_threats(profile: PassengerProfile, diff: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if GameState.tutorial_active:
		return out
	var d: Dictionary = DIFFICULTY[diff]
	var own := gang_id_of(profile)
	var crews: Array[GangData] = []
	if own != &"":
		for g in gangs:
			if g.id != own and _rng.randf() < float(d["rival_chance"]):
				crews.append(g)
	elif not gangs.is_empty() and _rng.randf() < float(d["ambush"]):
		crews.append(gangs[_rng.randi() % gangs.size()])
	for g in crews:
		out.append({
			"gang": g,
			"progress": _rng.randf_range(0.12, 0.6),
			"cars": int(d["cars"]) + (1 if diff >= Difficulty.HARD and _rng.randf() < 0.4 else 0),
			"pattern": PATTERNS[_rng.randi() % PATTERNS.size()],
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["progress"] < b["progress"])
	return out


func _update_threats() -> void:
	if threats.is_empty():
		return
	var rides := get_tree().get_first_node_in_group(&"ride_manager") as RideManager
	if rides == null or rides.state != RideManager.State.RIDING or rides.events == null or rides.events.ctx == null:
		return
	var progress := rides.events.ctx.progress()
	while not threats.is_empty() and progress >= float(threats[0]["progress"]):
		fire_threat(threats.pop_front(), rides)


## The crew shows up (out of sight, placed on the route like any ride event's pursuers).
func fire_threat(threat: Dictionary, rides: RideManager) -> Array[EnemyCar]:
	var g: GangData = threat["gang"]
	var director := get_tree().get_first_node_in_group(&"enemy_director") as EnemyDirector
	if director == null or rides.ride == null:
		return []
	var data := load(g.car) as EnemyCarData if g.car != "" else null
	var cars := director.spawn_on_route(rides.ride.destination.global_position, threat["pattern"], int(threat["cars"]), data)
	if cars.is_empty():
		return cars
	var own := gang_by_id(gang_id_of(rides.ride.profile))
	if own != null and not own.panic_lines.is_empty():
		EventBus.passenger_bark.emit(rides.ride.passenger.display_name if rides.ride.passenger != null else own.display_name,
				own.panic_lines[_rng.randi() % own.panic_lines.size()])
	EventBus.ride_alert.emit("%s ARE COMING FOR YOU" % g.display_name.to_upper(), 3.0)
	return cars


func _clear_ride() -> void:
	threats.clear()
	difficulty = -1


# --- The ride card -------------------------------------------------------------------

func _announce(ride: Ride) -> void:
	var d: Dictionary = DIFFICULTY[difficulty]
	var who := ride.passenger.display_name if ride.passenger != null else ride.profile.display_name
	var lines := PackedStringArray()
	var own := gang_by_id(gang_id_of(ride.profile))
	var stripe: Color = own.color if own != null else Color(1.0, 0.85, 0.15)
	var title := who
	if own != null:
		title += "  ·  %s" % own.display_name.to_upper()
	elif ride.profile.occupation != "" and ride.profile.occupation != "Unknown":
		title += "  ·  %s" % ride.profile.occupation
	lines.append("[color=#%s]%s RIDE[/color]   time x%.2f   pay x%.1f" % [
		(d["color"] as Color).to_html(false), d["name"], float(d["time"]), float(d["pay"])])
	lines.append("→ %s" % ride.destination.stop_name)
	if own != null:
		lines.append("[color=#ff6a5a]Gang member: the other gangs may come for you.[/color]")
	elif not threats.is_empty():
		lines.append("[color=#ff6a5a]Word on the street: a crew is looking for an easy cab.[/color]")
	for text in describe_events(ride.profile, ride.action_id):
		lines.append(text)
	EventBus.ride_announced.emit(title, lines, stripe)


## What the passenger's ride events may do, in plain words (one line per kind of event).
## Events that need a file action the ride was not started with are left out.
static func describe_events(profile: PassengerProfile, action_id: StringName = &"drive") -> PackedStringArray:
	var out := PackedStringArray()
	for e in profile.ride_events:
		if e == null:
			continue
		if e.requires_action != &"" and e.requires_action != action_id:
			continue
		if e.unless_action != &"" and e.unless_action == action_id:
			continue
		var text := ""
		if e is SpawnPursuersEvent:
			text = "Somebody is after them: expect company."
		elif e is PassengerAttackEvent:
			text = "Armed and jumpy: they may turn on you."
		elif e is StealCashEvent:
			text = "Light fingers: watch your cash."
		elif e is RewardEvent:
			text = "Might leave you a little something."
		elif e is ForceDetourEvent:
			text = "May change their mind about where to go."
		elif e is HeatChangeEvent:
			text = "The police are interested in this one."
		elif e is TimerModifierEvent:
			text = "Their schedule may change mid-ride."
		if text != "" and not out.has(text):
			out.append(text)
	return out
