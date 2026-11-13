shader_type spatial;
render_mode diffuse_lambert, specular_disabled, vertex_lighting;

// PS1-style world material: vertex snapping (wobble), affine texture mapping, flat colour,
// optional low-res texture, optional world-space checker (for blockouts).
// Global strengths are toggled by main.gd (F1). Defaults live in Project Settings > Shader Globals.

global uniform float ps1_snap_strength;
global uniform float ps1_affine_strength;
global uniform vec2 ps1_snap_resolution;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec2 uv_scale = vec2(1.0);
uniform bool use_vertex_color = false;
// 0 = no wobble (use for the cab interior, which sits right in front of the camera).
uniform float snap_multiplier : hint_range(0.0, 4.0) = 1.0;
uniform float affine_multiplier : hint_range(0.0, 1.0) = 1.0;
// > 0 draws a world-space checker of this size in metres (blockout speed reference).
uniform float checker_size = 0.0;
uniform vec4 checker_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength = 0.0;

varying vec3 affine_uv;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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

	// Affine mapping trick: interpolate uv*w and w, divide per-fragment => screen-linear UVs.
	affine_uv = vec3(UV * uv_scale * clip.w, clip.w);
}

void fragment() {
	vec2 uv_correct = UV * uv_scale;
	vec2 uv_affine = affine_uv.xy / affine_uv.z;
	vec2 uv = mix(uv_correct, uv_affine, clamp(ps1_affine_strength * affine_multiplier, 0.0, 1.0));

	vec4 base = albedo * texture(albedo_texture, uv);
	if (use_vertex_color) {
		base *= COLOR;
	}
	if (checker_size > 0.0) {
		float c = mod(floor(world_pos.x / checker_size) + floor(world_pos.z / checker_size), 2.0);
		base.rgb = mix(base.rgb, checker_color.rgb, c);
	}
	ALBEDO = base.rgb;
	ROUGHNESS = 1.0;
	EMISSION = base.rgb * emission_strength;
}
