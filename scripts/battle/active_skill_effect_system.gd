class_name ActiveSkillEffectSystem
extends RefCounted
## 主动技能 Gameplay Impact 执行器。
## 技能资格、Command Buffer 与 Cast 时间线仍由 Main 编排；具体效果集中在这里扩展。

var frontal_effects: Array[Dictionary] = []
var expanding_shockwaves: Array[Dictionary] = []
## 施法者跟随型持续范围效果；每个 pulse 都读取施法者当前权威位置。
var continuous_area_effects: Array[Dictionary] = []

var _controller: Node2D


func _init(controller: Node2D) -> void:
	_controller = controller

## Cast Start 固化资源倍率和强/弱动作选择。返回值只进入本次权威时间线，
## 不回写 CardDB，也不会让动画决定伤害。
func prepare_cast(source: Unit, skill: Dictionary) -> Dictionary:
	var prepared := skill.duplicate(true)
	if bool(prepared.get("uses_skill_resource", false)) and source.skill_resource_enabled and source.skill_resource_max > 0.0:
		var resource_stacks := source.get_skill_resource_stacks()
		var resource_ratio := source.consume_skill_resource_ratio()
		prepared["resource_ratio"] = resource_ratio
		prepared["resource_stacks"] = resource_stacks
		var damage_by_stacks = prepared.get("resource_damage_by_stacks", [])
		if damage_by_stacks is Array and not (damage_by_stacks as Array).is_empty():
			var damage_index := clampi(resource_stacks, 0, (damage_by_stacks as Array).size() - 1)
			prepared["damage"] = float((damage_by_stacks as Array)[damage_index])
		var resource_actions = prepared.get("resource_visual_actions", [])
		if resource_actions is Array and not (resource_actions as Array).is_empty():
			var action_index := clampi(resource_stacks, 0, (resource_actions as Array).size() - 1)
			prepared["visual_action"] = String((resource_actions as Array)[action_index])
		var hit_damage_sequences = prepared.get("resource_hit_damage_sequences", [])
		var hit_delay_sequences = prepared.get("resource_hit_delay_sequences", [])
		if (
			hit_damage_sequences is Array and hit_delay_sequences is Array
			and not (hit_damage_sequences as Array).is_empty() and not (hit_delay_sequences as Array).is_empty()
		):
			var hit_index := clampi(resource_stacks, 0, mini((hit_damage_sequences as Array).size(), (hit_delay_sequences as Array).size()) - 1)
			prepared["prepared_hit_damages"] = (hit_damage_sequences as Array)[hit_index].duplicate()
			prepared["prepared_hit_delays"] = (hit_delay_sequences as Array)[hit_index].duplicate()
		var max_scale := maxf(float(prepared.get("resource_damage_scale_max", 1.0)), 1.0)
		if max_scale > 1.0:
			prepared["damage"] = float(prepared.get("damage", 0.0)) * lerpf(1.0, max_scale, resource_ratio)
		var strong_action := String(prepared.get("full_resource_visual_action", ""))
		if resource_ratio >= 0.999:
			if not strong_action.is_empty():
				prepared["visual_action"] = strong_action
			prepared["damage"] = float(prepared.get("damage", 0.0)) * maxf(float(prepared.get("resource_full_damage_multiplier", 1.0)), 1.0)
			prepared["stun_duration"] = float(prepared.get("stun_duration", 0.0)) * maxf(float(prepared.get("resource_full_stun_multiplier", 1.0)), 1.0)
			prepared["cast_duration"] = float(prepared.get("full_resource_cast_duration", prepared.get("cast_duration", 0.0)))
			prepared["impact_delay"] = float(prepared.get("full_resource_impact_delay", prepared.get("impact_delay", 0.0)))
			prepared["full_resource"] = true
			prepared["cast_end_heal"] = maxf(float(prepared.get("full_resource_cast_end_heal", 0.0)), 0.0)
		if prepared.has("resource_shield_max"):
			prepared["shield"] = maxf(float(prepared.get("resource_shield_max", 0.0)), 0.0) * resource_ratio
	return prepared


## 双形态技能只在 Cast Start 决定形态分支和锁定朝向，之后进入 Main 的通用 Impact 队列。
func prepare_dual_form_cast(source: Unit, skill: Dictionary) -> Dictionary:
	var prepared := skill.duplicate(true)
	prepared["cast_forward"] = frontal_forward(source)
	if source.form_index == 0:
		if not source.transform_to_mega(true):
			return {}
		prepared["impact_delay"] = maxf(float(prepared.get("transform_impact_delay", 0.0)), 0.0)
		prepared["cast_duration"] = maxf(float(prepared.get("transform_cast_duration", 0.0)), 0.0)
		# transform_to_mega() 已发布合成变形动作，不再重复播放大形态主动动作。
		prepared["visual_action"] = ""
	return prepared


## Cast Start 的效果必须在施法窗口开始时发生；它不依赖动画，也不等待 Gameplay Impact。
func apply_cast_start(source: Unit, skill: Dictionary) -> void:
	if not bool(skill.get("shield_on_cast_start", false)):
		return
	var amount := maxf(float(skill.get("shield", 0.0)), 0.0)
	var duration := maxf(float(skill.get("shield_duration", 0.0)), 0.0)
	if amount <= 0.0 or duration <= 0.0:
		return
	source.mark_skill_resource_combat_activity()
	source.add_shield(amount, duration, bool(skill.get("shield_decay", false)))


## Cast End 效果与动作总时长对齐，但仍由固定模拟计时，不依赖 AnimationPlayer 回调。
func apply_cast_end(source: Unit, skill: Dictionary) -> void:
	var heal_amount := maxf(float(skill.get("cast_end_heal", 0.0)), 0.0)
	if heal_amount > 0.0:
		source.heal(heal_amount)


func apply(source: Unit, skill: Dictionary) -> bool:
	match StringName(skill.get("kind", "")):
		&"buff":
			source.apply_active_buff(
				float(skill.get("duration", 0.0)),
				float(skill.get("speed_multiplier", 1.0)),
				float(skill.get("damage_multiplier", 1.0)),
				float(skill.get("attack_speed_multiplier", 1.0))
			)
			if not bool(skill.get("shield_on_cast_start", false)):
				source.add_shield(float(skill.get("shield", 0.0)), float(skill.get("shield_duration", skill.get("duration", 0.0))), bool(skill.get("shield_decay", false)))
		&"nova":
			activate_nova(source, skill)
		&"summon":
			activate_summon(source, skill)
		&"dual_form":
			apply_frontal_stun(source, skill, source.active_skill_cast_facing)
		&"frontal":
			apply_frontal(source, skill, source.active_skill_cast_facing)
		&"forward_area":
			apply_forward_area(source, skill, source.active_skill_cast_facing)
		&"continuous_area":
			activate_continuous_area(source, skill)
		&"empowered_attack":
			source.prepare_empowered_attack(
				float(skill.get("empowered_damage_multiplier", 1.0)),
				float(skill.get("empowered_speed_multiplier", 1.0)),
				int(skill.get("blind_charges", 0))
			)
		&"attack_lifesteal":
			for target in _skill_target_units(source, skill):
				target.apply_attack_lifesteal(
					float(skill.get("heal_ratio", 0.0)),
					float(skill.get("max_health_ratio", 1.0))
				)
		&"area_shield":
			apply_area_shield(source, skill)
		_:
			push_error("未实现的主动技能 kind：%s" % String(skill.get("kind", "")))
			return false
	return true


## 范围护盾沿用普通攻击的“表面间距”口径：技能 radius 与卡牌 attack range
## 可以填同一数值，大小不同的友军也会在与索敌一致的边界上获得护盾。
## combatants 中的 Unit、建筑、防御塔与水晶统一提供 add_shield()，都可成为目标。
func apply_area_shield(source: Unit, skill: Dictionary) -> void:
	var radius := maxf(float(skill.get("radius", 0.0)), 0.0)
	var amount := maxf(float(skill.get("shield", 0.0)), 0.0)
	var duration := maxf(float(skill.get("shield_duration", 0.0)), 0.0)
	if radius <= 0.0 or amount <= 0.0 or duration <= 0.0:
		return
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if not combatant is Node2D or not is_instance_valid(combatant) or combatant.hp <= 0.0:
			continue
		var ally = combatant
		if ally.team != source.team or not ally.has_method("add_shield"):
			continue
		if source.surface_gap_to_circle(ally.global_position, ally.body_radius) > radius:
			continue
		ally.add_shield(amount, duration, bool(skill.get("shield_decay", false)))


## 主动效果默认只作用于施法者；deployment_group 会选中同一次卡牌部署中仍存活的成员。
func _skill_target_units(source: Unit, skill: Dictionary) -> Array[Unit]:
	var targets: Array[Unit] = []
	if StringName(skill.get("target_scope", "self")) != &"deployment_group" or source.deployment_group_id < 0:
		targets.append(source)
		return targets
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if not combatant is Unit or not is_instance_valid(combatant) or combatant.hp <= 0.0:
			continue
		var member := combatant as Unit
		if member.team == source.team and member.deployment_group_id == source.deployment_group_id:
			targets.append(member)
	return targets


func activate_nova(source: Unit, skill: Dictionary) -> void:
	var radius := float(skill.get("radius", 0.0))
	var amount := float(skill.get("damage", 0.0))
	var knockback := float(skill.get("knockback", 0.0))
	var knockback_duration := float(skill.get("knockback_duration", 0.2))
	var knockback_mass_factor_max := float(skill.get("knockback_mass_factor_max", 1.4))
	var ground_only := bool(skill.get("ground_only", false))
	var slow_duration := float(skill.get("slow_duration", 0.0))
	var slow_multiplier := float(skill.get("slow_multiplier", 1.0))
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if combatant == source or not is_instance_valid(combatant) or combatant.team == source.team or combatant.hp <= 0.0:
			continue
		if ground_only and combatant is Unit and (combatant as Unit).is_air:
			continue
		if combatant.global_position.distance_to(source.global_position) > radius + combatant.body_radius:
			continue
		if amount > 0.0:
			_damage_combatant(source, combatant, amount, source.global_position)
		if combatant is Unit and is_instance_valid(combatant) and combatant.hp > 0.0:
			if knockback > 0.0:
				(combatant as Unit).apply_knockback(source.global_position, knockback, knockback_duration, knockback_mass_factor_max)
			if slow_duration > 0.0:
				(combatant as Unit).apply_slow(slow_duration, slow_multiplier)
	if not bool(skill.get("shield_on_cast_start", false)):
		source.add_shield(float(skill.get("shield", 0.0)), float(skill.get("shield_duration", 0.0)), bool(skill.get("shield_decay", false)))


## 持续范围伤害不保存固定中心；每次脉冲都以 source.global_position 为中心。
## 首次伤害在第一个 tick_interval 到达时结算，持续 duration 秒，避免把施法
## 起始帧重复算成额外伤害。技能窗口可只锁 attack，让施法者继续移动/转向。
func activate_continuous_area(source: Unit, skill: Dictionary) -> void:
	var duration := maxf(float(skill.get("duration", skill.get("cast_duration", 0.0))), 0.0)
	var tick_interval := maxf(float(skill.get("tick_interval", 1.0)), 0.01)
	var radius := maxf(float(skill.get("radius", 0.0)), 0.0)
	var amount := maxf(float(skill.get("damage", 0.0)), 0.0)
	if duration <= 0.0 or radius <= 0.0 or amount <= 0.0:
		return
	continuous_area_effects.append({
		"source_ref": weakref(source),
		"team": source.team,
		"radius": radius,
		"damage": amount,
		"ground_only": bool(skill.get("ground_only", false)),
		"time_left": duration,
		"next_tick": tick_interval,
		"tick_interval": tick_interval,
	})


func _apply_continuous_area_pulse(source: Unit, effect: Dictionary) -> void:
	var center: Vector2 = effect.get("center", Vector2.ZERO)
	if not bool(effect.get("fixed_position", false)) and source != null and is_instance_valid(source):
		center = source.global_position
	var radius := maxf(float(effect.get("radius", 0.0)), 0.0)
	var amount := maxf(float(effect.get("damage", 0.0)), 0.0)
	var ground_only := bool(effect.get("ground_only", false))
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		var source_team := int(effect.get("team", source.team if source != null else -1))
		if combatant == source or not is_instance_valid(combatant) or combatant.team == source_team or combatant.hp <= 0.0:
			continue
		if ground_only and combatant is Unit and (combatant as Unit).is_air:
			continue
		if combatant.global_position.distance_to(center) > radius + combatant.body_radius:
			continue
		if amount > 0.0:
			if source != null and is_instance_valid(source):
				_damage_combatant(source, combatant, amount, center)
			else:
				combatant.take_damage(amount, null, source_team, center)
		if combatant is Unit and is_instance_valid(combatant) and combatant.hp > 0.0 and float(effect.get("slow_duration", 0.0)) > 0.0:
			(combatant as Unit).apply_slow(float(effect.get("slow_duration", 0.0)), float(effect.get("slow_multiplier", 1.0)))


func activate_summon(source: Unit, skill: Dictionary) -> void:
	var spawn_id := String(skill.get("spawn_id", ""))
	var count := maxi(int(skill.get("spawn_count", 1)), 1)
	var summon_stats := CardDB.get_unit_stats(spawn_id)
	if summon_stats.is_empty():
		push_error("主动技能引用了不存在的召唤单位：%s" % spawn_id)
		return
	var summon_radius := float(summon_stats.get("radius", 14.0))
	for index in range(count):
		var angle := TAU * float(index) / float(count)
		var offset := Vector2.RIGHT.rotated(angle) * (source.body_radius + summon_radius + Unit.SUMMON_SEPARATION)
		_controller.spawn_summoned(source.team, spawn_id, source.global_position + offset)


## 扇形/梯形主动统一按施法开始时锁定的朝向结算。目标碰撞圆会扩张边界，
## 但动画、箭矢线条和预警多边形都不参与权威命中。
func apply_frontal(source: Unit, skill: Dictionary, forward: Vector2 = Vector2.ZERO) -> void:
	forward = frontal_forward(source) if forward.length_squared() < 0.001 else forward.normalized()
	var side := Vector2(-forward.y, forward.x)
	var length := maxf(float(skill.get("length", 0.0)), 0.0)
	var shape := StringName(skill.get("shape", "trapezoid"))
	var amount := maxf(float(skill.get("damage", 0.0)), 0.0)
	var ground_only := bool(skill.get("ground_only", false))
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if combatant == source or not is_instance_valid(combatant) or combatant.team == source.team or combatant.hp <= 0.0:
			continue
		if ground_only and combatant is Unit and (combatant as Unit).is_air:
			continue
		var local_offset: Vector2 = combatant.global_position - source.global_position
		var forward_distance := local_offset.dot(forward) - source.body_radius
		var lateral_distance := absf(local_offset.dot(side))
		var hit := false
		var damage_multiplier := 1.0
		if shape == &"fan":
			var half_angle := deg_to_rad(clampf(float(skill.get("arc_degrees", 0.0)), 0.0, 179.0) * 0.5)
			var fan_inner_arc := bool(skill.get("fan_inner_arc", false))
			# 普通扇形以施法者前缘为圆心；环形扇区则以内外同心圆弧贴合施法者体型。
			var inner_radius := source.body_radius if fan_inner_arc else 0.0
			var outer_radius := inner_radius + length
			var sector_offset := local_offset if fan_inner_arc else local_offset - forward * source.body_radius
			var radial_distance := sector_offset.length()
			var angular_margin := asin(clampf(combatant.body_radius / maxf(radial_distance, combatant.body_radius), 0.0, 1.0))
			var angular_distance := absf(wrapf(sector_offset.angle() - forward.angle(), -PI, PI))
			var sector_hit := false
			if fan_inner_arc:
				# 内边界沿人物前半圆，侧边从人物左右两侧连接至外圆弧端点。
				var outer_forward := cos(half_angle) * outer_radius
				var outer_lateral := sin(half_angle) * outer_radius
				var boundary_forward := clampf(local_offset.dot(forward), 0.0, outer_radius)
				var side_half_width := 0.0
				if boundary_forward <= outer_forward:
					side_half_width = lerpf(inner_radius, outer_lateral, boundary_forward / maxf(outer_forward, 0.001))
				else:
					side_half_width = sqrt(maxf(outer_radius * outer_radius - boundary_forward * boundary_forward, 0.0))
				sector_hit = (
					local_offset.dot(forward) >= -combatant.body_radius
					and radial_distance >= maxf(inner_radius - combatant.body_radius, 0.0)
					and radial_distance <= outer_radius + combatant.body_radius
					and lateral_distance <= side_half_width + combatant.body_radius
				)
			else:
				sector_hit = (
					forward_distance >= -combatant.body_radius
					and radial_distance <= outer_radius + combatant.body_radius
					and angular_distance <= half_angle + angular_margin
				)
			var center_width := maxf(float(skill.get("center_width", 0.0)), 0.0)
			var center_ratio := clampf(float(skill.get("center_ratio", 0.0)), 0.0, 1.0)
			var in_center := false
			if center_width > 0.0:
				# 格温式核心区是从扇区起点延伸到外弧的恒定宽度长条，而不是随距离变宽的小扇形。
				in_center = forward_distance >= -combatant.body_radius and forward_distance <= length + combatant.body_radius and lateral_distance <= center_width * 0.5 + combatant.body_radius
				hit = sector_hit or in_center
			elif center_ratio > 0.0:
				var center_distance := maxf(forward_distance, 0.0)
				in_center = lateral_distance <= tan(half_angle * center_ratio) * center_distance + combatant.body_radius
				hit = sector_hit
			else:
				hit = sector_hit
			if hit and in_center:
				damage_multiplier = maxf(float(skill.get("center_damage_multiplier", 1.0)), 1.0)
		else:
			var near_half := maxf(float(skill.get("near_width", skill.get("width", 0.0))) * 0.5, 0.0)
			var far_half := maxf(float(skill.get("far_width", skill.get("width", 0.0))) * 0.5, 0.0)
			var width_ratio := clampf(forward_distance / maxf(length, 0.001), 0.0, 1.0)
			var half_width := lerpf(near_half, far_half, width_ratio)
			hit = forward_distance >= -combatant.body_radius and forward_distance <= length + combatant.body_radius and lateral_distance <= half_width + combatant.body_radius
			var center_ratio := clampf(float(skill.get("center_ratio", 0.0)), 0.0, 1.0)
			if hit and center_ratio > 0.0 and lateral_distance <= half_width * center_ratio + combatant.body_radius:
				damage_multiplier = maxf(float(skill.get("center_damage_multiplier", 1.0)), 1.0)
		if not hit:
			continue
		if amount > 0.0:
			_damage_combatant(source, combatant, amount * damage_multiplier)
		if combatant is Unit and is_instance_valid(combatant) and combatant.hp > 0.0 and float(skill.get("slow_duration", 0.0)) > 0.0:
			(combatant as Unit).apply_slow(float(skill.slow_duration), float(skill.get("slow_multiplier", 1.0)))


## 向施法开始时锁定方向的前方圆形区域落下一颗星；冲击波由固定 tick 独立扩散。
func apply_forward_area(source: Unit, skill: Dictionary, forward: Vector2 = Vector2.ZERO) -> void:
	forward = frontal_forward(source) if forward.length_squared() < 0.001 else forward.normalized()
	var center := source.global_position + forward * maxf(float(skill.get("forward_distance", 0.0)), 0.0)
	var radius := maxf(float(skill.get("radius", 0.0)), 0.0)
	var amount := maxf(float(skill.get("damage", 0.0)), 0.0)
	var stun_duration := maxf(float(skill.get("stun_duration", 0.0)), 0.0)
	var already_hit := {}
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if combatant == source or not is_instance_valid(combatant) or combatant.team == source.team or combatant.hp <= 0.0:
			continue
		if combatant.global_position.distance_to(center) > radius + combatant.body_radius:
			continue
		already_hit[int(combatant.get_instance_id())] = true
		if amount > 0.0:
			_damage_combatant(source, combatant, amount, center)
		if combatant is Unit and is_instance_valid(combatant) and combatant.hp > 0.0 and float(skill.get("slow_duration", 0.0)) > 0.0:
			(combatant as Unit).apply_slow(float(skill.slow_duration), float(skill.get("slow_multiplier", 1.0)))
		if is_instance_valid(combatant) and combatant.hp > 0.0 and stun_duration > 0.0 and combatant.has_method("stun"):
			combatant.stun(stun_duration)
	var zone_duration := maxf(float(skill.get("zone_duration", 0.0)), 0.0)
	var zone_tick_interval := maxf(float(skill.get("zone_tick_interval", 1.0)), 0.01)
	if zone_duration > 0.0:
		# 固定落点区域独立于施法者存活状态，创造后完整维持 zone_duration。
		continuous_area_effects.append({
			"source_ref": weakref(source), "team": source.team,
			"fixed_position": true, "center": center,
			"radius": radius,
			"damage": maxf(float(skill.get("zone_damage", 0.0)), 0.0),
			"ground_only": bool(skill.get("ground_only", false)),
			"time_left": zone_duration, "next_tick": zone_tick_interval,
			"tick_interval": zone_tick_interval,
			"slow_duration": maxf(float(skill.get("zone_slow_duration", 0.0)), 0.0),
			"slow_multiplier": clampf(float(skill.get("zone_slow_multiplier", 1.0)), 0.1, 1.0),
		})
		add_fixed_area_effect(center, radius, radius, zone_duration, source.team, &"frost_storm")
		if _controller.mode == "host":
			_controller._rpc_frontal_skill_fx.rpc(
				-1, center, Vector2.UP, 0.0, radius, radius, zone_duration, source.team, "frost_storm"
			)
	var shockwave_duration := maxf(float(skill.get("shockwave_duration", 0.0)), 0.0)
	if bool(skill.get("shockwave_full_only", false)) and not bool(skill.get("full_resource", false)):
		shockwave_duration = 0.0
	if shockwave_duration <= 0.0:
		return
	var end_radius := maxf(float(skill.get("shockwave_end_radius", radius)), radius)
	expanding_shockwaves.append({
		"source_ref": weakref(source), "team": source.team, "center": center,
		"start_radius": radius, "end_radius": end_radius,
		"previous_radius": radius, "timer": shockwave_duration, "duration": shockwave_duration,
		"damage": maxf(float(skill.get("shockwave_damage", 0.0)), 0.0),
		"slow_duration": maxf(float(skill.get("shockwave_slow_duration", 0.0)), 0.0),
		"slow_multiplier": clampf(float(skill.get("shockwave_slow_multiplier", 1.0)), 0.1, 1.0),
		"hit_ids": already_hit,
	})
	add_fixed_area_effect(center, radius, end_radius, shockwave_duration, source.team, &"shockwave")
	if _controller.mode == "host":
		_controller._rpc_frontal_skill_fx.rpc(
			-1, center, Vector2.UP, 0.0, end_radius, radius, shockwave_duration, source.team, "shockwave"
		)


func begin_forward_area_visual(source: Unit, skill: Dictionary, cast_forward: Vector2) -> void:
	# 固定持续区域技能在 Impact 时直接生成正式区域；不提前绘制龙王式落点预警/星体。
	if float(skill.get("zone_duration", 0.0)) > 0.0:
		return
	var duration := maxf(float(skill.get("impact_delay", 0.0)), 0.0)
	if duration <= 0.0:
		return
	var center := source.global_position + cast_forward.normalized() * maxf(float(skill.get("forward_distance", 0.0)), 0.0)
	var radius := maxf(float(skill.get("radius", 0.0)), 0.0)
	add_fixed_area_effect(center, radius, radius, duration, source.team, &"target_circle")
	if _controller.mode == "host":
		_controller._rpc_frontal_skill_fx.rpc(
			-1, center, Vector2.UP, 0.0, radius, 0.0, duration, source.team, "target_circle"
		)


func add_fixed_area_effect(center: Vector2, start_radius: float, end_radius: float, duration: float, p_team: int, shape: StringName) -> void:
	frontal_effects.append({
		"source_ref": null, "net_id": -1, "fixed_position": true,
		"pos": center, "forward": Vector2.UP, "source_radius": 0.0,
		"length": end_radius, "width": start_radius, "shape": String(shape),
		"timer": duration, "duration": duration, "team": p_team,
	})


func _damage_combatant(source: Unit, combatant: Node2D, amount: float, origin: Vector2 = Vector2(INF, INF)) -> bool:
	if combatant == null or not is_instance_valid(combatant) or combatant.hp <= 0.0 or amount <= 0.0:
		return false
	if source.battle_context != null:
		return source.battle_context.apply_damage_pulse(source, combatant, amount, 0.0, origin, false)
	var was_alive: bool = combatant.hp > 0.0
	var source_position := source.global_position if origin.x == INF else origin
	var landed: bool = combatant.take_damage(amount, source, source.team, source_position)
	if landed and was_alive and combatant.hp <= 0.0 and is_instance_valid(source):
		source.on_enemy_killed(combatant)
	return landed


func begin_frontal_visual(source: Unit, skill: Dictionary, cast_forward: Vector2) -> void:
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
	if _controller.mode == "host":
		_controller._rpc_frontal_skill_fx.rpc(
			source.net_id, source.global_position, cast_forward, source.body_radius,
			float(skill.get("length", 0.0)), float(skill.get("width", skill.get("far_width", 0.0))),
			duration, source.team, String(skill.get("shape", "rectangle")),
			float(skill.get("near_width", skill.get("width", 0.0))), float(skill.get("far_width", skill.get("width", 0.0))),
			float(skill.get("arc_degrees", 0.0)), int(skill.get("projectile_count", 0)),
			float(skill.get("center_ratio", 0.0)), float(skill.get("center_width", 0.0)),
			bool(skill.get("fan_inner_arc", false)), String(skill.get("projectile_visual", "arrow")),
			projectile_launch_delay, projectile_flight_duration,
			float(skill.get("projectile_visual_height", 0.0)),
			float(skill.get("projectile_visual_forward_offset", source.body_radius)),
			float(skill.get("projectile_visual_width", 0.0))
		)


func tick_effects(dt: float) -> void:
	_tick_expanding_shockwaves(dt)
	_tick_continuous_area_effects(dt)


func _tick_continuous_area_effects(dt: float) -> void:
	var alive: Array[Dictionary] = []
	for effect in continuous_area_effects:
		var source = (effect.source_ref as WeakRef).get_ref()
		var fixed_position := bool(effect.get("fixed_position", false))
		if not fixed_position and (not source is Unit or not is_instance_valid(source) or source.hp <= 0.0):
			continue
		# 跟随施法者的持续范围与施法者控制状态一起暂停；固定落点区域
		# 已经脱离施法动作，不因凤凰死亡或被控制而缩短 3 秒寿命。
		if not fixed_position and source is Unit and ((source as Unit).is_frozen() or (source as Unit).is_stunned()):
			alive.append(effect)
			continue
		effect.time_left = maxf(float(effect.time_left) - dt, 0.0)
		effect.next_tick = float(effect.next_tick) - dt
		var tick_interval := maxf(float(effect.get("tick_interval", 1.0)), 0.01)
		# 支持测试或低帧率调用一次跨过多个固定脉冲；固定模拟通常每次只跨一个。
		while float(effect.next_tick) <= 0.001:
			_apply_continuous_area_pulse(source as Unit, effect)
			effect.next_tick = float(effect.next_tick) + tick_interval
		if float(effect.time_left) > 0.001:
			alive.append(effect)
	continuous_area_effects.assign(alive)


func _tick_expanding_shockwaves(dt: float) -> void:
	var alive: Array[Dictionary] = []
	for shockwave in expanding_shockwaves:
		shockwave.timer = maxf(float(shockwave.timer) - dt, 0.0)
		var progress := 1.0 - float(shockwave.timer) / maxf(float(shockwave.duration), 0.001)
		var current_radius := lerpf(float(shockwave.start_radius), float(shockwave.end_radius), progress)
		var source = (shockwave.source_ref as WeakRef).get_ref()
		for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
			if not is_instance_valid(combatant) or combatant.team == int(shockwave.team) or combatant.hp <= 0.0:
				continue
			var instance_id := int(combatant.get_instance_id())
			if (shockwave.hit_ids as Dictionary).has(instance_id):
				continue
			if combatant.global_position.distance_to(shockwave.center) > current_radius + combatant.body_radius:
				continue
			shockwave.hit_ids[instance_id] = true
			if source is Unit and is_instance_valid(source):
				_damage_combatant(source as Unit, combatant, float(shockwave.damage), shockwave.center)
			else:
				combatant.take_damage(float(shockwave.damage), null, int(shockwave.team), shockwave.center)
			if combatant is Unit and is_instance_valid(combatant) and combatant.hp > 0.0 and float(shockwave.slow_duration) > 0.0:
				(combatant as Unit).apply_slow(float(shockwave.slow_duration), float(shockwave.slow_multiplier))
		shockwave.previous_radius = current_radius
		if float(shockwave.timer) > 0.001:
			alive.append(shockwave)
	expanding_shockwaves.assign(alive)


func apply_frontal_stun(source: Unit, skill: Dictionary, forward: Vector2) -> void:
	forward = forward.normalized()
	var side := Vector2(-forward.y, forward.x)
	var length := maxf(float(skill.get("length", 0.0)), 0.0)
	var half_width := maxf(float(skill.get("width", 0.0)) * 0.5, 0.0)
	var amount := maxf(float(skill.get("damage", 0.0)), 0.0)
	var stun_duration := maxf(float(skill.get("stun_duration", 0.0)), 0.0)
	var ground_only := bool(skill.get("ground_only", true))
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if combatant == source or not is_instance_valid(combatant) or combatant.team == source.team or combatant.hp <= 0.0:
			continue
		if ground_only and combatant is Unit and (combatant as Unit).is_air:
			continue
		var local_offset: Vector2 = combatant.global_position - source.global_position
		var forward_distance := local_offset.dot(forward) - source.body_radius
		var lateral_distance := absf(local_offset.dot(side))
		if forward_distance < -combatant.body_radius or forward_distance > length + combatant.body_radius:
			continue
		if lateral_distance > half_width + combatant.body_radius:
			continue
		if amount > 0.0:
			combatant.take_damage(amount, source, source.team, source.global_position)
		if is_instance_valid(combatant) and combatant.hp > 0.0 and stun_duration > 0.0 and combatant.has_method("stun"):
			combatant.stun(stun_duration)


func frontal_forward(source: Unit) -> Vector2:
	var forward := source.get_visual_facing_direction()
	if forward.length_squared() < 0.001:
		forward = Vector2.UP if source.team == 0 else Vector2.DOWN
	return forward.normalized()


func add_frontal_effect(source: Unit, skill: Dictionary, duration: float, cast_forward: Vector2) -> void:
	frontal_effects.append({
		"source_ref": weakref(source),
		"net_id": source.net_id,
		"pos": source.global_position,
		"forward": cast_forward,
		"source_radius": source.body_radius,
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
		"source_ref": weakref(source),
		"net_id": source.net_id,
		"fixed_position": false,
		"pos": source.global_position,
		"forward": Vector2.UP,
		"source_radius": source.body_radius,
		"length": radius,
		"width": radius,
		"shape": "continuous_area",
		"timer": duration,
		"duration": duration,
		"team": source.team,
	})
	if _controller.mode == "host":
		_controller._rpc_frontal_skill_fx.rpc(
			source.net_id, source.global_position, Vector2.UP, source.body_radius,
			radius, radius, duration, source.team, "continuous_area"
		)


func tick_visuals(delta: float) -> void:
	var alive: Array[Dictionary] = []
	for effect in frontal_effects:
		var source = effect_source(effect)
		if source is Unit and (source.frozen_timer > 0.0 or source.stun_timer > 0.0):
			alive.append(effect)
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
		var client_source = _controller._client_units.get(net_id)
		if client_source is Unit and is_instance_valid(client_source):
			return client_source
	return null


func clear() -> void:
	frontal_effects.clear()
	expanding_shockwaves.clear()
	continuous_area_effects.clear()
