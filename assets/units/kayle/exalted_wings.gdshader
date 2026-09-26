shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform sampler2D level16_gradient : source_color, filter_linear;
uniform sampler2D rage_gradient : source_color, filter_linear;
uniform sampler2D fire_tile : source_color, filter_linear_mipmap, repeat_enable;
uniform float strength = 0.0;
uniform float elapsed = 0.0;
void fragment() {
	vec4 base = texture(base_texture, UV);
	float lightness = dot(base.rgb, vec3(0.2126, 0.7152, 0.0722));
	// 原版16级渐变的第一行是金白色带；保留原网格、羽毛纹理明暗与透明度。
	ALBEDO = texture(level16_gradient, vec2(1.0 - lightness, 0.0625)).rgb;
	// 同一原版Enrage遮罩直接混入16级材质，避免透明羽毛的多遍排序覆盖怒焰层。
	float flame = texture(fire_tile, UV * 2.0 + elapsed * vec2(-0.4, 0.25)).r;
	vec3 rage = texture(rage_gradient, vec2(clamp(0.85 - lightness * 0.45 - flame * 0.25, 0.05, 0.95), 0.5)).rgb;
	ALBEDO = mix(ALBEDO, rage * (1.0 + flame * 0.3), strength * (0.65 + flame * 0.35));
	ALPHA = base.a;
}
