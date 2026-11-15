class_name TaxiDamage
extends Node3D
## Player taxi damage model (Phase 06). Child of the Taxi.
## - Taxi body HP: crashes (above a threshold, not jump landings) + bullets on the body hitbox.
## - Driver HP: bullets through the cabin hitbox (scaled); passenger is hit by a share of those.
## - Smoke under 50 % body HP, fire under 20 %. Taxi or driver at 0 -> the cab explodes and the
##   run is over (user, 2026-11-15; main.gd shows game over). Repair shops fix damage before that.
##   In worlds without a repair shop (shooting range) a wreck repairs itself after
##   `auto_repair_time` instead.

signal wrecked(reason: StringName)

@export var taxi: Taxi
@export var crash_damage_threshold: float = 8.0  # velocity change (m/s per tick) before crashes hurt
@export var crash_damage_scale: float = 2.0
@export var landing_grace: float = 0.3           # s after a jump landing with no crash damage
@export var driver_damage_mult: float = 0.45     # cabin hit -> driver
@export var cabin_body_mult: float = 0.15        # cabin hit -> taxi body too
@export var body_hit_mult: float = 0.6           # bullet on the body hitbox -> taxi body
@export var passenger_hit_chance: float = 0.35
@export var driver_max_hp: float = 100.0
@export var passenger_max_hp: float = 60.0
@export var auto_repair_time: float = 4.0        # only in worlds without a repair shop

var taxi_health: HealthComponent
var driver_health: HealthComponent
var passenger_health: HealthComponent
var passenger_aboard: bool = false
var is_wrecked: bool = false
## The driver died: the run is over (no repair, no limping).
var is_dead: bool = false

var _since_landing: float = 99.0
var _repair_timer: float = -1.0
var _smoke: CPUParticles3D
var _fire: CPUParticles3D
var _rng := RandomNumberGenerator.new()
var _heal_driver_left: float = 0.0
var _heal_body_left: float = 0.0
var _heal_rate: float = 1.0   # fraction of the remaining heal applied per second (set by drink)


func _ready() -> void:
	add_to_group(&"taxi_damage")
	_rng.randomize()
	if taxi == null:
		taxi = get_parent() as Taxi
	taxi_health = _make_health("TaxiHealth", PlayerStats.get_stat(&"taxi_max_hp"))
	driver_health = _make_health("DriverHealth", driver_max_hp)
	passenger_health = _make_health("PassengerHealth", passenger_max_hp)
	taxi_health.died.connect(_wreck.bind(&"taxi_destroyed"))
	driver_health.died.connect(_wreck.bind(&"driver_killed"))
	passenger_health.died.connect(func() -> void:
		passenger_aboard = false
		EventBus.passenger_killed.emit())
	taxi_health.damaged.connect(func(amount: float, hp_left: float) -> void:
		EventBus.taxi_damaged.emit(amount, hp_left))

	var body := _make_hitbox("BodyHitbox", Vector3(1.95, 1.0, 4.5), Vector3(0, 0.1, 0), taxi_health)
	body.damage_multiplier = body_hit_mult
	body.hit.connect(_on_body_hit)
	var cabin := _make_hitbox("CabinHitbox", Vector3(1.7, 0.85, 2.2), Vector3(0, 0.95, 0.35), null)
	cabin.hit.connect(_on_cabin_hit)

	_smoke = CombatFx.make_particles("res://assets/materials/fx_smoke.tres", 14, 1.4, 0.35, 2.0)
	_smoke.position = Vector3(0, 0.6, -1.7)
	add_child(_smoke)
	_fire = CombatFx.make_particles("res://assets/materials/fx_fire.tres", 18, 0.6, 0.3, 2.5)
	_fire.position = Vector3(0, 0.6, -1.7)
	add_child(_fire)

	if taxi != null:
		taxi.crashed.connect(_on_crashed)
		taxi.landed.connect(func(_fall: float) -> void: _since_landing = 0.0)
	EventBus.ride_started.connect(func(_r: RefCounted) -> void:
		passenger_health.revive()
		passenger_aboard = true)
	EventBus.ride_completed.connect(func(_r: RefCounted, _p: int) -> void: passenger_aboard = false)
	EventBus.ride_failed.connect(func(_r: RefCounted, _reason: StringName) -> void: passenger_aboard = false)


func _process(delta: float) -> void:
	_since_landing += delta
	if _heal_driver_left > 0.0 or _heal_body_left > 0.0:
		var d := minf(_heal_driver_left, _heal_rate * delta)
		var b := minf(_heal_body_left, _heal_rate * delta * 0.6)
		driver_health.heal(d)
		taxi_health.heal(b)
		_heal_driver_left -= d
		_heal_body_left -= b
	var ratio := taxi_health.hp / taxi_health.max_hp
	_smoke.emitting = ratio < 0.5
	_fire.emitting = ratio < 0.2 or is_wrecked
	if _repair_timer >= 0.0:
		_repair_timer -= delta
		if _repair_timer < 0.0:
			repair()


func repair() -> void:
	if is_dead:
		return   # dead is dead: the run is over
	var was_wrecked := is_wrecked
	is_wrecked = false
	taxi_health.revive()
	driver_health.revive()
	_heal_driver_left = 0.0
	_heal_body_left = 0.0
	if was_wrecked and taxi != null:
		if taxi.limp:
			taxi.limp = false
		else:   # it was parked dead (no repair shop in this world)
			taxi.request_reset()
			_set_player_control(true)
	_repair_timer = -1.0


## Energy drink: heals the driver (and a bit of the taxi) smoothly over `duration` seconds.
func drink(driver_amount: float, body_amount: float, duration: float) -> void:
	if is_wrecked:
		return
	_heal_driver_left += driver_amount
	_heal_body_left += body_amount
	_heal_rate = maxf(driver_amount, body_amount / 0.6) / maxf(duration, 0.05)


## Applies crash-style damage directly (also used by tests).
func apply_crash(impact: float) -> void:
	_on_crashed(impact)


func _on_crashed(impact: float) -> void:
	if is_wrecked or _since_landing < landing_grace:
		return
	var damage := (impact - crash_damage_threshold) * crash_damage_scale
	if damage > 0.0:
		taxi_health.apply_damage(damage)


func _on_body_hit(damage: float, source: Vector3) -> void:
	EventBus.player_hit.emit(damage, source)


func _on_cabin_hit(damage: float, source: Vector3) -> void:
	if is_wrecked:
		return
	driver_health.apply_damage(damage * driver_damage_mult)
	taxi_health.apply_damage(damage * cabin_body_mult)
	if passenger_aboard and _rng.randf() < passenger_hit_chance:
		passenger_health.apply_damage(damage)
	EventBus.player_hit.emit(damage, source)


func _wreck(reason: StringName) -> void:
	if is_wrecked:
		return
	is_wrecked = true
	wrecked.emit(reason)
	EventBus.taxi_wrecked.emit(reason)
	# Either bar at 0 ends the run (user 2026-11-15: "when your life runs out you explode").
	# Only worlds without repair shops (shooting range) keep the old self-repair.
	if reason == &"driver_killed" or get_tree().get_first_node_in_group(&"repair_shops") != null:
		_die()
		return
	EventBus.hud_message.emit("WRECKED!", &"bad")
	_set_player_control(false)
	_repair_timer = auto_repair_time


## The driver is dead (user request 2026-11-15): the cab blows up, the player loses control and
## the run is over. Same when the taxi body hits 0, in any world that has repair shops.
func _die() -> void:
	is_dead = true
	_set_player_control(false)
	_fire.emitting = true
	if taxi != null:
		CombatFx.explosion(taxi.get_parent(), taxi.global_position)
		EventBus.explosion.emit(taxi.global_position, 1.5)
		taxi.apply_central_impulse(Vector3(0, taxi.mass * 6.0, 0))
		taxi.apply_torque_impulse(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * taxi.mass * 2.0)
	EventBus.hud_message.emit("YOU'RE DEAD", &"bad")
	EventBus.player_died.emit()


func _set_player_control(enabled: bool) -> void:
	var player_input := taxi.get_node_or_null("PlayerInput") as PlayerVehicleInput if taxi != null else null
	if player_input != null:
		player_input.enabled = enabled


func _make_health(node_name: String, max_hp: float) -> HealthComponent:
	var h := HealthComponent.new()
	h.name = node_name
	h.max_hp = max_hp
	add_child(h)
	return h


func _make_hitbox(node_name: String, size: Vector3, pos: Vector3, health: HealthComponent) -> Hitbox:
	var hitbox := Hitbox.new()
	hitbox.name = node_name
	hitbox.health = health
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	hitbox.add_child(col)
	add_child(hitbox)
	return hitbox
