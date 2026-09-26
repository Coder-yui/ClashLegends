extends RefCounted
## 通用受疗反馈：沿用恕瑞玛回复光的光环 / 上浮十字，淡绿、小范围、纯表现。
const DURATION := 0.7

static func draw_effect(canvas: Unit, progress: float) -> void:
	var t := clampf(progress, 0.0, 1.0)
	var alpha := 0.62 * sin(PI * t)
	canvas.draw_set_transform(canvas.status_effect_origin(), -canvas.get_global_transform_with_canvas().get_rotation(), Vector2.ONE)
	canvas.draw_arc(Vector2.ZERO, 17.0 + t * 5.0, 0, TAU, 32, Color(0.48, 0.9, 0.64, alpha * 0.55), 1.6, true)
	# 每个十字独立的出生延迟、上浮距离和淡出，不整排同步升起。
	var delays := [0.0, 0.13, 0.26]
	var offsets := [-17.0, 18.0, 1.0]
	for i in 3:
		var age := t * DURATION - float(delays[i])
		var lifetime := 0.43 - float(i) * 0.02
		if age <= 0.0 or age >= lifetime: continue
		var rise := age / lifetime
		var pos := Vector2(float(offsets[i]), -22.0 - rise * (25.0 + float(i) * 3.0))
		var tint := Color(0.63, 1.0, 0.75, 0.76 * sin(PI * rise))
		canvas.draw_line(pos - Vector2(3.2, 0), pos + Vector2(3.2, 0), tint, 2.0, true)
		canvas.draw_line(pos - Vector2(0, 3.2), pos + Vector2(0, 3.2), tint, 2.0, true)
	canvas.draw_set_transform(canvas._vis_offset, 0.0, Vector2.ONE)
