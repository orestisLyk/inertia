shader_type spatial;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;
uniform float distortion = 0.0;
uniform float noise_scale = 2.0;
// Accumulated by the script, so changing the speed never makes the noise jump.
uniform float fx_time = 0.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash(i + vec3(0.0, 0.0, 0.0)), hash(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

void vertex() {
	// Offset depends only on the vertex position, so faces sharing a corner never tear apart.
	vec3 p = VERTEX * noise_scale;
	vec3 d = vec3(
		value_noise(p + vec3(0.0, fx_time, 0.0)),
		value_noise(p + vec3(17.1, fx_time, 5.3)),
		value_noise(p + vec3(3.7, 9.2, fx_time))
	) - 0.5;
	VERTEX += d * 2.0 * distortion;
}

void fragment() {
	vec3 base = albedo.rgb;
	if (use_texture) {
		base *= texture(albedo_texture, UV).rgb;
	}
	ALBEDO = base;
}
