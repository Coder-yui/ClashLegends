class_name GrowthEffect2D
extends RefCounted
## 自制花叶效果：只绘制权威成长状态和成功获得事件，不驱动击退/召唤。

static func _ellipse(center: Vector2, radius: float, begin: float = 0.0, end: float = TAU) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 49:
		var angle := lerpf(begin, end, float(i) / 48.0)
		points.append(center + Vector2(cos(angle), sin(angle) * 0.52) * radius)
	return points

static func _leaf(canvas: Node2D, center: Vector2, angle: float, size: float, color: Color, squash: float = 1.0) -> void:
	var points := PackedVector2Array()
	for i in 17:
		var t := TAU * float(i) / 16.0
		var local := Vector2(cos(t) * size, sin(t) * absf(sin(t)) * size * 0.43 * squash)
		points.append(center + local.rotated(angle))
	canvas.draw_colored_polygon(points, color)
	var axis := Vector2.from_angle(angle) * size * 0.8
	canvas.draw_line(center - axis, center + axis, Color(0.91, 1.0, 0.77, color.a * 0.7), 0.8, true)

static func draw_wave(canvas: Node2D, skills: RefCounted, effect: Dictionary) -> void:
	var progress := clampf(1.0 - float(effect.timer) / float(effect.duration), 0.0, 1.0)
	var fade := pow(1.0 - progress, 0.9)
	var center: Vector2 = skills.project_height(effect.pos, float(effect.height))
	var reach := float(effect.radius) * (0.16 + 0.92 * (1.0 - pow(1.0 - progress, 2.0)))
	canvas.draw_polyline(_ellipse(center, reach), Color(0.76, 0.67, 0.97, 0.30 * fade), 15.0, true)
	canvas.draw_polyline(_ellipse(center, reach), Color(0.92, 0.91, 1.0, 0.85 * fade), 3.4, true)
	canvas.draw_polyline(_ellipse(center, reach * 0.83), Color(0.78, 0.91, 0.70, 0.42 * fade), 2.0, true)
	for i in 8:
		var angle := TAU * float(i) / 8.0 + 0.24
		var drift := angle + sin(progress * PI) * (0.22 if i % 2 == 0 else -0.22)
		var distance := reach * (0.80 + float(i % 3) * 0.10)
		var point: Vector2 = skills.project_height(effect.pos, float(effect.height) + sin(progress * PI) * 0.55)
		point += Vector2(cos(drift), sin(drift) * 0.52) * distance
		var color := Color(0.72, 0.96, 0.52, fade * 0.98)
		_leaf(canvas, point, angle + progress * (5.0 if i % 2 else -4.0), 8.0 + float(i % 3) * 1.5, color, 0.45 + absf(cos(progress * 9.0 + i)) * 0.55)
