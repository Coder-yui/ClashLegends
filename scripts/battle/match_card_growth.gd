class_name MatchCardGrowth
extends RefCounted
## 每阵营局内成长。卡组/轮转保存来源卡，部署和UI查询当前解锁定义。
var _teams: Dictionary = {}

func resolved_id(team: int, card_id: String) -> String:
	return String(_teams.get(team, {}).get(card_id, {}).get("unlocked", card_id))

func record_hit(source: Unit, target: Node2D) -> void:
	var stats := CardDB.get_card(source.card_id)
	if not stats.has("growth_ranged_id") or not target is Unit or target.is_building or target.team == source.team: return
	if not _teams.has(source.team): _teams[source.team] = {}
	if not _teams[source.team].has(source.card_id):
		_teams[source.team][source.card_id] = {"ranged": 0, "melee": 0, "unlocked": source.card_id}
	var progress: Dictionary = _teams[source.team][source.card_id]
	if progress.unlocked != source.card_id: return
	var kind := "ranged" if target.projectile_speed > 0.0 or target.continuous_attack else "melee"
	progress[kind] += 1
	if progress[kind] >= int(stats["growth_" + kind + "_hits"]):
		progress.unlocked = String(stats["growth_" + kind + "_id"])

func progress(team: int, card_id: String) -> Dictionary:
	return _teams.get(team, {}).get(card_id, {}).duplicate(true)

func snapshot() -> Dictionary:
	return _teams.duplicate(true)

func replace_replica(value: Dictionary) -> void:
	_teams = value.duplicate(true)

func clear() -> void:
	_teams.clear()

static func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary: return false
	for team in value:
		if not team is int or team not in [0,1] or not value[team] is Dictionary: return false
		for id in value[team]:
			if not id is String or not CardDB.has_card(id): return false
			var stats := CardDB.get_card(id)
			var item = value[team][id]
			if not stats.has("growth_ranged_id") or not item is Dictionary or item.size() != 3: return false
			for kind in ["ranged","melee"]:
				if not item.get(kind) is int or item[kind] < 0 or item[kind] > int(stats["growth_"+kind+"_hits"]): return false
			if not item.get("unlocked") is String or item.unlocked not in [id,stats.growth_ranged_id,stats.growth_melee_id]: return false
	return true
