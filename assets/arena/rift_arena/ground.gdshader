shader_type spatial;
render_mode cull_back;

uniform sampler2D surface_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;

varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 tile = vec2(world_position.x + 9.0, world_position.z / sqrt(2.0) + 16.0);
	vec2 p = world_position.xz;
	float broad = noise(p * 0.7) * 0.6 + noise(p * 1.8) * 0.4;
	float detail = noise(p * 13.0) * 0.6 + noise(p * 31.0) * 0.4;
	float spread = 5.5;
	if (tile.y < 6.5) { spread *= clamp((tile.y - 3.0) / 3.5, 0.0, 1.0); }
	if (tile.y > 25.5) { spread *= clamp((29.0 - tile.y) / 3.5, 0.0, 1.0); }
	float distance_to_path = min(abs(tile.x - (9.0 - spread)), abs(tile.x - (9.0 + spread)));
	float path = 1.0 - smoothstep(0.6, 1.7, distance_to_path + (broad - 0.5) * 0.9);
	vec2 painted_uv = abs(mod(p * 0.17, 2.0) - 1.0) * 0.494 + vec2(0.003);
	vec3 grass = textureLod(surface_atlas, painted_uv, 1.5).rgb * vec3(0.60, 0.77, 1.0);
	grass = mix(grass, vec3(0.21, 0.28, 0.13), 0.28);
	vec3 earth = texture(surface_atlas, painted_uv + vec2(0.0, 0.5)).rgb * vec3(0.70, 0.77, 0.85);
	float edge = smoothstep(0.0, 1.8, min(tile.x, 18.0 - tile.x));
	ALBEDO = mix(grass, earth, path * 0.78) * (0.85 + detail * 0.30) * mix(0.65, 1.0, edge);
	EMISSION = ALBEDO * 0.20;
	ROUGHNESS = 1.0;
	SPECULAR = 0.08;
}
