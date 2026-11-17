extends Node
## Headless D-092 stress test through Main: five hunters chase a taxi that jumps to another
## street every 12 s for 90 s, so they keep re-routing round corners. Measures:
##   stuck   seconds a hunter spent nearly still while far from the taxi (sum over cars)
##   unstuck times the AI had to reverse out; rescues = moved out of sight by the director
##   walls   HP the hunters lost while the taxi was nowhere near them (must be 0: no crash
##           damage from buildings)
## FAIL if wall damage > 0 or stuck time is above STUCK_LIMIT.
## Run: Godot_console.exe --headless --path <project> --fixed-fps 60 res://tests/enemy_corners_autotest.tscn

const MAIN := preload("res://src/main/main.tscn")
const DURATION := 90.0
const JUMP_EVERY := 12.0
const CARS := 5
const STUCK_LIMIT := 60.0

var _taxi: Taxi
var _damage: TaxiDamage
var _city: City
var _director: EnemyDirector
var _cars: Array[EnemyCar] = []
var _hp: Dictionary = {}          # car -> hp last frame
var _modes: Dictionary = {}       # car -> mode last frame
var _relocated: Dictionary = {}   # car -> relocated_frame seen
var _t: float = 0.0
var _jump_t: float = 0.0
var _stuck: float = 0.0
var _stuck_by: Dictionary = {}   # AI mode -> stuck seconds
var _still: Dictionary = {}      # car -> seconds still in a row (debug)
var _unstuck: int = 0
var _rescues: int = 0
var _walls: float = 0.0
var _cars_hit: float = 0.0     # crashes into traffic / each other: these still hurt
var _wall_crashes: int = 0
var _running: bool = false
var _rng := RandomNumberGenerator.new()
var _done: bool = false


func _ready() -> void:
	_rng.seed = 92
	MapData.use_builtin()
	Escalation.enabled = false
	GameState.reset_run()
	add_child(MAIN.instantiate())
	_start()


func _start() -> void:
	while get_tree().get_first_node_in_group(&"player_vehicle") == null:
		await get_tree().physics_frame
	_taxi = get_tree().get_first_node_in_group(&"player_vehicle") as Taxi
	_damage = _taxi.get_node("TaxiDamage") as TaxiDamage
	_city = get_tree().get_first_node_in_group(&"city") as City
	_director = get_tree().get_first_node_in_group(&"enemy_director") as EnemyDirector
	var shift := get_tree().get_first_node_in_group(&"shift_manager") as ShiftManager
	while not shift.is_active:
		await get_tree().physics_frame
	var tutorial := get_tree().get_first_node_in_group(&"tutorial") as Tutorial
	if tutorial != null:
		tutorial.skip()
	for i in 30:
		await get_tree().physics_frame
	var street := get_tree().get_first_node_in_group(&"street_encounters")
	if street != null:
		street.process_mode = Node.PROCESS_MODE_DISABLED
	_director.max_enemies = CARS
	_cars = _director.spawn_pursuers(CARS)
	for c in _cars:
		c.relocations_left = 999   # measure the driving, not the director giving up
		c.gunner.process_mode = Node.PROCESS_MODE_DISABLED   # no stray bullets between hunters
		c.crashed.connect(_on_crash.bind(c))   # runs after the car's own crash handler
		_hp[c] = c.health.hp
		_relocated[c] = c.relocated_frame
	_running = true


func _physics_process(delta: float) -> void:
	if not _running or _done:
		return
	_t += delta
	if not _damage.is_dead:
		_damage.repair()
	GameState.set_heat(0)   # no police waves on top
	_jump_t += delta
	if _jump_t >= JUMP_EVERY:
		_jump_t = 0.0
		_jump()
	for c in _cars:
		if not is_instance_valid(c) or c.is_destroyed:
			continue
		var d := c.global_position.distance_to(_taxi.global_position)
		if c.ai.mode == EnemyDriverAI.Mode.UNSTUCK and _modes.get(c, -1) != EnemyDriverAI.Mode.UNSTUCK:
			_unstuck += 1
		_modes[c] = c.ai.mode
		if c.relocated_frame != _relocated[c]:
			_relocated[c] = c.relocated_frame
			_rescues += 1
		if d > 25.0 and c.linear_velocity.length() < 1.5 and c.ai.mode != EnemyDriverAI.Mode.AMBUSH:
			_stuck += delta
			var m := String(EnemyDriverAI.Mode.keys()[c.ai.mode])
			_stuck_by[m] = float(_stuck_by.get(m, 0.0)) + delta
			_still[c] = float(_still.get(c, 0.0)) + delta
			if OS.get_environment("CORNERS_DEBUG") != "" and m == "CHASE" and int(_still[c]) != int(_still[c] - delta):
				print("[CornersDebug] %s still %.1fs d %.0f sight %s route %d thr %.2f brk %.2f steer %.2f turn %.2f fwd %.1f pos %s" % [c.name, _still[c], d,
						c.ai._sight, c.ai._route.size(), c.input.throttle, c.input.brake, c.input.steer, c.ai._turning, c.forward_speed, c.global_position.round()])
		elif _still.has(c):
			_still[c] = 0.0
		c.health.hp = c.health.max_hp   # nobody dies or retreats: keep them all hunting
	if _t >= DURATION:
		_finish()


## A crash the car's handler just processed: any HP gone right now came from it (the test
## tops every car up each frame). Without a car in the contacts it was a wall.
func _on_crash(impact: float, c: EnemyCar) -> void:
	if impact <= 6.0:
		return
	var lost := c.health.max_hp - c.health.hp
	var by_car := false
	for b in c.get_colliding_bodies():
		by_car = by_car or b is RigidBody3D
	if by_car:
		_cars_hit += lost
	else:
		_walls += lost
		_wall_crashes += 1
	c.health.hp = c.health.max_hp


## The taxi jumps to a random street 60-160 m away.
func _jump() -> void:
	var here := _taxi.global_position
	var options: Array[Vector3] = []
	for p in _city.road_points_reachable(here):
		var d := Vector2(p.x - here.x, p.z - here.z).length()
		if d > 60.0 and d < 160.0:
			options.append(p)
	if options.is_empty():
		return
	var p := options[_rng.randi() % options.size()]
	_taxi.teleport(Transform3D(Basis.IDENTITY, p + Vector3(0, 1.2, 0)))


func _finish() -> void:
	_done = true
	var alive := _cars.filter(func(c: EnemyCar) -> bool: return is_instance_valid(c)).size()
	print("[CornersTest] %d cars, %.0f s: stuck %.1f s, unstuck %d, rescues %d, wall crashes %d (damage %.0f), car-on-car damage %.0f, alive %d" % [
			CARS, DURATION, _stuck, _unstuck, _rescues, _wall_crashes, _walls, _cars_hit, alive])
	print("[CornersTest] stuck by mode: %s" % _stuck_by)
	var errors: PackedStringArray = []
	if _walls > 0.0:
		errors.append("hunters took %.0f damage from buildings" % _walls)
	if _stuck > STUCK_LIMIT:
		errors.append("hunters stuck %.1f s (limit %.0f)" % [_stuck, STUCK_LIMIT])
	if errors.is_empty():
		print("[CornersTest] PASS")
		get_tree().quit(0)
	else:
		for e in errors:
			print("[CornersTest] FAIL: ", e)
		get_tree().quit(1)
