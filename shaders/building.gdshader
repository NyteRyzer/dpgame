// Flat cartoon facade with procedural windows that light up at night.
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

global uniform float night_factor;

uniform vec4 wall_color : source_color = vec4(0.6, 0.6, 0.65, 1.0);
uniform vec4 window_color : source_color = vec4(0.16, 0.22, 0.32, 1.0);
uniform vec4 lit_color : source_color = vec4(1.0, 0.86, 0.5, 1.0);
uniform vec4 trim_color : source_color = vec4(0.3, 0.3, 0.34, 1.0);
uniform vec2 window_spacing = vec2(3.0, 3.6);
uniform bool windows = true;

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = wall_color.rgb;
	vec3 em = vec3(0.0);
	if (abs(wnorm.y) > 0.5) {
		col = trim_color.rgb;
	} else if (windows) {
		float u = abs(wnorm.x) > 0.5 ? wpos.z : wpos.x;
		vec2 g = vec2(u, wpos.y - 0.6) / window_spacing;
		vec2 f = fract(g);
		if (f.x > 0.22 && f.x < 0.78 && f.y > 0.28 && f.y < 0.78 && wpos.y > 1.2) {
			float h = hash(floor(g) + floor(wpos.xz * 0.01));
			col = window_color.rgb;
			if (h < 0.15 + 0.5 * night_factor) {
				em = lit_color.rgb * (0.25 + 1.6 * night_factor);
				col = mix(col, lit_color.rgb, 0.4 * night_factor);
			}
		}
		// Cartoon floor bands.
		if (fract(wpos.y / window_spacing.y) < 0.05) {
			col *= 0.8;
		}
	}
	ALBEDO = col;
	EMISSION = em;
}
