shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform float strength = 0.0;
uniform float elapsed = 0.0;
void vertex() { VERTEX += NORMAL * 0.035; }
void fragment() {
 float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
 float pulse = 0.8 + 0.2 * sin(elapsed * 3.3);
 ALBEDO = vec3(0.6, 0.08, 1.0);
 ALPHA = strength * pulse * (0.035 + 0.5 * rim);
}
