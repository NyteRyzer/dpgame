// Animated swirling ectoplasm disc for portals and rifts.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 color_a : source_color = vec4(0.2, 1.0, 0.45, 1.0);
uniform vec4 color_b : source_color = vec4(0.05, 0.35, 0.15, 1.0);
uniform float speed = 1.5;
uniform float intensity = 1.6;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float a = atan(uv.y, uv.x);
	float s = sin(a * 6.0 + r * 14.0 - TIME * speed * 3.0) * 0.5 + 0.5;
	float rim = smoothstep(1.0, 0.82, r);
	vec3 col = mix(color_b.rgb, color_a.rgb, s) * (1.3 - r);
	ALBEDO = col * intensity * rim;
	ALPHA = rim;
}
