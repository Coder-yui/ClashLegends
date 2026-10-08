extends Node2D
## 仅消费可靠 card_event；镜面留在释放位置，不影响复制体和权威时钟。
const LIFETIME := 0.5
var elapsed := 0.0
var team := 0

func _ready() -> void:
	z_index = 20

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= LIFETIME:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var alpha := smoothstep(0.0, 0.05, elapsed) * (1.0 - smoothstep(0.3, LIFETIME, elapsed))
	var reveal := lerpf(0.65, 1.0, smoothstep(0.0, 0.07, elapsed))
	var tint := Color(0.45, 0.8, 1.0) if team == 0 else Color(1.0, 0.42, 0.62)
	var highlight := tint.lerp(Color.WHITE, 0.65)
	var center := Vector2(0, -43)
	var points := PackedVector2Array()
	for i in 65:
		var angle := TAU * float(i) / 64.0
		points.append(center + Vector2(cos(angle) * 27.0 * reveal, sin(angle) * 40.0))
	# 镜面中心落在释放点，压平为约57×36px的地面椭圆。
	draw_set_transform(Vector2(0, 19.35), 0.0, Vector2(1.05, 0.45))
	draw_colored_polygon(points, Color(tint.darkened(0.65), 0.66 * alpha))
	draw_polyline(points, Color(tint, 0.15 * alpha), 9, true)
	draw_polyline(points, Color(highlight, alpha), 3, true)
	var inner := PackedVector2Array()
	for point in points: inner.append(center + (point - center) * 0.87)
	draw_polyline(inner, Color(tint, 0.6 * alpha), 1, true)
	# 两条斜向高光，让镜面与普通法术圈有清楚区别。
	var sweep := sin(clampf(elapsed / 0.32, 0, 1) * PI) * 6.0
	draw_line(Vector2(-15 + sweep, -35), Vector2(7 + sweep, -65), Color(highlight, 0.7 * alpha), 4, true)
	draw_line(Vector2(-8 + sweep, -24), Vector2(14 + sweep, -54), Color(highlight, 0.4 * alpha), 2, true)
	var shatter := smoothstep(0.3, LIFETIME, elapsed)
	for i in 6:
		var angle := TAU * float(i) / 6.0
		var point := center + Vector2(cos(angle) * 30, sin(angle) * 40) * (1 + shatter * 0.6)
		var shard := PackedVector2Array([point + Vector2(0, -5), point + Vector2(3, 1), point + Vector2(-2, 4)])
		draw_colored_polygon(shard, Color(highlight, alpha * (0.35 + shatter)))
