shader_type canvas_item;
render_mode unshaded, blend_add;
uniform sampler2D fire_palette : source_color, filter_linear;
uniform sampler2D sword_palette : source_color, filter_linear;
uniform int layer = 0;
uniform float age = 0.0;
uniform float strength = 1.0;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	vec4 tint = vertex_tint;
	vec2 uv = UV;
	float mask = 1.0;
	if (layer == 2 || layer == 3) {
		// 原Fire Trail / Fire1的texDiv(1,.5)及UV速率(1,.25)/(1,.1)。
		uv = fract(uv * vec2(1.0, 0.5) + age * vec2(1.0, layer == 2 ? 0.25 : 0.1));
		float side = abs(UV.x * 2.0 - 1.0);
		float front = 0.20 + 0.27 * side * side;
		mask = smoothstep(front - 0.06, front + 0.06, UV.y) * (1.0 - smoothstep(front + 0.20, 0.98, UV.y));
		mask *= 1.0 - smoothstep(0.72, 1.0, side);
	}
	vec4 texel = texture(TEXTURE, uv);
	if (layer == 1) {
		float light = max(texel.r, texel.g);
		COLOR = vec4(texture(sword_palette, vec2(light, 0.45)).rgb * vec3(1.0, 0.8509804, 0.09019608), texel.a * strength);
	} else if (layer == 2) {
		float light = texel.r;
		vec3 fire = texture(fire_palette, vec2(light, 0.125)).rgb;
		COLOR = vec4(fire * light, mask * strength);
	} else if (layer == 3) {
		COLOR = vec4(vec3(0.9, 0.28, 0.035) * texel.r, mask * strength * 0.4);
	} else if (layer == 4) {
		COLOR = vec4(texel.rgb * vec3(1.0, 0.63, 0.03), texel.a * strength);
	} else {
		COLOR = vec4(texel.rgb, texel.a * strength);
	}
	COLOR *= tint;
}
