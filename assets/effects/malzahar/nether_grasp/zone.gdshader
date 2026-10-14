shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float elapsed = 0.0;
uniform float strength = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float mist(vec2 p) { return noise(p)*0.58 + noise(p*2.1+3.7)*0.28 + noise(p*4.3)*0.14; }
void fragment() {
 vec2 p=UV*2.0-1.0;
 float r=length(p), a=atan(p.y,p.x);
 float clip=1.0-smoothstep(0.985,1.0,r);
 float t=elapsed;
 float rot=t*0.24-r*2.4;
 vec2 q=mat2(vec2(cos(rot),sin(rot)),vec2(-sin(rot),cos(rot)))*p;
 float clouds=mist(q*5.0+vec2(t*0.13,-t*0.10));
 float veins=pow(1.0-abs(sin(a*5.0+r*10.0-t*1.5+clouds*3.0)),12.0);
 float spiral=pow(0.5+0.5*sin(a*3.0+r*15.0+t*2.0+clouds*2.0),8.0);
 float corona=exp(-pow((r-(0.88+0.018*sin(a*9.0-t*2.0)))*36.0,2.0));
 float boundary=exp(-pow((r-0.975)*100.0,2.0))*(0.45+0.30*sin(a*12.0+t*2.2));
 float fragments=pow(max(0.0,sin(a*19.0-t*1.2)),18.0)*exp(-pow((r-0.77)*28.0,2.0));
 float pulse=0.80+0.20*cos(t*12.56637);
 float energy=(0.30*veins+0.26*spiral)*smoothstep(0.08,0.40,r)+corona*0.65*pulse+fragments*0.7+boundary;
 vec3 deep=mix(vec3(0.045,0.008,0.09),vec3(0.22,0.025,0.37),clouds);
 ALBEDO=deep+vec3(0.52,0.12,0.85)*energy;
 ALPHA=strength*clip*(0.55+0.16*clouds+0.22*clamp(energy,0.0,1.0));
}
