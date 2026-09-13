extends RefCounted
## 环身枪芒：仅绘制，调用方提供权威范围和只读动作进度。
const DURATION := 0.45

static func draw_effect(canvas: CanvasItem, radius: float, facing: Vector2, progress: float) -> void:
	var t := clampf(progress, 0.0, 1.0)
	var alpha := smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.55, 1.0, t))
	var head := facing.angle() - 2.4 + TAU * minf(t / 0.72, 1.0)
	var span := lerpf(0.35, 4.4, minf(t * 5.0, 1.0))
	var reach := radius * lerpf(0.78, 1.0, minf(t * 4.0, 1.0))
	# 三层渐细弧带：透明暖金晕、金色主体、窄象牙白刃口。
	_ribbon(canvas, reach, head, span, radius * 0.22, Color(1.0, 0.66, 0.18, alpha * 0.12))
	_ribbon(canvas, reach, head, span, radius * 0.105, Color(1.0, 0.77, 0.30, alpha * 0.66))
	_ribbon(canvas, reach, head, span * 0.94, radius * 0.028, Color(1.0, 0.97, 0.79, alpha * 0.95))
	# 内侧短余波留出人物中心，不画持续护卫圆圈。
	_ribbon(canvas, reach * 0.76, head - 0.4, span * 0.65, radius * 0.028, Color(1.0, 0.83, 0.46, alpha * 0.32))
	for i in range(9):
		var angle := facing.angle() + float(i) * 2.39996
		var distance := radius * (0.67 + 0.30 * t + 0.035 * float(i % 3))
		var point := Vector2.from_angle(angle) * distance
		var tangent := Vector2.from_angle(angle + PI * 0.5)
		var size := (2.0 + float(i % 3)) * sin(PI * t)
		canvas.draw_line(point - tangent * size, point + tangent * size, Color(1.0, 0.88, 0.55, alpha * 0.65), 1.2, true)

static func _ribbon(canvas: CanvasItem, radius: float, head: float, span: float, width: float, tint: Color) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	# Each quad has a tapered width and opacity, avoiding blunt arc endpoints.
	for i in range(56):
		points.clear()
		colors.clear()
		for corner in range(4):
			var u := float(i + (1 if corner in [1, 2] else 0)) / 56.0
			var envelope := pow(sin(PI * u), 0.65)
			var angle := head - span + span * u
			var r := radius - (width * envelope if corner >= 2 else 0.0)
			points.append(Vector2.from_angle(angle) * r)
			colors.append(Color(tint, tint.a * pow(u, 0.6) * envelope))
		canvas.draw_polygon(points, colors)
