shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform sampler2D overlay_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float elapsed = 0.0;
uniform float strength = 0.0;
void vertex() { VERTEX += NORMAL * 0.15; }
void fragment() {
	vec4 texel = texture(overlay_texture, UV + vec2(0.4, 0.2) * elapsed);
	ALBEDO = texel.rgb * vec3(0.83, 0.13, 1.0);
	ALPHA = texel.a * strength * 0.4;
}
