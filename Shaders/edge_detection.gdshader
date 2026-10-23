shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_nearest;
uniform vec4 edge_color : source_color = vec4(0.025, 0.025, 0.025, 1.0);
uniform float depth_threshold : hint_range(0.001, 1.0) = 0.05;
uniform float normal_threshold : hint_range(0.01, 1.0) = 0.2;

void vertex() {
	// Cover the whole screen regardless of where the quad sits in the world.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_projection) {
	float depth = texture(depth_texture, uv).r;
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return -view.z / view.w;
}

void fragment() {
	vec2 texel = 1.0 / VIEWPORT_SIZE;
	vec3 center_normal = texture(normal_texture, SCREEN_UV).xyz * 2.0 - 1.0;
	float center_depth = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float edge = 0.0;

	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			if (x == 0 && y == 0) {
				continue;
			}
			vec2 uv = SCREEN_UV + vec2(float(x), float(y)) * texel;
			float sample_depth = linear_depth(uv, INV_PROJECTION_MATRIX);
			vec3 sample_normal = texture(normal_texture, uv).xyz * 2.0 - 1.0;
			// Scale by distance so far-away surfaces don't produce false edges.
			float depth_edge = step(depth_threshold * center_depth, abs(center_depth - sample_depth));
			float normal_edge = step(normal_threshold, 1.0 - dot(center_normal, sample_normal));
			edge = max(edge, max(depth_edge, normal_edge));
		}
	}

	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	ALBEDO = mix(scene, edge_color.rgb, edge);
}
