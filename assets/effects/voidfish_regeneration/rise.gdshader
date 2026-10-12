shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float opacity = 0.0;
uniform float phase = 0.0;
uniform float mirror_sign = 1.0;
void vertex() {
	// Billboard keeps each rising wisp readable from either team's camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float bend = sin(UV.y * 5.0 + phase * 5.0) * 0.12 * mirror_sign;
	float ribbon = pow(max(0.0, 1.0 - abs(UV.x - 0.5 - bend) * 2.5), 2.0);
	float ends = smoothstep(0.0, 0.22, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	ALBEDO = mix(vec3(0.36, 0.035, 0.85), vec3(0.72, 0.20, 1.0), ribbon);
	ALPHA = ribbon * ends * opacity;
}
