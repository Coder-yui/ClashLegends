extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "空投熊", "cost": 4, "type": "spell", "spell_kind": "airdrop_bear",
			"deploy_zone": "own_side", "deploy_half_only": true, "deploy_ignore_structures": true,
			"radius": 100.0, "damage": 160, "duration": 0.5, "spell_windup": 1.0,
			"tower_damage_multiplier": 0.3, "spawn_id": "tibbers", "spawn_deploy_time": 0.0,
			"active_cost_bonus": 2,
			"description": "仅己方半场：预警1秒后，提伯斯用0.5秒从空中落下，在半径2.5格内造成160范围伤害，并在中心召唤可立即行动的提伯斯。对空中单位有效；防御塔与水晶受到48伤害。提伯斯不随法术结束消失。",
			"active_skills": [{"name": "焚怒降临", "kind": "spell_airdrop_bear", "cost": 2, "max_uses": 1, "cooldown": 0.0,
				"stun_duration": 1.5, "radius": 100.0, "damage": 20, "tick_interval": 0.5,
				"duration": 5.0, "attack_speed_multiplier": 1.5,
				"description": "落地额外眩晕1.5秒（水晶免疫）。提伯斯永久灼烧周围2.5格内敌人，每0.5秒20伤害，并在出生后5秒内获得50%攻速加成。灼烧对空中与建筑有效；凝滞暂时抑制，死亡结束。"}],
		},
		"visual": {"color": Color(0.95, 0.32, 0.08),
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/airdrop_bear/player.gd", "variant": "impact"}]},
			"active_skills": [{"icon_path": "res://assets/skills/annie_r.png", "resource_dependencies": {"effects": [{"provider": "res://assets/effects/airdrop_bear/player.gd", "variant": "aura"}]}}]},
		# BEGIN IMPORTED AUDIO airdrop_bear
		"audio": {
			"events": {
				"spell:cast": {
					"pool": [
						"res://assets/audio/units/airdrop_bear/play_sfx_annie_annier_oncast_r1.wav",
						"res://assets/audio/units/airdrop_bear/play_sfx_annie_annier_oncast_r2.wav",
						"res://assets/audio/units/airdrop_bear/play_sfx_annie_annier_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"spell:enraged": {
					"pool": [
						"res://assets/audio/units/airdrop_bear/play_sfx_annie_annier_tibbers_enraged_buffactivate_r1.wav",
						"res://assets/audio/units/airdrop_bear/play_sfx_annie_annier_tibbers_enraged_buffactivate_r2.wav",
						"res://assets/audio/units/airdrop_bear/play_sfx_annie_annier_tibbers_enraged_buffactivate_r3.wav"
					],
					"volume_db": 0.0, "bus": "Combat"
				},
				"spell:impact": {
					"pool": [
						"res://assets/audio/units/airdrop_bear/play_sfx_annie_annier_onhitlocation.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			}
		},
		# END IMPORTED AUDIO airdrop_bear
		"card_art": {"path": "res://assets/cards/airdrop_bear_loading.png"},
	}
