shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform sampler2D source_texture : repeat_enable, filter_linear;
uniform sampler2D erosion_texture : repeat_enable, filter_linear;
uniform float age = 2.0;
void fragment() {
 float t=clamp(age/2.0,0.0,1.0);
 float tint=t<0.3?1.0:(t<0.5?mix(1.0,0.19607843,(t-0.3)/0.2):mix(0.19607843,0.0,(t-0.5)/0.5));
 float alpha=t<0.5?1.0:(1.0-t)/0.5;
 vec4 lit=texture(source_texture,UV)*vec4(vec3(tint),alpha);
 float noise=texture(erosion_texture,clamp(UV,vec2(0.0),vec2(1.0))).a;
 float drive=mix(-0.5,1.0,t);
 lit.a*=clamp((drive-noise+0.8)/0.1,0.0,1.0)-clamp((drive-noise)/0.15,0.0,1.0);
 ALBEDO=OUTPUT_IS_SRGB?lit.rgb:mix(lit.rgb/12.92,pow((lit.rgb+vec3(0.055))/1.055,vec3(2.4)),step(vec3(0.04045),lit.rgb));
 ALPHA=clamp(lit.a,0.0,1.0);
}
