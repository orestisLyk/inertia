shader_type sky;

uniform vec3 top_color : source_color = vec3(0.01, 0.01, 0.05);
uniform vec3 horizon_color : source_color = vec3(0.08, 0.06, 0.18);
uniform vec3 bottom_color : source_color = vec3(0.03, 0.04, 0.08);
uniform float star_density : hint_range(0.9, 1.0) = 0.985;
uniform float star_scale = 70.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 color;
	if (dir.y >= 0.0) {
		color = mix(horizon_color, top_color, pow(clamp(dir.y, 0.0, 1.0), 0.5));
		vec3 p = dir * star_scale;
		vec3 cell = floor(p);
		float chance = hash(cell);
		float dist = length(fract(p) - 0.5);
		float twinkle = 0.5 + 0.5 * hash(cell + 7.0);
		float star = step(star_density, chance) * smoothstep(0.3, 0.0, dist) * twinkle;
		color += vec3(star) * smoothstep(0.0, 0.15, dir.y);
	} else {
		color = mix(horizon_color, bottom_color, clamp(-dir.y * 3.0, 0.0, 1.0));
	}
	COLOR = color;
}
