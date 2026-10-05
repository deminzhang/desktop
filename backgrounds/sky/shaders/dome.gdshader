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
// the equatorial frame and has to turn with the stars. Below the horizon the ground
// is a translucent film in three latitude layers, and the band - being the sky's own
// content - is read *through* it; the stars are not, and keep the mask they carry at
// the horizon (2026-10-14 用户: "地平线下的黑色没挡住银河", then "地平线下的黑调成半透
// ... 分个三层透度,代表三层纬度,每层变暗1/4", then "三层间改成渐变").
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, fog_disabled;

// where a vertex of the sky goes on the frame, in place of the camera's own
// rectilinear lens (the reasoning is in the include). The dome is the layer that
// has to cover the whole frame, so it is the one that leans on it hardest: the
// map's frame is wider than the lens', and the sphere behind it has a direction
// for every pixel of it.
#include "res://backgrounds/sky/shaders/sky_projection.gdshaderinc"

// night
uniform vec3 night_zenith : source_color = vec3(0.090, 0.130, 0.260);
uniform vec3 night_horizon : source_color = vec3(0.200, 0.260, 0.420);
uniform vec3 night_ground : source_color = vec3(0.050, 0.060, 0.090);
// day
// Deliberately deeper than a real noon: the star field stays on the sky all day
// (sky.gd's DAY_STAR_FLOOR), and a wall of daylight blue would swallow it. This
// is the brightest the sky is allowed to get and still be a starfield.
uniform vec3 day_zenith : source_color = vec3(0.200, 0.255, 0.420);
uniform vec3 day_horizon : source_color = vec3(0.300, 0.345, 0.450);
uniform vec3 day_ground : source_color = vec3(0.090, 0.098, 0.110);
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
// how much of the night the Milky Way keeps: the band is diffuse and a wall of
// daylight blue does not hide it the way it hides a point of light, so it goes
// much further down than the stars do (sky.gd's two floors)
uniform float band_night = 1.0;
uniform vec3 sun_world = vec3(0.0, -1.0, 0.0);   // the Sun's direction in world

// Galactic frame, in this sphere's equatorial coordinates. Left at zero length
// the band is off; the sky sets both vectors from the catalogue's frame.
uniform vec3 galactic_pole = vec3(0.0);
uniform vec3 galactic_centre = vec3(0.0);
uniform vec3 band_colour : source_color = vec3(0.62, 0.64, 0.72);
uniform float band_strength = 0.16;
uniform float band_width = 0.13;  // radians, gaussian sigma in galactic latitude
// The ground below the horizon, as 用户 asked for it on 2026-10-14: "地平线下的黑调成半透
// ... 分个三层透度,代表三层纬度,每层变暗1/4". The ground is not a slab but a translucent
// film in three latitude layers, each `ground_step` more opaque than the one above it, so
// the sky's own content - its gradient and the Milky Way - carries on underneath and is
// read *through* it. 6 deg of latitude a layer because that is what the ground the *frame*
// shows is made of: at the opening 42.5/96 framing (--sky-view=180,42.5 --sky-fov=96) the
// frame's own ground runs 0..-26.8 deg, deepest at the two bottom corners, so the three
// layers tile the top 18 deg of it and what is left below - the corners - stays at the
// third one's opacity, the film's own floor; a view dropped onto the horizon (180,0)
// reaches the third layer sooner and keeps it (its ground runs to -40).
uniform float ground_span = 0.10472;   // radians of latitude per layer, 6 deg
uniform float ground_step = 0.25;      // how much more opaque each one is
// Where the layers meet (用户 2026-10-14, right after seeing the first cut: "三层间改成
// 渐变"): a seam is not an edge but a gradient, taken `ground_blend` of latitude either
// side of it. A quarter of the span is what is set here - at half the span the plateaus
// are gone and the film is one continuous ramp, at 0 it is back to three hard bands.
uniform float ground_blend = 0.0131;   // radians either side of a seam, 0.75 deg

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

// `dir` must be a unit vector: the latitude below is an asin of its dot with the
// pole, and the bulge a power of its dot with the centre. Handed a position - the
// vertex itself, 500 units out - the first collapses the band to a hairline and
// the second raises 500 to the 2.5 (the sky's own flavour of a units bug).
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
	POSITION = SKY_CLIP(VIEW_MATRIX * MODEL_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	float altitude = clamp(world_dir.y, -1.0, 1.0);
	float down = pow(max(-altitude, 0.0), ground_curve);
	// How much of the sky the ground hides here: nothing above the horizon, a quarter for
	// the film's first layer, and another quarter at each seam below it. The seams are
	// gradients `ground_blend` wide either side rather than edges (用户 2026-10-14:
	// "三层间改成渐变"), so the film reads as one sheet lying in three layers: the two
	// smoothsteps are the seam at -1 span and the one at -2, and there is no third - the
	// last layer is what is left at the bottom.
	float seam = ground_blend / ground_span;
	float depth = -altitude / ground_span;
	float veil = altitude >= 0.0
			? 0.0
			: ground_step * (1.0 + smoothstep(1.0 - seam, 1.0 + seam, depth)
					+ smoothstep(2.0 - seam, 2.0 + seam, depth));
	// The sky's own gradient and the ground's own tone, both taken at this altitude. The
	// sky's runs off the altitude's *size*, because it is the same sky carried on below
	// the horizon (`reach` is the `up` of the old two-palette form); above the horizon
	// only it is drawn (`veil` is 0 there, and the two forms are the same picture), and
	// below it the ground's tone comes in over it layer by layer.
	float reach = pow(abs(altitude), sky_curve);
	vec3 unlit = mix(mix(night_horizon, night_zenith, reach),
			mix(night_horizon, night_ground, down), veil);
	vec3 lit = mix(mix(day_horizon, day_zenith, reach),
			mix(day_horizon, day_ground, down), veil);
	vec3 colour = mix(unlit, lit, day);

	// the glow sits on the Sun's side of the sky, and only while it is low
	vec3 level = vec3(world_dir.x, 0.0, world_dir.z);
	vec3 sun_level = vec3(sun_world.x, 0.0, sun_world.z);
	if (length(level) > 1.0e-4 && length(sun_level) > 1.0e-4) {
		float side = max(dot(normalize(level), normalize(sun_level)), 0.0);
		float band = exp(-pow(max(altitude, 0.0) / twilight_height, 2.0));
		colour += twilight_colour * (twilight * band * pow(side, 3.0));
	}

	// the Milky Way goes through the same film: it is the sky's own content, so it is
	// read *through* the layers at three quarters, a half, a quarter of its strength
	// rather than cut off at the horizon (用户 2026-10-14). The stars do not come
	// through - a point of light is put out by the least haze, and they keep their own
	// 2 deg mask (star.gdshader, line.gdshader).
	ALBEDO = colour + milky_way(normalize(local_pos)) * band_night * (1.0 - veil);
}
