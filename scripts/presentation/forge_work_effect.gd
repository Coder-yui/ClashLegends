extends RefCounted
## 纯UI表现：可靠锻造提示启动/取消，不能驱动发锤或增幅。
const DURATION := 3.6
const STRIKE_PERIOD := 0.6
var elapsed := DURATION

func on_cue(cue: StringName) -> void:
	if cue == &"forge:pulse": elapsed = 0.0
	elif cue == &"forge:cancel": elapsed = DURATION

func advance(delta: float, alive: bool) -> void:
	elapsed = minf(DURATION, elapsed + delta) if alive else DURATION

func draw_effect(canvas: Node2D, bar_center: Vector2) -> void:
	if elapsed >= DURATION: return
	var transform := canvas.get_global_transform_with_canvas()
	var center := transform.affine_inverse() * (bar_center - Vector2(0, 28.0 * transform.y.length()))
	var rotation := -transform.get_rotation()
	canvas.draw_set_transform(center, rotation, Vector2.ONE)
	var phase := fposmod(elapsed, STRIKE_PERIOD) / STRIKE_PERIOD
	# 慢抬锤、快落锤、短暂停留：每0.6秒一敲，共六次。
	var lift := smoothstep(0.0, 0.62, phase) if phase < 0.62 else 1.0 - smoothstep(0.62, 0.82, phase)
	var impact := clampf((phase - 0.82) / 0.18, 0.0, 1.0)
	var flash := (1.0 - impact) if phase >= 0.82 else 0.0
	var edge := Color("382820")
	# 铁锭顶面与斜侧面，保持小尺寸下的可读性。
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-13, 5), Vector2(7, 5), Vector2(12, 9), Vector2(-9, 9)]), Color("b4b9bd").lerp(Color("ffd79b"), flash * 0.8))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-9, 9), Vector2(12, 9), Vector2(9, 14), Vector2(-11, 14), Vector2(-13, 5)]), Color("636976"))
	canvas.draw_line(Vector2(-9, 9), Vector2(11, 9), Color("e1aa6b"), 1.3, true)
	canvas.draw_line(Vector2(-12, 15), Vector2(11, 15), edge, 2.0, true)
	if flash > 0.0:
		for i in 5:
			var direction := Vector2.from_angle(-PI + 0.28 + i * 0.65)
			var start := Vector2(-4, 5) + direction * (4.0 + impact * 10.0)
			canvas.draw_line(start, start + direction * 3.0, Color(1.0, 0.65, 0.13, flash), 1.5, true)
	# 复用永久增幅标记的同一把橙色锤子，围绕柄端摆动。
	var pivot := center + Vector2(6, -2).rotated(rotation)
	canvas.draw_set_transform(pivot, rotation - PI * 0.75 + lift * 1.05, Vector2.ONE)
	canvas._draw_team_attack_boost_hammer(Vector2(0, -7).rotated(PI / 4.0))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
