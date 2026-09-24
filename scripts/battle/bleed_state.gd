class_name BleedState
extends RefCounted
## 目标持有的来源独立流血；20Hz连续累计伤害，刷新窗口不清零小数余量。
var _sources: Dictionary = {}
var replica_stacks := 0

func stacks(source: Node2D) -> int:
	return int(_sources.get(source.get_instance_id(), {}).get("stacks", 0)) if is_instance_valid(source) else 0

func total_stacks() -> int:
	var result := replica_stacks
	for effect in _sources.values(): result = maxi(result, int(effect.stacks))
	return result

func apply(target: Node2D, source: Unit, definition: Dictionary, full: bool) -> int:
	if target.hp <= 0.0 or not CombatInteraction.allows(target, source): return 0
	var id := source.get_instance_id()
	var effect: Dictionary = _sources.get(id, {"source": weakref(source), "team": source.team, "position": source.global_position, "stacks": 0, "remainder": 0.0})
	effect.stacks = int(definition.bleed_max_stacks) if full else mini(int(effect.stacks) + 1, int(definition.bleed_max_stacks))
	effect.ticks = maxi(1, ceili(float(definition.bleed_duration) * 20.0))
	effect.dps = float(definition.bleed_damage_per_second)
	effect.fraction = 0.0
	_sources[id] = effect
	return int(effect.stacks)

func advance(target: Node2D, dt: float) -> void:
	if target.hp <= 0.0 or target.is_queued_for_deletion():
		clear()
		return
	for id in _sources.keys():
		var effect: Dictionary = _sources[id]
		effect.fraction += dt * 20.0
		var steps := mini(floori(float(effect.fraction) + 0.00000001), int(effect.ticks))
		effect.fraction -= steps
		effect.ticks -= steps
		var amount := float(effect.remainder) + float(effect.dps) * int(effect.stacks) * steps / 20.0
		var damage := BattleNumbers.quantity(amount)
		effect.remainder = amount - damage
		var source = effect.source.get_ref()
		if damage > 0:
			if target.battle_context != null and target.battle_context.damage_batch().collecting:
				target.battle_context.damage_batch().submit_damage(target, damage, source, int(effect.team), effect.position, true)
			else:
				target.take_damage(damage, source, int(effect.team), effect.position, true)
		if int(effect.ticks) <= 0: _sources.erase(id)

func clear() -> void:
	_sources.clear()
	replica_stacks = 0
