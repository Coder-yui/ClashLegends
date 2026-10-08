uniform float p[38];
uniform vec2 cell=vec2(1.0);
uniform vec2 cell_mult=vec2(1.0);
uniform vec2 uv_center=vec2(0.5);
uniform vec2 uv_flip=vec2(0.0);
uniform vec2 mult_center=vec2(0.5);
uniform vec2 mult_flip=vec2(0.0);
uniform sampler2D mult_texture : repeat_enable, filter_linear;
uniform sampler2D palette_texture : repeat_disable, filter_linear;
uniform sampler2D ramp_texture : repeat_disable, filter_linear;
uniform bool has_mult=false;
uniform bool has_palette=false;
uniform bool has_ramp=false;
uniform vec4 palette_mix=vec4(0.299,0.587,0.114,0.0);
uniform float palette_row=0.125;
uniform int address_mode=0;
uniform int mult_address=0;
uniform float opacity=1.0;
varying vec4 tint;
vec2 address(vec2 v,int mode){if(mode>=2)return clamp(v,vec2(0.0),vec2(1.0));if(mode==1)return vec2(1.0)-abs(mod(v,vec2(2.0))-vec2(1.0));return fract(v);}
vec2 layer_uv(vec2 uv,int start,vec2 center,vec2 flip,vec2 cells){
 vec2 at=(uv-center)*vec2(p[start+1],p[start+2]);float c=cos(p[start]),s=sin(p[start]);
 at=vec2(c*at.x-s*at.y,s*at.x+c*at.y)+center+vec2(p[start+3],p[start+4]);
 return vec2(p[start+5],p[start+6])+mix(at,vec2(1.0)-at,flip)*cells;
}
void vertex(){tint=COLOR;}
void fragment(){
 vec2 uv=layer_uv(UV,21,uv_center,uv_flip,cell);
 vec2 mult_uv=layer_uv(UV,28,mult_center,mult_flip,cell_mult);
 vec4 texel=texture(TEXTURE,address(uv,address_mode));
 if(has_palette)texel.rgb=texture(palette_texture,vec2(clamp(dot(texel,palette_mix),0.0,1.0),palette_row)).rgb;
 if(has_ramp)texel*=texture(ramp_texture,vec2(p[35],p[36]));
 if(has_mult)texel*=texture(mult_texture,address(mult_uv,mult_address));
 COLOR=texel*tint;
#ifdef PURE_ADD
 COLOR.rgb*=opacity;COLOR.a=1.0;
#else
 COLOR.a*=opacity;
#endif
}
