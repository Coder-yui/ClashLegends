extends RefCounted
## 跟随士兵的金黄回复光：脚下光环和向上飘动的十字，不参与治疗结算。
static func draw_effect(canvas: Node2D, progress: float) -> void:
	var alpha := 0.35 * sin(PI * clampf(progress, 0.0, 1.0))
	canvas.draw_circle(Vector2.ZERO, 24.0, Color(1.0, 0.72, 0.04, 0.18 * alpha))
	canvas.draw_arc(Vector2.ZERO, 21.0 + progress * 8.0, 0, TAU, 40, Color(1.0, 0.83, 0.12, alpha), 2.5, true)
	for i in range(5):
		var pos := Vector2((i - 2) * 9.0, -12.0 - progress * 55.0 - float(i % 2) * 12.0)
		var tint := Color(1.0, 0.88, 0.18, alpha)
		canvas.draw_line(pos - Vector2(4, 0), pos + Vector2(4, 0), tint, 2.5, true)
		canvas.draw_line(pos - Vector2(0, 4), pos + Vector2(0, 4), tint, 2.5, true)
