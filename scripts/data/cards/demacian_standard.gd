extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "德邦军旗", "cost": 2, "type": "building", "deploy_zone": "global",
			"description": "可在敌方半区部署。周围4格内友方单位与建筑攻速提升25%，多面军旗不叠加；离开范围或军旗死亡后失效。不影响防御塔和水晶。",
			"hp": 360, "damage": 0, "range": 0.0, "speed": 0.0, "interval": 1.0,
			"radius": RADIUS_MEDIUM, "size_tier": SIZE_MEDIUM, "deploy_time": 1.0, "footprint_tiles": Vector2i(1, 1),
			"can_attack": false, "is_air": false, "is_building": true, "building_only": false, "can_attack_air": false,
			"lifespan": 12.0, "lifespan_hp_decay": true,
			"haste_aura_radius": 160.0, "haste_aura_multiplier": 1.25,
			"active_skills": [{"name": "黄金圣盾", "kind": "area_shield", "cost": 1,
				"max_uses": 2, "cooldown": 5.0, "radius": 160.0 - RADIUS_MEDIUM,
				"shield": 120, "shield_duration": 3.0, "slow_duration": 2.0, "slow_multiplier": 0.65,
				"description": "为旗杆中心4格内友军提供120点护盾，持续3秒；范围内敌方单位减速35%，持续2秒。包含自身、友方建筑与防御塔。"}],
		},
		"visual": {
			"visual_scene_path": "res://assets/units/demacian_standard/standard_view.tscn",
			"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING, "visual_forward_yaw": 0.0, "color": Color(0.9, 0.72, 0.25),
			"visual_animations": {"idle": "summonerbeacon_idle", "death": "summonerbeacon_death", "death_duration": 0.8},
			"visual_active_buff_scene": "res://assets/effects/demacian_standard/golden_aegis.tscn",
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/demacian_standard/player.gd", "variant": "flag"}, {"provider": "res://assets/effects/demacian_standard/player.gd", "variant": "fall"}, {"provider": "res://assets/effects/demacian_standard/player.gd", "variant": "fall_red"}, {"provider": "res://assets/effects/demacian_standard/player.gd", "variant": "landing"}]},
			"active_skills": [{"icon_path": "res://assets/skills/demacian_standard_0.png", "resource_dependencies": {"fields": ["visual_active_buff_scene"], "effects": [{"provider": "res://assets/effects/demacian_standard/player.gd", "variant": "nova"}, {"provider": "res://assets/effects/demacian_standard/player.gd", "variant": "shield"}]}}],
		},
		# BEGIN IMPORTED AUDIO demacian_standard
		"audio": {
			"events": {
				"deploy:start": {
					"pool": [
						"res://assets/audio/units/demacian_standard/play_sfx_jarvaniv_jarvanivdemacianstandard_fall_r1.wav",
						"res://assets/audio/units/demacian_standard/play_sfx_jarvaniv_jarvanivdemacianstandard_fall_r2.wav",
						"res://assets/audio/units/demacian_standard/play_sfx_jarvaniv_jarvanivdemacianstandard_fall_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"shield:cast": {
					"pool": [
						"res://assets/audio/units/demacian_standard/play_sfx_jarvaniv_jarvanivgoldenaegis_oncast_r1.wav",
						"res://assets/audio/units/demacian_standard/play_sfx_jarvaniv_jarvanivgoldenaegis_oncast_r2.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"deploy:release": {
					"action_time": 0.5,
					"pool": [
						"res://assets/audio/units/demacian_standard/play_sfx_jarvaniv_jarvanivdemacianstandard_hit_r1.wav",
						"res://assets/audio/units/demacian_standard/play_sfx_jarvaniv_jarvanivdemacianstandard_hit_r2.wav",
						"res://assets/audio/units/demacian_standard/play_sfx_jarvaniv_jarvanivdemacianstandard_hit_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			}
		},
		# END IMPORTED AUDIO demacian_standard
		"card_art": {"path": "res://assets/cards/demacian_standard.png"},
	}
