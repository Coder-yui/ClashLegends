extends Control
## 16px锁形，避免字体字形缺失；不接收输入。
func _draw() -> void:
	draw_arc(Vector2(9, 7), 3.0, PI, TAU, 12, Color.WHITE, 1.6, true)
	draw_style_box(_body(), Rect2(4, 7, 10, 7))
	draw_line(Vector2(9, 9), Vector2(9, 12), Color(0.1, 0.14, 0.2), 1.5)
func _body() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.94, 1)
	style.set_corner_radius_all(2)
	return style
