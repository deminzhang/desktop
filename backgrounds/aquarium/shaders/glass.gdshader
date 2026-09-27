// Tank glass, seen from inside: faint tint, smudges, and a grazing-angle
// sheen that mirrors the lit interior instead of the dark room beyond.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://backgrounds/aquarium/shaders/underwater.gdshaderinc"

uniform vec3 tint : source_color = vec3(0.34, 0.72, 0.80);
uniform vec3 sheen : source_color = vec3(0.42, 0.72, 0.86);
uniform float base_opacity = 0.040;
uniform float rim = 0.42;
uniform float smudge = 0.35;

void fragment() {
	float f = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 3.0);
	float s = fbm2(UV * vec2(2.5, 11.0));
	vec3 refl = mix(tint * 0.35, sheen, f);
	ALBEDO = refl * (0.35 + 0.50 * s);
	ROUGHNESS = mix(0.03, 0.30, s);
	METALLIC = 0.0;
	SPECULAR = 0.90;
	ALPHA = clamp(base_opacity + f * rim + s * smudge * 0.05, 0.0, 0.85);
	EMISSION = sheen * f * f * 0.45;
}
