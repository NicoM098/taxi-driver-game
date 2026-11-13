shader_type canvas_item;

// PS1 colour-depth reduction with ordered (Bayer 4x4) dithering.
// Applied as the material of the SubViewportContainer that shows the low-res 3D world,
// so the dither pattern is aligned to the low-res pixels (not the screen pixels).

uniform float color_levels = 32.0; // 32 = 5 bits per channel (15-bit colour)
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	ivec2 p = ivec2(floor(UV * vec2(textureSize(TEXTURE, 0))));
	float threshold = BAYER[(p.y % 4) * 4 + (p.x % 4)] / 16.0 - 0.5;
	float steps = max(color_levels - 1.0, 1.0);
	vec3 col = c.rgb + threshold * dither_strength / steps;
	col = floor(col * steps + 0.5) / steps;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
