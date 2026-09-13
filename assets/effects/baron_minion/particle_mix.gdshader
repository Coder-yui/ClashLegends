shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D source_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mult_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D ramp_texture : source_color, filter_linear, repeat_disable;
uniform bool has_mult = false;
uniform bool has_ramp = false;
uniform bool scroll_rgb_only = false;
uniform vec2 uv_speed = vec2(0.0);
uniform vec2 mult_speed = vec2(0.0);
uniform vec2 uv_div = vec2(1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float elapsed = 0.0;
uniform float age_ratio = 0.0;
uniform int frame = 0;
void fragment() {
 vec2 tiles = max(uv_div, vec2(1.0));
 vec2 frame_offset = vec2(mod(float(frame), tiles.x), floor(float(frame) / tiles.x));
 vec2 uv = (UV + frame_offset) / tiles;
 vec4 texel = texture(source_texture, uv + elapsed * uv_speed);
 if (scroll_rgb_only) texel.a = texture(source_texture, uv).a;
 if (has_mult) texel *= texture(mult_texture, UV + elapsed * mult_speed);
 vec4 ramp = has_ramp ? texture(ramp_texture, vec2(age_ratio, 0.5)) : vec4(1.0);
 ALBEDO = texel.rgb * tint.rgb * ramp.rgb;
 ALPHA = texel.a * tint.a * ramp.a;
}
