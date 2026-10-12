shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float opacity = 1.0;
void vertex() {
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
 vec2 p = (UV - 0.5) * 2.0;
 float core = pow(max(0.0, 1.0 - dot(p,p)), 2.0);
 ALBEDO = vec3(1.0, 0.72, 0.26);
 ALPHA = core * opacity;
}
