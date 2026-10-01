shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
// Bard Base R Temp_Avatar: attached mesh 1.02, alpha 0.700008², UV scroll (0, 0.4).
uniform sampler2D swirl : source_color, repeat_enable, filter_linear_mipmap;
uniform float mesh_scale = 1.02;
uniform float depth_bias = 0.0;
void vertex() {
    VERTEX *= mesh_scale;
    POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    POSITION.z += depth_bias * POSITION.w;
}
void fragment() {
    vec4 tex = texture(swirl, UV + vec2(0.0, TIME * 0.4));
    ALBEDO = tex.rgb;
    ALPHA = tex.a * 0.4900112;
}
