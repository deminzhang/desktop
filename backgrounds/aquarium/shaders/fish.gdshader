// Fish: lateral body wave driven per instance, vertex colour albedo with the
// alpha channel used as an emissive mask (neon stripes).
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float sway_amp = 0.085;
uniform float beat_rate = 1.0;
uniform float emission_scale = 0.55;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);

varying vec4 inst;

void vertex() {
	vec4 ic = INSTANCE_CUSTOM; // x phase, y beat rate, z tint shift, w tail gain
	inst = ic;
	float t = clamp(VERTEX.z + 0.5, 0.0, 1.0); // 0 nose .. 1 tail
	float k = t * t;
	float ph = ic.x + TIME * ic.y * beat_rate * 6.2831853;
	VERTEX.x += sin(ph) * sway_amp * k * (1.0 + ic.w);
	VERTEX.y += cos(ph) * 0.010 * k;
}

void fragment() {
	vec3 c = COLOR.rgb * tint;
	c = mix(c, c * vec3(1.10, 1.02, 0.90), clamp(inst.z, 0.0, 1.0));
	ALBEDO = c;
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	EMISSION = c * COLOR.a * emission_scale + c * f * 0.10;
	ROUGHNESS = 0.42;
	METALLIC = 0.05;
	SPECULAR = 0.40;
}
