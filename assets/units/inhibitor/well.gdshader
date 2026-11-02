shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float surface_visible = 1.0;
uniform float opening_radius = 0.82;
void fragment() {
    vec3 position = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 center = MODEL_MATRIX[3].xyz;
    vec3 to_camera = INV_VIEW_MATRIX[2].xyz;
    if (surface_visible < 0.5) { discard; }
    if (position.y < center.y && abs(to_camera.y) > 0.0001) {
        vec2 aperture = (position - to_camera * (position.y - center.y) / to_camera.y).xz;
        if (length(aperture - center.xz) > opening_radius) { discard; }
    }
    vec4 color = texture(albedo_texture, UV) * albedo_color;
    if (color.a < 0.1) { discard; }
    ALBEDO = color.rgb;
}
