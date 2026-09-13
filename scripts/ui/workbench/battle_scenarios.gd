extends RefCounted
## 只描述卡牌和落点，不修改战斗规则或卡牌数值。
const PRESETS := [
	{"id": "surrounded", "name": "敌人包围", "hint": "八名地面近战从四周接近；观察范围技能、转身与索敌。"},
	{"id": "bridge_crowd", "name": "拥挤过桥", "hint": "随十二名友军经过左桥，对岸有敌军；观察排队、推挤与交战。"},
	{"id": "crossfire", "name": "远近夹击", "hint": "近战牵制、远程从两侧射击；观察目标选择、弹体与控制。"},
	{"id": "duel", "name": "单体对战", "hint": "与敌方盖伦对战；观察部署、首击、攻击衔接和主动技能。"},
]

static func placements(id: String, card_id: String, team: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var center := Vector2(380, 820)
	match id:
		"surrounded":
			for offset in [Vector2(-120,0),Vector2(120,0),Vector2(0,-120),Vector2(0,120),Vector2(-80,-80),Vector2(80,-80),Vector2(-80,80),Vector2(80,80)]:
				result.append({"card": "melee_minion", "team": 1-team, "pos": center + offset})
		"bridge_crowd":
			center = Vector2(ArenaRules.BRIDGE_X_LEFT, 820)
			for row in 4:
				for column in 3:
					result.append({"card": "melee_minion", "team": team, "pos": Vector2(100+column*40,860+row*40)})
			for row in 2:
				for column in 3:
					result.append({"card": "melee_minion", "team": 1-team, "pos": Vector2(100+column*40,460-row*40)})
		"crossfire":
			for offset in [Vector2(-120,-200),Vector2(120,-200),Vector2(-160,-120),Vector2(160,-120)]:
				result.append({"card": "ranged_minion", "team": 1-team, "pos": center + offset})
			for offset in [Vector2(-40,-80),Vector2(40,-80)]:
				result.append({"card": "melee_minion", "team": 1-team, "pos": center + offset})
		"duel":
			result.append({"card": "garen", "team": 1-team, "pos": center + Vector2(0,-160)})
		_:
			return result
	# 最后放当前卡，法术能命中已布置的目标。
	result.append({"card": card_id, "team": team, "pos": center})
	if team == 1:
		for entry in result:
			entry.pos.y = ArenaRules.FIELD_H - entry.pos.y
	return result
