shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
// The native untextured sphere needs view-angle falloff; a white fallback
// texture would make a solid luminous ball and obscure the actor.
void vertex() { NORMAL = normalize(VERTEX); }
void fragment() {
 float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
 ALBEDO = tint.rgb;
 ALPHA = tint.a * rim * 0.45;
}
