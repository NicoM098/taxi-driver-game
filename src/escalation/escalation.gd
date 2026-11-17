class_name Escalation
extends Node
## Escalation (Iteration 20, D-091): the run is three stages instead of one difficulty that
## only climbs. Each stage changes who answers the heat; you reach its boss fight with a mix
## of fares delivered, kills and time survived in the stage; beating the boss starts the next.
##   1 STREET WAR   police + gangs                       boss: the Precinct Captain (+2 cruisers)
##   2 CRACKDOWN    SWAT + gangs, gang bosses roam        boss: the three gang bosses at once
##   3 ALL-OUT WAR  military + cartel, lieutenants roam  boss: the Army APC and the Kingpin
## After the last boss the war goes on at stage 3 (VICTORY). Stages are data
## (res://data/stages/), enemy cars too (res://data/enemies/). The heat stars still work inside
## a stage; a stage can keep them from cooling below `heat_floor`.
## Node in game.tscn (group "escalation"). `enabled` = false: the old single-stage game.
## Debug: F11 completes the current stage's objectives.

static var enabled: bool = true

const STAGE_DIR := "res://data/stages/"
## Seconds between "the boss is coming" and the boss arriving / between stages.
const BOSS_WARNING := 6.0
const NEXT_STAGE_DELAY := 5.0

enum Phase { STAGE, BOSS_INCOMING, BOSS, CLEARED, VICTORY }

## Big centre-screen banner (StageHud).
signal announced(title: String, subtitle: String, colour: Color)

var stages: Array[StageData] = []
var index: int = 0
var phase: Phase = Phase.STAGE
var fares: int = 0
var kills: int = 0
var seconds: float = 0.0
var phase_left: float = 0.0
## {data: EnemyCarData, car: EnemyCar, down: bool} per boss of the current fight.
var bosses: Array[Dictionary] = []

var _director: EnemyDirector
var _elite_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"escalation")
	if not enabled:
		set_physics_process(false)
		return
	_rng.randomize()
	for file in ResourceLoader.list_directory(STAGE_DIR):
		var s := load(STAGE_DIR + file) as StageData
		if s != null:
			stages.append(s)
	stages.sort_custom(func(a: StageData, b: StageData) -> bool: return a.number < b.number)
	EventBus.ride_completed.connect(func(_r: RefCounted, _p: int) -> void:
		if phase == Phase.STAGE and _active():
			fares += 1)
	EventBus.enemy_destroyed.connect(_on_enemy_destroyed)
	EventBus.heat_changed.connect(_on_heat_changed)
	EventBus.shift_started.connect(func(_n: int) -> void: start_stage(0))


func stage() -> StageData:
	return stages[index] if index < stages.size() else null


func objectives_met() -> bool:
	var s := stage()
	return s != null and fares >= s.fares and kills >= s.kills and seconds >= s.seconds


func start_stage(i: int) -> void:
	if stages.is_empty():
		return
	index = clampi(i, 0, stages.size() - 1)
	phase = Phase.STAGE
	fares = 0
	kills = 0
	seconds = 0.0
	bosses.clear()
	var s := stage()
	_elite_timer = s.elite_interval * 0.6
	_apply_roster()
	if GameState.heat < s.heat_floor:
		GameState.set_heat(s.heat_floor)
	announced.emit("STAGE %d — %s" % [s.number, s.title.to_upper()], s.tagline, s.color)


func _physics_process(delta: float) -> void:
	if _director == null:
		_director = get_tree().get_first_node_in_group(&"enemy_director") as EnemyDirector
		if _director != null:
			_apply_roster()
		return
	if stages.is_empty() or not _active():
		return
	var s := stage()
	if InputMap.has_action(&"debug_next_stage") and Input.is_action_just_pressed(&"debug_next_stage") \
			and phase == Phase.STAGE:
		fares = maxi(fares, s.fares)
		kills = maxi(kills, s.kills)
		seconds = maxf(seconds, s.seconds)
	match phase:
		Phase.STAGE:
			seconds += delta
			_update_elites(delta, s)
			if objectives_met():
				phase = Phase.BOSS_INCOMING
				phase_left = BOSS_WARNING
				announced.emit("BOSS FIGHT", "%s %s coming for you." % [s.boss_title, "is" if s.boss_cars.size() == 1 else "are"], s.color)
				EventBus.hud_message.emit("%s INCOMING" % s.boss_title.to_upper(), &"bad")
		Phase.BOSS_INCOMING:
			phase_left -= delta
			if phase_left <= 0.0:
				_spawn_bosses(s)
		Phase.BOSS:
			_update_bosses()
		Phase.CLEARED:
			phase_left -= delta
			if phase_left <= 0.0:
				start_stage(index + 1)


func _apply_roster() -> void:
	var s := stage()
	if s == null or _director == null:
		return
	_director.set_roster(_load(s.law_car), _load(s.crime_car), s.max_enemies)


func _update_elites(delta: float, s: StageData) -> void:
	if s.elite_cars.is_empty() or s.elite_interval <= 0.0 or GameState.heat < s.elite_heat:
		return
	_elite_timer -= delta
	if _elite_timer > 0.0:
		return
	var data := _load(s.elite_cars[_rng.randi() % s.elite_cars.size()])
	var cars := _director.spawn_pursuers(1, data)
	if cars.is_empty():
		_elite_timer = 10.0   # no room right now: try again soon
		return
	_elite_timer = s.elite_interval
	EventBus.ride_alert.emit("%s IS HUNTING YOU" % data.display_name.to_upper(), 3.5)


func _spawn_bosses(s: StageData) -> void:
	phase = Phase.BOSS
	bosses.clear()
	for path in s.boss_cars:
		var data := _load(path)
		if data == null:
			continue
		var entry := {"data": data, "car": null, "down": false}
		bosses.append(entry)
		_spawn_boss(entry)
	if s.escort_count > 0 and s.escort_car != "":
		_director.spawn_pursuers(s.escort_count, _load(s.escort_car))
	EventBus.ride_alert.emit("BOSS FIGHT: %s" % s.boss_title.to_upper(), 4.0)
	if bosses.is_empty():
		_clear_stage()


func _spawn_boss(entry: Dictionary) -> void:
	var car := _director.spawn_boss(entry["data"])
	entry["car"] = car
	if car != null:
		car.destroyed.connect(func(_c: EnemyCar) -> void: entry["down"] = true)


func _update_bosses() -> void:
	var left := 0
	for entry in bosses:
		if entry["down"]:
			continue
		left += 1
		# Gone without being destroyed (cleared, fell out of the world): it comes back.
		if not _alive(entry):
			_spawn_boss(entry)
	if left == 0:
		_clear_stage()


func _clear_stage() -> void:
	var s := stage()
	GameState.add_cash(s.reward)
	var shift := get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
	if shift != null:
		shift.register_bonus_cash(s.reward)
	if index + 1 < stages.size():
		phase = Phase.CLEARED
		phase_left = NEXT_STAGE_DELAY
		announced.emit("STAGE %d CLEARED" % s.number, "+$%d.  It gets worse from here." % s.reward, Color(0.45, 1, 0.5))
	else:
		phase = Phase.VICTORY
		announced.emit("THE CITY IS YOURS", "+$%d.  The war goes on: keep driving." % s.reward, Color(0.45, 1, 0.5))


## Live boss cars with their health (StageHud): [{name, hp, max_hp}].
func boss_health() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in bosses:
		var data: EnemyCarData = entry["data"]
		var hp := 0.0
		if not entry["down"] and _alive(entry) and (entry["car"] as EnemyCar).health != null:
			hp = (entry["car"] as EnemyCar).health.hp
		out.append({"name": data.display_name, "hp": hp, "max_hp": data.hp})
	return out


## The entry's car still exists (a freed car cannot even be assigned to a typed variable).
static func _alive(entry: Dictionary) -> bool:
	var car: Variant = entry["car"]
	return car != null and is_instance_valid(car)


func _on_enemy_destroyed(_enemy: Node, _bounty: int) -> void:
	if phase == Phase.STAGE and _active():
		kills += 1


func _on_heat_changed(heat: int) -> void:
	var s := stage()
	if s != null and heat < s.heat_floor and _active():
		GameState.set_heat.call_deferred(s.heat_floor)


func _active() -> bool:
	if GameState.tutorial_active:
		return false
	var shift := get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
	return shift == null or shift.is_active


static func _load(path: String) -> EnemyCarData:
	return load(path) as EnemyCarData if path != "" else null
