shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 edge_tint : source_color = vec3(0.25, 0.65, 1.0);
void fragment() {
	vec2 at = (UV - vec2(0.5)) * 2.04;
	float radius = length(at);
	float mask = 1.0 - smoothstep(1.0 - 1.0 / 160.0, 1.0, radius);
	// 同色的低频流动覆盖整个圆面；不做亮度脉冲或强烈发光。
	float flow = sin(at.x * 10.0 + TIME * 0.35 + sin(at.y * 9.0 - TIME * 0.23));
	float weave = sin(at.y * 15.0 + at.x * 7.0 - TIME * 0.28);
	float field = mask * (0.09 + 0.03 * flow + 0.02 * weave);
	// 按BattleEffects2D常规范围边界的1.8战场像素线宽，透明度由0.72降为0.55。
	float distance_px = abs(radius - 1.0) * 160.0;
	float aa = max(fwidth(radius) * 160.0, 0.01);
	float edge = (1.0 - smoothstep(0.9 - aa * 0.5, 0.9 + aa * 0.5, distance_px)) * 0.55;
	vec3 shared_tint = vec3(0.58, 0.67, 0.61);
	ALPHA = field + edge;
	ALBEDO = mix(shared_tint, edge_tint, edge / max(ALPHA, 0.0001));
}
