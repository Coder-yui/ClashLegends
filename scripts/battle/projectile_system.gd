class_name ProjectileSystem
extends Node2D
## 主机权威弹体模拟与客户端弹体插值/绘制。伤害仍回到 Battle Controller 统一结算。

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
	var source_form_index := (attacker as Unit).form_index if attacker is Unit else -1
	if projectile_speed <= 0.0:
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
		var forward_offset := (attacker as Unit).projectile_visual_forward_offset
		if forward_offset > 0.0:
			visual_offset = direction * forward_offset
			visual_offset_follows_trajectory = true
	elif attacker is Tower:
		projectile_visual = &"tower_orb"
		visual_offset = (attacker as Tower).projectile_visual_offset
		visual_offset_follows_trajectory = visual_offset.length_squared() > 0.001
	var start_position := attacker.global_position
	if projectile_visual in [&"arrow", &"needle", &"boomerang"]:
		start_position += direction * (attacker.body_radius + MUZZLE_FORWARD_GAP)
	var id := _next_id
	_next_id += 1
	projectiles[id] = {
		"pos": start_position, "target": target, "attacker": attacker,
		"source_form_index": source_form_index, "source_pos": attacker.global_position,
		"team": attacker.team, "damage": amount, "speed": projectile_speed,
		"effects": effects.duplicate(true),
		"splash": splash_radius, "knockback": knockback, "color": projectile_color,
		"radius": 7.0 if projectile_visual == &"tower_orb" else (3.0 if projectile_visual == &"arrow" else 4.0),
		"visual": projectile_visual, "visual_height": projectile_visual_height,
		"visual_scale": projectile_visual_scale, "impact_visual": projectile_impact_visual,
		"visual_offset": visual_offset, "visual_origin_offset": visual_offset,
		"visual_offset_follows_trajectory": visual_offset_follows_trajectory,
		"visual_launch_pos": start_position, "direction": direction,
	}
	queue_redraw()

func tick(dt: float) -> void:
	var finished := []
	for id in projectiles:
		var projectile: Dictionary = projectiles[id]
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
			if projectile.splash > 0.0 and StringName(projectile.get("impact_visual", "")) != &"":
				_context.show_projectile_impact(target_pos, projectile.splash, projectile.color, StringName(projectile.impact_visual))
			var hit_from: Node2D = projectile.attacker if (projectile.attacker != null and is_instance_valid(projectile.attacker)) else null
			_context.resolve_attack_hit(projectile.team, pos, target, projectile.damage, projectile.splash, projectile.knockback, hit_from, projectile.source_pos, int(projectile.get("source_form_index", -1)), projectile.get("effects", {}))
			finished.append(id)
	for id in finished:
		projectiles.erase(id)
	queue_redraw()

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
	impact_effects.append({
		"pos": position, "radius": radius, "color": color, "visual": visual,
		"timer": 0.38, "duration": 0.38,
	})
	queue_redraw()

func clear_all() -> void:
	projectiles.clear()
	client_projectiles.clear()
	impact_effects.clear()
	queue_redraw()

func _draw() -> void:
	var visible := client_projectiles if _context != null and _context.is_net_client() else projectiles
	for id in visible:
		var projectile: Dictionary = visible[id]
		match StringName(projectile.get("visual", &"orb")):
			&"tower_orb": _draw_tower_orb(projectile)
			&"arrow": _draw_arrow(projectile)
			&"needle": _draw_needle(projectile)
			&"boomerang": _draw_boomerang(projectile)
			# orb 同样必须使用纯表现炮口偏移；权威弹体位置仍保留在 projectile.pos。
			_:
				if StringName(projectile.get("impact_visual", "")) == &"splash_wave" or float(projectile.get("visual_scale", 1.0)) > 1.01:
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
