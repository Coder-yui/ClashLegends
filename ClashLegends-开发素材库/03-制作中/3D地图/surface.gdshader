shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D painted_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 atlas_region=vec4(.14,.035,.23,.07);
uniform vec3 tint=vec3(1.0);
uniform float texture_scale=.45;
uniform float painted_weight=.75;
varying vec3 world_position;
varying vec3 world_normal;
vec3 sample_surface(vec2 p) {
    vec2 mirrored=abs(mod(p,2.0)-1.0);
    return texture(painted_atlas,atlas_region.xy+mirrored*atlas_region.zw).rgb;
}
void vertex() {
    world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
    vec3 p=world_position*texture_scale;
    vec3 blend=pow(abs(world_normal),vec3(4));
    blend/=max(dot(blend,vec3(1)),.001);
    vec3 paint=sample_surface(p.zy)*blend.x+sample_surface(p.xz)*blend.y+sample_surface(p.xy)*blend.z;
    vec3 color=mix(tint*.20,paint*tint*1.10,painted_weight);
    // Soft colored occlusion is local to scenery, independent of simulation/time.
    float top=max(world_normal.y,0.0);
    ALBEDO=color*(.82+top*.18);
    EMISSION=ALBEDO*.13;
    ROUGHNESS=1.0;
}
