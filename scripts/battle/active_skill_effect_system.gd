class_name ActiveSkillEffectSystem
extends RefCounted
## 主动技能 EffectExecution 执行器。
## 资格归 ActiveSkillRoster，施法协调归 ActiveSkillLifecycle；这里只执行权威效果。

var dash_strikes: Array[DashStrikeState] = []
var ornn_charges: Array[OrnnChargeState] = []
var death_heal_zones: Array[Dictionary] = []
var sacrifice_results: Array[Dictionary] = []
var _next_result_id := 1
var _resolved_results: Dictionary = {}
var _expiry_explosions: Array[Dictionary] = []
var expanding_shockwaves: Array[Dictionary] = []
## 施法者跟随型持续范围效果；每个 pulse 都读取施法者当前权威位置。
var continuous_area_effects: Array[Dictionary] = []

class RefundReceipt extends RefCounted:
	var settled := false
	var rollback: Callable
	func refund() -> void:
		if settled: return
		settled = true
		if rollback.is_valid(): rollback.call()

class CastHitState extends RefCounted:
	var landed := false

var _controller: Node2D
var _presentation: SkillEffectPresentation


func _init(controller: Node2D, presentation: SkillEffectPresentation) -> void:
	_controller = controller
	_presentation = presentation

## Cast Start 固化资源倍率和强/弱动作选择。返回值只进入本次权威时间线，
## 不回写 CardDB，也不会让动画决定伤害。
func prepare_cast(source: Unit, skill: Dictionary) -> Dictionary:
	var prepared := skill.duplicate(true)
	prepared["effect_delivery"] = CombatInteraction.Delivery.new()
	if StringName(prepared.get("kind", "")) == &"blink_nova": prepared["cast_forward"] = frontal_forward(source)
	if bool(prepared.get("uses_skill_resource", false)) and source.skill_resource_enabled and source.skill_resource_max > 0.0:
		var resource_stacks := source.get_skill_resource_stacks()
		var resource_ratio := source.get_skill_resource_ratio()
		if not bool(prepared.get("resource_consume_only_full", false)) or resource_ratio >= 0.999:
			source.consume_skill_resource_ratio()
		else:
			source.grant_partial_cast_resource(float(prepared.get("resource_nonfull_cast_gain", 0.0)))
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
			prepared["result_creation_delay"] = float(prepared.get("full_resource_result_creation_delay", prepared.get("result_creation_delay", 0.0)))
			prepared["full_resource"] = true
			prepared["first_hit_heal"] = maxf(float(prepared.get("full_resource_first_hit_heal", 0.0)), 0.0)
			prepared["cast_end_heal"] = maxf(float(prepared.get("full_resource_cast_end_heal", 0.0)), 0.0)
		if prepared.has("resource_shield_max"):
			prepared["shield"] = maxf(float(prepared.get("resource_shield_max", 0.0)), 0.0) * resource_ratio
	for key in prepared:
		if String(key).ends_with("duration") and (prepared[key] is float or prepared[key] is int):
			prepared[key] = BattleNumbers.decimal(float(prepared[key]))
	return prepared


## 双形态技能只在 Cast Start 决定形态分支和锁定朝向，之后进入 Main 的通用 Impact 队列。
func prepare_dual_form_cast(source: Unit, skill: Dictionary) -> Dictionary:
	var prepared := skill.duplicate(true)
	prepared["effect_delivery"] = CombatInteraction.Delivery.new()
	prepared["cast_forward"] = frontal_forward(source)
	if source.form_index == 0:
		if not source.transform_to_mega(true):
			return {}
		prepared["impact_delay"] = maxf(float(prepared.get("transform_impact_delay", 0.0)), 0.0)
		prepared["cast_duration"] = maxf(float(prepared.get("transform_cast_duration", 0.0)), 0.0)
		# transform_to_mega() 已发布合成变形动作，不再重复播放大形态主动动作。
		prepared["visual_action"] = ""
	for key in prepared:
		if String(key).ends_with("duration") and (prepared[key] is float or prepared[key] is int):
			prepared[key] = BattleNumbers.decimal(float(prepared[key]))
	return prepared


## Cast Start 的效果必须在施法窗口开始时发生；它不依赖动画，也不等待 EffectExecution。
func apply_cast_start(source: Unit, skill: Dictionary) -> void:
	if StringName(skill.get("kind", "")) == &"counter_strike":
		source.begin_counter_strike(skill)
	if StringName(skill.get("kind", "")) == &"aftershock":
		source.apply_damage_reduction(float(skill.duration), float(skill.damage_reduction), skill, source.status_source("aftershock"))
	if StringName(skill.get("kind", "")) == &"undying_rage":
		source.begin_undying_rage(float(skill.duration))
	if not bool(skill.get("shield_on_cast_start", false)):
		return
	var amount := maxf(float(skill.get("shield", 0.0)), 0.0)
	var duration := maxf(float(skill.get("shield_duration", 0.0)), 0.0)
	if amount <= 0.0 or duration <= 0.0:
		return
	source.add_shield(amount, duration, bool(skill.get("shield_decay", false)), source.status_source("shield"))


## Cast End 效果与动作总时长对齐，但仍由固定模拟计时，不依赖 AnimationPlayer 回调。
func apply_cast_end(source: Unit, skill: Dictionary) -> void:
	if bool(skill.get("cast_end_heal_requires_hit", false)):
		var state = skill.get("cast_hit_state")
		if not state is CastHitState or not state.landed:
			return
	var heal_amount := maxf(float(skill.get("cast_end_heal", 0.0)), 0.0)
	if heal_amount > 0.0:
		source.heal(heal_amount)


func apply(source: Unit, skill: Dictionary) -> bool:
	var previous := CombatInteraction.current_delivery
	CombatInteraction.current_delivery = skill.get("effect_delivery")
	var result := _apply(source, skill)
	CombatInteraction.current_delivery = previous
	return result

func _apply(source: Unit, skill: Dictionary) -> bool:
	match StringName(skill.get("kind", "")):
		&"self_sacrifice":
			source.sacrifice_without_reward()
		&"effect_shield":
			source.apply_effect_shield(float(skill.duration), float(skill.get("block_haste_duration", 0.0)), float(skill.get("block_attack_speed_multiplier", 1.0)), source.status_source("effect_shield"))
			source.battle_context.notify_unit_audio_event(source, &"effect_shield:start", source.get_visual_screen_position())
		&"counter_strike", &"aftershock", &"undying_rage":
			pass # 效果在 Cast Start 原子生效，受控不取消已施加的独立状态。
		&"death_spawn":
			for target in _skill_target_units(source, skill):
				target.apply_death_spawn(String(skill.spawn_id), float(skill.duration), source.status_source("death_spawn"))
		&"sacrifice_empower":
			var applied := false
			for target in _skill_target_units(source, skill):
				applied = target.apply_sacrifice_empowerment(float(skill.damage_multiplier), float(skill.visual_scale_multiplier), float(skill.health_bonus_ratio), float(skill.body_scale_multiplier), float(skill.speed_multiplier)) or applied
			return applied
		&"permanent_growth":
			return apply_permanent_growth(source, skill)
		&"terrain_charge":
			ornn_charges.append(OrnnChargeState.new(source, skill))
			_controller.notify_unit_audio_event(source, &"charge:start", source.global_position)
		&"dash_strike":
			dash_strikes.append(DashStrikeState.new(source, skill))
		&"bleeding_execute":
			source.prepare_execute_attack(skill)
		&"explosive_shield":
			if source.hp <= 0.0 or source.death_form.used: return false
			source.add_shield(float(skill.shield), float(skill.shield_duration), false, source.status_source("explosive_shield"), {}, skill)
		&"sanctuary":
			source.begin_target_protection(float(skill.radius), float(skill.duration))
		&"timed_form":
			return source.transform_to_mega(true)
		&"buff":
			for target in _skill_target_units(source, skill):
				var target_skill := _member_buff_skill(target, skill)
				if float(target_skill.get("heal_amount", 0.0)) > 0.0:
					target.heal(float(target_skill.heal_amount))
				target.apply_active_buff(
					float(target_skill.get("duration", 0.0)),
					float(target_skill.get("speed_multiplier", 1.0)),
					float(target_skill.get("damage_multiplier", 1.0)),
					float(target_skill.get("attack_speed_multiplier", 1.0)),
					bool(target_skill.get("ignore_movement_slow", false)),
					bool(target_skill.get("ignore_attack_speed_slow", false)),
					source.status_source(String(skill.get("name", "buff")))
				)
				if float(target_skill.get("heal_ratio", 0.0)) > 0.0:
					target.apply_timed_lifesteal(float(target_skill.duration), float(target_skill.heal_ratio), source.status_source("timed_lifesteal"))
				if bool(target_skill.get("ignore_unit_collision", false)):
					target.apply_unit_phasing(float(target_skill.duration), source.status_source("unit_phasing"))
				if target_skill.has("range_bonus") or target_skill.has("piercing_attacks") or target_skill.has("projectile_speed_multiplier"):
					target.apply_ranged_attack(float(target_skill.duration), float(target_skill.get("range_bonus", 0.0)), bool(target_skill.get("piercing_attacks", false)), float(target_skill.get("piercing_distance", 0.0)), float(target_skill.get("projectile_speed_multiplier", 1.0)), source.status_source("ranged_attack"))
				if not bool(target_skill.get("shield_on_cast_start", false)):
					target.add_shield(float(target_skill.get("shield", 0.0)), float(target_skill.get("shield_duration", target_skill.get("duration", 0.0))), bool(target_skill.get("shield_decay", false)), source.status_source("shield"))
		&"blink_nova":
			var origin := source.global_position
			var direction: Vector2 = skill.get("cast_forward", frontal_forward(source))
			# 配置为额外前延的基础距离，实时加上施法者半径；加2px覆盖结构分离间距及边界余量。
			var extension := float(skill.landing_extension) + source.body_radius + 2.0 if skill.has("landing_extension") else 0.0
			var landing := UnitLandingQuery.displacement_endpoint(source, origin, direction, float(skill.length), extension)
			if not landing.is_finite(): return false
			_presentation.present_fixed_area(origin, 65.0, 65.0, 3.0, source.team, &"riftwalk_vanish")
			source.teleport_to(landing)
			_presentation.present_fixed_area(landing, 65.0, 65.0, 3.0, source.team, &"riftwalk_appear")
			activate_nova(source, skill)
			source.battle_context.notify_unit_audio_event(source, &"active:land", landing)
		&"nova":
			activate_nova(source, skill)
			if skill.has("impact_visual_shape"):
				_presentation.present_fixed_area(source.global_position, float(skill.radius), float(skill.radius), float(skill.impact_visual_duration), source.team, StringName(skill.impact_visual_shape))
		&"summon":
			activate_summon(source, skill)
		&"toggle_form":
			source.toggle_weapon_form()
		&"dual_form":
			apply_frontal_stun(source, skill, skill.get("cast_forward", source.active_skill_cast_facing))
		&"frontal":
			apply_frontal(source, skill, skill.get("cast_forward", source.active_skill_cast_facing))
		&"forward_area":
			apply_forward_area(source, skill, skill.get("cast_forward", source.active_skill_cast_facing if is_instance_valid(source) else Vector2.ZERO))
		&"continuous_area":
			activate_continuous_area(source, skill)
		&"channeled_attack":
			source.prepare_channeled_attack(skill)
		&"empowered_attack":
			source.prepare_empowered_attack(
				float(skill.get("empowered_damage_multiplier", 1.0)),
				float(skill.get("empowered_speed_multiplier", 1.0)),
				int(skill.get("blind_charges", 0)),
				{"hit_heal": float(skill.get("hit_heal", 0.0)), "strike_type": skill.get("strike_type", "basic_attack"), "cleave_damage": float(skill.get("cleave_damage", 0.0)), "cleave_radius": float(skill.get("cleave_radius", 0.0)), "cleave_heal_ratio": float(skill.get("heal_ratio", 0.0))}
			)
		&"attack_lifesteal":
			for target in _skill_target_units(source, skill):
				target.apply_attack_lifesteal(
					float(skill.get("heal_ratio", 0.0)),
					float(skill.get("max_health_ratio", 1.0))
				)
		&"restoration_shield":
			for target in _skill_target_units(source, skill):
				target.add_restoration_shield(float(skill.get("shield", 0.0)), float(skill.get("shield_duration", 0.0)), source.status_source("restoration_shield"))
		&"area_shield":
			apply_area_shield(source, skill)
		_:
			push_error("未实现的主动技能 kind：%s" % String(skill.get("kind", "")))
			return false
	return true


## 范围护盾沿用普通攻击的“表面间距”口径：技能 radius 与卡牌 attack range
## 可以填同一数值，大小不同的友军也会在与索敌一致的边界上获得护盾。
## combatants 中的 Unit、建筑、防御塔与水晶统一提供 add_shield()，都可成为目标。
static func growth_target(source: Unit, skill: Dictionary) -> Unit:
	if not is_instance_valid(source) or not source.is_inside_tree(): return null
	var candidates: Array[Unit] = []
	var radius := float(skill.get("radius", 0.0))
	for target in source.get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(target) or not target is Unit: continue
		if target.is_building or target.card_id == "anivia_egg" or target.growth_body_scale > 1.0: continue
		if not CombatInteraction.allows_allied_target(target, source.team): continue
		if source.global_position.distance_squared_to(target.global_position) > radius * radius: continue
		candidates.append(target)
	candidates.sort_custom(func(a: Unit, b: Unit) -> bool:
		var ac := int(CardDB.get_card(a.card_id).get("cost", 0))
		var bc := int(CardDB.get_card(b.card_id).get("cost", 0))
		if ac != bc: return ac > bc
		var ad := source.global_position.distance_squared_to(a.global_position)
		var bd := source.global_position.distance_squared_to(b.global_position)
		if not is_equal_approx(ad, bd): return ad < bd
		return a.combat_source_id < b.combat_source_id
	)
	return candidates[0] if not candidates.is_empty() else null

func apply_permanent_growth(source: Unit, skill: Dictionary) -> bool:
	var target := growth_target(source, skill)
	if target == null or not target.apply_permanent_growth(float(skill.health_bonus_ratio), float(skill.body_scale_multiplier)):
		var receipt = skill.get("refund_receipt")
		if receipt is RefundReceipt: receipt.refund()
		source.cancel_skill_cast()
		return false
	var receipt = skill.get("refund_receipt")
	if receipt is RefundReceipt: receipt.settled = true
	_controller.present_growth_wave(target, float(skill.knockback_radius))
	var order: Array = skill.get("displacement_order", [])
	if order.is_empty(): order = _controller.combat_service().next_displacement_order(source)
	for enemy in source.get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(enemy) or not enemy is Unit or enemy.team == source.team or enemy.is_building: continue
		if not CombatInteraction.allows(enemy, source, source.team, target.global_position): continue
		if enemy.global_position.distance_to(target.global_position) > float(skill.knockback_radius) + enemy.body_radius: continue
		enemy.apply_knockback(target.global_position, float(skill.knockback), float(skill.knockback_duration), float(skill.get("knockback_mass_factor_max", 1.4)), order, CombatInteraction.effect_context(source))
	return true

func apply_area_shield(source: Unit, skill: Dictionary) -> void:
	_controller.notify_unit_audio_event(source, &"shield:cast", source.global_position)
	var radius := maxf(float(skill.get("radius", 0.0)), 0.0)
	var amount := maxf(float(skill.get("shield", 0.0)), 0.0)
	var duration := maxf(float(skill.get("shield_duration", 0.0)), 0.0)
	if radius <= 0.0 or amount <= 0.0 or duration <= 0.0:
		return
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(combatant) or not combatant is Node2D or combatant.hp <= 0.0:
			continue
		var ally = combatant
		if ally.team != source.team:
			continue
		if source.surface_gap_to_circle(ally.global_position, ally.body_radius) > radius:
			continue
		ally.add_shield(amount, duration, bool(skill.get("shield_decay", false)), source.status_source("shield"))
		_controller.notify_unit_audio_event(source, &"shield:applied", ally.global_position)


## 主动效果默认只作用于施法者；deployment_group 会选中同一次卡牌部署中仍存活的成员。
func _skill_target_units(source: Unit, skill: Dictionary) -> Array[Unit]:
	var targets: Array[Unit] = []
	if StringName(skill.get("target_scope", "self")) != &"deployment_group" or source.deployment_group_id < 0:
		if CombatInteraction.allows_allied_target(source, source.team): targets.append(source)
		return targets
	for member in _controller.runtime.living_deployment_members(source.deployment_group_id, source.team):
		if CombatInteraction.allows_allied_target(member, source.team): targets.append(member)
	return targets


## 异构编队的主动技能可声明复用成员自己的同名 buff；这样近战兵和远程兵
## 保留各自的持续时间、移速/攻速倍率与表现特效，技能资格仍由编队持有者统一管理。
func _member_buff_skill(target: Unit, fallback: Dictionary) -> Dictionary:
	if not bool(fallback.get("copy_member_buff", false)):
		return fallback
	var member_stats := CardDB.get_card(target.card_id)
	var skill_name := StringName(fallback.get("name", ""))
	for candidate in member_stats.get("active_skills", []):
		if (
			candidate is Dictionary
			and StringName(candidate.get("kind", "")) == &"buff"
			and (skill_name.is_empty() or StringName(candidate.get("name", "")) == skill_name)
		):
			return candidate
	return fallback


func activate_nova(source: Unit, skill: Dictionary) -> void:
	var displacement_order: Array = skill.get("displacement_order", [])
	if displacement_order.is_empty():
		displacement_order = _controller.combat_service().next_displacement_order(source)
	var radius := float(skill.get("radius", 0.0))
	var amount := float(skill.get("damage", 0.0))
	var knockback := float(skill.get("knockback", 0.0))
	var knockback_duration := float(skill.get("knockback_duration", 0.2))
	var knockback_mass_factor_max := float(skill.get("knockback_mass_factor_max", 1.4))
	var ground_only := bool(skill.get("ground_only", false))
	var slow_duration := float(skill.get("slow_duration", 0.0))
	var slow_multiplier := float(skill.get("slow_multiplier", 1.0))
	var receipts: Array[Dictionary] = []
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if combatant == source or not is_instance_valid(combatant) or combatant.team == source.team or combatant.hp <= 0.0:
			continue
		if not CombatInteraction.allows(combatant, source, source.team, source.global_position): continue
		if ground_only and combatant is Unit and (combatant as Unit).is_air:
			continue
		if combatant.global_position.distance_to(source.global_position) > radius + combatant.body_radius:
			continue
		if (amount > 0.0 or float(skill.get("stun_duration", 0.0)) > 0.0 or float(skill.get("knockback", 0.0)) > 0.0) and CombatInteraction.blocks_effect(combatant, CombatInteraction.effect_context(source)): continue
		if amount > 0.0:
			var receipt := _damage_combatant(source, combatant, amount, source.global_position)
			receipts.append(receipt)
			if String(skill.get("kind", "")) == "counter_strike":
				var target_point: Vector2 = combatant.global_position
				var hit_source_ref: WeakRef = weakref(source)
				var hit_team := source.team
				_after_damage(func():
					if not receipt.landed: return
					_presentation.present_fixed_area(target_point, 30.0, 30.0, 0.8, hit_team, &"counter_strike_hit")
					var live_source = hit_source_ref.get_ref()
					if is_instance_valid(live_source): _controller.notify_unit_audio_event(live_source, &"counter_strike:hit", target_point))
		if is_instance_valid(combatant) and combatant is Unit and combatant.hp > 0.0:
			if String(skill.get("kind", "")) == "counter_strike":
				(combatant as Unit).stun(float(skill.stun_duration), source.status_source("counter_strike"), CombatInteraction.effect_context(source))
			if knockback > 0.0:
				(combatant as Unit).apply_knockback(source.global_position, knockback, knockback_duration, knockback_mass_factor_max, displacement_order, CombatInteraction.effect_context(source))
			if slow_duration > 0.0:
				(combatant as Unit).apply_slow(slow_duration, slow_multiplier, source.status_source("skill"), CombatInteraction.effect_context(source))
				if float(skill.get("attack_slow_multiplier", 1.0)) < 1.0 and not combatant.is_building:
					(combatant as Unit).apply_attack_speed_slow(slow_duration, float(skill.attack_slow_multiplier), source.status_source("skill"), CombatInteraction.effect_context(source))
	if not bool(skill.get("shield_on_cast_start", false)):
		source.add_shield(float(skill.get("shield", 0.0)), float(skill.get("shield_duration", 0.0)), bool(skill.get("shield_decay", false)), source.status_source("shield"))


## 持续范围伤害不保存固定中心；每次脉冲都以 source.global_position 为中心。
## 首次伤害在第一个 tick_interval 到达时结算，持续 duration 秒，避免把施法
## 起始帧重复算成额外伤害。技能窗口可只锁 attack，让施法者继续移动/转向。
	var source_ref: WeakRef = weakref(source)
	_after_damage(func():
		var live_source = source_ref.get_ref()
		if receipts.any(func(result): return result.landed) and is_instance_valid(live_source):
			_controller.notify_unit_audio_event(live_source, StringName(String(skill.get("visual_action", "")) + ":hit"), live_source.global_position))

func activate_continuous_area(source: Unit, skill: Dictionary) -> void:
	var duration := maxf(float(skill.get("duration", skill.get("cast_duration", 0.0))), 0.0)
	var tick_interval := maxf(float(skill.get("tick_interval", 1.0)), 0.01)
	var radius := maxf(float(skill.get("radius", 0.0)), 0.0)
	var amount := maxf(float(skill.get("damage", 0.0)), 0.0)
	if duration <= 0.0 or radius <= 0.0 or amount <= 0.0:
		return
	continuous_area_effects.append({
		"effect_delivery": CombatInteraction.current_delivery, "created_tick": _controller.get_authoritative_server_tick() if _controller.simulation_step_active() else -1,
		"status_source": source.status_source("skill_area"), "cast_serial": source.active_skill_cast_serial, "action_serial": source.get_visual_action_serial(),
		"source_ref": weakref(source),
		"visual_action": String(skill.get("visual_action", "")),
		"team": source.team,
		"radius": radius,
		"damage": amount,
		"ground_only": bool(skill.get("ground_only", false)),
		"time_left": duration,
		"next_tick": tick_interval,
		"tick_interval": tick_interval,
	})


func _apply_continuous_area_pulse(source: Unit, effect: Dictionary) -> void:
	var previous := CombatInteraction.current_delivery
	CombatInteraction.current_delivery = effect.get("effect_delivery")
	_apply_continuous_delivery(source, effect)
	CombatInteraction.current_delivery = previous

func _apply_continuous_delivery(source: Unit, effect: Dictionary) -> void:
	var center: Vector2 = effect.get("center", Vector2.ZERO)
	if not bool(effect.get("fixed_position", false)) and source != null and is_instance_valid(source):
		center = source.global_position
	var radius := maxf(float(effect.get("radius", 0.0)), 0.0)
	var amount := maxf(float(effect.get("damage", 0.0)), 0.0)
	var ground_only := bool(effect.get("ground_only", false))
	var receipts: Array[Dictionary] = []
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		var source_team := int(effect.get("team", source.team if source != null else -1))
		if combatant == source or not is_instance_valid(combatant) or combatant.team == source_team or combatant.hp <= 0.0:
			continue
		if not CombatInteraction.allows(combatant, source, source_team, effect.get("source_position", center)): continue
		if ground_only and combatant is Unit and (combatant as Unit).is_air:
			continue
		if combatant.global_position.distance_to(center) > radius + combatant.body_radius:
			continue
		if amount > 0.0:
			if source != null and is_instance_valid(source):
				receipts.append(_damage_combatant(source, combatant, amount, center))
			else:
				receipts.append(BattleNumbers.hit(combatant, amount, null, source_team, effect.get("source_position", center)))
		if is_instance_valid(combatant) and combatant is Unit and combatant.hp > 0.0 and float(effect.get("slow_duration", 0.0)) > 0.0:
			(combatant as Unit).apply_slow(float(effect.get("slow_duration", 0.0)), float(effect.get("slow_multiplier", 1.0)), effect.status_source, CombatInteraction.effect_context(source, int(effect.team), effect.get("source_position", center)))
	var action := String(effect.get("visual_action", ""))
	var source_ref: WeakRef = weakref(source) if is_instance_valid(source) else null
	_after_damage(func():
		var live_source = source_ref.get_ref() if source_ref != null else null
		if receipts.any(func(result): return result.landed) and not action.is_empty():
			_controller.notify_unit_audio_event(live_source, StringName(action + ":hit"), center))


func begin_channel_zone(source: Unit, center: Vector2, skill: Dictionary) -> void:
	continuous_area_effects.append({"effect_delivery": skill.get("effect_delivery"), "source_ref": weakref(source), "source_position": source.global_position,
		"team": source.team, "fixed_position": true, "center": center, "radius": float(skill.radius),
		"damage": float(skill.zone_damage), "time_left": float(skill.zone_duration),
		"next_tick": float(skill.zone_tick_interval), "tick_interval": float(skill.zone_tick_interval),
		"created_tick": _controller.get_authoritative_server_tick() if _controller.simulation_step_active() else -1})
	_controller.present_zone_audio(source, "channel", center, float(skill.zone_duration))
	_presentation.present_fixed_area(center, float(skill.radius), float(skill.radius), float(skill.zone_duration), source.team, &"nether_zone")

func activate_summon(source: Unit, skill: Dictionary) -> void:
	var spawn_id := String(skill.get("spawn_id", ""))
	var count := maxi(int(skill.get("spawn_count", 1)), 1)
	var summon_stats := CardDB.get_unit_stats(spawn_id)
	if summon_stats.is_empty():
		push_error("主动技能引用了不存在的召唤单位：%s" % spawn_id)
		return
	if String(skill.get("spawn_side", "")) == "below":
		source.begin_summon_sequence(spawn_id, count, float(skill.spawn_sequence_interval), 0.0)
		return
	var summon_radius := float(summon_stats.get("radius", 14.0))
	var summon_team := source.team
	var summon_center := source.global_position
	var source_radius := source.body_radius
	if bool(skill.get("sacrifice_source", false)):
		source.end_life_for_summon() # 先释放建筑占位，召唤不依赖已死亡来源。
	for index in range(count):
		var angle := TAU * float(index) / float(count)
		var offset := Vector2.RIGHT.rotated(angle) * (source_radius + summon_radius + Unit.SUMMON_SEPARATION)
		_controller.spawn_summoned(summon_team, spawn_id, summon_center + offset, -1.0, "", -1, summon_center)


## 扇形/梯形主动统一按施法开始时锁定的朝向结算。目标碰撞圆会扩张边界，
## 但动画、箭矢线条和预警多边形都不参与权威命中。
func apply_frontal(source: Unit, skill: Dictionary, forward: Vector2 = Vector2.ZERO) -> void:
	var source_ref: WeakRef = weakref(source)
	var action := String(skill.get("visual_action", ""))
	if not action.is_empty():
		_controller.notify_unit_audio_event(source, StringName(action + ":release"), source.global_position)
	if bool(skill.get("projectile_stop_on_hit", false)) or bool(skill.get("projectile_piercing", false)):
		_controller.projectile_service().launch_skill_fan(source, skill, frontal_forward(source) if forward.length_squared() < 0.001 else forward.normalized())
		return
	var receipts: Array[Dictionary] = []
	var center_receipts: Array[Dictionary] = []
	forward = frontal_forward(source) if forward.length_squared() < 0.001 else forward.normalized()
	_presentation.present_frontal_impact(source, skill, forward)
	var side := Vector2(-forward.y, forward.x)
	var length := maxf(float(skill.get("length", 0.0)), 0.0)
	var shape := StringName(skill.get("shape", "trapezoid"))
	var amount := maxf(float(skill.get("damage", 0.0)), 0.0)
	var ground_only := bool(skill.get("ground_only", false))
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if combatant == source or not is_instance_valid(combatant) or combatant.team == source.team or combatant.hp <= 0.0:
			continue
		if not CombatInteraction.allows(combatant, source, source.team, source.global_position): continue
		if ground_only and combatant is Unit and (combatant as Unit).is_air:
			continue
		var local_offset: Vector2 = combatant.global_position - source.global_position
		var forward_distance := local_offset.dot(forward) - source.body_radius
		var lateral_distance := absf(local_offset.dot(side))
		var hit := false
		var damage_multiplier := 1.0
		var in_center := false
		if shape == &"fan":
			var half_angle := deg_to_rad(clampf(float(skill.get("arc_degrees", 0.0)), 0.0, 180.0) * 0.5)
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
			in_center = false
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
			var center_width := maxf(float(skill.get("center_width", 0.0)), 0.0)
			var center_half := center_width * 0.5 if center_width > 0.0 else half_width * center_ratio
			if hit and center_half > 0.0 and lateral_distance <= center_half + combatant.body_radius:
				in_center = true
				damage_multiplier = maxf(float(skill.get("center_damage_multiplier", 1.0)), 1.0)
		if not hit:
			continue
		if amount > 0.0:
			var hit_amount := BattleNumbers.quantity(amount * damage_multiplier)
			if bool(skill.get("applies_on_hit_passive", false)):
				hit_amount += source.on_hit_passive_damage(combatant)
			var receipt := _damage_combatant(source, combatant, hit_amount)
			receipts.append(receipt)
			if in_center: center_receipts.append(receipt)
			if skill.get("cast_hit_state") is CastHitState:
				var state: CastHitState = skill.cast_hit_state
				_after_damage(func():
					if not receipt.landed or state.landed: return
					state.landed = true
					var live_source = source_ref.get_ref()
					if is_instance_valid(live_source) and live_source.hp > 0.0:
						live_source.heal(float(skill.get("first_hit_heal", 0.0))), true)
		if is_instance_valid(combatant) and combatant is Unit and combatant.hp > 0.0 and float(skill.get("slow_duration", 0.0)) > 0.0:
			(combatant as Unit).apply_slow(float(skill.slow_duration), float(skill.get("slow_multiplier", 1.0)), source.status_source("skill"), CombatInteraction.effect_context(source))
	_after_damage(func():
		var live_source = source_ref.get_ref()
		if not is_instance_valid(live_source) or action.is_empty(): return
		var center_landed := center_receipts.any(func(result): return result.landed)
		if receipts.any(func(result): return result.landed):
			var cue := action + ":hit"
			if skill.has("hit_audio_phase"):
				cue += "_" + String(skill.hit_audio_phase)
				if center_landed: cue += "_center"
			_controller.notify_unit_audio_event(live_source, StringName(cue), live_source.global_position)
		if center_landed:
			_controller.notify_unit_audio_event(live_source, StringName(action + ":hit_center"), live_source.global_position))


## 向施法开始时锁定方向的前方圆形区域落下一颗星；冲击波由固定 tick 独立扩散。

func apply_forward_area(source: Unit, skill: Dictionary, forward: Vector2 = Vector2.ZERO) -> void:
	var context: Dictionary = skill.get("independent_result", {})
	var result_id := int(context.get("result_id", 0))
	if result_id > 0:
		if _resolved_results.has(result_id): return
		_resolved_results[result_id] = true
	if context.is_empty():
		forward = frontal_forward(source) if forward.length_squared() < 0.001 else forward.normalized()
		context = {"center": source.global_position + forward * maxf(float(skill.get("forward_distance", 0.0)), 0.0),
			"team": source.team, "source_position": source.global_position, "source_ref": weakref(source), "form": source.form_index,
			"status_source": source.status_source("skill_area"), "audio_source": PresentationConfig.attack_source(source)}
	var center: Vector2 = context.center
	var source_team := int(context.team)
	_controller.present_skill_projectile_hit(context.audio_source, String(skill.get("visual_action", "")), center, "impact")
	var radius := maxf(float(skill.get("radius", 0.0)), 0.0)
	var amount := maxf(float(skill.get("damage", 0.0)), 0.0)
	var stun_duration := maxf(float(skill.get("stun_duration", 0.0)), 0.0)
	var already_hit := {}
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if combatant == source or not is_instance_valid(combatant) or combatant.team == source_team or combatant.hp <= 0.0:
			continue
		if not CombatInteraction.allows(combatant, source, source_team, context.get("source_position", center)): continue
		if combatant.global_position.distance_to(center) > radius + combatant.body_radius:
			continue
		already_hit[int(combatant.get_instance_id())] = true
		if (amount > 0.0 or float(skill.get("stun_duration", 0.0)) > 0.0 or float(skill.get("knockback", 0.0)) > 0.0) and CombatInteraction.blocks_effect(combatant, CombatInteraction.effect_context(source)): continue
		if amount > 0.0:
			_damage_result(source, combatant, amount, context)
		if is_instance_valid(combatant) and combatant is Unit and combatant.hp > 0.0 and float(skill.get("slow_duration", 0.0)) > 0.0:
			(combatant as Unit).apply_slow(float(skill.slow_duration), float(skill.get("slow_multiplier", 1.0)), context.status_source, CombatInteraction.effect_context(source, source_team, context.get("source_position", center)))
		if is_instance_valid(combatant) and combatant.hp > 0.0 and stun_duration > 0.0:
			combatant.stun(stun_duration, context.status_source, CombatInteraction.effect_context(source, source_team, context.get("source_position", center)))
	var zone_duration := maxf(float(skill.get("zone_duration", 0.0)), 0.0)
	var zone_tick_interval := maxf(float(skill.get("zone_tick_interval", 1.0)), 0.01)
	if zone_duration > 0.0:
		# 固定落点区域独立于施法者存活状态，创造后完整维持 zone_duration。
		continuous_area_effects.append({
		"effect_delivery": CombatInteraction.current_delivery, "created_tick": _controller.get_authoritative_server_tick() if _controller.simulation_step_active() else -1,
			"status_source": context.status_source,
		"source_ref": context.source_ref, "source_position": context.get("source_position", center), "team": source_team,
			"fixed_position": true, "center": center,
			"radius": radius,
			"damage": maxf(float(skill.get("zone_damage", 0.0)), 0.0),
			"ground_only": bool(skill.get("ground_only", false)),
			"time_left": zone_duration, "next_tick": zone_tick_interval,
			"tick_interval": zone_tick_interval,
			"slow_duration": maxf(float(skill.get("zone_slow_duration", 0.0)), 0.0),
			"slow_multiplier": clampf(float(skill.get("zone_slow_multiplier", 1.0)), 0.1, 1.0),
		})
		_presentation.present_fixed_area(center, radius, radius, zone_duration, source_team, &"frost_storm")
		_controller.present_zone_audio(source, String(skill.get("visual_action", "")), center, zone_duration)

	# 落地爆闪由真实效果节点触发；预警自行结束不能伪造命中。
	if float(skill.get("shockwave_duration", 0.0)) > 0.0:
		var impact_shape := &"star_impact_strong" if bool(skill.get("full_resource", false)) else &"star_impact"
		_presentation.present_fixed_area(center, radius, radius, 0.65, source_team, impact_shape)

	var shockwave_duration := maxf(float(skill.get("shockwave_duration", 0.0)), 0.0)
	if bool(skill.get("shockwave_full_only", false)) and not bool(skill.get("full_resource", false)):
		shockwave_duration = 0.0
	if shockwave_duration <= 0.0:
		return
	var end_radius := maxf(float(skill.get("shockwave_end_radius", radius)), radius)
	expanding_shockwaves.append({
		"effect_delivery": CombatInteraction.current_delivery, "created_tick": _controller.get_authoritative_server_tick() if _controller.simulation_step_active() else -1,
		"status_source": context.status_source,
		"source_ref": context.source_ref, "source_position": context.get("source_position", center), "team": source_team, "center": center,
		"start_radius": radius, "end_radius": end_radius,
		"previous_radius": radius, "timer": shockwave_duration, "duration": shockwave_duration,
		"damage": maxf(float(skill.get("shockwave_damage", 0.0)), 0.0),
		"slow_duration": maxf(float(skill.get("shockwave_slow_duration", 0.0)), 0.0),
		"slow_multiplier": clampf(float(skill.get("shockwave_slow_multiplier", 1.0)), 0.1, 1.0),
		"hit_ids": already_hit,
		"audio_source": context.audio_source,
		"visual_action": String(skill.get("visual_action", "")),
	})
	_presentation.present_fixed_area(center, radius, end_radius, shockwave_duration, source_team, &"shockwave")



func create_scheduled_result(source: Unit, skill: Dictionary) -> void:
	prepare_forward_area_result(source, skill, skill.cast_forward)

func prepare_forward_area_result(source: Unit, skill: Dictionary, cast_forward: Vector2) -> void:
	if skill.has("independent_result"): return
	# 固定持续区域技能在 Impact 时直接生成正式区域；不提前绘制龙王式落点预警/星体。
	if float(skill.get("zone_duration", 0.0)) > 0.0:
		return
	var duration := maxf(float(skill.get("impact_delay", 0.0)) - float(skill.get("result_creation_delay", 0.0)), 0.0)
	if duration <= 0.0:
		return
	var center := source.global_position + cast_forward.normalized() * maxf(float(skill.get("forward_distance", 0.0)), 0.0)
	if bool(skill.get("independent_on_creation", false)):
		skill["independent_result"] = {"result_id": _next_result_id, "center": center, "team": source.team,
			"source_ref": weakref(source), "source_position": source.global_position, "form": source.form_index,
			"status_source": source.status_source("skill_area"), "audio_source": PresentationConfig.attack_source(source)}
		_controller.present_skill_projectile_hit(skill.independent_result.audio_source, String(skill.get("visual_action", "")), center, "start")
	var radius := maxf(float(skill.get("radius", 0.0)), 0.0)
	_next_result_id += 1
	var shape := &"target_circle_strong" if bool(skill.get("full_resource", false)) else &"target_circle"
	_presentation.present_fixed_area(center, radius, radius, duration, source.team, shape)
	# 固定结果预警不依赖施法者的动作、位移或存活。



func _damage_result(source: Unit, target: Node2D, amount: float, context: Dictionary) -> Dictionary:
	return _controller.combat_service().resolve_attack_hit(int(context.team), context.center, target, amount, 0.0, 0.0,
		source if is_instance_valid(source) else null, context.get("source_position", context.center), int(context.form),
		{"presentation_source": context.audio_source}, false)


func _damage_combatant(source: Unit, combatant: Node2D, amount: float, origin: Vector2 = Vector2(INF, INF)) -> Dictionary:
	if not is_instance_valid(source) or not is_instance_valid(combatant) or combatant.hp <= 0.0 or amount <= 0.0:
		return BattleNumbers.pending_hit(false, amount)
	var source_position := source.global_position if origin.x == INF else origin
	return _controller.combat_service().resolve_damage_hit(combatant, amount, source, source.team, source_position, true)

## 只把真实结果的消费者推迟到相应提交阶段；即时模式已完成原正式小批次。
func _after_damage(callback: Callable, benefit: bool = false) -> void:
	var resolver: CombatResolver = _controller.combat_service()
	if resolver.collecting:
		if benefit: resolver.defer_benefit(callback)
		else: resolver.defer_effect(callback)
	else: callback.call()


func queue_expiry_explosion(source: Unit, skill: Dictionary) -> void:
	_expiry_explosions.append({"source": weakref(source), "skill": skill})

## 起跳固化单个建筑引用及独立结果后立即死亡；原目标失效只保留爆炸表现。
func begin_sacrifice(source: Unit, target: Node2D) -> void:
	if not is_instance_valid(source) or source.hp <= 0.0 or not _sacrifice_target_valid(target, source.team): return
	var stats: Dictionary = source._base_form_stats
	var direction := source.global_position.direction_to(target.global_position)
	var center := source.global_position + direction * (source.body_radius + source._target_gap(target))
	var duration := ceilf(float(stats.sacrifice_delay) / Unit.SIM_DT) * Unit.SIM_DT
	var audio_source := PresentationConfig.attack_source(source)
	_next_result_id += 1
	var result := {"center": center, "team": source.team, "form": source.form_index, "card_id": source.card_id,
		"target_ref": weakref(target), "sacrifice_id": _next_result_id,
		"source_ref": weakref(source), "source_position": source.global_position, "audio_source": audio_source,
		"time_left": duration, "damage": float(stats.sacrifice_damage) * source.sacrifice_empowerment.x,
		"forward": direction, "visual_scale": source.sacrifice_empowerment.y,
		"created_tick": _controller.get_authoritative_server_tick() if _controller.simulation_step_active() else -1,
		"delivery": CombatInteraction.Delivery.new()}
	sacrifice_results.append(result)
	var effect := {"source_ref": null, "net_id": -1, "fixed_position": true,
		"pos": source.global_position, "end_position": center, "forward": direction,
		"length": 0.0, "width": 0.0, "shape": "sacrifice_leap",
		"sacrifice_id": result.sacrifice_id, "impact_delay": duration, "visual_scale": result.visual_scale,
		"card_id": source.card_id, "form": source.form_index, "timer": duration + 2.2, "duration": duration + 2.2, "team": source.team}
	_presentation.frontal_effects.append(effect)
	_controller.publish_skill_fx(effect)
	_controller.present_skill_projectile_hit(audio_source, "sacrifice", source.global_position, "start")
	source.finish_sacrifice_leap()

func _sacrifice_target_valid(target: Node2D, source_team: int) -> bool:
	return is_instance_valid(target) and not target.is_queued_for_deletion() and target.hp > 0.0 and target.team != source_team and (target is Tower or (target is Unit and target.is_building))

func _tick_sacrifices(dt: float) -> void:
	var waiting: Array[Dictionary] = []
	for result in sacrifice_results:
		if _controller.simulation_step_active() and int(result.created_tick) == _controller.get_authoritative_server_tick():
			waiting.append(result)
			continue
		result.time_left = float(result.time_left) - dt
		if float(result.time_left) > 0.000001:
			waiting.append(result)
			continue
		var source = (result.source_ref as WeakRef).get_ref()
		var previous_delivery = CombatInteraction.current_delivery
		CombatInteraction.current_delivery = result.delivery
		var target = (result.target_ref as WeakRef).get_ref()
		if _sacrifice_target_valid(target, int(result.team)) and CombatInteraction.allows(target, source, int(result.team), result.source_position):
			if not CombatInteraction.blocks_effect(target, CombatInteraction.effect_context(source, int(result.team), result.source_position)):
				_damage_result(source, target, float(result.damage), result)
		CombatInteraction.current_delivery = previous_delivery
		# 可靠抵达确认连接同一个纯表现代理，不在客户端按计时预测爆炸。
		var impact := {"source_ref": null, "net_id": -1, "fixed_position": true,
			"pos": result.center, "forward": result.forward, "visual_scale": result.visual_scale, "length": 0.0, "width": 0.0,
			"shape": "sacrifice_burst", "sacrifice_id": result.sacrifice_id, "card_id": result.card_id,
			"timer": 2.2, "duration": 2.2, "team": result.team}
		_presentation.frontal_effects.append(impact)
		_controller.publish_skill_fx(impact)
		_controller.present_skill_projectile_hit(result.audio_source, "sacrifice", result.center, "impact")
	sacrifice_results = waiting

func begin_death_heal(source: Unit, stats: Dictionary) -> void:
	var zone := {"position": source.global_position, "team": source.team, "card_id": source.card_id,
		"radius": float(stats.death_heal_radius), "remaining": float(stats.death_heal_duration),
		"delay": float(stats.get("death_heal_delay", 0.0)), "activated": false,
		"transition_delay": float(stats.get("death_transition_delay", -1.0)), "transition_played": not stats.has("death_transition_delay"),
		"formation_delay": float(stats.get("death_shrine_delay", stats.get("death_heal_delay", 0.0))), "presented": false,
		"rate": float(stats.death_heal_per_second), "remainder": 0.0,
		"created_tick": _controller.get_authoritative_server_tick() if _controller.simulation_step_active() else -1}
	death_heal_zones.append(zone)
	if float(zone.formation_delay) <= 0.0: _present_death_shrine(zone)
	if float(zone.delay) <= 0.0: zone.activated = true

func _present_death_shrine(zone: Dictionary) -> void:
	if bool(zone.presented): return
	zone.presented = true
	_presentation.present_fixed_area(zone.position, float(zone.radius), float(zone.radius), float(zone.remaining) + float(zone.delay), int(zone.team), &"scuttle_void_shrine" if zone.card_id == "void_scuttle_crab" else &"scuttle_shrine")
	_controller.present_skill_projectile_hit({"card_id": zone.card_id, "team": zone.team}, "shrine", zone.position, "start")

func _tick_death_heal(dt: float) -> void:
	var alive: Array[Dictionary] = []
	for zone in death_heal_zones:
		if _controller.simulation_step_active() and int(zone.created_tick) == _controller.get_authoritative_server_tick():
			alive.append(zone)
			continue
		if not bool(zone.transition_played):
			zone.transition_delay = maxf(0.0, float(zone.transition_delay) - dt)
			if float(zone.transition_delay) <= 0.00001:
				zone.transition_played = true
				_controller.present_skill_projectile_hit({"card_id": zone.card_id, "team": zone.team}, "shrine", zone.position, "leap")
		var waiting := minf(dt, float(zone.delay))
		zone.delay = maxf(0.0, float(zone.delay) - waiting)
		if float(zone.delay) <= 0.00001: zone.delay = 0.0
		var active_dt := maxf(0.0, dt - waiting)
		zone.formation_delay = maxf(0.0, float(zone.formation_delay) - dt)
		if float(zone.formation_delay) <= 0.00001: _present_death_shrine(zone)
		if float(zone.delay) > 0.0:
			alive.append(zone)
			continue
		zone.activated = true
		var elapsed := minf(active_dt, float(zone.remaining))
		zone.remaining = maxf(0.0, float(zone.remaining) - elapsed)
		zone.remainder = float(zone.remainder) + float(zone.rate) * elapsed
		var amount := floorf(float(zone.remainder) + 0.00001)
		zone.remainder = maxf(0.0, float(zone.remainder) - amount)
		if amount > 0.0:
			for target in _controller.get_tree().get_nodes_in_group("combatants"):
				if not is_instance_valid(target) or not target is Unit or target.is_building or target.hp <= 0.0 or target.team != int(zone.team): continue
				if target.global_position.distance_to(zone.position) <= float(zone.radius) + target.body_radius:
					target.heal(amount, {"team": int(zone.team), "position": zone.position})
		if float(zone.remaining) > 0.00001: alive.append(zone)
	death_heal_zones.assign(alive)

func tick_effects(dt: float) -> void:
	_tick_death_heal(dt)
	_tick_sacrifices(dt)
	var active_charges: Array[OrnnChargeState] = []
	for charge in ornn_charges:
		if charge.tick(dt): active_charges.append(charge)
	ornn_charges = active_charges
	var ongoing: Array[DashStrikeState] = []
	for dash in dash_strikes:
		if dash.tick(dt): ongoing.append(dash)
	dash_strikes = ongoing
	for pending in _expiry_explosions:
		var source = pending.source.get_ref()
		if not is_instance_valid(source) or source.hp <= 0.0 or source.death_form.used: continue
		var explosion: Dictionary = pending.skill.duplicate(true)
		explosion.erase("shield")
		activate_nova(source, explosion)
		if String(explosion.get("kind", "")) == "counter_strike":
			_presentation.present_fixed_area(source.global_position, float(explosion.radius), float(explosion.radius), 1.2, source.team, &"counter_strike")
			_controller.notify_unit_audio_event(source, &"counter_strike:explode", source.global_position)
		elif String(explosion.get("kind", "")) == "aftershock":
			_presentation.present_fixed_area(source.global_position, float(explosion.radius), float(explosion.radius), 1.8, source.team, &"aftershock")
			_controller.notify_unit_audio_event(source, &"aftershock:explode", source.global_position)
		else:
			_presentation.present_shield_explosion(source, float(explosion.radius))
			_controller.notify_unit_audio_event(source, &"shield:explode", source.global_position)
	_expiry_explosions.clear()
	_tick_expanding_shockwaves(dt)
	_tick_continuous_area_effects(dt)


func _tick_continuous_area_effects(dt: float) -> void:
	var alive: Array[Dictionary] = []
	for effect in continuous_area_effects:
		if _controller.simulation_step_active() and int(effect.get("created_tick", -1)) == _controller.get_authoritative_server_tick():
			alive.append(effect)
			continue
		var source = (effect.source_ref as WeakRef).get_ref()
		if not is_instance_valid(source): source = null
		var fixed_position := bool(effect.get("fixed_position", false))
		if not fixed_position and (not is_instance_valid(source) or not source is Unit or source.hp <= 0.0):
			continue
		# 跟随施法者的持续范围在冰冻取消后终止；固定落点区域
		# 已经脱离施法动作，不因凤凰死亡或被控制而缩短 3 秒寿命。
		if not fixed_position and source is Unit and (source.is_frozen() or int(effect.get("cast_serial", source.active_skill_cast_serial)) <= source.cancelled_skill_cast_serial or int(effect.get("action_serial", 2147483647)) <= source.cancelled_visual_serial):
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
		if _controller.simulation_step_active() and int(shockwave.get("created_tick", -1)) == _controller.get_authoritative_server_tick():
			alive.append(shockwave)
			continue
		var previous := CombatInteraction.current_delivery
		CombatInteraction.current_delivery = shockwave.get("effect_delivery")
		shockwave.timer = maxf(float(shockwave.timer) - dt, 0.0)
		var progress := 1.0 - float(shockwave.timer) / maxf(float(shockwave.duration), 0.001)
		var current_radius := lerpf(float(shockwave.start_radius), float(shockwave.end_radius), progress)
		var source = (shockwave.source_ref as WeakRef).get_ref()
		for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
			if not is_instance_valid(combatant) or combatant.team == int(shockwave.team) or combatant.hp <= 0.0:
				continue
			if not CombatInteraction.allows(combatant, source, int(shockwave.team), shockwave.get("source_position", shockwave.center)): continue
			var instance_id := int(combatant.get_instance_id())
			if (shockwave.hit_ids as Dictionary).has(instance_id):
				continue
			if combatant.global_position.distance_to(shockwave.center) > current_radius + combatant.body_radius:
				continue
			shockwave.hit_ids[instance_id] = true
			var hit_position: Vector2 = combatant.global_position
			var receipt: Dictionary
			if is_instance_valid(source) and source is Unit:
				receipt = _damage_combatant(source as Unit, combatant, float(shockwave.damage), shockwave.center)
			else:
				receipt = BattleNumbers.hit(combatant, float(shockwave.damage), null, int(shockwave.team), shockwave.get("source_position", shockwave.center))
			_after_damage(func():
				if receipt.landed:
					_controller.present_skill_projectile_hit(shockwave.get("audio_source", {}), String(shockwave.get("visual_action", "")), hit_position, "wave_hit"))
			if is_instance_valid(combatant) and combatant is Unit and combatant.hp > 0.0 and float(shockwave.slow_duration) > 0.0:
				(combatant as Unit).apply_slow(float(shockwave.slow_duration), float(shockwave.slow_multiplier), shockwave.status_source, CombatInteraction.effect_context(source, int(shockwave.team), shockwave.get("source_position", shockwave.center)))
		CombatInteraction.current_delivery = previous
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
	var receipts: Array[Dictionary] = []
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if combatant == source or not is_instance_valid(combatant) or combatant.team == source.team or combatant.hp <= 0.0:
			continue
		if not CombatInteraction.allows(combatant, source, source.team, source.global_position): continue
		if ground_only and combatant is Unit and (combatant as Unit).is_air:
			continue
		var local_offset: Vector2 = combatant.global_position - source.global_position
		var forward_distance := local_offset.dot(forward) - source.body_radius
		var lateral_distance := absf(local_offset.dot(side))
		if forward_distance < -combatant.body_radius or forward_distance > length + combatant.body_radius:
			continue
		if lateral_distance > half_width + combatant.body_radius:
			continue
		if (amount > 0.0 or float(skill.get("stun_duration", 0.0)) > 0.0 or float(skill.get("knockback", 0.0)) > 0.0) and CombatInteraction.blocks_effect(combatant, CombatInteraction.effect_context(source)): continue
		if amount > 0.0:
			receipts.append(BattleNumbers.hit(combatant, amount, source, source.team, source.global_position))
		if is_instance_valid(combatant) and combatant.hp > 0.0 and stun_duration > 0.0:
			combatant.stun(stun_duration, source.status_source("skill"), CombatInteraction.effect_context(source))


	var source_ref: WeakRef = weakref(source)
	_after_damage(func():
		var live_source = source_ref.get_ref()
		if not is_instance_valid(live_source) or not receipts.any(func(result): return result.landed): return
		var action := String(skill.get("visual_action", "active"))
		if action.is_empty(): action = "transform_active"
		_controller.notify_unit_audio_event(live_source, StringName(action + ":hit"), live_source.global_position))

func frontal_forward(source: Unit) -> Vector2:
	var forward := source.get_visual_facing_direction()
	if forward.length_squared() < 0.001:
		forward = Vector2.UP if source.team == 0 else Vector2.DOWN
	return forward.normalized()


func clear() -> void:
	death_heal_zones.clear()
	sacrifice_results.clear()
	for charge in ornn_charges:
		var source = charge.source_ref.get_ref()
		if is_instance_valid(source): charge._finish(source)
	ornn_charges.clear()
	for dash in dash_strikes:
		var source = dash.source_ref.get_ref()
		if is_instance_valid(source): dash._finish(source)
	dash_strikes.clear()
	_expiry_explosions.clear()
	_resolved_results.clear()
	_next_result_id = 1
	expanding_shockwaves.clear()
	continuous_area_effects.clear()
