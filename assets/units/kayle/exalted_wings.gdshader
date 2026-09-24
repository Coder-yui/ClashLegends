shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform sampler2D level16_gradient : source_color, filter_linear;
void fragment() {
	vec4 base = texture(base_texture, UV);
	float lightness = dot(base.rgb, vec3(0.2126, 0.7152, 0.0722));
	// 原版16级渐变的第一行是金白色带；保留原网格、羽毛纹理明暗与透明度。
	ALBEDO = texture(level16_gradient, vec2(1.0 - lightness, 0.0625)).rgb;
	ALPHA = base.a;
}
