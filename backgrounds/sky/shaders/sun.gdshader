// The Sun's disc and the glow around it, on one additive quad.
//
// The disc's radius arrives as `core`, the fraction of this quad's radius it
// covers - computed on the CPU out of the Sun's distance that day, so the size
// stays an ephemeris quantity instead of a constant in here. The glow is the
// same quad's falloff, and the environment's glow (sky.gd) blooms both.
//
// The horizon is taken from the fragment's own world position, the way the star
// field does it: whatever is under the ground is under the ground, so the Sun is
// cut by the horizon exactly where the horizon is drawn, and the air it is seen
// through thickens as it goes down.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled,
		fog_disabled;

// hdr: the core is meant to sit over the glow threshold, the halo well under it
uniform float core = 0.067;
uniform float core_brightness = 9.0;
uniform float halo_brightness = 0.9;
uniform vec3 disc_colour : source_color = vec3(1.0, 0.96, 0.90);
uniform vec3 sunset_colour : source_color = vec3(1.0, 0.42, 0.12);
// the altitude (its sine) the low-Sun reddening reaches up to
uniform float reddening = 0.055;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// the ground is opaque and the horizon is where it is
	if (world_position.y <= 0.0) {
		discard;
	}
	float radius = length(UV - vec2(0.5)) * 2.0;
	if (radius > 1.0) {
		discard;
	}
	float altitude = normalize(world_position).y;
	// one airmass more at the horizon: the disc loses its blue and the glow with
	// it, which is what a setting Sun looks like
	float thick = exp(-max(altitude, 0.0) / reddening);
	vec3 tint = mix(disc_colour, sunset_colour, thick);
	float disc = 1.0 - smoothstep(core * 0.86, core, radius);
	float wide = pow(1.0 - radius, 3.0);
	float tight = exp(-radius / (core * 1.6));
	ALBEDO = tint * (disc * core_brightness
			+ (wide + tight * 1.6) * halo_brightness);
}
