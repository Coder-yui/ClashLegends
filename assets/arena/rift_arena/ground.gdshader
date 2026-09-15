shader_type spatial;
render_mode specular_disabled;
// Original Riot UV atlases: sample only inspected, opaque subregions.
uniform sampler2D meadow_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
vec2 mirror_uv(vec2 p) { return abs(mod(p,2.0)-1.0); }
vec3 grass_sample(vec2 p) {
    // Two incommensurate, rotated scales break any common repeat period.
    vec3 a=texture(grass_texture,p).rgb;
    vec2 q=mat2(vec2(.80,.60),vec2(-.60,.80))*p*.713+vec2(.27,.51);
    vec3 b=texture(grass_texture,q).rgb;
    return mix(a,b,.38+noise(p*.4)*.18);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
#include "res://assets/arena/rift_arena/nexus_aperture.gdshaderinc"
void fragment() {
    clip_nexus_well(world_position, INV_VIEW_MATRIX[2].xyz);
    vec2 tile=vec2(world_position.x+9.0,world_position.z/sqrt(2.0)+16.0);
    float broad=noise(tile*.24);
    float spread=5.5;
    if(tile.y<6.5) { spread*=clamp((tile.y-3.0)/3.5,0.0,1.0); }
    if(tile.y>25.5) { spread*=clamp((29.0-tile.y)/3.5,0.0,1.0); }
    float d=min(abs(tile.x-(9.0-spread)),abs(tile.x-(9.0+spread)));
    float path=1.0-smoothstep(.40,1.48,d+(noise(tile*1.25)-.5)*.38);
    float courtyard=min(length((tile-vec2(9,3))*vec2(1,.93)),length((tile-vec2(9,29))*vec2(1,.93)));
    path=max(path,(1.0-smoothstep(1.75,3.35,courtyard))*.84);
    vec3 grass=grass_sample(tile*.15);
    grass=mix(grass,vec3(.17,.27,.12),.18)*vec3(.90,1.00,1.08);
    vec3 earth=texture(meadow_atlas,vec2(.613,.455)+mirror_uv(tile*.37)*vec2(.037,.07)).rgb;
    earth=mix(earth,vec3(.26,.205,.115),.64);
    float bank=1.0-smoothstep(.0,.68,min(abs(tile.y-15.0),abs(tile.y-17.0)));
    vec3 result=mix(grass,earth,path*.76);
    result=mix(result,result*vec3(.77,.92,.97),bank*.34);
    float edge=1.0-smoothstep(.0,1.25,min(tile.x,18.0-tile.x));
    ALBEDO=result*(.96+broad*.20)*mix(1.0,.85,edge);
    EMISSION=ALBEDO*.12;
    ROUGHNESS=1.0;
}
