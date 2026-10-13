shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform sampler2D source_texture : repeat_enable, filter_linear;
uniform sampler2D erosion_texture : hint_default_white, repeat_enable, filter_linear;
uniform vec2 cell = vec2(1.0);
uniform bool has_erosion = false;
uniform vec4 erosion_mixer = vec4(0.0,0.0,0.0,1.0);
uniform vec3 erosion_band = vec3(1.0,0.3,0.3);
void fragment() {
 vec2 tex_uv = vec2(fract(UV.x), UV.y) * cell;
 vec4 lit = texture(source_texture, tex_uv) * COLOR;
 if (has_erosion) {
  float noise = dot(texture(erosion_texture, tex_uv), erosion_mixer);
  float edge = UV2.x - clamp(noise, 0.0, 1.0);
  lit.a *= clamp((edge + erosion_band.x) / erosion_band.y, 0.0, 1.0) - clamp(edge / erosion_band.z, 0.0, 1.0);
 }
 ALBEDO = OUTPUT_IS_SRGB ? lit.rgb : mix(lit.rgb/12.92,pow((lit.rgb+vec3(0.055))/1.055,vec3(2.4)),step(vec3(0.04045),lit.rgb));
 ALPHA = clamp(lit.a,0.0,1.0);
}
