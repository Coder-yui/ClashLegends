extends RefCounted
## 通用眩晕：头顶紫色扁平漩涡，持续旋转；与骨骼冻结和权威计时独立。
static func draw_effect(canvas: Node2D, origin: Vector2, phase: float) -> void:
	canvas.draw_set_transform(origin, -canvas.get_global_transform_with_canvas().get_rotation(), Vector2.ONE)
	var points := PackedVector2Array()
	for i in 49:
		var t := float(i) / 48.0
		var angle := phase * TAU + t * TAU * 1.55
		var radius := lerpf(2.0, 13.0, t)
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.43))
	canvas.draw_polyline(points, Color(0.22, 0.06, 0.36, 0.32), 4.5, true)
	canvas.draw_polyline(points, Color(0.72, 0.40, 1.0, 0.85), 2.0, true)
	canvas.draw_circle(points[48], 1.8, Color(0.91, 0.76, 1.0, 0.9))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
