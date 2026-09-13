shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D source_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 tint=vec3(1.15,1.22,1.16);
void fragment() {
    vec4 paint=texture(source_albedo,UV);
    ALBEDO=paint.rgb*tint;
    EMISSION=ALBEDO*.22;
    ALPHA=paint.a;
    ALPHA_SCISSOR_THRESHOLD=.35;
    ROUGHNESS=1.0;
}
