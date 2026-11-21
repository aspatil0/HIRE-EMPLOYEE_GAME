shader_type canvas_item;
render_mode blend_mul, unshaded;
// Scene lighting as a full-screen multiply pass.
// Each light: lights[i] = (x, y, radius, intensity) in design pixels,
// light_colors[i] = (r, g, b, vertical_squash). Squash < 1 flattens the pool
// into an ellipse (e.g. lamp light spreading across a desk).

uniform vec3 ambient = vec3(0.14, 0.16, 0.22);
uniform int light_count = 0;
uniform vec4 lights[10];
uniform vec4 light_colors[10];

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 l = ambient;
	for (int i = 0; i < 10; i++) {
		if (i >= light_count) {
			break;
		}
		vec4 L = lights[i];
		vec4 C = light_colors[i];
		vec2 d = local_pos - L.xy;
		d.y /= max(C.a, 0.05);
		float f = clamp(1.0 - length(d) / max(L.z, 1.0), 0.0, 1.0);
		f = f * f * (3.0 - 2.0 * f);
		l += C.rgb * L.w * f;
	}
	COLOR = vec4(min(l, vec3(1.0)), 1.0);
}
