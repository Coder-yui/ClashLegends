uniform float opacity = 1.0;
#ifdef SETT_ATTACHED
uniform bool has_reflection=false;
uniform sampler2D reflection_texture : repeat_disable, filter_linear;
uniform vec4 rim=vec4(0.0);
uniform vec4 reflection_params=vec4(0.0);
uniform vec3 reflection_tint=vec3(1.0);
#endif
uniform bool native_space = false;
uniform float source_length = 732.0;
uniform float source_origin_z = 47.0;

uniform float p[38];
uniform bool is_mesh=false;
uniform bool cull_mesh=false;
uniform bool billboard=false;
uniform bool directed=false;
uniform bool is_ray=false;
uniform mat3 projection_basis=mat3(1.0);
uniform mat3 shape_basis=mat3(1.0);
uniform float reach=2.0;
uniform float pivot=0.0;
uniform float push_pull=0.0;
uniform sampler2D source_texture : repeat_enable, filter_linear;
uniform sampler2D mult_texture : repeat_enable, filter_linear;
uniform sampler2D ramp_texture : repeat_disable, filter_linear;
uniform sampler2D erosion_texture : repeat_enable, filter_linear;
uniform sampler2D normal_texture : repeat_disable, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
#ifdef CASK_WARP
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
#endif

uniform vec2 cell=vec2(1.0);
uniform vec2 cell_mult=vec2(1.0);
uniform vec2 uv_center=vec2(0.5);
uniform vec2 uv_flip=vec2(0.0);
uniform vec2 mult_center=vec2(0.5);
uniform vec2 mult_flip=vec2(0.0);
uniform int address_mode=0;
uniform int mult_address=0;
uniform int erosion_address=0;
uniform bool has_mult=false;
uniform bool has_ramp=false;
uniform bool has_erosion=false;
uniform bool has_soft=false;
uniform vec4 erosion_mix=vec4(0.0,0.0,0.0,1.0);
uniform vec3 erosion_band=vec3(1.5,10.0,10.0);
uniform vec4 soft_params=vec4(0.0,1e8,1.0,1.0);
uniform float alpha_ref=0.0;
uniform float warp_strength=0.0;
varying vec2 base_uv;
varying vec2 mult_uv;
varying vec4 tint;
varying float unit_scale;
vec2 layer_uv(vec2 texuv, int start, vec2 center, vec2 flip, vec2 cells) {
 vec2 at=(texuv-center)*vec2(p[start+1],p[start+2]);
 float c=cos(p[start]),s=sin(p[start]);
 at=vec2(c*at.x-s*at.y,s*at.x+c*at.y)+center+vec2(p[start+3],p[start+4]);
 return vec2(p[start+5],p[start+6])+mix(at,vec2(1.0)-at,flip)*cells;
}
vec2 addressed(vec2 at,int mode) {
 if(mode>=2) return clamp(at,vec2(0.0),vec2(1.0));
 if(mode==1) return vec2(1.0)-abs(mod(at,vec2(2.0))-vec2(1.0));
 return fract(at);
}
uniform vec4 range_params=vec4(183.0,79.0,194.0,37.0);
// Warning and impact share the original origin and one uniform scale.
vec3 fit_range(vec3 pos) {
 if(native_space) return pos;
 return (pos-vec3(0.0,0.0,source_origin_z))*(range_params.x/source_length);
}

void vertex() {
#ifdef SETT_ATTACHED
 VERTEX *= vec3(p[4],p[5],p[6]);
 base_uv=layer_uv(UV,21,uv_center,uv_flip,cell);
 mult_uv=layer_uv(UV,28,mult_center,mult_flip,cell_mult);
 tint=vec4(p[7],p[8],p[9],p[10]);
 unit_scale=length(MODEL_MATRIX[0].xyz);
#else
 vec3 center=vec3(p[1],p[2],p[3]);
 vec3 size=vec3(p[4],p[5],p[6]);
 mat3 axes=mat3(vec3(p[12],p[15],p[18]),vec3(p[13],p[16],p[19]),vec3(p[14],p[17],p[20]));
 vec2 texuv=UV;
 vec3 pos;
 if(is_mesh){pos=center+axes*(VERTEX*size);}
 else {
  vec2 corner=VERTEX.xy;
  vec2 at=vec2(corner.x,corner.y+pivot)*reach;
  if(billboard){
   vec2 offset;
   if(directed){
    vec2 up=(mat3(VIEW_MATRIX)*mat3(MODEL_MATRIX)*projection_basis*axes[1]).xy;
    up=dot(up,up)>0.0?normalize(up):vec2(0.0,1.0);
    offset=vec2(up.y,-up.x)*(at.x*size.x)+up*(at.y*size.y);
   }else{float c=cos(p[11]),s=sin(p[11]);offset=vec2(at.x*c-at.y*s,at.x*s+at.y*c)*size.xy;}
   // Keep camera-facing sprites circular under the battlefield ground projection.
   vec3 world_offset=INV_VIEW_MATRIX[0].xyz*offset.x+INV_VIEW_MATRIX[1].xyz*offset.y;
   pos=projection_basis*fit_range(center)+inverse(mat3(MODEL_MATRIX))*world_offset*length(MODEL_MATRIX[0].xyz)*length(projection_basis[0])*(native_space ? 1.0 : range_params.x/source_length);
   texuv=vec2(corner.x+0.5,0.5-corner.y);
  }else if(is_ray){
   vec3 mapped_center=projection_basis*center;
   vec3 along=normalize(shape_basis*axes[2]);
   vec3 eye=(inverse(MODEL_MATRIX)*vec4(CAMERA_POSITION_WORLD,1.0)).xyz;
   vec3 aside=cross(along,eye-mapped_center);
   vec3 across=dot(aside,aside)>0.0?-normalize(aside):axes[0];
   pos=mapped_center+along*(size.z+(corner.y+0.5)*size.y)+across*(corner.x*size.x);
   texuv=vec2(corner.x+0.5,0.5-corner.y);
  }else{pos=center+axes[0]*(at.x*size.x)+axes[1]*(at.y*size.y);texuv=vec2(corner.y+0.5,corner.x+0.5);}
 }
 // Apply the same transform to warning and impact geometry.
 if(is_mesh || (!billboard && !is_ray))pos=projection_basis*fit_range(pos);
 VERTEX=pos;
 base_uv=layer_uv(texuv,21,uv_center,uv_flip,cell);
 mult_uv=layer_uv(texuv,28,mult_center,mult_flip,cell_mult);
 tint=vec4(p[7],p[8],p[9],p[10])*COLOR;
 unit_scale=length(MODEL_MATRIX[0].xyz);
 if(push_pull!=0.0){vec3 world=(MODEL_MATRIX*vec4(pos,1.0)).xyz;VERTEX+=(inverse(mat3(MODEL_MATRIX))*normalize(world-CAMERA_POSITION_WORLD))*push_pull*unit_scale;}
#endif
}

void fragment() {
 #ifdef SETT_ATTACHED
 if(cull_mesh && !FRONT_FACING)discard;
#else
 if(is_mesh && cull_mesh && !FRONT_FACING)discard;
#endif
 vec4 texel=texture(source_texture,addressed(base_uv,address_mode));
 if(has_ramp) texel*=texture(ramp_texture,has_mult?mult_uv:vec2(p[35],p[36]));
 if(has_mult) texel*=texture(mult_texture,addressed(mult_uv,mult_address));
 vec4 lit=texel*tint;
 lit.a*=opacity;
 if(has_erosion){
  float v=clamp(dot(texture(erosion_texture,addressed(base_uv,erosion_address)),erosion_mix),0.0,1.0);
  lit.a*=clamp((p[37]-v+erosion_band.x)*erosion_band.y,0.0,1.0)-clamp((p[37]-v)*erosion_band.z,0.0,1.0);
 }
 if(has_soft){
  float depth=texture(depth_texture,SCREEN_UV).r;
  vec3 ndc=vec3(SCREEN_UV*2.0-1.0,depth);
  #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
  ndc.z=depth*2.0-1.0;
  #endif
  vec4 scene=INV_PROJECTION_MATRIX*vec4(ndc,1.0);
  float gap=(VERTEX.z-scene.z/scene.w)/unit_scale;
  vec2 v=clamp((vec2(gap)-soft_params.xy)*soft_params.zw,vec2(0.0),vec2(1.0));
  v=v*v*(vec2(3.0)-2.0*v);
  lit*=v.x-v.y;
 }
 #ifdef SETT_ATTACHED
 if(has_reflection){
  float facing=max(clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),1e-20);
  float reflect_alpha=mix(reflection_params.y,reflection_params.z,1.0-pow(facing,reflection_params.x));
  // The authored reflection is Generic_White_Cubemap: all six faces are white.
  vec3 mirrored=texture(reflection_texture,vec2(0.5)).rgb*reflect_alpha*mix(vec3(1.0),reflection_tint,reflect_alpha);
  lit.rgb+=(mirrored+(1.0-pow(facing,rim.w))*rim.rgb)*texel.a;
 }
 lit.rgb=clamp(lit.rgb,vec3(0.0),vec3(1.0));
#else
 if(is_mesh)lit.rgb=clamp(lit.rgb,vec3(0.0),vec3(1.0));
#endif
 if(lit.a<alpha_ref)discard;

#ifdef CASK_WARP
 vec4 n=texture(normal_texture,base_uv); vec4 ramp=has_ramp?texture(ramp_texture,vec2(p[35],p[36])):vec4(1.0); vec3 back=texture(screen_texture,SCREEN_UV+(n.xy-vec2(0.5))*warp_strength*ramp.a*2.0).rgb; lit.rgb*=OUTPUT_IS_SRGB ? back : mix(back*12.92,1.055*pow(max(back,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),back)); lit.a=n.a*ramp.a;
#endif
 // LoL's shader samples raw colour values. Convert the finished colour for Godot's linear target.
 ALBEDO=OUTPUT_IS_SRGB ? lit.rgb : mix(lit.rgb/12.92,pow((lit.rgb+vec3(0.055))/1.055,vec3(2.4)),step(vec3(0.04045),lit.rgb));
#ifdef PURE_ADD
 ALBEDO*=opacity;
 ALPHA=1.0;
#else
 ALPHA=clamp(lit.a,0.0,1.0);
#endif
}
