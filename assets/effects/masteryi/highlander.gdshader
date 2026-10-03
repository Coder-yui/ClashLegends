shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float phase = 0.0;
void fragment() {
	float core = pow(max(0.0, 1.0 - abs(UV.y * 2.0 - 1.0)), 1.4);
	float ends = smoothstep(0.0, 0.09, UV.x) * pow(1.0 - UV.x, 0.65);
	float flow = 0.65 + 0.35 * sin(UV.x * 18.0 - phase * 13.0);
	ALBEDO = mix(vec3(1.0, 0.63, 0.05), vec3(1.0, 0.94, 0.36), core);
	ALPHA = core * ends * flow * min(phase * 8.0, 1.0) * 1.0;
}
