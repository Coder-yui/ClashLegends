shader_type spatial;
render_mode cull_disabled;

varying vec3 world_position;

vec2 cell_hash(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float wave = sin(p.x * 4.0 + p.y * 7.0 - TIME * 0.8);
	float cross_wave = sin(p.x * 7.3 - p.y * 4.8 + sin(p.x * 1.4 + TIME * 0.25));
	vec2 flow = p * 2.4 + vec2(TIME * 0.07, sin(p.x * 1.3 + TIME * 0.15) * 0.25);
	vec2 cell = floor(flow), f = fract(flow);
	float first = 8.0, second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			float d = length(offset + cell_hash(cell + offset) - f);
			if (d < first) { second = first; first = d; }
			else { second = min(second, d); }
		}
	}
	float caustic = 1.0 - smoothstep(0.015, 0.065, second - first);
	float depth = 1.0 - smoothstep(0.7, 1.38, abs(p.y));
	vec3 deep = vec3(0.025, 0.17, 0.18);
	vec3 shallow = vec3(0.07, 0.31, 0.29);
	ALBEDO = mix(shallow, deep, depth * 0.8) + vec3(0.08, 0.19, 0.15) * caustic * 0.38;
	float shore = smoothstep(1.13, 1.39, abs(p.y));
	float foam = shore * (0.55 + 0.45 * sin(p.x * 10.0 - TIME));
	ALBEDO += vec3(0.12, 0.25, 0.20) * foam;
	ROUGHNESS = 0.42;
	SPECULAR = 0.35;
	NORMAL = normalize(vec3(wave * 0.025, 1.0, cross_wave * 0.025));
}
