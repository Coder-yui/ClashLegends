extends RefCounted
## 有实体箭头和尾翼的弩箭；颜色/尺寸只影响绘制。
static func draw_bolt(canvas: Node2D, pos: Vector2, direction: Vector2, venom: bool, travelled: float = 0.0) -> void:
	if venom:
		_draw_venom(canvas, pos, direction, travelled)
		return
	var side := direction.orthogonal()
	var length := 9.0
	var green := Color(0.48, 0.66, 0.24)
	var tip := pos + direction * length
	var tail := pos - direction * length
	canvas.draw_line(tail, tip, Color(0.16, 0.12, 0.07), 3.8, true)
	canvas.draw_line(tail, tip, green, 2.2, true)
	canvas.draw_colored_polygon(PackedVector2Array([tip + direction * 4.0, tip - direction * 6.0 + side * 4.0, tip - direction * 4.0, tip - direction * 6.0 - side * 4.0]), green)
	for sign_value in [-1.0, 1.0]:
		canvas.draw_colored_polygon(PackedVector2Array([tail, tail + direction * 6.0, tail + direction * 2.0 + side * sign_value * 4.5]), Color(0.48, 0.35, 0.19))

static func _draw_venom(canvas: Node2D, pos: Vector2, direction: Vector2, travelled: float) -> void:
	var length := minf(maxf(travelled, 0.0), 150.0)
	# 拖尾只覆盖已经飞过的路径，不能伸到炮口身后或预告尚未命中的整条射线。
	for i in 12:
		var a := float(i) / 12.0
		var b := float(i + 1) / 12.0
		var start := pos - direction * length * a
		var end := pos - direction * length * b
		var fade := pow(1.0 - a, 1.3)
		canvas.draw_line(start, end, Color(0.02, 0.34, 0.07, 0.35 * fade), 10.0, true)
		canvas.draw_line(start, end, Color(0.06, 0.65, 0.12, 0.85 * fade), 4.0, true)
		canvas.draw_line(start, end, Color(0.48, 0.95, 0.24, fade), 1.5, true)
	canvas.draw_circle(pos, 3.0, Color(0.14, 0.72, 0.12, 0.65))
