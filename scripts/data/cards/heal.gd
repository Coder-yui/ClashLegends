extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "治疗术", "cost": 3, "type": "spell",
			"spell_kind": "heal",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"description": "范围治疗法术，立刻回复范围内友军单位的生命值；对建筑卡、防御塔和水晶无效。",
			"active_name": "强化治疗",
			# 法术卡：不生成单位，点击位置范围内友军单位立刻回复生命。
			"radius": 110.0,    # 影响范围半径
			"duration": 1.2,    # 治疗光效持续时间（治疗本身立即结算）
			"heal_amount": 300,
			# 强化治疗（主动槽）：费用 +1；全图友军单位获得略提高的治疗，范围内友军额外获得护盾（含建筑）。
			"active_cost_bonus": 1,
			"active_heal_multiplier": 1.25,
			"active_shield": 240,
			"active_shield_duration": 3.0,
			"color": Color(1.00, 0.93, 0.60),
		},
		"visual": {
		},
		# BEGIN EVENT AUDIO heal
		"audio": {
			"events": {
				"spell:cast": {
					"pool": [
						"res://assets/audio/spells/heal/play_sfx_summonerheal_oncast_r1.wav",
						"res://assets/audio/spells/heal/play_sfx_summonerheal_oncast_r2.wav",
						"res://assets/audio/spells/heal/play_sfx_summonerheal_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			}
		},
		# END EVENT AUDIO heal
		"card_art": {}, # 默认 assets/cards/<card_id>_loading.*
	}
