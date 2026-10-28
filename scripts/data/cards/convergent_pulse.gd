extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "聚合脉冲", "cost": 3, "type": "spell", "spell_kind": "convergent_pulse",
			"deploy_zone": "global", "deploy_ignore_structures": true,
			"radius": 105.0, "damage": 180, "spell_windup": 0.65, "duration": 0.4, "pull_distance": 80.0,
			"tower_damage_multiplier": 0.3, "active_cost_bonus": 1,
			"description": "蓄能0.65秒后，对半径2.625格内敌方地面、空中及建筑造成180伤害，将可移动单位向中心拉拢。向中心方向强制位移2格，基础持续0.4秒；途中无碰撞，可穿过单位及中心，结束校正至合法落点；防御塔与水晶承受30%伤害，建筑不被拉动。",
			"active_skills": [{"name": "强化脉冲", "kind": "spell_convergent_pulse", "cost": 1,
				"max_uses": 1, "cooldown": 0.0, "damage": 270, "radius": 130.0, "pull_distance": 100.0, "duration": 0.5,
				"description": "伤害提高至270，半径扩大至3.25格，强制位移提高至2.5格，基础持续0.5秒。"}],
		},
		"visual": {"color": Color(0.25, 0.7, 0.9),
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/convergent_pulse/player.gd", "variant": "pulse"}, {"provider": "res://assets/effects/convergent_pulse/player.gd", "variant": "ball"}]},
			"active_skills": [{"icon_path": "res://assets/skills/orianna_r.png"}]},
		# BEGIN IMPORTED AUDIO convergent_pulse
		"audio": {
			"events": {
				"spell:cast": {
					"pool": [
						"res://assets/audio/units/convergent_pulse/play_sfx_orianadetonatecommand_oncast_r1.wav",
						"res://assets/audio/units/convergent_pulse/play_sfx_orianadetonatecommand_oncast_r2.wav",
						"res://assets/audio/units/convergent_pulse/play_sfx_orianadetonatecommand_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spell:charge": {
					"pool": [
						"res://assets/audio/units/convergent_pulse/play_sfx_orianna_oriannadetonatecommand_buffactivate_r1.wav",
						"res://assets/audio/units/convergent_pulse/play_sfx_orianna_oriannadetonatecommand_buffactivate_r2.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spell:hit": {
					"pool": [
						"res://assets/audio/units/convergent_pulse/play_sfx_orianna_oriannadetonatecommand_hit_r1.wav",
						"res://assets/audio/units/convergent_pulse/play_sfx_orianna_oriannadetonatecommand_hit_r2.wav",
						"res://assets/audio/units/convergent_pulse/play_sfx_orianna_oriannadetonatecommand_hit_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			}
		},
		# END IMPORTED AUDIO convergent_pulse
		"card_art": {"path": "res://assets/cards/convergent_pulse_loading.png"},
	}
