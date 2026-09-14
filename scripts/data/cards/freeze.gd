extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "冰冻", "cost": 3, "type": "spell",
			"spell_kind": "freeze",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"description": "范围控制法术，冻结范围内的敌方单位，为己方争取进攻窗口。",
			"active_name": "强化冰冻",
			# 法术卡：不生成单位，在点击位置范围内冻结敌方单位3秒
			"radius": 110.0,    # 影响范围半径
			"duration": 3.0,    # 冰冻持续时间
			"active_slow_duration": 2.0,
			"active_slow_multiplier": 0.50,
		},
		"visual": {
			"color": Color(0.40, 0.70, 1.00),
		},
		# BEGIN EVENT AUDIO freeze
		"audio": {
			"events": {
				"spell:cast": {
					"pool": ["res://assets/audio/units/freeze/play_sfx_cr_freeze_spell_cast_first3s.wav"],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
		},
		# END EVENT AUDIO freeze
		"card_art": {},
	}
