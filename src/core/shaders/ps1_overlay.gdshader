shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled;

// Flat-colour overlay for 3D HUD elements (guide arrow): drawn in the transparent pass
// with no depth test, so cabin geometry closer to the camera never hides it.

uniform vec4 albedo : source_color = vec4(1.0);

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;  // writing ALPHA moves it to the transparent pass (drawn after opaque)
}
