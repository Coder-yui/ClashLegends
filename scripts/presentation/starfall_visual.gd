extends RefCounted
## 星落/天瀑纯绘制。只读取事件进度；不创建伤害、碰撞或随机战斗状态。
const BLUE := Color(0.24, 0.66, 1.0)
const VIOLET := Color(0.51, 0.32, 1.0)
const GOLD := Color(1.0, 0.79, 0.35)
const WHITE := Color(0.91, 0.98, 1.0)

static func tint(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))

static func star(view: Node2D, pos: Vector2, size: float, color: Color) -> void:
	view.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0, -size), pos + Vector2(size * 0.18, -size * 0.18),
		pos + Vector2(size * 0.65, 0), pos + Vector2(size * 0.18, size * 0.18),
		pos + Vector2(0, size), pos + Vector2(-size * 0.18, size * 0.18),
		pos + Vector2(-size * 0.65, 0), pos + Vector2(-size * 0.18, -size * 0.18)]), color)

static func glow(view: Node2D, pos: Vector2, radius: float, color: Color, alpha: float) -> void:
	for layer in range(6, 0, -1):
		view.draw_circle(pos, radius * float(layer) / 3.0, tint(color, alpha * 0.045 * float(7 - layer)))

static func draw_effect(view: Node2D, effect: Dictionary) -> void:
	var center: Vector2 = effect.pos
	var radius := float(effect.length)
	var progress := 1.0 - clampf(float(effect.timer) / maxf(float(effect.duration), 0.001), 0.0, 1.0)
	var shape := String(effect.shape)
	var strong := shape.ends_with("strong")
	var accent := GOLD if strong else BLUE
	if shape == "shockwave":
		var wave := lerpf(float(effect.width), radius, progress)
		var alpha := pow(1.0 - progress, 1.4)
		# 波头就是实际传播半径；后面的光带只作余辉，不提前越过波头。
		for layer in 5:
			view.draw_arc(center, maxf(1.0, wave - layer * 8.0), 0, TAU, 160, tint(VIOLET.lerp(BLUE, float(layer) / 5), alpha * 0.12), 12, true)
		view.draw_arc(center, wave, 0, TAU, 160, tint(WHITE, alpha * 0.9), 2, true)
		view.draw_arc(center, maxf(1, wave - 6), 0, TAU, 160, tint(GOLD, alpha * 0.7), 3, true)
		for i in 32:
			var angle := TAU * float(i) / 32 + 0.13
			star(view, center + Vector2.from_angle(angle) * maxf(0, wave - 15), 3.5 + 2 * sin(i * 4.1), tint(WHITE, alpha * 0.7))
		return
	if shape.begins_with("star_impact"):
		var fade := pow(1.0 - progress, 2.0)
		var spread := 1.0 - pow(1.0 - progress, 3.0)
		glow(view, center, radius * (0.18 + 0.45 * spread), accent, fade)
		glow(view, center, radius * 0.4, VIOLET, fade * 0.7)
		view.draw_arc(center, maxf(1, radius * spread), 0, TAU, 96, tint(accent, fade), 4, true)
		view.draw_arc(center, maxf(1, radius * spread * 0.85), 0, TAU, 96, tint(WHITE, fade * 0.8), 1.5, true)
		star(view, center, (75.0 if strong else 48.0) * fade, tint(WHITE, fade))
		for i in 22 if strong else 14:
			var angle := float(i) * 2.39996
			var ray := Vector2.from_angle(angle)
			var distance := radius * (0.3 + float(i % 5) * 0.13) * spread
			var pos := center + ray * distance
			view.draw_line(pos - ray * 16 * (1.0 - progress), pos, tint(accent, fade * 0.7), 2, true)
			star(view, pos, 2 + fade * 5, tint(WHITE, fade))
		return
	# 预警边缘始终标出真实范围；内部仅低透明星云和渐亮的轨道。
	var appear := smoothstep(0.0, 0.14, progress)
	var team_color := BLUE if int(effect.team) == 0 else Color(1.0, 0.34, 0.36)
	view.draw_circle(center, radius, tint(VIOLET, 0.035 * appear))
	view.draw_arc(center, radius, 0, TAU, 96, tint(team_color, 0.5 * appear), 1.5, true)
	for i in 3:
		var angle := TAU * i / 3.0 + progress * 0.6
		view.draw_arc(center, radius * 0.88, angle, angle + 1.25, 28, tint(accent, appear * 0.45), 2.0, true)
		star(view, center + Vector2.from_angle(angle) * radius * 0.88, 5, tint(WHITE, appear * 0.7))
	for i in 16:
		var angle := float(i) * 2.39996 + progress * 0.65
		var orbit := radius * (0.25 + float(i % 5) * 0.135) * (1.0 - progress * 0.32)
		star(view, center + Vector2.from_angle(angle) * orbit, 1.5 + 1.5 * sin(progress * PI), tint(BLUE.lerp(GOLD, float(i % 3) / 2.0), 0.65 * appear))
	var fall := smoothstep(0.30, 1.0, progress)
	var height := radius * 2.6 * (1.0 - fall)
	var core := center + Vector2(0, -height)
	var core_size := (18.0 if strong else 11.0) * appear
	var tail := Vector2(-24, -110) * (0.25 + 0.75 * fall)
	for layer in range(5, 0, -1):
		var width := core_size * layer * 0.48
		view.draw_colored_polygon(PackedVector2Array([core + Vector2(-width, 0), core + tail * (1.0 + layer * 0.18), core + Vector2(width, 0)]), tint(accent.lerp(VIOLET, layer / 5.0), appear * 0.075))
	glow(view, core, core_size * 1.7, VIOLET, appear)
	glow(view, core, core_size, accent, appear)
	view.draw_circle(core, core_size * 0.56, tint(WHITE, appear))
	star(view, core, core_size * 1.8, tint(WHITE, appear * 0.95))
	if strong:
		view.draw_arc(core, core_size * 1.4, progress * 3, progress * 3 + 4.6, 40, tint(GOLD, appear * 0.8), 1.5, true)
