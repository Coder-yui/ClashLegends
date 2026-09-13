shader_type canvas_item;

// 水晶凹槽由 3D 模型负责遮挡，背景不再按固定屏幕坐标挖孔。
void fragment() {
	COLOR = texture(TEXTURE, UV);
}
