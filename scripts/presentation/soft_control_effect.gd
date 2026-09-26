extends RefCounted
## 状态只读的循环表现：黄色移动拖痕 / 冷灰蓝下落短线。相位刷新不重播。
const ATTACK_SLOW_DENSITY := 0.8
const LOOP_SECONDS := 10.0 # 0.4 / 0.8 / 1.2 Hz 发射与其他状态循环的公共周期。

static func draw_effect(canvas: Unit, phase: float, movement_slow: bool, attack_slow: bool) -> void:
	var rotation := -canvas.get_global_transform_with_canvas().get_rotation()
	canvas.draw_set_transform(canvas.status_effect_origin(), rotation, Vector2.ONE)
	var radius := clampf(canvas.visual_radius + 4.0, 18.0, 32.0)
	if movement_slow:
		var forward := canvas._status_visual_velocity.rotated(-rotation).normalized()
		var side := forward.orthogonal()
		# 少量贴脚拖痕朝移动反向淡出，静止时立即隐藏，不画持续光圈。
		for i in 3:
			var t := fposmod(phase * 1.5 + float(i) / 3.0, 1.0)
			var p := -forward * (radius * 0.3 + t * 22.0) + side * float(i - 1) * 9.0
			var alpha := sin(PI * t) * 0.80
			var points := PackedVector2Array([p + side * 3.5, p - forward * 3.0, p - forward * 8.0 - side * 2.0])
			canvas.draw_polyline(points, Color(0.65, 0.38, 0.04, alpha * 0.4), 4.8, true)
			canvas.draw_polyline(points, Color(1.0, 0.87, 0.38, alpha), 2.4, true)
	if attack_slow:
		# 固定种子的错落分布与不同下落周期；不逐帧随机，避免闪烁。
		var offsets := [-0.94, 0.43, -0.36, 0.91, -0.68, 0.12, 0.68]
		for i in offsets.size():
			var cycle := fposmod(phase * (0.5 + float(i % 3) * 0.5) * ATTACK_SLOW_DENSITY + float(i) * 0.381966, 1.0)
			# 每条流保留原下落速度与寿命，周期后段留空，平均密度降低 20%。
			if cycle >= ATTACK_SLOW_DENSITY: continue
			var t := cycle / ATTACK_SLOW_DENSITY
			var p := Vector2(float(offsets[i]) * radius, lerpf(-52.0 - float(i % 3) * 4.0, -5.0, t))
			var tail := Vector2(0.0, -(4.0 + float(i % 3)) * 1.3) # 延长 30%，竖直短线沿固定 X 下落。
			var alpha := sin(PI * t) * 0.84
			canvas.draw_line(p + tail, p, Color(0.28, 0.39, 0.51, alpha * 0.4), 4.2, true)
			canvas.draw_line(p + tail, p, Color(0.76, 0.88, 1.0, alpha), 2.0, true)
	canvas.draw_set_transform(canvas._vis_offset, 0.0, Vector2.ONE)
