extends RefCounted
## 共用电磁光弹绘制，位置由调用方权威弹体或表现数据提供。
static func draw_effect(canvas: CanvasItem, center: Vector2, direction: Vector2, effect: Dictionary) -> void:
	var forward := Vector2.UP if direction.length_squared() < 0.001 else direction.normalized()
	var side := Vector2(-forward.y, forward.x)
	var visual_width := maxf(float(effect.get("projectile_visual_width", effect.get("far_width", 24.0))), 4.0)
	var half_width := visual_width * 0.5
	var half_length := 25.0
	# 宽外辉光与权威路径同宽，核心和双股电弧构成电磁波光弹；全部仅参与绘制。
	canvas.draw_line(center - forward * half_length, center + forward * half_length, Color(0.05, 0.46, 1.0, 0.16), visual_width, true)
	canvas.draw_line(center - forward * (half_length - 2.0), center + forward * (half_length - 2.0), Color(0.10, 0.78, 1.0, 0.58), visual_width * 0.52, true)
	canvas.draw_line(center - forward * (half_length - 4.0), center + forward * (half_length - 4.0), Color(0.82, 0.98, 1.0, 0.96), visual_width * 0.16, true)
	for polarity in [-1.0, 1.0]:
		var wave_points := PackedVector2Array()
		for index in range(9):
			var ratio := float(index) / 8.0
			var longitudinal := lerpf(-half_length, half_length, ratio)
			var amplitude: float = sin(ratio * TAU * 2.0) * half_width * 0.48 * polarity
			wave_points.append(center + forward * longitudinal + side * amplitude)
		canvas.draw_polyline(wave_points, Color(0.42, 0.92, 1.0, 0.90), 1.8, true)
	var head := center + forward * half_length
	canvas.draw_circle(head, half_width, Color(0.08, 0.58, 1.0, 0.22))
	canvas.draw_arc(head, half_width * 0.82, 0.0, TAU, 28, Color(0.54, 0.96, 1.0, 0.92), 2.2, true)
	canvas.draw_circle(head, maxf(half_width * 0.25, 2.0), Color(0.94, 1.0, 1.0, 1.0))

