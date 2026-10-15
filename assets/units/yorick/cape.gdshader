shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform sampler2D flow_texture : source_color, repeat_enable;
uniform sampler2D color_texture : source_color, repeat_enable;
// Each AttachedMesh samples its birth UV phase once; only the flow map scrolls.
uniform float uv_phase = 0.0;
uniform float age = 0.0;
uniform float scroll_speed = -0.15;
void fragment() {
 vec4 flow = texture(flow_texture, UV + vec2(0.0, uv_phase + age * scroll_speed));
 vec4 tint = texture(color_texture, UV);
 ALBEDO = flow.rgb * tint.rgb;
 ALPHA = flow.a * tint.a;
}
