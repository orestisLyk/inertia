shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform float width = 0.04;

void vertex() {
	// Inflate the hull outward per axis, so box corners stay sharp and the outline has a uniform width.
	VERTEX += sign(VERTEX) * width;
}

void fragment() {
	ALBEDO = vec3(1.0);
}
