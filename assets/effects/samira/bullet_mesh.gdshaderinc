uniform float p[38];
uniform sampler2D source_texture : repeat_enable, filter_linear;
uniform vec4 source_fresnel;
varying vec3 native_rim;
void vertex() {
	mat3 axes = mat3(vec3(p[12],p[15],p[18]),vec3(p[13],p[16],p[19]),vec3(p[14],p[17],p[20]));
	VERTEX = vec3(p[1],p[2],p[3]) + axes * (VERTEX * vec3(p[4],p[5],p[6]));
	vec3 surface = normalize(MODELVIEW_NORMAL_MATRIX * axes * NORMAL);
	vec3 eye = normalize(-(MODELVIEW_MATRIX * vec4(VERTEX,1.0)).xyz);
	float facing = max(clamp(dot(eye,surface),0.0,1.0),1e-30);
	native_rim = (1.0-pow(facing,source_fresnel.w))*source_fresnel.rgb;
}
void fragment() {
	vec4 lit = texture(source_texture,UV)*vec4(p[7],p[8],p[9],p[10]);
	lit.rgb = clamp(lit.rgb + native_rim*p[10],vec3(0.0),vec3(1.0));
	ALBEDO = OUTPUT_IS_SRGB ? lit.rgb : mix(lit.rgb/12.92,pow((lit.rgb+vec3(0.055))/1.055,vec3(2.4)),step(vec3(0.04045),lit.rgb));
	ALPHA = clamp(lit.a,0.0,1.0);
}
