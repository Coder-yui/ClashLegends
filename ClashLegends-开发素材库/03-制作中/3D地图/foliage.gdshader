shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D canopy_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 tint=vec3(1.2,1.35,1.25);
void fragment() {
    vec4 paint=texture(canopy_atlas,UV);
    ALBEDO=paint.rgb*tint;
    EMISSION=ALBEDO*.32;
    ALPHA=paint.a;
    ALPHA_SCISSOR_THRESHOLD=.5;
    ROUGHNESS=1.0;
}
