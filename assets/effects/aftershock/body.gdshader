shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D source_texture : repeat_enable;
uniform sampler2D reflection_texture;
uniform float strength = 0.0;
uniform vec4 source_tint = vec4(1.0);
uniform vec4 source_uv = vec4(1.0, 1.0, 0.0, 0.0);
void vertex() { VERTEX += NORMAL * 0.002; }
void fragment() {
	vec4 texel = texture(source_texture, UV * source_uv.xy + source_uv.zw);
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	// 原 AttachedMesh REFLECTIVE：白色立方体，原始反射参数与采样色/UV。
	float opacity = mix(-0.5, 2.0, 1.0 - pow(facing, 0.1));
	vec3 reflection = texture(reflection_texture, vec2(0.5)).rgb * opacity * mix(vec3(1.0), vec3(0.2901961, 1.0, 0.39607844), opacity);
	vec3 lit = clamp((texel.rgb + reflection * texel.a) * source_tint.rgb, vec3(0.0), vec3(1.0));
	ALBEDO = OUTPUT_IS_SRGB ? lit : mix(lit / 12.92, pow((lit + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), lit));
	ALPHA = strength * texel.a * source_tint.a;
}
