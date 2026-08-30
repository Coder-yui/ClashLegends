class_name SpellSystem
extends RefCounted
## 数据驱动法术的权威执行与持续区域。
## Main 只负责出牌编排；新增 spell_kind 时在这里实现一次，并由 CardDB 拒绝未实现的配置。

var freeze_effects: Array[Dictionary] = []
var slow_zones: Array[Dictionary] = []
var slow_effects: Array[Dictionary] = []

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
				_controller._rpc_freeze_fx.rpc(position, radius, duration, slow_duration, slow_multiplier)
			return true
		_:
			push_error("未实现的 spell_kind：%s" % String(stats.get("spell_kind", "")))
			return false


func apply_freeze(position: Vector2, radius: float, duration: float, team: int, slow_duration: float = 0.0, slow_multiplier: float = 1.0) -> void:
	freeze_effects.append({"pos": position, "timer": duration, "duration": duration, "radius": radius})
	if slow_duration > 0.0:
		slow_zones.append({"pos": position, "radius": radius, "delay": duration, "timer": slow_duration, "team": team, "multiplier": slow_multiplier})
		slow_effects.append({"pos": position, "radius": radius, "delay": duration, "timer": slow_duration, "duration": slow_duration})
	for combatant in _controller.get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(combatant) or combatant.team == team or combatant.hp <= 0.0:
			continue
		if combatant.global_position.distance_to(position) > radius + combatant.body_radius:
			continue
		if combatant is Unit:
			(combatant as Unit).freeze(duration)
		elif combatant is Tower:
			(combatant as Tower).freeze(duration)


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


func clear() -> void:
	freeze_effects.clear()
	slow_zones.clear()
	slow_effects.clear()
