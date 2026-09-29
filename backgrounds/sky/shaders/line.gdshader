// Constellation figures and boundaries: thin ribbons lying on the celestial
// sphere, one quad per segment.
//
// Additive like the stars, so draw order between the two never matters, and with
// the same world-space horizon mask: whatever SkyRoot's rotation, nothing below
// the observer's horizon shows.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float horizon_fade = 0.035;
// how much of the night is left: 1 at night, 0 with the Sun up (set by sky.gd)
uniform float night = 1.0;
// the sphere the ribbons lie on, and the scale their width is drawn at: a
// hairline has to stay a hairline when the sky is zoomed (CameraRig), and the
// ribbons are built once at the sky's own 60 deg field
uniform float sphere_radius = 476.0;
uniform float size_scale = 1.0;

varying vec3 line_colour;
varying float altitude;

void vertex() {
	// a ribbon vertex sits on the sphere plus a tangential half-width, so the
	// point to grow the width from is the radius along its own direction
	vec3 base = normalize(VERTEX) * sphere_radius;
	VERTEX = base + (VERTEX - base) * size_scale;
	line_colour = COLOR.rgb;
	altitude = normalize((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz).y;
}

void fragment() {
	if (altitude <= 0.0) {
		discard;
	}
	ALBEDO = line_colour * night;
	ALPHA = smoothstep(0.0, horizon_fade, altitude);
}
