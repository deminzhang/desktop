// Swaying aquatic plants, drawn with MultiMesh so hundreds of blades cost one
// draw call. Per-instance custom data: x phase, y sway scale, z tint, w spare.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://backgrounds/aquarium/shaders/underwater.gdshaderinc"

uniform vec3 color_deep : source_color = vec3(0.05, 0.24, 0.11);
uniform vec3 color_tip : source_color = vec3(0.30, 0.72, 0.26);
uniform vec3 color_alt : source_color = vec3(0.62, 0.34, 0.14);
uniform vec3 caustic_color : source_color = vec3(0.70, 0.92, 1.00);
uniform float sway_amp = 0.20;
uniform float sway_speed = 0.50;
uniform float current = 0.40;
uniform float caustic_strength = 0.50;
uniform float glow = 0.45;

varying vec3 world_pos;
varying vec4 inst;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 ic = INSTANCE_CUSTOM;
	inst = ic;
	float k = VERTEX.y * VERTEX.y;
	float t = TIME * sway_speed + ic.x;
	VERTEX.x += sin(t * 1.70) * sway_amp * ic.y * k;
	VERTEX.z += cos(t * 1.23 + 1.1) * sway_amp * 0.8 * ic.y * k;
	VERTEX.x += sin(TIME * 0.19 + wp.z * 0.12) * current * k;
	VERTEX.z += cos(TIME * 0.14 + wp.x * 0.09) * current * 0.6 * k;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float g = COLOR.r;
	vec3 leaf = mix(color_deep, color_tip, g);
	leaf = mix(leaf, color_alt, clamp(inst.z, 0.0, 1.0) * g * 0.85);

	float c = caustic_web(world_pos.xz * 1.80, TIME);
	ALBEDO = leaf + caustic_color * c * caustic_strength * (0.25 + g);
	EMISSION = leaf * COLOR.a * glow + caustic_color * c * 0.10;
	ROUGHNESS = 0.55;
	METALLIC = 0.0;
	SPECULAR = 0.35;
}
