class_name CardPlayHistory
extends RefCounted
## 成功接受的卡牌记录；命令取得隔离副本，后续出牌不会改变已付款的镜像。
var _last: Dictionary = {}
var _mirror_generations: Dictionary = {}

static func is_mirror(card_id: String) -> bool:
	return CardDB.has_card(card_id) and StringName(CardDB.get_card(card_id).get("spell_kind", "")) == &"mirror"

func get_last(team: int) -> Dictionary:
	return _last.get(team, {}).duplicate(true)

func record(team: int, card_id: String, deployment_card_id: String, cost: int) -> void:
	_last[team] = {"card_id": card_id, "deployment_card_id": deployment_card_id, "cost": cost}

func replace_replica(team: int, value: Dictionary) -> void:
	if value.is_empty():
		_last.erase(team)
		return
	if not value.get("card_id") is String or not value.get("deployment_card_id") is String or not value.get("cost") is int:
		return
	if not CardDB.has_card(value.card_id) or is_mirror(value.card_id) or not CardDB.has_card(value.deployment_card_id) or value.cost < 0:
		return
	_last[team] = value.duplicate(true)

func begin_mirror(team: int) -> int:
	_mirror_generations[team] = int(_mirror_generations.get(team, 0)) + 1
	return int(_mirror_generations[team])

func is_latest_mirror(team: int, generation: int) -> bool:
	return generation < 0 or generation == int(_mirror_generations.get(team, 0))

func clear() -> void:
	_last.clear()
	_mirror_generations.clear()
