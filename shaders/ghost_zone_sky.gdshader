// Swirling green void of the Ghost Zone.
shader_type sky;

uniform vec3 deep_color : source_color = vec3(0.01, 0.07, 0.04);
uniform vec3 mid_color : source_color = vec3(0.05, 0.32, 0.14);
uniform vec3 swirl_color : source_color = vec3(0.25, 0.9, 0.45);
uniform vec3 violet_color : source_color = vec3(0.35, 0.1, 0.45);

void sky() {
	vec3 d = EYEDIR;
	float t = TIME * 0.05;
	float ang = atan(d.x, d.z);
	float swirl = sin(ang * 5.0 + d.y * 9.0 + t * 6.0) * 0.5 + 0.5;
	float n = sin(d.x * 7.0 + t * 3.0) * sin(d.y * 11.0 - t * 2.0) * sin(d.z * 6.0 + t);
	vec3 col = mix(deep_color, mid_color, smoothstep(-0.6, 0.8, d.y));
	col += swirl_color * smoothstep(0.55, 1.0, swirl) * 0.25;
	col = mix(col, violet_color, smoothstep(0.3, 0.9, n) * 0.5);
	float stars = step(0.9965, fract(sin(dot(floor(d * 220.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453));
	col += vec3(0.6, 1.0, 0.7) * stars;
	COLOR = col;
}
