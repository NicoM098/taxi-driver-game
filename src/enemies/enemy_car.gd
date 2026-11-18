class_name EnemyCar
extends Taxi
## AI-driven enemy vehicle (Phase 06). Reuses the Taxi raycast physics (same handling family)
## and builds its own blockout body, wheels, hitboxes, health, AI driver and gunman in code
## from an EnemyCarData. Physics layer 3 (enemy_vehicles).

signal destroyed(car: EnemyCar)

const WHEELS := [[-0.82, -1.35, true], [0.82, -1.35, true], [-0.82, 1.35, false], [0.82, 1.35, false]]

@export var data: EnemyCarData
var target: Taxi
var health: HealthComponent
var is_destroyed: bool = false

## Quieter than the player's own car: there can be several of them at once.
const ENEMY_ENGINE_DB: float = -14.0
var _engine: AudioStreamPlayer3D = null
var ai: EnemyDriverAI
var gunner: EnemyGunner
## Times the EnemyDirector may still put this car back on the player's tail after it was
## outrun (pursuers do not give up when the fare is delivered).
var relocations_left: int = 0
## A boss of the current boss fight (Escalation.mark_boss), even if its data is not a boss car
## (the gang bosses of stage 2 are elites too). D-106.
var boss_fight: bool = false
var marker: HostileMarker
var relocated_frame: int = -100000   # physics frame of the last relocation (teleports are deferred)

var _body: MeshInstance3D
var _body_mat: Material
var _fire: CPUParticles3D
var _smoke: CPUParticles3D


func _ready() -> void:
	if data == null:
		data = load("res://data/enemies/hitman_sedan.tres")
	collision_layer = 1 << 2
	collision_mask = 1 | 2 | 4 | 8 | 16 | 256
	mass = data.mass  # default 800: lighter than the taxi (1000): you can shove them instead of getting pinned
	gravity_scale = 1.3
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -0.2, 0.0)
	continuous_cd = true
	# Crash damage only from other cars (D-092): contacts tell a wall from a car.
	contact_monitor = true
	max_contacts_reported = 4
	angular_damp = 0.3
	max_speed = data.max_speed
	# Heavy cars (escalation bosses) get a stiffer suspension so they ride at the same height.
	if data.mass > 1000.0:
		spring_strength *= data.mass / 1000.0
		spring_damping *= data.mass / 1000.0
	nitro_tank = false   # the AI's boost is endless: they have no tank to manage
	engine_force = data.engine_force
	_body_mat = load(data.body_material)
	_body = build_body(self, _body_mat, data.siren, data.size, data.plow)
	build_wheels(self, data.size)
	_add_engine_audio()
	marker = HostileMarker.new()   # tells it apart from civilian traffic
	marker.boss = data.is_boss     # bosses: gold, a beam and a BOSS tag (D-102)
	marker.boss_name = data.display_name
	add_child(marker)

	health = HealthComponent.new()
	# Tougher the more the run has earned: an upgraded gun keeps its time-to-kill (D-093).
	health.max_hp = data.hp * WeaponUpgrades.enemy_hp_mult()
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_add_hitbox(Vector3(1.95 * data.size, 1.35, 4.45 * data.size), Vector3(0, 0.45, 0), 1.0)
	_add_hitbox(Vector3(0.6, 0.55, 0.6), Vector3(-0.4, 1.0, -0.05), 2.5).name = "DriverHitbox"

	_smoke = CombatFx.make_particles("res://assets/materials/fx_smoke.tres", 12, 1.2, 0.35, 2.0)
	_smoke.position = Vector3(0, 0.6, -1.7)
	add_child(_smoke)
	_fire = CombatFx.make_particles("res://assets/materials/fx_fire.tres", 20, 0.7, 0.35, 3.0)
	_fire.position = Vector3(0, 0.7, 0)
	add_child(_fire)

	ai = EnemyDriverAI.new()
	ai.name = "AI"
	ai.car = self
	add_child(ai)
	input_provider = ai
	gunner = EnemyGunner.new()
	gunner.name = "Gunner"
	gunner.car = self
	add_child(gunner)
	super._ready()
	crashed.connect(_on_crash)


## Positional engine note (D-067): one layer, pitched by speed, so you hear them coming and can
## tell roughly where they are. Silent once destroyed; absent entirely in headless runs.
func _add_engine_audio() -> void:
	if not Audio.enabled:
		return
	_engine = Audio.make_loop_3d(&"engine_mid", self, Audio.BUS_ENGINE, 80.0)
	_engine.play()


func _process(_delta: float) -> void:
	if _engine == null:
		return
	if is_destroyed:
		_engine.volume_db = -80.0
		return
	var t := clampf(linear_velocity.length() / maxf(max_speed, 1.0), 0.0, 1.0)
	_engine.pitch_scale = lerpf(0.78, 1.45, t)
	_engine.volume_db = ENEMY_ENGINE_DB + linear_to_db(clampf(0.4 + 0.6 * t, 0.0001, 1.0))


## Collision boxes + blockout body of an AI car (also used by traffic). Returns the lower
## body mesh (flashes when hit).
## `size` scales width and length (escalation bosses, D-091); `plow` adds a steel nose plow
## (with its own collision box: it is what hits you) and roof armour.
static func build_body(car: RigidBody3D, body_mat: Material, siren: bool = false, size: float = 1.0,
		plow: bool = false) -> MeshInstance3D:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	# Underside 0.1 m below the wheel mounts: clears a 0.2 m curb even with the suspension
	# fully compressed (a lower box hit sidewalk edges after landings, D-060).
	shape.size = Vector3(1.7 * size, 0.6, 4.2 * size)
	col.shape = shape
	col.position.y = 0.2
	car.add_child(col)
	var cabin_col := CollisionShape3D.new()
	var cabin_shape := BoxShape3D.new()
	cabin_shape.size = Vector3(1.5 * size, 0.6, 2.0 * size)
	cabin_col.shape = cabin_shape
	cabin_col.position = Vector3(0, 0.8, 0.3 * size)
	car.add_child(cabin_col)

	var lower := BoxMesh.new()
	lower.size = Vector3(1.8 * size, 0.8, 4.3 * size)
	var body := Blockout.add_mesh(car, lower, Vector3(0, 0.1, 0), body_mat)
	var cabin := BoxMesh.new()
	cabin.size = Vector3(1.6 * size, 0.6, 2.0 * size)
	var black: Material = load("res://assets/materials/taxi_black.tres")
	Blockout.add_mesh(car, cabin, Vector3(0, 0.8, 0.3 * size), black)
	if siren:
		var light := BoxMesh.new()
		light.size = Vector3(0.4, 0.15, 0.25)
		Blockout.add_mesh(car, light, Vector3(-0.25, 1.18, 0.3 * size), load("res://assets/materials/siren_red.tres"))
		Blockout.add_mesh(car, light, Vector3(0.25, 1.18, 0.3 * size), load("res://assets/materials/siren_blue.tres"))
	if plow:
		var nose_z := -4.3 * size * 0.5 - 0.25
		var blade := BoxMesh.new()
		blade.size = Vector3(2.0 * size, 0.55, 0.3)
		Blockout.add_mesh(car, blade, Vector3(0, 0.05, nose_z), black)
		var blade_col := CollisionShape3D.new()
		var blade_shape := BoxShape3D.new()
		blade_shape.size = Vector3(2.0 * size, 0.45, 0.3)
		blade_col.shape = blade_shape
		blade_col.position = Vector3(0, 0.12, nose_z)
		car.add_child(blade_col)
		for x: float in [-0.6, 0.0, 0.6]:
			var rib := BoxMesh.new()
			rib.size = Vector3(0.12, 0.6, 0.5)
			Blockout.add_mesh(car, rib, Vector3(x * size, 0.05, nose_z + 0.2), body_mat)
		var roof := BoxMesh.new()
		roof.size = Vector3(1.3 * size, 0.18, 1.4 * size)
		Blockout.add_mesh(car, roof, Vector3(0, 1.19, 0.3 * size), body_mat)
	return body


static func build_wheels(car: RigidBody3D, size: float = 1.0) -> void:
	var tyre := CylinderMesh.new()
	tyre.top_radius = 0.35
	tyre.bottom_radius = 0.35
	tyre.height = 0.25
	tyre.radial_segments = 8
	tyre.rings = 1
	var tyre_mat: Material = load("res://assets/materials/taxi_black.tres")
	var wheels_root := Node3D.new()
	wheels_root.name = "Wheels"
	car.add_child(wheels_root)
	for w: Array in WHEELS:
		var wheel := TaxiWheel.new()
		wheel.position = Vector3(w[0] * size, 0.0, w[1] * size)
		wheel.is_front = w[2]
		var visual := Node3D.new()
		wheel.add_child(visual)
		var mesh := Blockout.add_mesh(visual, tyre, Vector3.ZERO, tyre_mat)
		mesh.rotation = Vector3(0.0, 0.0, PI * 0.5)
		wheel.visual = visual
		wheels_root.add_child(wheel)


func _add_hitbox(size: Vector3, pos: Vector3, mult: float) -> Hitbox:
	var hitbox := Hitbox.new()
	hitbox.health = health
	hitbox.damage_multiplier = mult
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	hitbox.add_child(col)
	add_child(hitbox)
	return hitbox


## Hits from vehicles (the taxi ramming, other cars) hurt; buildings, walls and props do not
## (user 2026-11-17: they wrecked themselves on corners over time, D-092).
func _on_crash(impact: float) -> void:
	if impact <= 6.0:
		return
	for body in get_colliding_bodies():
		if body is RigidBody3D:
			health.apply_damage((impact - 6.0) * 4.0)
			return


func _on_damaged(_amount: float, hp_left: float) -> void:
	_smoke.emitting = hp_left < health.max_hp * 0.5 and not is_destroyed
	if is_destroyed:
		return
	_body.material_override = load("res://assets/materials/target_hit.tres")
	var flash := create_tween()  # bound to this car: dies with it (safe if it explodes)
	flash.tween_interval(0.06)
	flash.tween_callback(func() -> void: _body.material_override = _body_mat)


## Killed: explode and vanish instantly (user feedback: wrecks pinned the taxi).
func _on_died() -> void:
	is_destroyed = true
	EventBus.enemy_destroyed.emit(self, data.bounty)
	AmmoPickup.drop_for_kill(get_parent(), global_position, data.hp)   # ammo comes from kills (D-094)
	destroyed.emit(self)
	CombatFx.explosion(get_parent(), global_position)
	EventBus.explosion.emit(global_position, 1.0)
	queue_free()


## Whether it is shown and treated as a boss (gold marker, edge arrow, minimap).
func is_boss() -> bool:
	return boss_fight or (data != null and data.is_boss)


## Makes it a boss of the boss fight (D-106): gold marker with its name.
func mark_boss() -> void:
	boss_fight = true
	if marker != null:
		marker.make_boss(data.display_name if data != null else "")
