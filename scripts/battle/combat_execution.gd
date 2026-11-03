class_name CombatExecution
extends RefCounted
## 生命阈值斩杀：护盾、减伤不参与；共享正常死亡链。
static func try_execute(target: Node2D, ratio: float, context: Dictionary = {}, affect_buildings: bool = false) -> bool:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or not (target is Unit or target is Tower): return false
	if not is_finite(ratio) or ratio <= 0.0 or ratio > 1.0 or target.hp <= 0.0 or target.hp >= target.max_hp * ratio: return false
	if not affect_buildings and (target is Tower or target.is_building): return false
	if not CombatInteraction.allows_effect(target, context): return false
	if target is Unit and target.buffs.remaining(&"undying") > 0.0: return false
	CombatInteraction.record_combat_effect(target, context)
	if target is Unit: target._die(true)
	else: target.execute_death()
	return true
