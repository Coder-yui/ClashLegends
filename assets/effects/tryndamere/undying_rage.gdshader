shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D source_texture : source_color, repeat_enable;
uniform sampler2D mult_texture : source_color, repeat_enable;
uniform sampler2D erosion_map : repeat_enable;
uniform bool has_mult = false;
uniform bool has_erosion = false;
uniform vec2 uv_rate = vec2(0.0);
uniform vec2 mult_rate = vec2(0.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 reflection_color : source_color = vec4(0.0);
uniform float fresnel = 0.0;
uniform float erosion_drive = 0.0;
uniform float strength = 0.0;
uniform float elapsed = 0.0;
uniform float surface_offset = 0.001;
void vertex() { VERTEX += NORMAL * surface_offset; }
void fragment() {
 vec4 tex = texture(source_texture, UV + uv_rate * elapsed);
 if (has_mult) tex *= texture(mult_texture, UV + mult_rate * elapsed);
 float mask = 1.0;
 // The source erosion texture stores its pattern in alpha, not white RGB.
 if (has_erosion) mask = smoothstep(erosion_drive - 0.08, erosion_drive + 0.08, texture(erosion_map, UV).a);
 float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
 float rim = fresnel + (1.0 - fresnel) * pow(1.0 - facing, 5.0);
 ALBEDO = tex.rgb * tint.rgb + reflection_color.rgb * (reflection_color.a + rim);
 ALPHA = tex.a * tint.a * mask * strength;
}
