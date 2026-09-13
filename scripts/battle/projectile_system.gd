class_name ProjectileSystem
extends Node2D
## 主机权威弹体模拟与客户端弹体插值/绘制。伤害仍回到 Battle Controller 统一结算。
signal skill_hit(source: Dictionary, action: String, position: Vector2)
signal launch_audio_started(id: int, source: Dictionary, position: Vector2)
signal launch_audio_stopped(id: int)
signal launch_audio_cleared()
signal impact_added(position: Vector2, radius: float, color: Color, visual: StringName)
signal visuals_cleared()

const MUZZLE_FORWARD_GAP := 5.0 * CardDB.CHARACTER_SCALE_MULTIPLIER

var projectiles: Dictionary = {}
var client_projectiles: Dictionary = {}
var impact_effects: Array[Dictionary] = []
var _next_id := 1
var _context: BattleContext

func setup(context: BattleContext) -> void:
	_context = context

func launch(attacker: Node2D, target: Node2D, amount: float, projectile_speed: float, splash_radius: float, knockback: float, projectile_color: Color, effects: Dictionary = {}) -> void:
	if target == null or not is_instance_valid(target) or target.hp <= 0.0:
		return
	if target is Unit and (target as Unit).is_hidden_from(attacker):
		return
	effects = effects.duplicate(true)
	if (attacker is Unit or attacker is Tower) and not effects.has("presentation_source"):
		effects["presentation_source"] = PresentationConfig.attack_source(attacker)
	var source_form_index := (attacker as Unit).form_index if attacker is Unit else -1
	var first_strike := bool(effects.get("first_strike", false))
	if attacker is Unit:
		_context.notify_unit_audio_event(attacker as Unit, &"first_strike:missile_cast" if first_strike else &"attack_missile_cast", attacker.global_position)
	if projectile_speed <= 0.0:
		if first_strike and attacker is Unit:
			_context.notify_unit_audio_event(attacker as Unit, &"first_strike:missile_launch", attacker.global_position)
		_context.resolve_attack_hit(attacker.team, attacker.global_position, target, amount, splash_radius, knockback, attacker, attacker.global_position, source_form_index, effects)
		return
	var direction := attacker.global_position.direction_to(target.global_position)
	var projectile_visual := &"orb"
	var projectile_visual_height := 0.0
	var projectile_visual_scale := 1.0
	var projectile_impact_visual := &""
	var visual_offset := Vector2.ZERO
	var visual_offset_follows_trajectory := false
	if attacker is Unit:
		projectile_visual = StringName((attacker as Unit).projectile_visual)
		projectile_visual_height = (attacker as Unit).projectile_visual_height
		projectile_visual_scale = (attacker as Unit).projectile_visual_scale
		projectile_impact_visual = (attacker as Unit).projectile_impact_visual
		if attacker.active_buff_timer > 0.0 and attacker.active_buff_projectile_visual != &"":
			projectile_visual = attacker.active_buff_projectile_visual
			projectile_impact_visual = &"baron_siege_hit"
		var forward_offset := (attacker as Unit).projectile_visual_forward_offset
		if forward_offset > 0.0:
			visual_offset = direction * forward_offset
			visual_offset_follows_trajectory = true
	elif attacker is Tower:
		projectile_visual = &"tower_orb"
		visual_offset = (attacker as Tower).projectile_visual_offset
		visual_offset_follows_trajectory = visual_offset.length_squared() > 0.001
	var start_position := attacker.global_position
	if projectile_visual in [&"arrow", &"needle", &"boomerang", &"ice_cone"]:
		start_position += direction * (attacker.body_radius + MUZZLE_FORWARD_GAP)
	var id := _next_id
	_next_id += 1
	projectiles[id] = {
		"pos": start_position, "target": target, "attacker": attacker,
		"source_form_index": source_form_index, "source_pos": attacker.global_position,
		"team": attacker.team, "damage": amount, "speed": projectile_speed,
		"effects": effects.duplicate(true),
		"first_strike": first_strike,
		"splash": splash_radius, "knockback": knockback, "color": projectile_color,
		"radius": 7.0 if projectile_visual == &"tower_orb" else (3.0 if projectile_visual == &"arrow" else 4.0),
		"visual": projectile_visual, "visual_height": projectile_visual_height,
		"visual_scale": projectile_visual_scale, "impact_visual": projectile_impact_visual,
		"visual_offset": visual_offset, "visual_origin_offset": visual_offset,
		"visual_offset_follows_trajectory": visual_offset_follows_trajectory,
		"visual_launch_pos": start_position, "direction": direction,
	}
	if projectile_visual == &"baron_siege":
		_context.show_projectile_impact(start_position + visual_offset - Vector2(0, projectile_visual_height), 1.0, projectile_color, &"baron_siege_cast")
	if attacker is Unit:
		var cue := &"first_strike:missile_launch" if first_strike else (&"empowered_launch" if bool(effects.get("presentation_source", {}).get("empowered", false)) else &"attack_launch")
		var source: Dictionary = effects.get("presentation_source", {})
		var audio: Dictionary = PresentationConfig.for_form(CardDB.get_card(String(source.get("card_id", ""))), source_form_index).get("audio", {})
		if cue == &"attack_launch" and bool(audio.get("attack_launch_until_impact", false)):
			projectiles[id]["owned_launch_audio"] = true
			launch_audio_started.emit(id, source, attacker.global_position)
		else:
			_context.notify_unit_audio_event(attacker as Unit, cue, attacker.global_position)
	queue_redraw()

func tick(dt: float) -> void:
	var finished := []
	# 同 Tick 的箭共享开始时的碰撞对象，前箭击杀也不会让并排后箭穿过尸体打后排。
	var fan_colliders: Array = []
	for projectile in projectiles.values():
		if projectile.get("skill_fan", false):
			for combatant in get_tree().get_nodes_in_group("combatants"):
				if is_instance_valid(combatant) and combatant.hp > 0.0:
					fan_colliders.append([combatant, combatant.global_position, combatant.body_radius])
			break
	for id in projectiles:
		var projectile: Dictionary = projectiles[id]
		if projectile.get("skill_fan", false):
			if _tick_skill_arrow(projectile, dt, fan_colliders):
				finished.append(id)
			continue
		var target = projectile.get("target")
		if target == null or not is_instance_valid(target) or target.hp <= 0.0:
			finished.append(id)
			continue
		var attacker = projectile.get("attacker")
		if attacker != null and is_instance_valid(attacker):
			projectile.source_pos = attacker.global_position
		if target is Unit and (target as Unit).is_hidden_from_position(projectile.team, projectile.source_pos):
			finished.append(id)
			continue
		var target_pos: Vector2 = target.global_position
		var pos: Vector2 = projectile.pos
		projectile.direction = pos.direction_to(target_pos)
		var next_pos := pos.move_toward(target_pos, projectile.speed * dt)
		projectile.pos = next_pos
		if projectile.get("visual_offset_follows_trajectory", false):
			var visual_launch_pos: Vector2 = projectile.get("visual_launch_pos", pos)
			var travel_distance := visual_launch_pos.distance_to(next_pos)
			var total_distance := maxf(visual_launch_pos.distance_to(target_pos), 1.0)
			var travel_ratio := clampf(travel_distance / total_distance, 0.0, 1.0)
			var visual_origin_offset: Vector2 = projectile.get("visual_origin_offset", Vector2.ZERO)
			projectile.visual_offset = visual_origin_offset * (1.0 - travel_ratio)
		projectiles[id] = projectile
		if next_pos.distance_to(target_pos) <= target.body_radius + projectile.radius:
			if StringName(projectile.get("impact_visual", "")) == &"baron_siege_hit":
				_context.show_projectile_impact(target_pos, 1.0, projectile.color, &"baron_siege_hit")
			elif projectile.splash > 0.0 and StringName(projectile.get("impact_visual", "")) != &"":
				_context.show_projectile_impact(target_pos, projectile.splash, projectile.color, StringName(projectile.impact_visual))
			var hit_from: Node2D = projectile.attacker if (projectile.attacker != null and is_instance_valid(projectile.attacker)) else null
			_context.resolve_attack_hit(projectile.team, pos, target, projectile.damage, projectile.splash, projectile.knockback, hit_from, projectile.source_pos, int(projectile.get("source_form_index", -1)), projectile.get("effects", {}))
			finished.append(id)
	for id in finished:
		if bool(projectiles[id].get("owned_launch_audio", false)):
			launch_audio_stopped.emit(id)
		projectiles.erase(id)
	queue_redraw()

## 扇形直线技能弹体；阻挡/穿透由数据决定，同次施法共享目标去重。
static func skill_fan_direction(forward: Vector2, arc_degrees: float, count: int, index: int) -> Vector2:
	var half_angle := deg_to_rad(arc_degrees * 0.5) * 0.92
	var ratio := 0.5 if count == 1 else float(index) / float(count - 1)
	return forward.normalized().rotated(lerpf(-half_angle, half_angle, ratio))

func launch_skill_fan(source: Unit, skill: Dictionary, forward: Vector2) -> void:
	var count := maxi(int(skill.get("projectile_count", 0)), 1)
	var length := float(skill.get("length", 0.0))
	var flight := maxf(float(skill.get("projectile_flight_duration", 0.0)), 0.01)
	var cast: Dictionary = {"targets": {}, "sound_played": false}
	var radius := float(skill.get("near_width", 6.0)) * 0.5 if String(skill.get("shape", "")) == "trapezoid" else 3.0
	for index in count:
		var direction := skill_fan_direction(forward, float(skill.get("arc_degrees", 0.0)), count, index)
		var pos := source.global_position + direction * source.body_radius
		projectiles[_next_id] = {
			"skill_fan": true, "cast": cast, "skill": skill,
			"attacker": source, "source_pos": source.global_position,
			"presentation_source": PresentationConfig.attack_source(source),
			"team": source.team, "source_form_index": source.form_index,
			"pos": pos, "direction": direction, "speed": length / flight,
			"remaining": length, "damage": float(skill.get("damage", 0.0)),
			"radius": radius, "visual": StringName(skill.get("projectile_visual", "arrow")), "color": source.color,
			"visual_height": float(skill.get("projectile_visual_height", source.projectile_visual_height)),
			"visual_offset": direction * (float(skill.get("projectile_visual_forward_offset", source.body_radius)) - source.body_radius),
			"visual_scale": maxf(float(skill.get("projectile_visual_width", radius * 2.0)) / (radius * 2.0), 1.0),
		}
		_next_id += 1
	queue_redraw()

func _tick_skill_arrow(projectile: Dictionary, dt: float, colliders: Array) -> bool:
	var distance := minf(float(projectile.remaining), float(projectile.speed) * dt)
	var origin: Vector2 = projectile.pos
	var direction: Vector2 = projectile.direction
	var piercing := bool(projectile.skill.get("projectile_piercing", false))
	var contacts: Array = []
	for collider in colliders:
		var candidate: Node2D = collider[0]
		if not is_instance_valid(candidate) or candidate.team == int(projectile.team):
			continue
		if candidate is Unit:
			if bool(projectile.skill.get("ground_only", false)) and candidate.is_air:
				continue
			if candidate.is_hidden_from_position(projectile.team, projectile.source_pos):
				continue
		var offset: Vector2 = collider[1] - origin
		var radius := float(collider[2]) + float(projectile.radius)
		var along := offset.dot(direction)
		var perpendicular_squared := maxf(offset.length_squared() - along * along, 0.0)
		if perpendicular_squared > radius * radius:
			continue
		var half_chord := sqrt(maxf(radius * radius - perpendicular_squared, 0.0))
		if along + half_chord < 0.0:
			continue
		var contact := maxf(along - half_chord, 0.0)
		if contact <= distance:
			contacts.append([contact, candidate])
	contacts.sort_custom(func(a, b):
		return a[1].get_instance_id() < b[1].get_instance_id() if is_equal_approx(a[0], b[0]) else a[0] < b[0])
	for contact in contacts:
		var target: Node2D = contact[1]
		projectile.pos = origin + direction * float(contact[0])
		var targets: Dictionary = projectile.cast.targets
		var target_id := target.get_instance_id()
		if not targets.has(target_id):
			targets[target_id] = true
			var source: Node2D = projectile.attacker if is_instance_valid(projectile.attacker) else null
			var landed := _context.resolve_attack_hit(projectile.team, origin, target, projectile.damage, 0.0, 0.0, source, projectile.source_pos, projectile.source_form_index, {}, false)
			if landed:
				if target is Unit and is_instance_valid(target) and target.hp > 0.0:
					var skill: Dictionary = projectile.skill
					if float(skill.get("slow_duration", 0.0)) > 0.0:
						target.apply_slow(float(skill.slow_duration), float(skill.get("slow_multiplier", 1.0)))
					if float(skill.get("stun_duration", 0.0)) > 0.0:
						target.stun(float(skill.stun_duration))
				if piercing or not bool(projectile.cast.sound_played):
					projectile.cast.sound_played = true
					skill_hit.emit(projectile.presentation_source, String(projectile.skill.get("visual_action", "")), projectile.pos)
		# 非穿透箭仍被已命中过的实体阻挡；穿透牌继续处理本 Tick 沿途目标。
		if not piercing:
			return true
	projectile.pos = origin + direction * distance
	projectile.remaining = maxf(float(projectile.remaining) - distance, 0.0)
	return float(projectile.remaining) <= 0.0001

func tick_client_interpolation(delta: float) -> void:
	for id in client_projectiles:
		var projectile: Dictionary = client_projectiles[id]
		projectile.pos = (projectile.pos as Vector2).lerp(projectile.target_pos, minf(delta * 14.0, 1.0))
		var visual_offset: Vector2 = projectile.get("visual_offset", Vector2.ZERO)
		var target_visual_offset: Vector2 = projectile.get("target_visual_offset", Vector2.ZERO)
		projectile.visual_offset = visual_offset.lerp(target_visual_offset, minf(delta * 14.0, 1.0))
		client_projectiles[id] = projectile
	queue_redraw()

func tick_visuals(delta: float) -> void:
	var alive: Array[Dictionary] = []
	for effect in impact_effects:
		effect.timer = maxf(float(effect.timer) - delta, 0.0)
		if float(effect.timer) > 0.001:
			alive.append(effect)
	impact_effects.assign(alive)
	if not impact_effects.is_empty():
		queue_redraw()

func add_impact_visual(position: Vector2, radius: float, color: Color, visual: StringName) -> void:
	if visual == &"" or radius <= 0.0:
		return
	impact_added.emit(position, radius, color, visual)
	impact_effects.append({
		"pos": position, "radius": radius, "color": color, "visual": visual,
		"timer": 0.38, "duration": 0.38,
	})
	queue_redraw()

func clear_all() -> void:
	visuals_cleared.emit()
	launch_audio_cleared.emit()
	for id in projectiles:
		if bool(projectiles[id].get("owned_launch_audio", false)):
			launch_audio_stopped.emit(id)
	projectiles.clear()
	client_projectiles.clear()
	impact_effects.clear()
	queue_redraw()

func _draw() -> void:
	var visible := client_projectiles if _context != null and _context.is_net_client() else projectiles
	for id in visible:
		var projectile: Dictionary = visible[id]
		match StringName(projectile.get("visual", &"orb")):
			&"baron_siege": pass # 由纯表现 3D 粒子代理绘制
			&"tower_orb": _draw_tower_orb(projectile)
			&"arrow": _draw_arrow(projectile)
			&"card": _draw_card(projectile)
			&"electromagnetic_wave": preload("res://scripts/presentation/electromagnetic_projectile_2d.gd").draw_effect(self, _visual_position(projectile), _direction(projectile), {"projectile_visual_width": float(projectile.radius) * 2.0 * float(projectile.get("visual_scale", 1.0))})
			&"needle": _draw_needle(projectile)
			&"boomerang": _draw_boomerang(projectile)
			&"ice_cone": _draw_ice_cone(projectile)
			# orb 同样必须使用纯表现炮口偏移；权威弹体位置仍保留在 projectile.pos。
			_:
				if bool(projectile.get("first_strike", false)):
					_draw_first_strike_orb(projectile)
				elif StringName(projectile.get("impact_visual", "")) == &"splash_wave" or float(projectile.get("visual_scale", 1.0)) > 1.01:
					_draw_splash_orb(projectile)
				else:
					draw_circle(_visual_position(projectile), projectile.radius * float(projectile.get("visual_scale", 1.0)), projectile.color)
	for effect in impact_effects:
		_draw_impact_effect(effect)

func _draw_splash_orb(projectile: Dictionary) -> void:
	var pos := _visual_position(projectile)
	var direction := _direction(projectile)
	var radius := float(projectile.radius) * maxf(float(projectile.get("visual_scale", 1.0)), 1.0)
	var color: Color = projectile.color
	draw_line(pos - direction * radius * 2.2, pos - direction * radius * 0.35, Color(1.0, 0.16, 0.03, 0.28), radius * 1.15, true)
	draw_circle(pos, radius * 1.55, Color(1.0, 0.12, 0.025, 0.16))
	draw_circle(pos, radius * 1.16, Color(color.r, color.g, color.b, 0.52))
	draw_circle(pos, radius, color)
	draw_circle(pos - direction * radius * 0.22, radius * 0.46, Color(1.0, 0.88, 0.42, 0.98))
	draw_circle(pos - direction * radius * 0.34, radius * 0.20, Color(1.0, 1.0, 0.86, 1.0))

func _draw_first_strike_orb(projectile: Dictionary) -> void:
	var pos := _visual_position(projectile)
	var direction := _direction(projectile)
	var side := Vector2(-direction.y, direction.x)
	var radius := float(projectile.radius) * maxf(float(projectile.get("visual_scale", 1.0)), 1.0)
	var color: Color = projectile.color
	# 首击弹体仅增加表现层火光包围，不改变弹体半径、飞行和命中判定。
	draw_line(pos - direction * radius * 3.4, pos - direction * radius * 0.45, Color(1.0, 0.12, 0.015, 0.40), radius * 0.95, true)
	draw_line(pos - direction * radius * 2.4 + side * radius * 0.52, pos - direction * radius * 0.35, Color(1.0, 0.52, 0.06, 0.68), radius * 0.42, true)
	draw_line(pos - direction * radius * 2.25 - side * radius * 0.48, pos - direction * radius * 0.25, Color(1.0, 0.28, 0.02, 0.58), radius * 0.34, true)
	draw_circle(pos, radius * 2.05, Color(1.0, 0.12, 0.01, 0.18))
	draw_circle(pos, radius * 1.46, Color(1.0, 0.48, 0.04, 0.56))
	draw_circle(pos, radius * 1.05, Color(1.0, 0.76, 0.20, 0.96))
	draw_circle(pos - direction * radius * 0.20, radius * 0.54, Color(1.0, 0.98, 0.76, 1.0))

func _draw_impact_effect(effect: Dictionary) -> void:
	if StringName(effect.get("visual", "")) != &"splash_wave":
		return
	var duration := maxf(float(effect.get("duration", 0.38)), 0.001)
	var progress := 1.0 - clampf(float(effect.get("timer", 0.0)) / duration, 0.0, 1.0)
	var fade := 1.0 - progress
	var radius := float(effect.get("radius", 0.0)) * ease(clampf(progress * 1.28, 0.0, 1.0), -2.0)
	var pos: Vector2 = effect.get("pos", Vector2.ZERO)
	draw_circle(pos, radius, Color(1.0, 0.18, 0.025, 0.10 * fade))
	draw_arc(pos, radius, 0.0, TAU, 48, Color(1.0, 0.34, 0.06, 0.92 * fade), 3.5, true)
	draw_arc(pos, radius * 0.72, 0.0, TAU, 40, Color(1.0, 0.78, 0.24, 0.58 * fade), 2.0, true)
	var ray_length := radius * 0.38 * fade
	for index in range(8):
		var ray_direction := Vector2.from_angle(TAU * float(index) / 8.0)
		draw_line(pos + ray_direction * radius * 0.18, pos + ray_direction * (radius * 0.18 + ray_length), Color(1.0, 0.52, 0.10, 0.72 * fade), 2.0, true)

func _draw_needle(projectile: Dictionary) -> void:
	var pos := _visual_position(projectile)
	var direction := _direction(projectile)
	draw_line(pos - direction * 8.0, pos + direction * 8.0, projectile.color, 2.0, true)

func _draw_ice_cone(projectile: Dictionary) -> void:
	var pos := _visual_position(projectile)
	var direction := _direction(projectile)
	var side := Vector2(-direction.y, direction.x)
	var tip := pos + direction * 9.0
	var base := pos - direction * 5.0
	var glow := Color(0.72, 0.94, 1.0, 0.36)
	draw_circle(pos, 6.0, glow)
	draw_colored_polygon(PackedVector2Array([tip, base + side * 4.5, base - side * 4.5]), projectile.color)
	draw_polyline(PackedVector2Array([tip, base + side * 4.5, base - side * 4.5, tip]), Color(0.88, 0.98, 1.0, 0.96), 1.2, true)
	draw_line(base - direction * 1.0, tip - direction * 2.0, Color(0.95, 1.0, 1.0, 0.85), 1.2, true)

func _draw_boomerang(projectile: Dictionary) -> void:
	var pos := _visual_position(projectile)
	var direction := _direction(projectile)
	var side := Vector2(-direction.y, direction.x)
	var joint := pos + direction * 3.0
	draw_line(joint, pos - direction * 7.0 + side * 8.0, projectile.color, 3.0, true)
	draw_line(joint, pos - direction * 7.0 - side * 8.0, projectile.color, 3.0, true)

func _draw_arrow(projectile: Dictionary) -> void:
	var pos := _visual_position(projectile)
	var direction := _direction(projectile)
	var side := Vector2(-direction.y, direction.x)
	var tip := pos + direction * 10.0
	var neck := pos + direction * 4.0
	draw_line(pos - direction * 8.0, neck, projectile.color, 3.0, true)
	draw_colored_polygon(PackedVector2Array([tip, neck + side * 4.0, neck - side * 4.0]), projectile.color)

func _draw_tower_orb(projectile: Dictionary) -> void:
	var pos := _visual_position(projectile)
	var direction := _direction(projectile)
	var color: Color = projectile.color
	var radius: float = projectile.radius
	var glow := Color(color.r, color.g, color.b, 0.22)
	draw_line(pos - direction * 14.0, pos - direction * 3.0, glow, 5.0, true)
	draw_circle(pos, radius + 5.0, glow)
	draw_circle(pos, radius, color)
	draw_circle(pos - direction * radius * 0.25, radius * 0.34, Color(1.0, 1.0, 1.0, 0.82))

func _direction(projectile: Dictionary) -> Vector2:
	var direction: Vector2 = projectile.get("direction", Vector2.UP)
	return Vector2.UP if direction.length_squared() < 0.001 else direction.normalized()

func _visual_position(projectile: Dictionary) -> Vector2:
	var visual_offset: Vector2 = projectile.get("visual_offset", Vector2.ZERO)
	return projectile.pos + visual_offset + Vector2(0.0, -float(projectile.get("visual_height", 0.0)))

func _draw_card(projectile: Dictionary) -> void:
	var center := _visual_position(projectile)
	var direction := _direction(projectile)
	var side := Vector2(-direction.y, direction.x)
	var points := PackedVector2Array([center - direction * 9.0 - side * 5.0, center + direction * 9.0 - side * 5.0, center + direction * 9.0 + side * 5.0, center - direction * 9.0 + side * 5.0])
	draw_colored_polygon(points, Color(1.0, 0.94, 0.58, 0.96))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(0.32, 0.14, 0.08, 0.96), 1.5, true)
