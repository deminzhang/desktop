// The Moon: a sphere the Sun lights, so its phase is geometry rather than a
// painted crescent - the terminator's ellipse, how much of the disc is lit, and
// which limb faces the Sun all follow from the two directions.
//
// `sun_dir` is the Sun's direction in this mesh's own frame, which is the sky
// sphere's, since the node is scaled but never turned. The disc is a unit sphere
// at the origin, so a vertex's local position is its normal. Its apparent size
// is the node's scale, set from the Moon's distance on the CPU.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

uniform vec3 sun_dir = vec3(0.0, -1.0, 0.0);
uniform vec3 lit_colour : source_color = vec3(0.780, 0.760, 0.720);
uniform vec3 dark_colour : source_color = vec3(0.050, 0.050, 0.055);
// how soft the terminator is; the Moon's own is nearly a hard edge
uniform float terminator = 0.06;
uniform float maria = 0.22;

varying float sunward;
varying vec3 surface_point;
varying vec3 world_position;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

// one octave of value noise, for the maria
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

void vertex() {
	surface_point = normalize(VERTEX);
	sunward = dot(surface_point, sun_dir);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// the ground cuts the Moon the same way it cuts the Sun
	if (world_position.y <= 0.0) {
		discard;
	}
	float lit = smoothstep(-terminator, terminator, sunward);
	float mottle = 1.0 + maria * (value_noise(surface_point * 3.5) - 0.5)
			+ maria * 0.5 * (value_noise(surface_point * 9.0) - 0.5);
	ALBEDO = mix(dark_colour, lit_colour * mottle, lit);
}
