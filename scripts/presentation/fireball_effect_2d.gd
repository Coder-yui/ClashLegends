extends RefCounted
## 火焰弹及瞬时范围提示。尺寸、拖尾和淡出只参与绘制。

static func draw_flight(canvas: Node2D, center: Vector2, direction: Vector2, radius: float) -> void:
	var side := direction.orthogonal()
	var phase := float(Time.get_ticks_msec()) * 0.014
	# 短、低透明度的收尖拖尾，避免连续火柱遮住目标。
	for index in range(6, 0, -1):
		var t := float(index) / 6.0
		var point := center - direction * radius * (0.6 + t * 1.8)
		point += side * sin(phase + t * 4.0) * radius * 0.12 * t
		canvas.draw_circle(point, radius * (0.65 - t * 0.48), Color(1.0, 0.24 + 0.25 * (1.0 - t), 0.025, (1.0 - t * 0.8) * 0.32))
	canvas.draw_circle(center, radius * 1.3, Color(1.0, 0.20, 0.015, 0.13))
	# 不规则火舌朝后伸展；主体轮廓仍保持紧凑。
	for index in range(5):
		var angle := TAU * float(index) / 5.0 + phase * 0.18
		var offset := Vector2.from_angle(angle) * radius * 0.55
		var tip := center + offset - direction * radius * (0.9 + 0.2 * sin(phase + index))
		canvas.draw_colored_polygon(PackedVector2Array([center + offset + side * radius * 0.35, tip, center + offset - side * radius * 0.35]), Color(1.0, 0.32, 0.025, 0.65))
	canvas.draw_circle(center, radius, Color(1.0, 0.27, 0.025))
	canvas.draw_circle(center + direction * radius * 0.12, radius * 0.76, Color(1.0, 0.61, 0.06))
	canvas.draw_circle(center + direction * radius * 0.22, radius * 0.46, Color(1.0, 0.88, 0.36))
	canvas.draw_circle(center + direction * radius * 0.29, radius * 0.22, Color(1.0, 0.98, 0.76))

static func draw_impact(canvas: Node2D, effect: Dictionary) -> void:
	var center: Vector2 = effect.pos
	var radius := float(effect.radius)
	var remaining := clampf(float(effect.timer) / maxf(float(effect.duration), 0.001), 0.0, 1.0)
	var alpha := smoothstep(0.0, 0.75, remaining)
	# 第一帧即完整显示权威范围；描边向内，外缘不超出半径。
	canvas.draw_circle(center, radius, Color(1.0, 0.35, 0.035, 0.18 * alpha))
	canvas.draw_arc(center, maxf(radius - 3.0, 0.0), 0.0, TAU, 64, Color(1.0, 0.24, 0.015, 0.25 * alpha), 6.0, true)
	canvas.draw_arc(center, maxf(radius - 1.0, 0.0), 0.0, TAU, 64, Color(1.0, 0.73, 0.20, 0.95 * alpha), 2.0, true)
	canvas.draw_circle(center, radius * 0.24, Color(1.0, 0.90, 0.52, pow(remaining, 3.0) * 0.7))
