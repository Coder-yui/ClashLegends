shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float fade = 1.0;
uniform float progress = 0.0;
uniform vec3 tint;
void vertex() {
 VERTEX *= vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
 vec2 p = (UV - vec2(0.5)) * 2.0;
 float ripple = sin(p.x * 12.0 + progress * 6.0) * sin(p.y * 9.0 - progress * 4.0);
 float cloud = pow(max(1.0 - length(p) + ripple * 0.10, 0.0), 1.5);
 ALBEDO = tint;
 ALPHA = cloud * fade * 0.48;
}
