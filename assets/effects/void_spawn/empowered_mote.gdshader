shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float opacity = 0.0;
uniform float elapsed = 0.0;
void vertex() {
 mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
 facing[0].xyz *= length(MODEL_MATRIX[0].xyz);
 facing[1].xyz *= length(MODEL_MATRIX[1].xyz);
 facing[2].xyz *= length(MODEL_MATRIX[2].xyz);
 MODELVIEW_MATRIX = VIEW_MATRIX * facing;
}
void fragment() {
 vec2 p = UV * 2.0 - 1.0;
 float r = length(p);
 float pulse = 0.94 + 0.06 * sin(elapsed * 2.7);
 float halo = exp(-r*r*5.0) * (1.0-smoothstep(0.75,1.0,r));
 float body = 1.0-smoothstep(0.12,0.62,r);
 float heart = exp(-dot(p-vec2(-0.06,-0.09),p-vec2(-0.06,-0.09))*65.0);
 vec3 violet = mix(vec3(0.21,0.025,0.65),vec3(0.65,0.12,1.0),body);
 ALBEDO = mix(violet,vec3(0.95,0.72,1.0),heart);
 ALPHA = opacity*pulse*(0.55*halo+0.45*body);
}
