class_name SpellSystem
extends RefCounted
## 数据驱动法术的权威执行与持续区域。
## Main 只负责出牌编排；新增 spell_kind 时在这里实现一次，并由 CardDB 拒绝未实现的配置。

var freeze_effects: Array[Dictionary] = []
var slow_zones: Array[Dictionary] = []
var slow_effects: Array[Dictionary] = []
## 治疗术表现区域：淡黄光圈；强化版额外带全图扩散波纹。
var heal_effects: Array[Dictionary] = []

var _controller: Node2D


func _init(controller: Node2D) -> void:
	_controller = controller


static func supports(kind: StringName) -> bool:
	return kind in CardDB.SPELL_KINDS


func cast(team: int, stats: Dictionary, position: Vector2, active_enabled: bool = false) -> bool:
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
			apply_heal(position, heal_radius, team, stats, active_enabled)
			if _controller.mode == "host":
				_controller._rpc_heal_fx.rpc_id(_controller.network_opponent_id(), _controller.network_session_id(), position, heal_radius, fx_duration, active_enabled)
			return true
		_:
			push_error("未实现的 spell_kind：%s" % String(stats.get("spell_kind", "")))
			return false


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
## 强化版（卡牌位于主动槽）：全图友军单位获得 active_heal_multiplier 倍治疗，
## 范围内所有友方战斗对象（含建筑卡、防御塔、水晶）额外获得护盾。
func apply_heal(position: Vector2, radius: float, team: int, stats: Dictionary, active_enabled: bool = false) -> void:
	var heal_amount := maxf(float(stats.get("heal_amount", 0.0)), 0.0)
	var heal_multiplier := maxf(float(stats.get("active_heal_multiplier", 1.0)), 1.0) if active_enabled else 1.0
	var shield_amount := maxf(float(stats.get("active_shield", 0.0)), 0.0) if active_enabled else 0.0
	var shield_duration := maxf(float(stats.get("active_shield_duration", 0.0)), 0.0)
	show_heal(position, radius, float(stats.get("duration", 1.2)), active_enabled)
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(combatant) or combatant.team != team or combatant.hp <= 0.0:
			continue
		var in_range: bool = combatant.global_position.distance_to(position) <= radius + combatant.body_radius
		if combatant is Unit and not (combatant as Unit).is_building and (active_enabled or in_range):
			(combatant as Unit).heal(heal_amount * heal_multiplier)
		if shield_amount > 0.0 and shield_duration > 0.0 and in_range and combatant.has_method("add_shield"):
			combatant.add_shield(shield_amount, shield_duration)


## 主机结算和客户端 RPC 共用表现创建入口，副本不创建权威区域。
func show_freeze(position: Vector2, radius: float, duration: float, slow_duration: float = 0.0) -> void:
	freeze_effects.append({"pos": position, "timer": duration, "duration": duration, "radius": radius})
	if slow_duration > 0.0:
		slow_effects.append({"pos": position, "radius": radius, "delay": duration, "timer": slow_duration, "duration": slow_duration})

func show_heal(position: Vector2, radius: float, duration: float, enhanced: bool = false) -> void:
	heal_effects.append({"pos": position, "radius": radius, "timer": duration, "duration": duration, "enhanced": enhanced})

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
