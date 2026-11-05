extends "res://scripts/data/card_schema.gd"
static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "法外狂徒", "cost": 4, "type": "unit",
			"description": "双弹匣霰弹枪手。每枪散射6颗不追踪、不能穿透的弹丸，每颗独立造成28伤害，近距离更容易全中。弹匣耗尽后换弹2秒；移动时剩1发也会换弹，有敌人进入射程便取消换弹开枪。命中质量小于4的单位时小幅击退。",
			"hp": 760, "damage": 28, "range": 120.0, "speed": SPEED_SLIGHTLY_SLOW,
			"interval": 0.9, "first_hit": 0.14, "size_tier": SIZE_SLIGHTLY_LARGE,
			"radius": RADIUS_SLIGHTLY_LARGE, "mass": 5.0, "sight": 240.0,
			"magazine_size": 2, "reload_duration": 2.0,
			"attack_pellets": 6, "attack_pellet_distance": 220.0, "attack_pellet_arc": 28.0,
			"attack_knockback_max_mass": 4.0, "knockback": 12.0,
			"projectile_speed": 900.0, "projectile_spawn_at_edge": false,
			"projectile_spawn_offset": 0.0, "projectile_collision_radius": 3.0,
			"attack_recovery_cancel_every_hits": 1,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{
				"name": "快速拔枪", "kind": "dash", "cost": 1, "max_uses": 2, "cooldown": 8.0,
				"length": 120.0, "landing_extension": 40.0, "cast_duration": 0.4, "impact_delay": 0.0,
				"dash_backward": true, "ammo_restore": 1, "cast_locks": ["movement", "attack", "facing"],
				"description": "向释放朝向的后方滑行3格并获得1发子弹（最多2发），取消当前换弹。终点受阻时向后额外寻找最多40＋身体半径＋2的合法落点，否则停在障碍前。1金币，共2次，冷却8秒。",
			}],
		},
		"visual": {
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/graves/player.gd", "variant": "missile"}, {"provider": "res://assets/effects/graves/player.gd", "variant": "cast"}]},
			"visual_active_buff_scene": "res://assets/effects/graves/buff.tscn",
			"visual_scene_path": "res://assets/units/graves/graves_view.tscn",
			"visual_forward_yaw": 0.0, "visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"color": Color(0.72, 0.42, 0.22), "projectile_visual": "graves_bullet", "projectile_visual_height": 48.0,
			"visual_animations": {
				"idle": "Idle1", "move": "Run", "attack": "graves_attack1_anm",
				"reload": "graves_reload_anm", "reload_move": "ReloadMove",
				"death": "Death", "death_duration": 0.8,
				"visual_actions": {"active": {"animation": "Spell3", "kind": "skill", "durations": [0.4]}},
			},
			"active_skills": [{"resource_dependencies": {"effects": [{"provider": "res://assets/effects/graves/player.gd", "variant": "dash"}]}, "visual_action": "active", "icon_path": "res://assets/skills/graves_e.png"}],
		},
		# BEGIN IMPORTED AUDIO graves
		"audio": {
			"events": {
				"attack_launch": {
					"pool": [
						"res://assets/audio/units/graves/play_sfx_graves_gravesbasicattack_onmissilelaunch_r1.wav",
						"res://assets/audio/units/graves/play_sfx_graves_gravesbasicattack_onmissilelaunch_r2.wav",
						"res://assets/audio/units/graves/play_sfx_graves_gravesbasicattack_onmissilelaunch_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"reload:start": {
					"pool": [
						"res://assets/audio/units/graves/play_sfx_graves_gravesbasicattackspread_reload_open.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"reload:end": {
					"pool": [
						"res://assets/audio/units/graves/play_sfx_graves_gravesbasicattackspread_reload_close.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"active:start": {
					"pool": [
						"res://assets/audio/units/graves/play_sfx_graves_gravesmove_oncast_r1.wav",
						"res://assets/audio/units/graves/play_sfx_graves_gravesmove_oncast_r2.wav",
						"res://assets/audio/units/graves/play_sfx_graves_gravesmove_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/graves/play_vo_graves_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/graves/play_vo_graves_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/graves/play_vo_graves_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				},
				"deploy:voice": {
					"clip_volume_db": {"res://assets/audio/units/graves/champion_choose_104_zh_cn.ogg": -18.0},
					"pool": [
						"res://assets/audio/units/graves/play_vo_graves_move2dstandard_r8_zh_cn.wav",
						"res://assets/audio/units/graves/champion_choose_104_zh_cn.ogg",
						"res://assets/audio/units/graves/play_vo_graves_move2dstandard_r6_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				}
			},
			"attack_hit": [
				"res://assets/audio/units/graves/play_sfx_graves_gravesbasicattack_onhit_1559186049_1153642577_r1.wav",
				"res://assets/audio/units/graves/play_sfx_graves_gravesbasicattack_onhit_1559186049_1153642577_r2.wav",
				"res://assets/audio/units/graves/play_sfx_graves_gravesbasicattack_onhit_1559186049_1153642577_r3.wav"
			],
			"attack_hit_volume_db": 0.0
		},
		# END IMPORTED AUDIO graves
		"card_art": {"path": "res://assets/cards/graves_loading.png"},
	}
