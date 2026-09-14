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

## 保留 take_damage 的命中/免疫契约，收益只读取这次实际生命损失。
static func hit(target: Node2D, amount: float, source: Node2D, team: int, position: Vector2) -> Dictionary:
	if target.battle_context != null and target.battle_context.damage_batch().collecting:
		return target.battle_context.damage_batch().submit_damage(target, amount, source, team, position)
	var requested := quantity(amount)
	var hp_before := float(target.hp)
	var shield_before := float(target.get("shield_hp"))
	var landed: bool = target.take_damage(requested, source, team, position)
	var health_lost := quantity(hp_before - float(target.hp)) if landed else 0
	var shield_absorbed := quantity(shield_before - float(target.get("shield_hp"))) if landed else 0
	return {
		"landed": landed, "damage": requested,
		"health_lost": health_lost, "shield_absorbed": shield_absorbed,
		"overkill": maxi(requested - health_lost - shield_absorbed, 0) if landed else 0,
	}

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
		if result.landed:
			_targets[id] = {"target": weakref(target), "remainder": total - base_damage}
		return result
