uniform float p[38];
uniform bool attached_enabled = false;
uniform sampler2D source_texture : repeat_enable, filter_linear;
uniform vec4 source_fresnel;
uniform sampler2D mult_texture : repeat_enable, filter_linear;
uniform bool has_mult = false;
uniform vec2 cell = vec2(1.0);
uniform vec2 cell_mult = vec2(1.0);
uniform vec2 uv_center = vec2(0.5);
uniform vec2 mult_center = vec2(0.5);
uniform vec2 uv_flip = vec2(0.0);
uniform vec2 mult_flip = vec2(0.0);
uniform int address_mode = 0;
uniform int mult_address = 0;
varying vec3 native_rim;
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

void vertex() {
	VERTEX *= vec3(p[4], p[5], p[6]);
	vec3 view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	// Weapon layers have no reflection definition. Do not evaluate pow(0, 0)
	// on back-facing vertices: GPU precision can flush tiny bases to zero.
	native_rim = vec3(0.0);
	if (source_fresnel.w > 0.0) {
		float facing = clamp(dot(normalize(-view_position), view_normal), 0.0, 1.0);
		float facing_power = 0.0;
		if (facing > 0.0) facing_power = pow(facing, source_fresnel.w);
		native_rim = (1.0 - facing_power) * source_fresnel.rgb;
	}
}
void fragment() {
	if (!attached_enabled) discard;
	vec4 texel = texture(source_texture, addressed(layer_uv(UV,21,uv_center,uv_flip,cell), address_mode));
	if (has_mult) texel *= texture(mult_texture,addressed(layer_uv(UV,28,mult_center,mult_flip,cell_mult),mult_address));
	vec4 lit = texel * vec4(p[7], p[8], p[9], p[10]);
	// Source skinnedmesh/particle_ps carries the rim by texture alpha.
	lit.rgb = clamp(lit.rgb + native_rim * texel.a, vec3(0.0), vec3(1.0));
	ALBEDO = OUTPUT_IS_SRGB ? lit.rgb : mix(lit.rgb / 12.92, pow((lit.rgb + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), lit.rgb));
	ALPHA = clamp(lit.a, 0.0, 1.0);
}
