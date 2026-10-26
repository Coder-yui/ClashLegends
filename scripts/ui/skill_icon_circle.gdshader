shader_type canvas_item;

uniform bool cooldown_active = false;
uniform float cooldown_completed : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR *= texture(TEXTURE, UV);
	float distance_from_center = length(UV - vec2(0.5));
	// 屏幕Y向下：12点起顺时针已完成区域露出，剩余扇面覆暗。
	float clockwise = mod(atan(UV.x - 0.5, 0.5 - UV.y) + 6.28318530718, 6.28318530718) / 6.28318530718;
	if (cooldown_active && clockwise >= cooldown_completed) {
		COLOR.rgb *= 0.26;
	}
	COLOR.a *= 1.0 - smoothstep(0.48, 0.5, distance_from_center);
}
