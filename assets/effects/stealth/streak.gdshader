shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float fade = 1.0;
uniform bool inward = true;
void fragment() {
 float across = pow(max(1.0 - abs(UV.x * 2.0 - 1.0), 0.0), 1.8);
 float head = inward ? 1.0 - UV.y : UV.y;
 float taper = smoothstep(0.0, 0.2, head) * (1.0 - smoothstep(0.75, 1.0, head));
 ALBEDO = mix(vec3(0.16, 0.68, 0.26), vec3(0.40, 0.78, 0.30), head);
 ALPHA = across * taper * fade * 0.46;
}
