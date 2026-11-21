shader_type canvas_item;
// Cinematic finishing pass: animated film grain, vignette and a faint
// exposure flicker. Drawn as a mix-blended overlay above the scene.

uniform vec2 canvas_size = vec2(1920.0, 1080.0);
uniform float grain_amount : hint_range(0.0, 0.3) = 0.07;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.6;
uniform float vignette_inner : hint_range(0.0, 1.0) = 0.38;
uniform float flicker : hint_range(0.0, 0.2) = 0.025;
uniform float grain_fps = 24.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = local_pos / canvas_size;
	float frame = floor(TIME * grain_fps);
	float n = hash(floor(local_pos * 0.75) + frame * 17.13) - 0.5;

	vec2 c = (uv - 0.5) * vec2(canvas_size.x / canvas_size.y, 1.0);
	float vig = smoothstep(vignette_inner, 1.05, length(c)) * vignette_strength;
	float fl = (hash(vec2(frame, 3.1)) - 0.5) * flicker;

	float g = abs(n) * grain_amount;
	float shade = clamp(vig + max(fl, 0.0), 0.0, 1.0);
	float a = shade + g * (1.0 - shade);
	vec3 rgb = (vec3(step(0.0, n)) * g * (1.0 - shade)) / max(a, 0.0001);
	COLOR = vec4(rgb, a);
}
