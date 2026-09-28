// Wet stone: mottled boulders and the tank's back wall, with caustics catching
// the upward faces. `relief` displaces the surface so a flat plane can serve as
// a rocky backdrop.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/underwater.gdshaderinc"

uniform vec3 stone_dark : source_color = vec3(0.26, 0.28, 0.25);
uniform vec3 stone_light : source_color = vec3(0.52, 0.53, 0.46);
uniform vec3 algae : source_color = vec3(0.20, 0.36, 0.24);
uniform vec3 caustic_color : source_color = vec3(0.70, 0.92, 1.00);
uniform float caustic_strength = 0.45;
uniform float caustic_scale = 2.00;
uniform float wetness = 0.55;
uniform float relief = 0.0;
uniform float noise_scale = 1.0;
uniform float vertical_fade = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

float relief_field(vec2 p) {
	return fbm2(p * noise_scale) + 0.5 * fbm2(p * noise_scale * 3.7 + 11.0);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (relief > 0.0) {
		vec2 p = world_pos.xy;
		float h = relief_field(p);
		float e = 0.12;
		float hx = relief_field(p + vec2(e, 0.0));
		float hy = relief_field(p + vec2(0.0, e));
		VERTEX += NORMAL * (h - 0.78) * relief;
		world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 n = normalize(vec3(-(hx - h) / e * relief, -(hy - h) / e * relief, 1.0));
		world_normal = normalize((MODEL_MATRIX * vec4(n, 0.0)).xyz);
	}
}

void fragment() {
	vec2 p = world_pos.xz;
	float mottle = fbm2(p * 1.3 + world_pos.y * 0.7);
	float speck = vnoise(p * 26.0);

	vec3 albedo = mix(stone_dark, stone_light, mottle * 0.8 + 0.2 * speck);
	// algae film on upward faces
	float up = clamp(world_normal.y, 0.0, 1.0);
	albedo = mix(albedo, algae, up * up * mottle * 0.7);
	if (vertical_fade > 0.0) {
		// backdrop only: settle into shadow toward the sand line
		albedo *= mix(0.45, 1.20, smoothstep(-1.9, 1.4, world_pos.y)) * vertical_fade
			+ (1.0 - vertical_fade);
	}

	float c = caustic_web(p * caustic_scale, TIME);
	ALBEDO = albedo + caustic_color * c * caustic_strength * (0.35 + up * 0.65);
	EMISSION = caustic_color * c * 0.18 * up;
	ROUGHNESS = mix(0.45, 0.85, mottle) * (1.0 - wetness * 0.35);
	METALLIC = 0.0;
	SPECULAR = 0.4;
}
