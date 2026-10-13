extends RefCounted
## 屏幕朝向的随身致盲标识；仅消费状态，不推进致盲次数。
static func draw_effect(canvas: Node2D, origin: Vector2) -> void:
	canvas.draw_set_transform(origin, -canvas.get_global_transform_with_canvas().get_rotation(), Vector2.ONE)
	var ink := Color(0.10, 0.06, 0.17, 0.95)
	var eye := PackedVector2Array()
	for i in 33:
		var angle := float(i) / 32.0 * TAU
		eye.append(Vector2(cos(angle) * 12.0, sin(angle) * absf(sin(angle)) * 7.0))
	canvas.draw_colored_polygon(eye, Color(0.10, 0.06, 0.17, 0.65))
	canvas.draw_polyline(eye, ink, 5.0, true)
	canvas.draw_polyline(eye, Color(0.96, 0.91, 1.0), 2.2, true)
	canvas.draw_circle(Vector2.ZERO, 3.5, Color(0.96, 0.91, 1.0))
	canvas.draw_line(Vector2(-10, 11), Vector2(10, -11), ink, 6.0, true)
	canvas.draw_line(Vector2(-10, 11), Vector2(10, -11), Color(0.79, 0.49, 1.0), 3.0, true)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
