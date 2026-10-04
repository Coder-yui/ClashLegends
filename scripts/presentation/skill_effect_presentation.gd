class_name SkillEffectPresentation
extends RefCounted
## 仅拥有表现实例、渲染计时及网络事件去重，不改变战斗状态。
var frontal_effects: Array[Dictionary] = []
var shield_effects: Array[Dictionary] = []
var _seen_independent_fx: Dictionary = {}
var _controller: Node2D

func _init(controller: Node2D) -> void:
	_controller = controller

func add_fixed_area_effect(center: Vector2, start_radius: float, end_radius: float, duration: float, p_team: int, shape: StringName) -> void:
	frontal_effects.append({
		"source_ref": null, "net_id": -1, "fixed_position": true,
		"pos": center, "forward": Vector2.UP, "source_radius": 0.0,
		"length": end_radius, "width": start_radius, "shape": String(shape),
		"timer": duration, "duration": duration, "team": p_team,
	})

func add_team_attack_boost(source: Unit, target: Unit, duration: float) -> Dictionary:
	if not is_instance_valid(source) or not is_instance_valid(target):
		return {}
	var effect := {
		"source_ref": null, "net_id": -1, "fixed_position": true,
		"pos": source.get_visual_screen_position(),
		"end_position": target.get_visual_screen_position(), "target_net_id": target.net_id, "target_instance_id": target.get_instance_id(), "forward": Vector2.UP,
		"length": source.global_position.distance_to(target.global_position),
		"width": 0.0, "shape": "team_attack_boost_hammer",
		"timer": duration, "duration": duration, "team": source.team,
	}
	frontal_effects.append(effect)
	return effect

func add_ornn_charge_impact(center: Vector2, radius: float, p_team: int) -> Dictionary:
	if radius <= 0.0:
		return {}
	var effect := {
		"source_ref": null, "net_id": -1, "fixed_position": true,
		"pos": center, "forward": Vector2.UP, "source_radius": 0.0,
		"length": radius, "width": radius, "shape": "ornn_charge_impact",
		"timer": 0.4, "duration": 0.4, "team": p_team,
	}
	frontal_effects.append(effect)
	return effect

func begin_frontal_visual(source: Unit, skill: Dictionary, cast_forward: Vector2) -> void:
	# 真实弹体通过 ProjectileSystem/快照绘制；这里只保留范围预警，避免重复画箭或卡牌。
	if bool(skill.get("projectile_stop_on_hit", false)) or bool(skill.get("projectile_piercing", false)):
		skill = skill.duplicate(true)
		if skill.has("projectile_spawn_offset"):
			skill["shape"] = "fan_shared"
		elif bool(skill.get("projectile_piercing", false)) and String(skill.get("shape", "")) == "fan":
			skill["shape"] = "projectile_fan"
		else:
			# 单枚首碰弹体沿直线前进，预警使用等宽轮廓；不把扇形夹角当弹道宽度。
			if bool(skill.get("projectile_stop_on_hit", false)) and int(skill.get("projectile_count", 0)) == 1:
				var path_width := maxf(float(skill.get("projectile_visual_width", 6.0)), 6.0)
				skill["shape"] = "trapezoid"
				skill["width"] = path_width
				skill["near_width"] = path_width
				skill["far_width"] = path_width
			skill["projectile_count"] = 0
	var duration := maxf(float(skill.get("impact_delay", 0.0)), 0.0)
	var projectile_launch_delay := maxf(float(skill.get("projectile_launch_delay", 0.0)), 0.0)
	var projectile_flight_duration := maxf(float(skill.get("projectile_flight_duration", 0.0)), 0.0)
	var hit_delays = skill.get("prepared_hit_delays", [])
	if hit_delays is Array:
		for hit_delay in hit_delays:
			duration = maxf(duration, float(hit_delay))
	if projectile_flight_duration > 0.0:
		duration = maxf(duration, projectile_launch_delay + projectile_flight_duration)
	if duration <= 0.0:
		return
	add_frontal_effect(source, skill, duration, cast_forward)
	_controller.publish_skill_fx(frontal_effects.back())

func add_frontal_effect(source: Unit, skill: Dictionary, duration: float, cast_forward: Vector2) -> void:
	frontal_effects.append({
		"status_source": source.status_source("skill_area"), "cast_serial": source.active_skill_cast_serial, "action_serial": source.get_visual_action_serial(),
		"source_ref": weakref(source),
		"net_id": source.net_id,
		"pos": source.global_position,
		"forward": cast_forward,
		"source_radius": float(skill.get("projectile_spawn_offset", source.body_radius)),
		"length": maxf(float(skill.get("length", 0.0)), 0.0),
		"width": maxf(float(skill.get("width", 0.0)), 0.0),
		"shape": String(skill.get("shape", "rectangle")),
		"near_width": maxf(float(skill.get("near_width", skill.get("width", 0.0))), 0.0),
		"far_width": maxf(float(skill.get("far_width", skill.get("width", 0.0))), 0.0),
		"arc_degrees": maxf(float(skill.get("arc_degrees", 0.0)), 0.0),
		"projectile_count": maxi(int(skill.get("projectile_count", 0)), 0),
		"projectile_visual": String(skill.get("projectile_visual", "arrow")),
		"projectile_launch_delay": maxf(float(skill.get("projectile_launch_delay", 0.0)), 0.0),
		"projectile_flight_duration": maxf(float(skill.get("projectile_flight_duration", 0.0)), 0.0),
		"projectile_visual_height": maxf(float(skill.get("projectile_visual_height", 0.0)), 0.0),
		"projectile_visual_forward_offset": maxf(float(skill.get("projectile_visual_forward_offset", source.body_radius)), 0.0),
		"projectile_visual_width": maxf(float(skill.get("projectile_visual_width", 0.0)), 0.0),
		"center_ratio": clampf(float(skill.get("center_ratio", 0.0)), 0.0, 1.0),
		"center_width": maxf(float(skill.get("center_width", 0.0)), 0.0),
		"fan_inner_arc": bool(skill.get("fan_inner_arc", false)),
		"timer": duration,
		"duration": duration,
		"team": source.team,
	})


## 审判等持续范围技能的预警跟随施法者，只影响表现，不参与权威命中。

func begin_continuous_area_visual(source: Unit, skill: Dictionary) -> void:
	var duration := maxf(float(skill.get("cast_duration", skill.get("duration", 0.0))), 0.0)
	var radius := maxf(float(skill.get("radius", 0.0)), 0.0)
	if duration <= 0.0 or radius <= 0.0:
		return
	frontal_effects.append({
		"status_source": source.status_source("skill_area"), "cast_serial": source.active_skill_cast_serial, "action_serial": source.get_visual_action_serial(),
		"source_ref": weakref(source),
		"net_id": source.net_id,
		"fixed_position": false,
		"pos": source.global_position,
		"forward": Vector2.UP,
		"source_radius": float(skill.get("projectile_spawn_offset", source.body_radius)),
		"length": radius,
		"width": radius,
		"shape": "continuous_area",
		"timer": duration,
		"duration": duration,
		"team": source.team,
	})
	_controller.publish_skill_fx(frontal_effects.back())


## RPC 只递交本次表现载荷，集合及其更新/清理仍由本系统持有。

func show_skill_effect(event_id: int, payload: Dictionary) -> void:
	if _seen_independent_fx.has(event_id): return
	_seen_independent_fx[event_id] = true
	show_network_frontal(payload)

func show_network_frontal(payload: Dictionary) -> void:
	var effect := payload.duplicate(true)
	effect.source_ref = null
	frontal_effects.append(effect)

func tick_visuals(delta: float) -> void:
	for index in range(shield_effects.size() - 1, -1, -1):
		shield_effects[index].timer = maxf(0.0, float(shield_effects[index].timer) - delta)
		if shield_effects[index].timer <= 0.0: shield_effects.remove_at(index)
	var alive: Array[Dictionary] = []
	for effect in frontal_effects:
		if String(effect.get("shape", "")) == "team_attack_boost_hammer":
			var target = _controller.find_client_unit(int(effect.get("target_net_id", -1))) if _controller.is_net_client() else instance_from_id(int(effect.get("target_instance_id", 0)))
			if not is_instance_valid(target) or target.hp <= 0.0 or not CombatInteraction.allows_allied_target(target, int(effect.get("team", target.team))): continue
			effect.end_position = target.get_visual_screen_position()
		var source = effect_source(effect)
		if not bool(effect.get("fixed_position", false)) and source is Unit and (source.hp <= 0.0 or source.is_frozen() or int(effect.get("cast_serial", source.active_skill_cast_serial)) <= source.cancelled_skill_cast_serial or int(effect.get("action_serial", 2147483647)) <= source.cancelled_visual_serial):
			continue
		effect.timer = maxf(0.0, float(effect.timer) - delta)
		if float(effect.timer) > 0.001:
			alive.append(effect)
	frontal_effects.assign(alive)

func effect_source(effect: Dictionary):
	var source_ref = effect.get("source_ref")
	if source_ref is WeakRef:
		var source = (source_ref as WeakRef).get_ref()
		if source is Unit and is_instance_valid(source):
			return source
	var net_id := int(effect.get("net_id", -1))
	if net_id >= 0:
		var client_source = _controller.find_client_unit(net_id)
		if client_source is Unit and is_instance_valid(client_source):
			return client_source
	return null

func present_area_shield(card_id: String, form: int, position: Vector2) -> void:
	var stats := PresentationConfig.for_form(CardDB.get_card(card_id), form)
	for skill in stats.get("active_skills", []):
		if String(skill.get("kind", "")) != "area_shield":
			continue
		# 射程从自身表面起算；波前到达自身半径 + 技能射程。
		var radius := float(stats.get("radius", 0.0)) + float(skill.get("radius", 0.0))
		shield_effects.append({"pos":position,"radius":radius,"duration":0.5,"timer":0.5})
		return

func clear() -> void:
	_seen_independent_fx.clear()
	shield_effects.clear()
	frontal_effects.clear()

func present_fixed_area(center: Vector2, start_radius: float, end_radius: float, duration: float, team: int, shape: StringName) -> void:
	add_fixed_area_effect(center, start_radius, end_radius, duration, team, shape)
	_controller.publish_skill_fx(frontal_effects.back())

func present_shield_explosion(source: Unit, radius: float) -> void:
	add_frontal_effect(source, {"shape": "shield_explosion", "length": radius}, 0.45, Vector2.UP)
	frontal_effects.back()["fixed_position"] = true
	_controller.publish_skill_fx(frontal_effects.back())

func add_summon_flight(source: Unit, destination: Vector2, airborne: bool, duration: float) -> Dictionary:
	var effect := {
		"source_ref": null, "net_id": -1, "fixed_position": true,
		"pos": source.global_position, "end_position": destination,
		"start_height": 0.7 * source.growth_body_scale + (CardDB.AIR_VISUAL_ELEVATION if source.is_air else 0.0),
		"end_height": CardDB.AIR_VISUAL_ELEVATION + 0.25 if airborne else 0.3,
		"shape": "summon_mote", "timer": duration, "duration": duration, "team": source.team,
	}
	frontal_effects.append(effect)
	return effect

func project_height(point: Vector2, height: float) -> Vector2:
	return _controller.project_effect_height(point, height)

func add_growth_wave(target: Unit, radius: float) -> Dictionary:
	var effect := {
		"source_ref": null, "net_id": -1, "fixed_position": true,
		"pos": target.global_position, "height": CardDB.AIR_VISUAL_ELEVATION if target.is_air else 0.08,
		"radius": radius, "shape": "growth_wave", "timer": 0.55, "duration": 0.55, "team": target.team,
	}
	frontal_effects.append(effect)
	return effect
