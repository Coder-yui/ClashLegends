shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform float strength = 0.0;
uniform float elapsed = 0.0;
void vertex() { VERTEX += NORMAL * 0.12; }
void fragment() {
 float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.6);
 float pulse = 0.8 + 0.2 * sin(elapsed * 7.0);
 ALBEDO = vec3(1.0, 0.035, 0.015);
 ALPHA = strength * pulse * (0.12 + 0.7 * rim);
}
