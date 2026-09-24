extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "镜像法术", "cost": 0, "type": "spell", "spell_kind": "mirror",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"radius": 1.0, "duration": 0.0,
			"description": "复制上一张成功使用的卡牌，支付该卡本身的费用。复制体不携带主动技能。镜像不会出现在开局四张手牌中，部署区域与复制目标相同。",
			"active_name": "完整镜像",
		},
		"visual": {"color": Color(0.45, 0.85, 1.0)},
		"card_art": {"path": "res://assets/cards/mirror_loading.png"},
		"audio": {},
	}
