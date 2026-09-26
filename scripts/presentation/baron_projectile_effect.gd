extends RefCounted
## 自制紫色包裹层；保留原弹体色芯，只读取已投影的位置与方向。
static func draw_flight(canvas: Node2D, position: Vector2, direction: Vector2, radius: float, core: Color) -> void:
	var r := maxf(radius, 3.0)
	for i in range(5, 0, -1):
		var t := float(i) / 5.0
		canvas.draw_circle(position - direction * r * 3.8 * t, r * (0.95 - t * 0.55), Color(0.58, 0.12, 0.95, 0.25 * (1.0 - t * 0.65)))
	canvas.draw_circle(position, r * 2.0, Color(0.48, 0.06, 0.85, 0.16))
	canvas.draw_circle(position, r * 1.55, Color(0.66, 0.17, 1.0, 0.38))
	canvas.draw_circle(position, r * 1.18, Color(0.77, 0.38, 1.0, 0.80))
	canvas.draw_circle(position, r * 0.82, core)
	canvas.draw_arc(position, r * 1.32, -0.6, 2.1, 18, Color(0.94, 0.70, 1.0, 0.85), 1.2, true)
	canvas.draw_circle(position - direction * r * 0.20, r * 0.30, Color(0.96, 0.82, 1.0, 0.95))

static func draw_burst(canvas: Node2D, effect: Dictionary) -> void:
	var progress := 1.0 - float(effect.timer) / float(effect.duration)
	var fade := 1.0 - progress
	var cast := String(effect.visual).ends_with("_cast")
	var size := 9.0 if cast else 17.0
	var position: Vector2 = effect.pos
	canvas.draw_circle(position, size * (0.3 + progress * 0.7), Color(0.62, 0.12, 0.95, fade * 0.20))
	canvas.draw_arc(position, size * (0.4 + progress), 0, TAU, 32, Color(0.80, 0.40, 1.0, fade * 0.65), 1.5, true)
