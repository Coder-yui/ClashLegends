extends RefCounted
## 状态只读的循环表现：黄色移动拖痕 / 冷灰蓝下落短线。相位刷新不重播。
const ATTACK_SLOW_DENSITY := 0.8
const LOOP_SECONDS := 10.0 # 0.4 / 0.8 / 1.2 Hz 发射与其他状态循环的公共周期。

const TRAIL_SPACING := 12.0
const TRAIL_LIFETIME := 0.85
var trails: Array[Dictionary] = []
var _distance := 0.0
var _last_origin := Vector2(INF, INF)

func advance(canvas: Unit, delta: float) -> void:
	for trail in trails:
		trail.age += delta
	trails = trails.filter(func(trail: Dictionary) -> bool: return trail.age < TRAIL_LIFETIME)
	var origin := canvas.to_global(canvas.status_effect_origin())
	if canvas.hp <= 0.0:
		trails.clear()
	if not canvas.movement_slow_effect_visible() or not _last_origin.is_finite():
		_distance = 0.0
		_last_origin = origin
		return
	# 用已过滤传送/击退的实际渲染位移累计距离；投影升降不增加发射量。
	var travel := canvas._status_visual_velocity.length() * delta
	var forward := canvas._status_visual_velocity.normalized()
	var radius := clampf(canvas.visual_radius + 4.0, 18.0, 32.0)
	var next := TRAIL_SPACING - _distance
	while next <= travel:
		var center := _last_origin.lerp(origin, next / travel) - forward * radius * 0.3
		trails.append({"center": center, "forward": forward, "radius": radius, "age": 0.0})
		next += TRAIL_SPACING
	_distance = fposmod(_distance + travel, TRAIL_SPACING)
	_last_origin = origin

func draw_trails(canvas: Unit) -> void:
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for trail in trails:
		var forward: Vector2 = trail.forward
		var side := forward.orthogonal()
		var alpha := (1.0 - float(trail.age) / TRAIL_LIFETIME) * 0.80
		for mirror in [-1.0, 1.0]:
			var start: Vector2 = trail.center + side * mirror * float(trail.radius) * 0.35
			var end: Vector2 = start - forward * 8.0 + side * mirror * 7.0
			canvas.draw_line(canvas.to_local(start), canvas.to_local(end), Color(0.65, 0.38, 0.04, alpha * 0.4), 4.8, true)
			canvas.draw_line(canvas.to_local(start), canvas.to_local(end), Color(1.0, 0.87, 0.38, alpha), 2.4, true)
	canvas.draw_set_transform(canvas._vis_offset, 0.0, Vector2.ONE)

static func draw_effect(canvas: Unit, phase: float, _movement_slow: bool, attack_slow: bool) -> void:
	var rotation := -canvas.get_global_transform_with_canvas().get_rotation()
	canvas.draw_set_transform(canvas.status_effect_origin(), rotation, Vector2.ONE)
	var radius := clampf(canvas.visual_radius + 4.0, 18.0, 32.0)
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
