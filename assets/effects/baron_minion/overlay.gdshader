shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;
uniform float elapsed = 0.0;
uniform float strength = 0.0;
varying vec3 surface_position;
void vertex() {
	surface_position = VERTEX;
	VERTEX += NORMAL * 0.08;
}
void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.6);
	float flow = sin(surface_position.y * 0.14 - elapsed * 3.0 + sin(surface_position.x * 0.12 + elapsed) * 1.8) * 0.5 + 0.5;
	float pulse = 0.92 + 0.08 * sin(elapsed * 2.4);
	ALBEDO = mix(vec3(0.32, 0.035, 0.64), vec3(0.78, 0.30, 1.0), rim * 0.75 + flow * 0.25);
	ALPHA = strength * pulse * (0.24 + rim * 0.46 + flow * 0.12);
}
