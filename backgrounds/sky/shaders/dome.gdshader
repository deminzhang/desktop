// Inner surface of the celestial sphere: the night-sky gradient, the day sky it
// crosses to as the Sun rises, the glow that hugs the horizon while the Sun is
// low, and the Milky Way.
//
// Painted on real geometry rather than left to a procedural skybox, because a
// scene whose only content is an Environment background does not present into
// the wallpaper window once the host has reparented it into the desktop's
// WorkerW layer (计划 §2.2 V3). The sphere also gives the star field a horizon
// and the compass something to hang the horizon ring on.
//
// The horizon comes from the world, not from this mesh's own frame: the sphere
// turns with the sky (SkyRoot), so what is up for the observer is a direction in
// the world - taken from the model matrix per vertex, the way the star shader
// takes it. The Milky Way keeps using the local position, because it is fixed to
// the equatorial frame and has to turn with the stars.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, fog_disabled;

// night
uniform vec3 night_zenith : source_color = vec3(0.090, 0.130, 0.260);
uniform vec3 night_horizon : source_color = vec3(0.200, 0.260, 0.420);
uniform vec3 night_ground : source_color = vec3(0.050, 0.060, 0.090);
// day
uniform vec3 day_zenith : source_color = vec3(0.170, 0.360, 0.720);
uniform vec3 day_horizon : source_color = vec3(0.620, 0.740, 0.880);
uniform vec3 day_ground : source_color = vec3(0.150, 0.160, 0.170);
uniform vec3 twilight_colour : source_color = vec3(0.900, 0.380, 0.140);

// how tightly the gradients hug the horizon in each half
uniform float sky_curve = 0.12;
uniform float ground_curve = 0.05;
// how high up the twilight glow reaches, as the sine of the altitude
uniform float twilight_height = 0.17;

// where the light is: handed in by sky.gd on every time step, from the Sun's
// altitude there (astro.gd's daylight() and twilight())
uniform float day = 0.0;         // 0 night .. 1 day
uniform float twilight = 0.0;    // the glow's strength
uniform vec3 sun_world = vec3(0.0, -1.0, 0.0);   // the Sun's direction in world

// Galactic frame, in this sphere's equatorial coordinates. Left at zero length
// the band is off; the sky sets both vectors from the catalogue's frame.
uniform vec3 galactic_pole = vec3(0.0);
uniform vec3 galactic_centre = vec3(0.0);
uniform vec3 band_colour : source_color = vec3(0.62, 0.64, 0.72);
uniform float band_strength = 0.16;
uniform float band_width = 0.13;  // radians, gaussian sigma in galactic latitude

varying vec3 local_pos;
varying vec3 world_dir;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

// one octave of value noise: enough to break the band up without a texture
float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
}

vec3 milky_way(vec3 dir) {
	if (length(galactic_pole) < 0.5 || length(galactic_centre) < 0.5) {
		return vec3(0.0);
	}
	float lat = asin(clamp(dot(dir, galactic_pole), -1.0, 1.0));
	float band = exp(-pow(lat / band_width, 2.0));
	// brighter towards the galactic centre, thinner and fainter the other way
	float central = dot(dir, galactic_centre);
	float bulge = 0.30 + 0.85 * pow(max(central, 0.0), 2.5);
	float mottle = 0.45 + 0.75 * value_noise(dir * 9.0) + 0.35 * value_noise(dir * 23.0);
	// a dust lane just off the plane, as the real one is
	float dust = 1.0 - 0.5 * exp(-pow((lat + 0.025) / (band_width * 0.28), 2.0))
			* value_noise(dir * 34.0);
	return band_colour * (band * band_strength * bulge * mottle * dust);
}

void vertex() {
	local_pos = VERTEX;
	world_dir = normalize((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	float altitude = clamp(world_dir.y, -1.0, 1.0);
	float up = pow(max(altitude, 0.0), sky_curve);
	float down = pow(max(-altitude, 0.0), ground_curve);
	vec3 night = altitude >= 0.0
			? mix(night_horizon, night_zenith, up)
			: mix(night_horizon, night_ground, down);
	vec3 lit = altitude >= 0.0
			? mix(day_horizon, day_zenith, up)
			: mix(day_horizon, day_ground, down);
	vec3 colour = mix(night, lit, day);

	// the glow sits on the Sun's side of the sky, and only while it is low
	vec3 level = vec3(world_dir.x, 0.0, world_dir.z);
	vec3 sun_level = vec3(sun_world.x, 0.0, sun_world.z);
	if (length(level) > 1.0e-4 && length(sun_level) > 1.0e-4) {
		float side = max(dot(normalize(level), normalize(sun_level)), 0.0);
		float band = exp(-pow(max(altitude, 0.0) / twilight_height, 2.0));
		colour += twilight_colour * (twilight * band * pow(side, 3.0));
	}

	ALBEDO = colour + milky_way(local_pos) * (1.0 - day);
}
