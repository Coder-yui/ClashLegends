shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D source_texture : repeat_enable;
uniform float strength = 0.0;
uniform float elapsed = 0.0;
void vertex() { VERTEX += NORMAL * 0.002; }
void fragment() {
 float pattern = texture(source_texture, UV + vec2(0.0, elapsed * 0.28)).r;
 float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
 ALBEDO = vec3(0.2, 1.0, 0.08);
 ALPHA = strength * (0.18 + pattern * 0.36 + rim * 0.28);
}
