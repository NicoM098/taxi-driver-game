class_name TrafficCar
extends Taxi
## A civilian car cruising the streets (street life, D-065). Same raycast physics as the taxi,
## the AI cars' blockout body in a random civilian colour, physics layer 4 (traffic).
## Driven by TrafficAI: right-hand lane, keeps distance, stops after a crash. Not destructible:
## bullets only shove it. Spawned / recycled by StreetLife around the player.

const COLORS: Array[Color] = [
	Color(0.75, 0.75, 0.78), Color(0.15, 0.25, 0.55), Color(0.2, 0.45, 0.25), Color(0.55, 0.5, 0.42),
	Color(0.12, 0.12, 0.14), Color(0.6, 0.35, 0.15), Color(0.45, 0.15, 0.4), Color(0.85, 0.85, 0.82),
]

var ai: TrafficAI
var color: Color = Color.WHITE

static var _mats: Dictionary = {}


func _ready() -> void:
	collision_layer = 1 << 3
	collision_mask = 1 | 2 | 4 | 8 | 16 | 256
	mass = 900.0
	gravity_scale = 1.3
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, -0.2, 0.0)
	continuous_cd = true
	angular_damp = 0.3
	max_speed = 16.0
	engine_force = 6500.0
	if color == Color.WHITE:
		color = COLORS.pick_random()
	EnemyCar.build_body(self, _material(color))
	EnemyCar.build_wheels(self)
	ai = TrafficAI.new()
	ai.name = "AI"
	ai.car = self
	add_child(ai)
	input_provider = ai
	super._ready()
	crashed.connect(ai.on_crash)


static func _material(c: Color) -> Material:
	var key := c.to_html()
	if not _mats.has(key):
		var m := (load("res://assets/materials/enemy_red.tres") as ShaderMaterial).duplicate() as ShaderMaterial
		m.set_shader_parameter(&"albedo", c)
		_mats[key] = m
	return _mats[key]
