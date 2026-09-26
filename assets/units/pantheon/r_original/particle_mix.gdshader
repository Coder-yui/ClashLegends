shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D source_texture : source_color, repeat_enable;
uniform sampler2D mult_texture : source_color, repeat_enable;
uniform sampler2D erosion_texture : repeat_enable;
uniform bool has_mult = false;
uniform bool has_erosion = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform vec2 uv_scroll = vec2(0.0);
uniform vec2 mult_scale = vec2(1.0);
uniform vec2 mult_scroll = vec2(0.0);
uniform vec2 tex_div = vec2(1.0);
uniform float elapsed = 0.0;
uniform float frame = 0.0;
uniform float erosion = 0.0;
uniform float opacity = 1.0;
void fragment() {
 vec2 atlas = (UV + vec2(mod(frame,tex_div.x),floor(frame/tex_div.x)))/tex_div;
 vec4 tex = texture(source_texture, atlas * uv_scale + uv_offset + elapsed * uv_scroll);
 if(has_mult) tex *= texture(mult_texture, UV * mult_scale + elapsed * mult_scroll);
 float alpha = tex.a;
 if(has_erosion) alpha *= smoothstep(erosion-0.08,erosion+0.08,texture(erosion_texture,UV).r);
 ALBEDO = tex.rgb * tint.rgb * COLOR.rgb;
 ALPHA = alpha * tint.a * COLOR.a * opacity;
}
