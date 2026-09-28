// Underside of the water surface: rippling, caustic-lit and mirror-bright at
// grazing angles. Rendered unshaded so the look is fully art-directed.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

#include "res://shaders/underwater.gdshaderinc"

uniform vec3 deep_color : source_color = vec3(0.020, 0.090, 0.130);
uniform vec3 bright_color : source_color = vec3(0.52, 0.80, 0.92);
uniform vec3 caustic_color : source_color = vec3(0.70, 0.95, 1.00);
uniform vec3 light_dir = vec3(0.25, 0.94, 0.22);
uniform float wave_scale = 1.0;
uniform float caustic_strength = 0.35;
uniform float opacity = 0.34;
uniform float time_scale = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h;
	vec2 g;
	water_waves(world_pos.xz * wave_scale, TIME * time_scale, h, g);
	VERTEX.y += h;
}

void fragment() {
	vec3 n = water_normal(world_pos.xz * wave_scale, TIME * time_scale);
	vec3 nv = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(abs(dot(normalize(VIEW), nv)), 0.0, 1.0), 3.0);
	float glint = pow(clamp(dot(n, normalize(light_dir)), 0.0, 1.0), 12.0);
	vec3 col = mix(deep_color, bright_color, clamp(fres * 0.85 + glint * 0.6, 0.0, 1.0));
	col += caustic_color * caustic_web(world_pos.xz * 1.60, TIME * time_scale) * caustic_strength;
	ALBEDO = col;
	ALPHA = clamp(opacity + fres * 0.55 + glint * 0.30, 0.0, 1.0);
	EMISSION = col * 0.16;
}
