class_name BattleNumbers
extends RefCounted
## 数量在结算边界四舍五入；比例和累计余量不提前截断。
static func quantity(value: float) -> int:
	return maxi(roundi(value), 0)

static func decimal(value: float) -> float:
	return snappedf(value, 0.01)

static func format_value(value: float) -> String:
	var rounded := decimal(value)
	return str(roundi(rounded)) if is_equal_approx(rounded, roundf(rounded)) else "%.2f" % rounded

## HitReceipt合同：accepted只是受理/排队；settled后landed才是提交事实。
## health_lost/shield_absorbed按本次真实结果分配；零伤害受理可landed，不能据名义damage吸血。
static func pending_hit(accepted: bool, amount: float) -> Dictionary:
	return {"accepted": accepted, "settled": not accepted, "landed": false, "blocked": false,
		"damage": quantity(amount), "health_lost": 0.0, "shield_absorbed": 0.0, "overkill": 0.0}

static func settle_hit(result: Dictionary, landed: bool, health_lost: float = 0.0, shield_absorbed: float = 0.0) -> void:
	result.settled = true
	result.landed = landed
	result.health_lost = maxf(health_lost, 0.0) if landed else 0.0
	result.shield_absorbed = maxf(shield_absorbed, 0.0) if landed else 0.0
	result.overkill = maxf(float(result.damage) - result.health_lost - result.shield_absorbed, 0.0) if landed else 0.0

static func hit(target: Node2D, amount: float, source: Node2D, team: int, position: Vector2) -> Dictionary:
	if target.battle_context != null:
		var resolver: CombatResolver = target.battle_context.damage_batch()
		if resolver.collecting: return resolver.submit_damage(target, amount, source, team, position)
		if not resolver.committing: return resolver.resolve_damage_hit(target, amount, source, team, position)
	# 无战场的纯逻辑对象保留即时入口；与正式批次共用回执构造/结算，不发另一套奖励。
	var result := pending_hit(target.hp > 0.0 and not target.is_queued_for_deletion() and CombatInteraction.allows(target, source, team, position), amount)
	var hp_before := float(target.hp)
	var shield_before := float(target.get("shield_hp"))
	var landed: bool = result.accepted and target.take_damage(result.damage, source, team, position)
	result.blocked = result.accepted and not landed
	settle_hit(result, landed, hp_before - float(target.hp), shield_before - float(target.get("shield_hp")))
	return result

## 每个来源实例持有自己的流；余量按目标隔离，死亡目标通过弱引用清理。
class DamageStream extends RefCounted:
	var _targets: Dictionary = {}

	func hit(target: Node2D, amount: float, source: Node2D, team: int, position: Vector2, bonus: float = 0.0) -> Dictionary:
		for key in _targets.keys():
			var previous = _targets[key].target.get_ref()
			if previous == null or previous.hp <= 0.0:
				_targets.erase(key)
		var id := target.get_instance_id()
		var remainder := float(_targets.get(id, {}).get("remainder", 0.0))
		var total := maxf(amount, 0.0) + remainder
		var base_damage := BattleNumbers.quantity(total)
		var result := BattleNumbers.hit(target, base_damage + bonus, source, team, position)
		if result.accepted:
			_targets[id] = {"target": weakref(target), "remainder": total - base_damage}
		return result
