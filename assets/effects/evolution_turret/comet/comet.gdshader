shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform bool head = false;
void fragment() {
 float alpha;
 vec3 tint;
 if (head) {
  float r = length((UV - vec2(0.5)) * 2.0);
  alpha = exp(-r*r*4.0) * (1.0-smoothstep(0.7,1.0,r));
  tint = mix(vec3(1.0,0.58,0.025),vec3(1.0,0.97,0.63),1.0-smoothstep(0.0,0.6,r));
 } else {
  float edge = abs(UV.x*2.0-1.0);
  alpha = pow(1.0-edge,1.5) * pow(UV.y,0.7);
  tint = mix(vec3(1.0,0.32,0.015),vec3(1.0,0.85,0.15),smoothstep(0.0,0.8,UV.y));
  tint = mix(tint,vec3(1.0,0.96,0.55),smoothstep(0.8,1.0,UV.y)*(1.0-edge));
 }
 ALBEDO = tint;
 ALPHA = alpha;
}
