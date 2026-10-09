shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform sampler2D source_texture : repeat_enable, filter_linear;
void fragment() {
 vec4 lit = texture(source_texture, UV) * COLOR;
 ALBEDO = OUTPUT_IS_SRGB ? lit.rgb : mix(lit.rgb/12.92,pow((lit.rgb+vec3(0.055))/1.055,vec3(2.4)),step(vec3(0.04045),lit.rgb));
 ALPHA = clamp(lit.a,0.0,1.0);
}
