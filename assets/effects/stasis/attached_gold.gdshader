shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// Bard Base R Gold_Avatar1: original Zhonya texture, attached mesh scale 1.01.
uniform sampler2D swirl : source_color, repeat_enable, filter_linear_mipmap;
uniform float mesh_scale = 1.01;
uniform float depth_bias = 0.0;
void vertex() {
    VERTEX *= mesh_scale;
    POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    POSITION.z += depth_bias * POSITION.w;
}
void fragment() {
    vec4 tex = texture(swirl, UV);
    ALBEDO = tex.rgb;
    ALPHA = tex.a * 0.4900112;
}
