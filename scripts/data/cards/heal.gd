extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "治疗术", "cost": 2, "type": "spell",
			"spell_kind": "heal",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"description": "范围治疗法术，立刻回复范围内友军单位的生命值；对建筑卡、防御塔和水晶无效。",
			# 法术卡：不生成单位，点击位置范围内友军单位立刻回复生命。
			"radius": 110.0,    # 影响范围半径
			"duration": 1.2,    # 治疗光效持续时间（治疗本身立即结算）
			"heal_amount": 200,
			# 两个主动槽选项均额外消耗 1 金币；强化治疗全图治疗，范围内提高 50%；过量治疗只治疗范围内单位并将溢出转盾。
			"active_cost_bonus": 1,
			"active_skills": [
				{
					"name": "强化治疗", "kind": "spell_heal", "cost": 1, "max_uses": 1, "cooldown": 0.0,
					"heal_multiplier": 1.50, "global_heal": true,
					"description": "全图友军普通单位获得治疗；落点范围内治疗量提高50%，不再额外获得护盾。",
				},
				{
					"name": "过量治疗", "kind": "spell_heal", "cost": 1, "max_uses": 1, "cooldown": 0.0,
					"heal_multiplier": 1.50, "global_heal": false,
					"overheal_shield_ratio": 0.50, "shield_duration": 3.0,
					"description": "范围内治疗量提高50%；溢出的治疗量按50%转为护盾，持续3秒。",
				},
			],
		},
		"visual": {
			"active_skills": [{"icon_path": "res://assets/skills/heal_0.png"}, {"icon_path": "res://assets/skills/heal_1.png"}],
			"color": Color(1.00, 0.93, 0.60),
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
			},
		},
		# END EVENT AUDIO heal
		"card_art": {},
	}
