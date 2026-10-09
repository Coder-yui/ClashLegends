shader_type canvas_item;
render_mode blend_add;
uniform vec2 atlas_div = vec2(3.0, 2.0);
uniform vec2 frame_cell = vec2(0.0);
uniform vec2 uv_scroll = vec2(2.0, 0.0);
uniform float source_age = 0.0;
uniform float birth_u = 0.0;
uniform float alpha_ref = 0.235294;
uniform float opacity = 1.0;
void fragment() {
	vec2 source_uv = (fract(UV + vec2(uv_scroll.y * source_age, birth_u + uv_scroll.x * source_age)) + frame_cell) / atlas_div;
	vec4 texel = texture(TEXTURE, source_uv);
	if (texel.a * opacity < alpha_ref) discard;
	// 原版默认 pass0 为纯加法；透明度曲线参与 alphaRef 裁剪。
	COLOR = vec4(texel.rgb, 1.0);
}
