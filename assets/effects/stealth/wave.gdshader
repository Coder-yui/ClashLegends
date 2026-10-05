shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float fade = 1.0;
void fragment() {
 vec2 p = (UV - vec2(0.5)) * 2.0;
 float r = length(p);
 float rim = exp(-pow((r - 0.82) * 19.0, 2.0));
 float wisps = 0.65 + 0.35 * sin(atan(p.y, p.x) * 9.0 + r * 16.0);
 ALBEDO = vec3(0.25, 0.72, 0.28);
 ALPHA = rim * wisps * fade * 0.22;
}
