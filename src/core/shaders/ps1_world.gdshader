shader_type spatial;
// Lit per pixel, not per vertex (D-064): street lamps arrived in Iteration 10, and with the road
// tessellated at 6 m (D-063) a vertex-lit pool of light would be computed at four corners 6 m
// apart and read as a faceted blob. The rest of the PS1 stack is untouched.
render_mode diffuse_lambert, specular_disabled;

// PS1-style world material: vertex snapping (wobble), affine texture mapping, flat colour,
// optional low-res texture, optional world-space checker (for blockouts) and optional
// procedural facade windows (D-061).
// Global strengths are toggled by main.gd (F1). Defaults live in Project Settings > Shader Globals.

global uniform float ps1_snap_strength;
global uniform float ps1_affine_strength;
global uniform vec2 ps1_snap_resolution;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec2 uv_scale = vec2(1.0);
// 0 = the mesh's own UVs (scaled by uv_scale).
// 1 = world-space planar UVs: one texture tile always covers `world_uv_metres` real metres, on a
//     box of any size. The city is generated from primitives of wildly different dimensions
//     (map_builder.gd), so their materials use 1 and a texture tiles correctly without any
//     per-piece setup. See D-061.
uniform int uv_mode : hint_range(0, 1) = 0;
uniform float world_uv_metres = 4.0;
uniform bool use_vertex_color = false;
// 0 = no wobble (use for the cab interior, which sits right in front of the camera).
uniform float snap_multiplier : hint_range(0.0, 4.0) = 1.0;
uniform float affine_multiplier : hint_range(0.0, 1.0) = 1.0;
// > 0 draws a world-space checker of this size in metres (blockout speed reference).
uniform float checker_size = 0.0;
uniform vec4 checker_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength = 0.0;

// --- Procedural facade windows (D-061) ---------------------------------------------------
// Drawn in world space on vertical faces only, so one material gives every generated building
// a window grid at a consistent real-world scale. No texture and no extra geometry.
uniform bool windows_enabled = false;
uniform vec2 window_cell = vec2(3.0, 3.4);        // metres between window centres (across, up)
uniform vec2 window_fill = vec2(0.42, 0.46);      // fraction of the cell that is glass
uniform float window_ground_floor = 4.5;          // metres of blank wall at street level
uniform vec4 window_dark : source_color = vec4(0.07, 0.08, 0.11, 1.0);
// How much of the wall colour an unlit window replaces. Below 1 the facade keeps its hue
// instead of reading as a grid of black holes.
uniform float window_dark_mix : hint_range(0.0, 1.0) = 0.72;
uniform vec4 window_lit : source_color = vec4(1.0, 0.85, 0.55, 1.0);
uniform float window_lit_chance : hint_range(0.0, 1.0) = 0.3;
uniform float window_lit_emission : hint_range(0.0, 4.0) = 1.2;
// 0 = nobody has a light on: lit windows fall back to looking exactly like unlit ones. Driven by
// the time of day (D-065) — in daylight a glowing window reads as a bug.
uniform float window_lit_amount : hint_range(0.0, 1.0) = 1.0;
// Windows fade back into the wall colour past this distance: at 320x240 a 1 m grid turns into
// moire long before it is readable. Fog finishes the job.
uniform float window_fade_near = 45.0;
uniform float window_fade_far = 85.0;

varying vec3 affine_uv;
varying vec2 base_uv;
varying vec3 world_pos;
varying vec3 world_normal;

// Planar projection picked from the dominant axis of the normal: XZ for floors and roofs,
// ZY / XY for walls. Y is flipped so textures are not upside down on walls.
vec2 planar_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	vec2 uv;
	if (a.y >= a.x && a.y >= a.z) {
		uv = p.xz;
	} else if (a.x >= a.z) {
		uv = vec2(p.z, -p.y);
	} else {
		uv = vec2(p.x, -p.y);
	}
	return uv / max(world_uv_metres, 0.001);
}

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));

	// Snap the projected vertex to a coarse screen grid (PS1 had no sub-pixel precision).
	float s = ps1_snap_strength * snap_multiplier;
	if (s > 0.0 && clip.w > 0.0) {
		vec2 grid = max(ps1_snap_resolution * 0.5 / s, vec2(1.0));
		vec2 ndc = clip.xy / clip.w;
		ndc = floor(ndc * grid + 0.5) / grid;
		clip.xy = ndc * clip.w;
	}
	POSITION = clip;

	base_uv = uv_mode == 1 ? planar_uv(world_pos, world_normal) : UV * uv_scale;
	// Affine mapping trick: interpolate uv*w and w, divide per-fragment => screen-linear UVs.
	affine_uv = vec3(base_uv * clip.w, clip.w);
}

// Returns rgb = window colour, a = how much of it covers the wall (0 = plain wall).
vec4 facade_window(vec3 p, vec3 n, out float emit) {
	emit = 0.0;
	vec3 a = abs(n);
	if (a.y >= 0.5) {
		return vec4(0.0);          // floors and roofs have no windows
	}
	float up = p.y - window_ground_floor;
	if (up <= 0.0) {
		return vec4(0.0);          // blank wall at street level
	}
	bool x_facing = a.x >= a.z;
	float across = x_facing ? p.z : p.x;
	vec2 cell = vec2(across, up) / max(window_cell, vec2(0.01));
	vec2 f = abs(fract(cell) - 0.5);
	vec2 half_fill = clamp(window_fill, vec2(0.0), vec2(1.0)) * 0.5;
	if (f.x >= half_fill.x || f.y >= half_fill.y) {
		return vec4(0.0);          // wall between windows
	}
	// Decorrelate the two parallel faces of the same building.
	float depth_coord = x_facing ? p.x : p.z;
	vec2 id = floor(cell) + vec2(floor(depth_coord * 0.25) * 7.3, x_facing ? 0.0 : 37.0);
	if (hash21(id) < window_lit_chance) {
		emit = window_lit_emission * window_lit_amount;
		return vec4(mix(window_dark.rgb, window_lit.rgb, window_lit_amount),
				mix(window_dark_mix, 1.0, window_lit_amount));
	}
	return vec4(window_dark.rgb, window_dark_mix);
}

void fragment() {
	vec2 uv_affine = affine_uv.xy / affine_uv.z;
	vec2 uv = mix(base_uv, uv_affine, clamp(ps1_affine_strength * affine_multiplier, 0.0, 1.0));

	vec4 base = albedo * texture(albedo_texture, uv);
	if (use_vertex_color) {
		base *= COLOR;
	}
	if (checker_size > 0.0) {
		float c = mod(floor(world_pos.x / checker_size) + floor(world_pos.z / checker_size), 2.0);
		base.rgb = mix(base.rgb, checker_color.rgb, c);
	}

	float emit = emission_strength;
	if (windows_enabled) {
		float win_emit = 0.0;
		vec4 win = facade_window(world_pos, normalize(world_normal), win_emit);
		if (win.a > 0.0) {
			float fade = 1.0 - smoothstep(window_fade_near, window_fade_far, length(VERTEX));
			base.rgb = mix(base.rgb, win.rgb, win.a * fade);
			emit = max(emit, win_emit * fade);
		}
	}

	ALBEDO = base.rgb;
	ROUGHNESS = 1.0;
	EMISSION = base.rgb * emit;
}
