// Native palette replaces texture RGB, preserves alpha, before ramp/mult/tint.
uniform sampler2D palette_texture : repeat_enable, filter_linear;
uniform bool has_palette = false;
uniform vec4 palette_mix = vec4(0.299, 0.587, 0.114, 0.0);
uniform float palette_row = 0.0;
uniform vec2 palette_scroll = vec2(0.0);
uniform int palette_address = 0;
vec4 native_palette(vec4 texel) {
 if (!has_palette) return texel;
 vec2 at = vec2(clamp(dot(texel, palette_mix), 0.0, 1.0), palette_row) + palette_scroll;
 if (palette_address >= 2) at = clamp(at, vec2(0.0), vec2(1.0));
 else if (palette_address == 1) at = vec2(1.0) - abs(mod(at, vec2(2.0)) - vec2(1.0));
 else at = fract(at);
 texel.rgb = texture(palette_texture, at).rgb;
 return texel;
}
