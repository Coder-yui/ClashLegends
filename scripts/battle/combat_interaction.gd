class_name CombatInteraction
extends RefCounted
## 交互按来源判定，不是全局 targetable。已有附着效果与无敌方来源的维护不被拦截。
## 单位来源使用当前中心；来源消失后使用出手时保存的中心；法术卡使用施法方水晶作为来源。
static func allows(target: Node2D, source: Node2D = null, source_team: int = -1, source_position: Vector2 = Vector2(INF, INF), attached: bool = false) -> bool:
	if not is_instance_valid(target): return false
	if in_stasis(target) or (target is Unit and target.death_form.waiting()): return false
	if attached or not target is Unit: return true
	if is_instance_valid(source):
		source_team = int(source.team)
		source_position = source.global_position
	if source_team < 0 or source_team == target.team: return true
	var protection: TargetProtectionState = target.target_protection
	return not protection.active() or not protection.contains(target.global_position) or protection.contains(source_position)

static func can_acquire(target, observer_team: int) -> bool:
	return is_instance_valid(target) and not in_stasis(target) and (not target is Unit or target.perceived_by_team(observer_team))

static func effect_context(source: Node2D = null, team: int = -1, position: Vector2 = Vector2(INF, INF), attached: bool = false) -> Dictionary:
	return {"source": source, "team": team, "position": position, "attached": attached}

static func allows_effect(target: Node2D, context: Dictionary) -> bool:
	var source = context.get("source")
	return allows(target, source if is_instance_valid(source) else null, int(context.get("team", -1)), context.get("position", Vector2(INF, INF)), bool(context.get("attached", false)))

## Friendly targeting does not inherit Gwen's enemy-only sanctuary rejection.
## Stasis/general untargetability read status families; their global application remains a separate capability.
static func allows_allied_target(target: Unit, team: int) -> bool:
	if not is_instance_valid(target) or target.team != team or target.hp <= 0.0 or not allows(target, null, team): return false
	return not in_stasis(target) and target.control.hard.remaining(&"untargetable") <= 0.0

static func in_stasis(target: Node2D) -> bool:
	return is_instance_valid(target) and (target is Unit or target is Tower) and target.control.hard.remaining(&"stasis") > 0.0

## 成功发生的伤害/控制/战斗减益：接受方入战，有敌对来源时来源也入战。
## 友方硬控同样记录接受方；普通友方收益不调用此入口。
static func record_combat_effect(target, context: Dictionary = {}) -> void:
	if not is_instance_valid(target): return
	if target.has_method("record_combat_activity"): target.record_combat_activity()
	var source = context.get("source")
	if is_instance_valid(source) and source != target and source.team != target.team and source.has_method("record_combat_activity"):
		source.record_combat_activity()
