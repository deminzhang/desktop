// Stars: one quad per catalogue star, built facing the sphere's centre.
//
// Not billboarded in the shader: every quad is already perpendicular to its own
// direction, and the camera never leaves the centre of the sphere, so the whole
// field is static geometry on SkyRoot - which is exactly what lets the sky idle
// between frames (计划 §7).
//
// Per star: COLOR is the star's colour times its magnitude brightness, UV is the
// quad corner for the disc falloff, UV2 carries (twinkle phase, twinkle amount).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float twinkle_rate = 1.7;
// sine of the altitude over which stars fade into the horizon
uniform float horizon_fade = 0.035;
// how much of the night is left: 1 at night, 0 with the Sun up (astro.gd's
// daylight() inverted, set by sky.gd)
uniform float night = 1.0;
// the sphere the quads are pinned to, and the scale their size is drawn at:
// the sky can be zoomed (CameraRig), and a star has to stay a point - the quads
// are built once at the sky's own 60 deg field, so this is that field over the
// one in use
uniform float sphere_radius = 480.0;
uniform float size_scale = 1.0;

varying vec3 star_colour;
varying float star_alpha;
varying float altitude;

void vertex() {
	// each quad is symmetric about its own direction on the sphere, so the point
	// to grow it from is the radius along that direction
	vec3 base = normalize(VERTEX) * sphere_radius;
	VERTEX = base + (VERTEX - base) * size_scale;
	star_colour = COLOR.rgb;
	float phase = UV2.x;
	float amp = UV2.y;
	star_alpha = 1.0 - amp * 0.5 * (1.0 + sin(TIME * twinkle_rate + phase * 6.2831853));
	// 地平蒙版: the sphere turns with the sky, so the observer's horizon is a
	// world-space test - whatever is below it is under the ground.
	altitude = normalize((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz).y;
}

void fragment() {
	if (altitude <= 0.0) {
		discard;
	}
	float disc = smoothstep(1.0, 0.12, length(UV - vec2(0.5)) * 2.0);
	ALBEDO = star_colour * star_alpha * night;
	ALPHA = disc * smoothstep(0.0, horizon_fade, altitude);
}
