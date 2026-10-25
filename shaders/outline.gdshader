// Inverted-hull cartoon outline, used as a next_pass on toon materials.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform float thickness = 0.02;
// Boxes have split normals, so push corners outward instead of along the normal.
uniform bool box_mode = false;

void vertex() {
	if (box_mode) {
		VERTEX += sign(VERTEX) * thickness;
	} else {
		VERTEX += NORMAL * thickness;
	}
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
