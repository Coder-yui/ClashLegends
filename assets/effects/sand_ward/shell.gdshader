shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform float elapsed = 0.0;
void fragment() {
 float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
 float bands = pow(0.5 + 0.5 * sin(UV.y * 65.0 - elapsed * 7.0 + sin(UV.x * 40.0)), 8.0);
 float gain = 1.0 - smoothstep(0.12, 0.4, elapsed);
 ALBEDO = vec3(1.0, 0.64, 0.12);
 ALPHA = rim * (0.23 + 0.1 * bands + 0.2 * gain) + bands * 0.012;
}
