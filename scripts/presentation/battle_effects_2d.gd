class_name BattleEffects2D
extends Node2D
## 只读表现数据绘制；SpellSystem/ActiveSkillEffectSystem 拥有状态。
var spells: RefCounted
var skills: RefCounted

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	for effect in skills.shield_effects:
		var elapsed := float(effect.duration) - float(effect.timer)
		var reach := clampf(elapsed / 0.28, 0.0, 1.0)
		var radius := float(effect.radius) * (1.0 - pow(1.0 - reach, 2.0))
		var alpha := (1.0 - smoothstep(0.23, 0.5, elapsed)) * smoothstep(0.0, 0.035, elapsed)
		var center: Vector2 = effect.pos
		# 快速金黄色波前与柔和内辉光；到达范围边界后淡出，不形成持续伤害圈。
		draw_circle(center, radius, Color(1.0, 0.78, 0.10, 0.055 * alpha))
		draw_arc(center, radius, 0.0, TAU, 96, Color(1.0, 0.69, 0.06, 0.16 * alpha), 16.0, true)
		draw_arc(center, radius, 0.0, TAU, 96, Color(1.0, 0.83, 0.15, 0.80 * alpha), 4.0, true)
		draw_arc(center, maxf(radius - 4.0, 0.0), 0.0, TAU, 96, Color(1.0, 0.96, 0.64, 0.65 * alpha), 1.5, true)

	# 冰冻区域效果
	for fe in spells.freeze_effects:
		var alpha: float = (fe.timer / fe.duration) * 0.25
		draw_circle(fe.pos, fe.radius, Color(0.40, 0.70, 1.00, alpha))
		draw_circle(fe.pos, fe.radius, Color(0.60, 0.85, 1.00, alpha * 0.5), false, 2.0)
	# 强化冰冻的减速阶段在冻结结束后才显示，和权威区域使用相同半径与时长。
	for effect in spells.slow_effects:
		if float(effect.delay) > 0.0:
			continue
		var slow_alpha: float = clampf(float(effect.timer) / maxf(float(effect.duration), 0.001), 0.0, 1.0)
		draw_circle(effect.pos, effect.radius, Color(0.20, 0.48, 0.92, 0.12 * slow_alpha))
		draw_arc(effect.pos, effect.radius, 0.0, TAU, 48, Color(0.38, 0.70, 1.0, 0.72 * slow_alpha), 3.0, true)
	# 治疗术区域效果：淡黄光圈 + 上升的十字光点；过量治疗额外强调同一范围。
	for effect in spells.heal_effects:
		var heal_progress := 1.0 - clampf(float(effect.timer) / maxf(float(effect.duration), 0.001), 0.0, 1.0)
		var heal_remaining := clampf(float(effect.timer) / maxf(float(effect.duration), 0.001), 0.0, 1.0)
		var heal_pos: Vector2 = effect.pos
		var heal_radius := float(effect.radius)
		if bool(effect.get("enhanced", false)):
			# 强化治疗的全图选项扩散到全场；过量治疗只强调落点范围。
			var wave_progress := clampf(heal_progress * 2.2, 0.0, 1.0)
			var wave_target_radius := 1180.0 if bool(effect.get("global_heal", false)) else heal_radius
			var wave_radius := lerpf(heal_radius * 0.35, wave_target_radius, wave_progress)
			var wave_alpha := 0.5 * maxf(1.0 - wave_progress * 1.3, 0.0)
			draw_arc(heal_pos, wave_radius, 0.0, TAU, 64, Color(1.0, 0.93, 0.60, wave_alpha), 4.0, true)
			draw_arc(heal_pos, wave_radius * 0.92, 0.0, TAU, 64, Color(1.0, 0.97, 0.75, wave_alpha * 0.6), 2.0, true)
		draw_circle(heal_pos, heal_radius, Color(1.0, 0.93, 0.60, 0.20 * heal_remaining))
		draw_arc(heal_pos, heal_radius, 0.0, TAU, 48, Color(1.0, 0.96, 0.72, 0.70 * heal_remaining), 3.0, true)
		# 中心圣光与上升的十字光点都是纯表现，不参与任何权威判定。
		draw_circle(heal_pos, 10.0 + 4.0 * sin(heal_progress * PI), Color(1.0, 0.98, 0.85, 0.85 * heal_remaining))
		for index in range(7):
			var mote_angle := TAU * float(index) / 7.0 + 0.35
			var mote_distance := heal_radius * (0.30 + 0.42 * float((index * 3) % 5) / 4.0)
			var mote_pos := heal_pos + Vector2.from_angle(mote_angle) * mote_distance - Vector2(0.0, heal_progress * 44.0)
			var mote_size := 4.5 + 2.0 * (0.5 + 0.5 * sin(heal_progress * PI * 2.0 + float(index)))
			var mote_color := Color(1.0, 0.97, 0.78, 0.85 * heal_remaining)
			draw_line(mote_pos - Vector2(mote_size, 0.0), mote_pos + Vector2(mote_size, 0.0), mote_color, 2.5, true)
			draw_line(mote_pos - Vector2(0.0, mote_size), mote_pos + Vector2(0.0, mote_size), mote_color, 2.5, true)
	# 纳尔 Spell2 使用三边矩形：两条侧边加远端宽边，靠纳尔的近端宽边刻意留空。
	for effect in skills.frontal_effects:
		_draw_frontal_skill_effect(effect)

func _draw_frontal_skill_effect(effect: Dictionary) -> void:
	var source = skills.effect_source(effect)
	var center: Vector2 = effect.get("pos", Vector2.ZERO)
	var forward: Vector2 = effect.get("forward", Vector2.UP)
	var source_radius := float(effect.get("source_radius", 0.0))
	if not bool(effect.get("fixed_position", false)) and source is Unit and is_instance_valid(source):
		center = (source as Unit).get_visual_screen_position()
		source_radius = (source as Unit).body_radius
	if forward.length_squared() < 0.001:
		return
	forward = forward.normalized()
	var side := Vector2(-forward.y, forward.x)
	var near_center := center + forward * source_radius
	var length := maxf(float(effect.get("length", 0.0)), 0.0)
	var far_center := near_center + forward * length
	var remaining_ratio := clampf(float(effect.get("timer", 0.0)) / maxf(float(effect.get("duration", 0.0)), 0.001), 0.0, 1.0)
	var progress := 1.0 - remaining_ratio
	# 技能范围预警可以从施法开始显示，但卡牌/箭矢等纯表现弹体要等到出手 tick 才出现。
	var projectile_progress := progress
	var projectile_visible := true
	var projectile_flight_duration := maxf(float(effect.get("projectile_flight_duration", 0.0)), 0.0)
	if projectile_flight_duration > 0.0:
		var cast_elapsed := progress * maxf(float(effect.get("duration", 0.0)), 0.0)
		var projectile_elapsed := cast_elapsed - maxf(float(effect.get("projectile_launch_delay", 0.0)), 0.0)
		projectile_visible = projectile_elapsed >= -0.0001
		projectile_progress = clampf(projectile_elapsed / projectile_flight_duration, 0.0, 1.0)
	var line_color := Color(0.28, 0.68, 1.0, 0.9) if int(effect.get("team", 0)) == 0 else Color(1.0, 0.34, 0.24, 0.9)
	var fill_color := Color(line_color.r, line_color.g, line_color.b, 0.10 + 0.06 * remaining_ratio)
	var shape := StringName(effect.get("shape", "rectangle"))
	if shape == &"continuous_area":
		var radius := maxf(length, 0.0)
		var pulse := 0.5 + 0.5 * sin(progress * TAU * 2.0)
		draw_circle(center, radius, Color(line_color.r, line_color.g, line_color.b, 0.035 + 0.025 * pulse))
		draw_arc(center, radius, 0.0, TAU, 72, Color(line_color.r, line_color.g, line_color.b, 0.72 * remaining_ratio), 3.0, true)
		draw_arc(center, radius * (0.82 + 0.10 * pulse), 0.0, TAU, 64, Color(1.0, 0.88, 0.36, 0.34 * remaining_ratio), 2.0, true)
		return
	if shape == &"frost_storm":
		var radius := maxf(length, 0.0)
		var pulse := 0.5 + 0.5 * sin(progress * TAU * 2.5)
		var frost_color := Color(0.56, 0.88, 1.0, 0.78 * remaining_ratio)
		draw_circle(center, radius, Color(0.28, 0.68, 1.0, 0.045 + 0.025 * pulse))
		draw_arc(center, radius, 0.0, TAU, 72, frost_color, 3.0, true)
		draw_arc(center, radius * (0.68 + 0.06 * pulse), 0.0, TAU, 64, Color(0.78, 0.96, 1.0, 0.52 * remaining_ratio), 2.0, true)
		for index in range(10):
			var angle := TAU * float(index) / 10.0 + progress * 0.8
			var flake_distance := radius * (0.28 + 0.42 * float((index * 7) % 10) / 9.0)
			var flake_center := center + Vector2.from_angle(angle) * flake_distance
			var flake_size := 3.0 + 2.0 * (0.5 + 0.5 * sin(progress * TAU + float(index)))
			var flake_direction := Vector2.from_angle(angle + PI * 0.25)
			draw_line(flake_center - flake_direction * flake_size, flake_center + flake_direction * flake_size, Color(0.88, 0.98, 1.0, 0.72 * remaining_ratio), 1.5, true)
			draw_line(flake_center - flake_direction.rotated(PI * 0.5) * flake_size, flake_center + flake_direction.rotated(PI * 0.5) * flake_size, Color(0.70, 0.92, 1.0, 0.58 * remaining_ratio), 1.0, true)
		return
	if shape == &"target_circle":
		var radius := length
		# 星落/天瀑的落点需要清晰可辨，但不能用大面积色块遮住圈内人物。
		# 填充最高仅 6% 不透明度，边缘单独保留适中的亮度用于读范围。
		var area_fill_alpha := 0.025 + 0.035 * remaining_ratio
		var area_line_color := Color(line_color.r, line_color.g, line_color.b, 0.52)
		draw_circle(center, radius, Color(line_color.r, line_color.g, line_color.b, area_fill_alpha))
		draw_arc(center, radius, 0.0, TAU, 64, area_line_color, 3.0, true)
		var star_height := radius * lerpf(2.2, 0.0, progress)
		var star_pos := center + Vector2(0.0, -star_height)
		draw_circle(star_pos, 9.0 + 5.0 * progress, Color(1.0, 0.90, 0.48, 0.96))
		draw_line(star_pos + Vector2(0.0, -34.0), star_pos, Color(0.72, 0.90, 1.0, 0.65), 5.0, true)
		return
	if shape == &"shockwave":
		var wave_radius := lerpf(maxf(float(effect.get("width", 0.0)), 0.0), length, progress)
		var wave_alpha := 0.92 * remaining_ratio
		draw_arc(center, wave_radius, 0.0, TAU, 96, Color(0.72, 0.90, 1.0, wave_alpha), 7.0, true)
		draw_arc(center, wave_radius + 7.0, 0.0, TAU, 96, Color(1.0, 0.84, 0.42, wave_alpha * 0.65), 3.0, true)
		return
	if shape == &"projectile_fan":
		# 与权威弹体共用夹角；宽 6px 表示半径 3px 的扫掠路径，目标自身半径由碰撞处理。
		var count := maxi(int(effect.get("projectile_count", 0)), 1)
		for index in count:
			var direction := ProjectileSystem.skill_fan_direction(forward, float(effect.get("arc_degrees", 0.0)), count, index)
			var start := center + direction * source_radius
			var end := start + direction * length
			draw_line(start, end, fill_color, 6.0, true)
			draw_line(start - direction.orthogonal() * 3.0, end - direction.orthogonal() * 3.0, line_color, 1.0, true)
			draw_line(start + direction.orthogonal() * 3.0, end + direction.orthogonal() * 3.0, line_color, 1.0, true)
			draw_arc(end, 3.0, direction.angle() - PI * 0.5, direction.angle() + PI * 0.5, 12, line_color, 1.0, true)
		return
	if shape == &"fan":
		var half_angle := deg_to_rad(float(effect.get("arc_degrees", 0.0)) * 0.5)
		var center_angle := forward.angle()
		var fan_inner_arc := bool(effect.get("fan_inner_arc", false))
		if fan_inner_arc:
			var inner_radius := source_radius
			var outer_radius := inner_radius + length
			var inner_left := center - side * inner_radius
			var inner_right := center + side * inner_radius
			var outer_left := center + Vector2.from_angle(center_angle - half_angle) * outer_radius
			var outer_right := center + Vector2.from_angle(center_angle + half_angle) * outer_radius
			var ring_points := PackedVector2Array([inner_left])
			for index in range(17):
				var outer_angle := lerpf(center_angle - half_angle, center_angle + half_angle, float(index) / 16.0)
				ring_points.append(center + Vector2.from_angle(outer_angle) * outer_radius)
			ring_points.append(inner_right)
			for index in range(16, -1, -1):
				var inner_angle := lerpf(center_angle - PI * 0.5, center_angle + PI * 0.5, float(index) / 16.0)
				ring_points.append(center + Vector2.from_angle(inner_angle) * inner_radius)
			draw_colored_polygon(ring_points, fill_color)
			draw_arc(center, outer_radius, center_angle - half_angle, center_angle + half_angle, 32, line_color, 3.0, true)
			draw_line(inner_left, outer_left, line_color, 2.0, true)
			draw_line(inner_right, outer_right, line_color, 2.0, true)
			draw_arc(center, inner_radius, center_angle - PI * 0.5, center_angle + PI * 0.5, 24, line_color, 2.0, true)
			if projectile_visible:
				var arrow_count := maxi(int(effect.get("projectile_count", 0)), 0)
				var arrow_distance := length * clampf(projectile_progress * 1.25, 0.0, 1.0)
				for index in range(arrow_count):
					var ratio := 0.5 if arrow_count == 1 else float(index) / float(arrow_count - 1)
					var arrow_angle := lerpf(center_angle - half_angle * 0.92, center_angle + half_angle * 0.92, ratio)
					var arrow_direction := Vector2.from_angle(arrow_angle)
					var arrow_pos := center + arrow_direction * (inner_radius + arrow_distance)
					_draw_frontal_projectile(arrow_pos, arrow_direction, effect)
			return
		var center_width := maxf(float(effect.get("center_width", 0.0)), 0.0)
		var center_half_width := center_width * 0.5
		var sector_near_left := near_center - side * center_half_width if center_width > 0.0 else near_center
		var sector_near_right := near_center + side * center_half_width if center_width > 0.0 else near_center
		var left_arc := near_center + Vector2.from_angle(center_angle - half_angle) * length
		var right_arc := near_center + Vector2.from_angle(center_angle + half_angle) * length
		var points := PackedVector2Array([sector_near_left])
		for index in range(17):
			var angle := lerpf(center_angle - half_angle, center_angle + half_angle, float(index) / 16.0)
			points.append(near_center + Vector2.from_angle(angle) * length)
		points.append(sector_near_right)
		draw_colored_polygon(points, fill_color)
		draw_arc(near_center, length, center_angle - half_angle, center_angle + half_angle, 32, line_color, 3.0, true)
		draw_line(sector_near_left, left_arc, line_color, 2.0, true)
		draw_line(sector_near_right, right_arc, line_color, 2.0, true)
		var center_ratio := clampf(float(effect.get("center_ratio", 0.0)), 0.0, 1.0)
		if center_width > 0.0:
			var center_points := PackedVector2Array([
				sector_near_left,
				far_center - side * center_half_width,
				far_center + side * center_half_width,
				sector_near_right,
			])
			var center_fill := Color(0.54, 0.94, 1.0, 0.22 + 0.12 * progress)
			draw_colored_polygon(center_points, center_fill)
			draw_line(center_points[0], center_points[1], Color(line_color.r, line_color.g, line_color.b, 0.72), 1.5, true)
			draw_line(center_points[3], center_points[2], Color(line_color.r, line_color.g, line_color.b, 0.72), 1.5, true)
		elif center_ratio > 0.0:
			var center_half_angle := half_angle * center_ratio
			var center_points := PackedVector2Array([near_center])
			for index in range(9):
				var angle := lerpf(center_angle - center_half_angle, center_angle + center_half_angle, float(index) / 8.0)
				center_points.append(near_center + Vector2.from_angle(angle) * length)
			var center_fill := Color(1.0, 0.96, 0.76, 0.16 + 0.10 * progress)
			draw_colored_polygon(center_points, center_fill)
		if projectile_visible:
			var arrow_count := maxi(int(effect.get("projectile_count", 0)), 0)
			var arrow_distance := length * clampf(projectile_progress * 1.25, 0.0, 1.0)
			for index in range(arrow_count):
				var ratio := 0.5 if arrow_count == 1 else float(index) / float(arrow_count - 1)
				var arrow_angle := lerpf(center_angle - half_angle * 0.92, center_angle + half_angle * 0.92, ratio)
				var arrow_direction := Vector2.from_angle(arrow_angle)
				var arrow_pos := near_center + arrow_direction * arrow_distance
				_draw_frontal_projectile(arrow_pos, arrow_direction, effect)
		return
	var near_half := maxf(float(effect.get("near_width", effect.get("width", 0.0))) * 0.5, 0.0)
	var far_half := maxf(float(effect.get("far_width", effect.get("width", 0.0))) * 0.5, 0.0)
	var near_left := near_center - side * near_half
	var near_right := near_center + side * near_half
	var far_left := far_center - side * far_half
	var far_right := far_center + side * far_half
	draw_colored_polygon(PackedVector2Array([near_left, far_left, far_right, near_right]), fill_color)
	draw_line(near_left, far_left, line_color, 3.0, true)
	draw_line(far_left, far_right, line_color, 3.0, true)
	draw_line(far_right, near_right, line_color, 3.0, true)
	if shape == &"trapezoid":
		draw_line(near_left, near_right, line_color, 3.0, true)
	var center_ratio := clampf(float(effect.get("center_ratio", 0.0)), 0.0, 1.0)
	if center_ratio > 0.0:
		var center_fill := Color(1.0, 0.96, 0.76, 0.16 + 0.10 * progress)
		draw_colored_polygon(PackedVector2Array([
			near_center - side * near_half * center_ratio,
			far_center - side * far_half * center_ratio,
			far_center + side * far_half * center_ratio,
			near_center + side * near_half * center_ratio,
		]), center_fill)
	if projectile_visible:
		var projectile_count := maxi(int(effect.get("projectile_count", 0)), 0)
		for index in range(projectile_count):
			var width_ratio := 0.5 if projectile_count == 1 else float(index) / float(projectile_count - 1)
			var projectile_pos := _frontal_projectile_visual_position(
				effect, center, forward, source_radius, near_half, far_half, width_ratio, projectile_progress
			)
			_draw_frontal_projectile(projectile_pos, forward, effect)

## 定向技能的纯表现弹体从模型炮口飞向权威路径末端；不改变范围轮廓或命中判定。
func _frontal_projectile_visual_position(effect: Dictionary, center: Vector2, forward: Vector2, source_radius: float, near_half: float, far_half: float, width_ratio: float, progress: float) -> Vector2:
	var launch_forward := maxf(float(effect.get("projectile_visual_forward_offset", source_radius)), 0.0)
	var height_offset := Vector2(0.0, -maxf(float(effect.get("projectile_visual_height", 0.0)), 0.0))
	var side := Vector2(-forward.y, forward.x)
	var start := center + forward * launch_forward + side * lerpf(-near_half, near_half, width_ratio) + height_offset
	var end := center + forward * (source_radius + maxf(float(effect.get("length", 0.0)), 0.0)) + side * lerpf(-far_half, far_half, width_ratio) + height_offset
	return start.lerp(end, clampf(progress, 0.0, 1.0))

func _draw_frontal_projectile(center: Vector2, direction: Vector2, effect: Dictionary) -> void:
	var visual := StringName(effect.get("projectile_visual", "arrow"))
	if visual == &"electromagnetic_wave":
		_draw_electromagnetic_wave_projectile(center, direction, effect)
		return
	if visual == &"laser":
		draw_line(center - direction * 18.0, center + direction * 18.0, Color(0.16, 0.76, 1.0, 0.20), 10.0, true)
		draw_line(center - direction * 16.0, center + direction * 16.0, Color(0.28, 0.88, 1.0, 0.92), 5.0, true)
		draw_line(center - direction * 14.0, center + direction * 14.0, Color(0.94, 1.0, 1.0, 1.0), 2.0, true)
		draw_circle(center + direction * 16.0, 4.0, Color(0.86, 1.0, 1.0, 0.96))
		return
	if visual != &"card":
		draw_line(center - direction * 10.0, center + direction * 5.0, Color(0.78, 0.94, 1.0, 0.95), 2.0, true)
		return
	var side := Vector2(-direction.y, direction.x)
	var half_width := 5.0
	var half_height := 9.0
	var points := PackedVector2Array([
		center - direction * half_height - side * half_width,
		center + direction * half_height - side * half_width,
		center + direction * half_height + side * half_width,
		center - direction * half_height + side * half_width,
	])
	draw_colored_polygon(points, Color(1.0, 0.94, 0.58, 0.96))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(0.32, 0.14, 0.08, 0.96), 1.5, true)
	draw_line(center - direction * 2.0, center + direction * 3.0, Color(0.78, 0.24, 0.18, 0.9), 1.5, true)

func _draw_electromagnetic_wave_projectile(center: Vector2, direction: Vector2, effect: Dictionary) -> void:
	preload("res://scripts/presentation/electromagnetic_projectile_2d.gd").draw_effect(self, center, direction, effect)

## 绘制当前卡牌的落点：格子边框用于确认“哪一格”，半透明占位用于确认卡牌大小。
## 这是纯表现层，不会修改部署坐标或战斗状态。
