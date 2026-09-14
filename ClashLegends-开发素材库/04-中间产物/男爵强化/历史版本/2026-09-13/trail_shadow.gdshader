shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D trail_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float elapsed = 0.0;
void fragment() {
	vec4 texel = texture(trail_texture, UV + vec2(0.33 - 0.5 * elapsed, 0.0));
	ALBEDO = texel.rgb * vec3(0.34117648, 0.02745098, 0.4745098);
	ALPHA = texel.a * COLOR.a * 0.49019608;
}
