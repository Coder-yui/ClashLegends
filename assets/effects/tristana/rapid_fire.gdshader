shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
uniform float phase = 0.0;
varying vec3 rest_position;
void vertex() {
	rest_position = VERTEX;
	VERTEX += NORMAL * 0.008;
}
void fragment() {
	float wave = 0.5 + 0.5 * sin(rest_position.y * 32.0 + rest_position.z * 18.0 - phase * 7.0);
	float grain = sin(rest_position.x * 91.0 + phase * 3.0) * sin(rest_position.z * 83.0 - phase * 5.0);
	float embers = pow(max(grain, 0.0), 8.0);
	float pulse = 0.85 + 0.15 * sin(phase * 11.0);
	ALBEDO = mix(vec3(1.0, 0.12, 0.015), vec3(1.0, 0.65, 0.12), embers);
	ALPHA = (0.22 + 0.22 * wave + 0.5 * embers) * pulse * COLOR.a;
}
