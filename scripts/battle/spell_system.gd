class_name SpellSystem
extends RefCounted
## 数据驱动法术的权威执行与持续区域。
## Main 只负责出牌编排；新增 spell_kind 时在这里实现一次，并由 CardDB 拒绝未实现的配置。

var freeze_effects: Array[Dictionary] = []
var slow_zones: Array[Dictionary] = []
var slow_effects: Array[Dictionary] = []
## 治疗术表现区域：淡黄光圈；全图强化治疗额外带全图扩散波纹。
var heal_effects: Array[Dictionary] = []

var _controller: Node2D


func _init(controller: Node2D) -> void:
	_controller = controller


static func supports(kind: StringName) -> bool:
	return kind in CardDB.SPELL_KINDS


func cast(team: int, stats: Dictionary, position: Vector2, active_enabled: bool = false, active_skill_index: int = 0) -> bool:
	match StringName(stats.get("spell_kind", "")):
		&"freeze":
			var radius := float(stats.get("radius", 0.0))
			var duration := float(stats.get("duration", 0.0))
			var slow_duration := float(stats.get("active_slow_duration", 0.0)) if active_enabled else 0.0
			var slow_multiplier := float(stats.get("active_slow_multiplier", 1.0))
			apply_freeze(position, radius, duration, team, slow_duration, slow_multiplier)
			if _controller.mode == "host":
				_controller._rpc_freeze_fx.rpc_id(_controller.network_opponent_id(), _controller.network_session_id(), position, radius, duration, slow_duration, slow_multiplier)
			return true
		&"heal":
			var heal_radius := float(stats.get("radius", 0.0))
			var fx_duration := float(stats.get("duration", 1.2))
			var active_skill: Dictionary = _active_heal_skill(stats, active_skill_index) if active_enabled else {}
			apply_heal(position, heal_radius, team, stats, active_enabled, active_skill)
			if _controller.mode == "host":
				_controller._rpc_heal_fx.rpc_id(_controller.network_opponent_id(), _controller.network_session_id(), position, heal_radius, fx_duration, active_enabled, bool(active_skill.get("global_heal", false)))
			return true
		_:
			push_error("未实现的 spell_kind：%s" % String(stats.get("spell_kind", "")))
			return false


func _active_heal_skill(stats: Dictionary, skill_index: int) -> Dictionary:
	var skills: Array = stats.get("active_skills", [])
	if skill_index < 0 or skill_index >= skills.size() or not skills[skill_index] is Dictionary:
		return {}
	return skills[skill_index] as Dictionary


func apply_freeze(position: Vector2, radius: float, duration: float, team: int, slow_duration: float = 0.0, slow_multiplier: float = 1.0) -> void:
	show_freeze(position, radius, duration, slow_duration)
	if slow_duration > 0.0:
		slow_zones.append({"pos": position, "radius": radius, "delay": duration, "timer": slow_duration, "team": team, "multiplier": slow_multiplier})
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(combatant) or combatant.team == team or combatant.hp <= 0.0:
			continue
		if combatant.global_position.distance_to(position) > radius + combatant.body_radius:
			continue
		if combatant is Unit:
			(combatant as Unit).freeze(duration)
		elif combatant is Tower:
			(combatant as Tower).freeze(duration)


## 治疗术权威结算。治疗只作用于普通单位（Unit 且非建筑卡），统一走 Unit.heal()，
## 不会超过单位最大生命值；建筑卡、防御塔与水晶不吃治疗。
## 治疗法术主动选项：强化治疗可全图治疗但只在落点范围内提高倍率；过量治疗只治疗范围内单位，
## 并将实际未恢复的部分按 overheal_shield_ratio 转为限时护盾；建筑卡、防御塔与水晶不受治疗影响。
func apply_heal(position: Vector2, radius: float, team: int, stats: Dictionary, active_enabled: bool = false, active_skill: Dictionary = {}) -> void:
	var heal_amount := maxf(float(stats.get("heal_amount", 0.0)), 0.0)
	var heal_multiplier := maxf(float(active_skill.get("heal_multiplier", 1.0)), 1.0) if active_enabled else 1.0
	var global_heal := active_enabled and bool(active_skill.get("global_heal", false))
	var overheal_shield_ratio := clampf(float(active_skill.get("overheal_shield_ratio", 0.0)), 0.0, 1.0) if active_enabled else 0.0
	var shield_duration := maxf(float(active_skill.get("shield_duration", 0.0)), 0.0) if active_enabled else 0.0
	show_heal(position, radius, float(stats.get("duration", 1.2)), active_enabled, global_heal)
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(combatant) or combatant.team != team or combatant.hp <= 0.0:
			continue
		var in_range: bool = combatant.global_position.distance_to(position) <= radius + combatant.body_radius
		if combatant is Unit and not (combatant as Unit).is_building and (in_range or global_heal):
			var requested_heal := heal_amount * heal_multiplier
			if global_heal and not in_range:
				requested_heal = heal_amount
			var hp_before := float(combatant.hp)
			(combatant as Unit).heal(requested_heal)
			if overheal_shield_ratio > 0.0 and shield_duration > 0.0 and combatant.has_method("add_shield"):
				var actual_heal := maxf(float(combatant.hp) - hp_before, 0.0)
				var overheal := maxf(requested_heal - actual_heal, 0.0)
				var shield_amount := BattleNumbers.quantity(overheal * overheal_shield_ratio)
				if shield_amount > 0:
					combatant.add_shield(shield_amount, shield_duration)


## 主机结算和客户端 RPC 共用表现创建入口，副本不创建权威区域。
func show_freeze(position: Vector2, radius: float, duration: float, slow_duration: float = 0.0) -> void:
	freeze_effects.append({"pos": position, "timer": duration, "duration": duration, "radius": radius})
	if slow_duration > 0.0:
		slow_effects.append({"pos": position, "radius": radius, "delay": duration, "timer": slow_duration, "duration": slow_duration})

func show_heal(position: Vector2, radius: float, duration: float, enhanced: bool = false, global_heal: bool = false) -> void:
	heal_effects.append({"pos": position, "radius": radius, "timer": duration, "duration": duration, "enhanced": enhanced, "global_heal": global_heal})

func tick(dt: float) -> void:
	var alive: Array[Dictionary] = []
	for zone in slow_zones:
		if float(zone.delay) > 0.0:
			zone.delay = maxf(0.0, float(zone.delay) - dt)
			alive.append(zone)
			continue
		zone.timer = maxf(0.0, float(zone.timer) - dt)
		for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
			if not combatant is Unit or not is_instance_valid(combatant) or combatant.team == int(zone.team) or combatant.hp <= 0.0:
				continue
			if combatant.global_position.distance_to(zone.pos) <= float(zone.radius) + combatant.body_radius:
				(combatant as Unit).apply_slow(dt + _controller.SIM_DT, float(zone.multiplier))
		if float(zone.timer) > 0.0:
			alive.append(zone)
	slow_zones.assign(alive)


func tick_visuals(delta: float) -> void:
	for effect in freeze_effects:
		effect.timer = maxf(0.0, float(effect.timer) - delta)
	freeze_effects.assign(freeze_effects.filter(func(effect): return float(effect.timer) > 0.0))
	for effect in slow_effects:
		if float(effect.delay) > 0.0:
			effect.delay = maxf(0.0, float(effect.delay) - delta)
		else:
			effect.timer = maxf(0.0, float(effect.timer) - delta)
	var alive: Array[Dictionary] = []
	for effect in slow_effects:
		if float(effect.delay) > 0.0 or float(effect.timer) > 0.0:
			alive.append(effect)
	slow_effects.assign(alive)
	for effect in heal_effects:
		effect.timer = maxf(0.0, float(effect.timer) - delta)
	heal_effects.assign(heal_effects.filter(func(effect): return float(effect.timer) > 0.0))


func clear() -> void:
	freeze_effects.clear()
	slow_zones.clear()
	slow_effects.clear()
	heal_effects.clear()
