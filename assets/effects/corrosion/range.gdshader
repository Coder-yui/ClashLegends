shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 rim_color : source_color = vec4(0.15,0.55,1.0,1.0);
void fragment() {
 float r = length(UV - vec2(0.5))*2.0;
 ALBEDO = rim_color.rgb;
 ALPHA = smoothstep(0.97,0.982,r)*(1.0-smoothstep(0.99,1.0,r))*0.65;
}
