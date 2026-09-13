shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D source_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_texture : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.9373, 0.4314, 0.8980, 1.0);
uniform float opacity = 1.0;
uniform float phase = 0.0;
uniform bool use_mask = false;
void fragment() {
	vec4 texel = texture(source_texture, UV);
	float mask = 1.0;
	if (use_mask) {
		vec2 p = UV - 0.5;
		vec2 uv = mat2(vec2(cos(phase), -sin(phase)), vec2(sin(phase), cos(phase))) * p + 0.5;
		mask = texture(mask_texture, uv).r;
	}
	ALBEDO = texel.rgb * tint.rgb;
	ALPHA = texel.a * tint.a * opacity * mask;
}
