shader_type spatial;
// Avatar: source blendMode=1 (alpha), native skinned-mesh scale and red Fresnel rim.
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled, fog_disabled;
uniform float p[38];
uniform bool attached_enabled = false;
uniform sampler2D source_texture : repeat_enable, filter_linear;
uniform vec4 source_fresnel;
varying vec3 native_rim;
void vertex() {
	VERTEX *= vec3(p[4], p[5], p[6]);
	vec3 view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	float facing = max(clamp(dot(normalize(-view_position), view_normal), 0.0, 1.0), 1e-30);
	native_rim = (1.0 - pow(facing, source_fresnel.w)) * source_fresnel.rgb;
}
void fragment() {
	if (!attached_enabled) discard;
	vec4 texel = texture(source_texture, UV);
	vec4 lit = texel * vec4(p[7], p[8], p[9], p[10]);
	// Source skinnedmesh/particle_ps carries the rim by texture alpha.
	lit.rgb = clamp(lit.rgb + native_rim * texel.a, vec3(0.0), vec3(1.0));
	ALBEDO = OUTPUT_IS_SRGB ? lit.rgb : mix(lit.rgb / 12.92, pow((lit.rgb + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), lit.rgb));
	ALPHA = clamp(lit.a, 0.0, 1.0);
}
