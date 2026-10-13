extends RefCounted
## 自制紫色渐变弹体；从紫色头部向后渐变为白色收尖拖尾。
static func draw_flight(canvas: Node2D, center: Vector2, direction: Vector2) -> void:
	var forward := direction.normalized()
	var side := forward.orthogonal()
	var purple := Color(0.50, 0.10, 0.88)
	var white := Color(0.98, 0.94, 1.0)
	for i in 20:
		var t0 := float(i) / 20.0
		var t1 := float(i + 1) / 20.0
		var a := center - forward * (3.0 + 31.0 * t0)
		var b := center - forward * (3.0 + 31.0 * t1)
		var w0 := 4.2 * pow(1.0 - t0, 0.7)
		var w1 := 4.2 * pow(1.0 - t1, 0.7)
		var c0 := purple.lerp(white, t0)
		var c1 := purple.lerp(white, t1)
		c0.a = 0.85 * (1.0 - 0.65 * t0)
		c1.a = 0.85 * (1.0 - 0.65 * t1)
		canvas.draw_polygon(PackedVector2Array([a+side*w0,b+side*w1,b-side*w1,a-side*w0]), PackedColorArray([c0,c1,c1,c0]))
	# 同心柔边从深紫外缘过渡到浅紫中心，保持紧凑轮廓。
	for i in range(12, 0, -1):
		var t := float(i) / 12.0
		var color := Color(0.83,0.57,1.0).lerp(Color(0.35,0.04,0.70),t)
		color.a = 0.12 if i > 9 else 0.9
		canvas.draw_circle(center, 6.0*t,color,true,-1.0,true)
