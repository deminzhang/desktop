// Screen-space finish for the aquarium window: soft vignette plus a cool haze
// that pools toward the bottom of the frame.
shader_type canvas_item;
render_mode blend_mix;

uniform float strength = 0.62;
uniform float inner = 0.32;
uniform float outer = 0.80;
uniform vec3 tint : source_color = vec3(0.006, 0.030, 0.045);
uniform float bottom_haze = 0.22;

void fragment() {
	vec2 uv = SCREEN_UV - vec2(0.5);
	uv.x *= 1.06;
	float d = length(uv);
	float v = smoothstep(inner, outer, d);
	float haze = smoothstep(0.55, 0.0, SCREEN_UV.y) * bottom_haze;
	COLOR = vec4(tint, clamp(v * strength + haze, 0.0, 1.0));
}
