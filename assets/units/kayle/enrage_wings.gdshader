shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform sampler2D rage_gradient : source_color, filter_linear;
uniform sampler2D fire_tile : source_color, filter_linear_mipmap, repeat_enable;
uniform float strength = 0.0;
uniform float elapsed = 0.0;
void fragment() {
    vec4 base = texture(base_texture, UV);
    // Skin0 Scrolling_Scale=(2,2), Scrolling_Rate=(-.4,.25), Mask_Intensity=.8；此处以保留羽毛轮廓的透明度曲线适配。
    float flame = texture(fire_tile, UV * 2.0 + elapsed * vec2(-0.4, 0.25)).r;
    float lightness = dot(base.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 rage = texture(rage_gradient, vec2(clamp(0.85 - lightness * 0.45 - flame * 0.25, 0.05, 0.95), 0.5)).rgb;
    // 原版Bloom=2；兼容渲染以有限亮度的颜色层适配，避免直接叠加烧白羽毛。
    ALBEDO = rage * (1.0 + flame * 0.3);
    ALPHA = base.a * strength * (0.65 + flame * 0.35);
}
