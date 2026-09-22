shader_type canvas_item;

void fragment() {
	COLOR *= texture(TEXTURE, UV);
	float distance_from_center = length(UV - vec2(0.5));
	COLOR.a *= 1.0 - smoothstep(0.48, 0.5, distance_from_center);
}
