shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D ice_mask;
uniform vec4 rim_color : source_color = vec4(0.15, 0.55, 1.0, 1.0);
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float mask = texture(ice_mask, UV).r;
	float cracks = 1.0 - smoothstep(0.48, 0.74, mask);
	float rim = smoothstep(0.93, 0.975, r) * (1.0 - smoothstep(0.985, 1.0, r));
	float edge = 1.0 - smoothstep(0.94, 1.0, r);
	vec3 ice = mix(vec3(0.03, 0.24, 0.50), vec3(0.55, 0.88, 1.0), smoothstep(0.4, 1.0, mask));
	ALBEDO = mix(ice, rim_color.rgb, rim);
	ALPHA = max(edge * (0.35 + cracks * 0.20), rim * 0.9);
}
