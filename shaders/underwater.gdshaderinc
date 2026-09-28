// Shared underwater helpers. Include from spatial shaders with
//   #include "res://shaders/underwater.gdshaderinc"

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm2(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// Animated caustic web in world XZ. Returns 0..1 with bright thin filaments.
float caustic_web(vec2 p, float t) {
	float v = 0.0;
	v += sin(p.x * 1.63 + t * 0.52);
	v += sin(p.y * 2.11 - t * 0.43);
	v += sin((p.x + p.y) * 1.27 + t * 0.71);
	v += sin((p.x - p.y) * 1.83 - t * 0.31);
	vec2 c = vec2(sin(t * 0.19) * 3.0, cos(t * 0.14) * 3.0);
	v += sin(length(p - c) * 2.7 - t * 0.9);
	float w = 1.0 - abs(v * 0.185);
	return pow(clamp(w, 0.0, 1.0), 6.0);
}

// Dune height field. Mirrored by Aquarium.dune_height() in GDScript so props
// can be planted exactly on the sand.
float dune_height(vec2 p) {
	return 0.22 * sin(p.x * 0.31) * cos(p.y * 0.27)
		+ 0.14 * sin((p.x + p.y * 0.7) * 0.53 + 1.7)
		+ 0.07 * cos((p.x * 0.8 - p.y) * 1.13 + 0.4);
}

// Water surface waves: height plus analytic gradient for the normal.
void water_waves(vec2 p, float t, out float h, out vec2 grad) {
	h = 0.0;
	grad = vec2(0.0);
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float ang = fi * 1.71 + 0.55;
		vec2 dir = vec2(cos(ang), sin(ang));
		float freq = 0.42 + fi * 0.33;
		float amp = 0.062 / (1.0 + fi * 0.6);
		float spd = 0.9 + fi * 0.28;
		float phase = dot(p, dir) * freq + t * spd;
		h += amp * sin(phase);
		grad += dir * (amp * freq * cos(phase));
	}
}

vec3 water_normal(vec2 p, float t) {
	float h;
	vec2 g;
	water_waves(p, t, h, g);
	return normalize(vec3(-g.x, 1.0, -g.y));
}
