// Aquarium sand bed: dunes, ripples, grain, caustics.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/underwater.gdshaderinc"

uniform vec3 sand_warm : source_color = vec3(0.54, 0.47, 0.35);
uniform vec3 sand_cool : source_color = vec3(0.27, 0.25, 0.20);
uniform vec3 caustic_color : source_color = vec3(0.72, 0.94, 1.00);
uniform float caustic_strength = 0.80;
uniform float caustic_scale = 2.20;
uniform float grain_scale = 55.0;
uniform float ripple_strength = 0.30;
uniform float time_scale = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

vec3 dune_normal(vec2 p) {
	float e = 0.08;
	float hx = dune_height(p + vec2(e, 0.0)) - dune_height(p - vec2(e, 0.0));
	float hz = dune_height(p + vec2(0.0, e)) - dune_height(p - vec2(0.0, e));
	return normalize(vec3(-hx / (2.0 * e), 1.0, -hz / (2.0 * e)));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += dune_height(world_pos.xz);
	world_normal = dune_normal(world_pos.xz);
}

void fragment() {
	vec2 p = world_pos.xz;

	float ripple = sin(p.x * 5.1 + sin(p.y * 0.7) * 1.4) * 0.5 + 0.5;
	float grain = vnoise(p * grain_scale);
	float mottle = fbm2(p * 0.6);

	vec3 albedo = mix(sand_cool, sand_warm, mottle * 0.75 + 0.25);
	albedo *= 0.78 + 0.34 * grain;
	albedo *= 1.0 - 0.10 * ripple;

	// ripple ridges along +x perturb the surface normal
	float dn = (ripple - 0.5) * ripple_strength + (grain - 0.5) * 0.30;
	vec3 wn = normalize(world_normal + vec3(dn * 0.55, 0.0, dn * 0.18));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	float c = caustic_web(p * caustic_scale, TIME * time_scale);
	ALBEDO = albedo + caustic_color * c * caustic_strength;
	EMISSION = caustic_color * c * 0.22;
	ROUGHNESS = mix(0.72, 0.95, grain);
	METALLIC = 0.0;
	SPECULAR = 0.28;
}
