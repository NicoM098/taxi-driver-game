class_name Lighting
extends RefCounted
## Time-of-day presets for the city (D-064). Everything the mood touches lives here: sky, ambient,
## the sun (or moon), fog, how hard the street lamps burn and how bright a lit window reads.
## Dusk is the default, per [[Art Direction]]: "dusky city, blue/purple shadows, sodium-orange
## street lights". No shadows in any mood — the PS1 look has none.

enum Mood {
	DAY,
	DUSK,
	NIGHT,
}

const ORDER: Array[Mood] = [Mood.DAY, Mood.DUSK, Mood.NIGHT]
const DEFAULT: Mood = Mood.DUSK

## Sodium orange. The hero colour (taxi yellow) sits right next to it on the wheel, so the taxi
## reads as lit rather than tinted.
const LAMP_COLOR: Color = Color(1.0, 0.72, 0.36)

const _PRESETS: Dictionary = {
	Mood.DAY: {
		"name": "day",
		"sky": Color(0.56, 0.6, 0.72),
		"ambient": Color(0.62, 0.64, 0.78),
		"ambient_energy": 0.7,
		"sun": Color(1.0, 0.97, 0.9),
		"sun_energy": 1.1,
		"sun_angles": Vector3(-55.0, -35.0, 0.0),
		"fog": Color(0.56, 0.6, 0.72),
		"fog_begin": 70.0,
		"fog_end": 220.0,
		"lamp_energy": 0.0,        # lamps are off in daylight
		"lamp_glow": 0.0,          # ...and their glass is just glass
		"window_emission": 0.0,
		"window_lit": 0.0,         # nobody has a light on either
	},
	Mood.DUSK: {
		"name": "dusk",
		"sky": Color(0.36, 0.31, 0.44),
		"ambient": Color(0.38, 0.36, 0.5),
		"ambient_energy": 0.62,
		"sun": Color(1.0, 0.6, 0.38),       # low orange sun raking down the streets
		"sun_energy": 0.9,
		"sun_angles": Vector3(-14.0, -115.0, 0.0),
		"fog": Color(0.4, 0.31, 0.39),
		"fog_begin": 55.0,
		"fog_end": 190.0,
		"lamp_energy": 1.6,
		"lamp_glow": 1.2,
		"window_emission": 1.2,
		"window_lit": 1.0,
	},
	Mood.NIGHT: {
		"name": "night",
		"sky": Color(0.07, 0.08, 0.15),
		"ambient": Color(0.17, 0.2, 0.32),
		"ambient_energy": 0.34,
		"sun": Color(0.55, 0.63, 0.95),     # moon, just enough to keep silhouettes readable
		"sun_energy": 0.2,
		"sun_angles": Vector3(-42.0, -140.0, 0.0),
		"fog": Color(0.08, 0.09, 0.17),
		"fog_begin": 40.0,
		"fog_end": 150.0,
		"lamp_energy": 2.4,
		"lamp_glow": 1.6,
		"window_emission": 1.8,
		"window_lit": 1.0,
	},
}


static func preset(mood: Mood) -> Dictionary:
	return _PRESETS.get(mood, _PRESETS[DEFAULT])


static func mood_name(mood: Mood) -> String:
	return String(preset(mood)["name"])


static func next(mood: Mood) -> Mood:
	var i := ORDER.find(mood)
	return ORDER[(i + 1) % ORDER.size()] if i >= 0 else DEFAULT


## How hard a street lamp's omni light burns in this mood (0 = switched off).
static func lamp_energy(mood: Mood) -> float:
	return float(preset(mood)["lamp_energy"])


## Emission of the lamp's own glass. Separate from the light it casts, because a lamp switched
## off must also stop glowing (D-065).
static func lamp_glow(mood: Mood) -> float:
	return float(preset(mood)["lamp_glow"])


## 0 = no window in the city has its light on, whatever `window_lit_chance` says (D-065).
static func window_lit_amount(mood: Mood) -> float:
	return float(preset(mood)["window_lit"])


## Are the taxi's headlights on in this mood? (D-065)
static func headlights_on(mood: Mood) -> bool:
	return lamp_energy(mood) > 0.0


## Emission multiplier for lit facade windows (D-061). They were tuned against a bright sky, so
## at night they need to burn harder to read as rooms with the light on.
static func window_emission(mood: Mood) -> float:
	return float(preset(mood)["window_emission"])


## Applies a mood to an existing environment + sun. Safe to call every time the mood changes.
static func apply(env: Environment, sun: DirectionalLight3D, mood: Mood) -> void:
	var p := preset(mood)
	if env != null:
		env.background_mode = Environment.BG_COLOR
		env.background_color = p["sky"]
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = p["ambient"]
		env.ambient_light_energy = p["ambient_energy"]
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_light_color = p["fog"]
		env.fog_density = 1.0
		env.fog_depth_begin = p["fog_begin"]
		env.fog_depth_end = p["fog_end"]
	if sun != null:
		sun.light_color = p["sun"]
		sun.light_energy = p["sun_energy"]
		sun.rotation_degrees = p["sun_angles"]
		sun.shadow_enabled = false
