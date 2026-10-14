shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float elapsed = 0.0;
uniform float strength = 1.0;
void fragment() {
 float across = abs(UV.x * 2.0 - 1.0);
 float halo = pow(max(0.0, 1.0 - across), 2.0);
 float core = 1.0 - smoothstep(0.05, 0.24, across);
 float flow = 0.88 + 0.12 * sin(UV.y * 35.0 - elapsed * 18.0);
 ALBEDO = mix(vec3(0.43, 0.015, 0.95), vec3(0.85, 0.40, 1.0), core);
 ALPHA = strength * halo * flow;
}
