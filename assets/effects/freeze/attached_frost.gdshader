shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// 与凝滞凹面覆盖相同的贴合/深度偏移，维持人物既有淡蓝色与透明度。
uniform vec4 frost_color : source_color = vec4(0.3, 0.7, 1.0, 0.28);
void vertex() {
    POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    POSITION.z += 0.00001 * POSITION.w;
}
void fragment() {
    ALBEDO = frost_color.rgb;
    ALPHA = frost_color.a;
}
