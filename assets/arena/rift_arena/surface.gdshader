shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D surface_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 quadrant = vec2(0.5, 0.0);
uniform vec3 tint = vec3(1.0);
uniform float texture_scale = 0.35;
varying vec3 world_position;
varying vec3 world_normal;

vec3 sample_surface(vec2 p) {
	vec2 mirrored = abs(mod(p, 2.0) - 1.0);
	return texture(surface_atlas, quadrant + vec2(0.003) + mirrored * 0.494).rgb;
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 p = world_position * texture_scale;
	vec3 blend = pow(abs(world_normal), vec3(4.0));
	blend /= max(dot(blend, vec3(1.0)), 0.001);
	vec3 painted = sample_surface(p.zy) * blend.x + sample_surface(p.xz) * blend.y + sample_surface(p.xy) * blend.z;
	ALBEDO = painted * tint;
	// Painted ambient fill preserves colored shadows under the dense canopy.
	EMISSION = ALBEDO * 0.22;
	ROUGHNESS = 1.0;
}
