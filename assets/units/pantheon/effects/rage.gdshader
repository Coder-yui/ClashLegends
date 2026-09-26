shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D glow_texture : source_color;
uniform sampler2D flare_texture : source_color;
uniform sampler2D streak_texture : source_color, repeat_enable;
uniform float strength = 0.0;
uniform float elapsed = 0.0;
uniform float weapon = 0.0;
void fragment() {
 vec4 glow = texture(glow_texture, UV);
 float streak = texture(streak_texture, UV * vec2(4.0, 2.0) + vec2(0.0, -elapsed)).r;
 float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
 float pulse = 0.5 + 0.5 * sin(elapsed * 5.0);
 float mask = mix(rim * (0.08 + 0.1 * pulse) + texture(flare_texture, UV).r * 0.04 * pulse, max(glow.r, glow.g) * (0.45 + streak * 0.7), weapon);
 ALBEDO = mix(vec3(0.72,0.025,0.045), vec3(1.0,0.34,0.07), weapon);
 ALPHA = clamp(mask * strength, 0.0, 0.9);
}
