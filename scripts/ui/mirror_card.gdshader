shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec2 uv = UV;
	float edge = min(min(uv.x, 1.0-uv.x), min(uv.y, 1.0-uv.y));
	float rim = 1.0 - smoothstep(0.012, 0.026, abs(edge-0.047));
	float inner = 1.0 - smoothstep(0.003, 0.009, abs(edge-0.09));
	float streak = pow(max(0.0, 1.0-abs(uv.x+uv.y*0.55-0.62)*7.0), 3.0);
	COLOR = vec4(mix(vec3(0.38,0.55,1.0), vec3(0.66,1.0,1.0), rim), 0.10+rim*0.65+inner*0.22+streak*0.21);
}
