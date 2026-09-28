extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "奥恩", "cost": 6, "type": "unit",
			"description": "慢速大型推进坦克，只攻击建筑。部署完成4秒后首次发锤，此后每8秒向全场一名未增幅友军发锤；锤子抵达后永久提高20%普通攻击伤害；主动技能向前冲撞，撞上建筑或地形时造成范围伤害与眩晕。",
			"hp": 1260, "damage": 104, "range": MELEE_RANGE_MIN,
			"speed": SPEED_SLOW, "interval": 2.0, "first_hit": 0.26,
			"size_tier": SIZE_LARGE, "radius": RADIUS_LARGE,
			"mass": 10.0, "sight": 220.0,
			"is_air": false, "building_only": true, "can_attack_air": false,
			"team_attack_boost_first_delay": 4.0,
			"team_attack_boost_interval": 8.0,
			"team_attack_boost_multiplier": 1.2,
			"active_skills": [{
				"name": "熔铸冲锋", "kind": "terrain_charge",
				"cost": 2, "max_uses": 2, "cooldown": 10.0,
				"length": 3.5 * ArenaRules.TILE_SIZE, "fixed_speed": 280.0, "width": 42.0,
				"trail_damage": 32, "radius": 82.0, "damage": 135,
				"stun_duration": 1.5, "cast_duration": 1.4,
				"charge_prepare_time": 0.35, "charge_recovery_time": 0.55, "charge_miss_recovery_time": 0.2,
				"cast_locks": ["movement", "attack", "facing"],
				"description": "蓄力0.35秒，向前冲锋3.5格（0.5秒）；撞到障碍停顿0.55秒，未撞到则收势0.2秒；冲锋速度不受移速影响。路径上的敌人受到少量伤害；遇到建筑、河流或场地边界时停止，并以障碍表面接触点为中心造成范围伤害和1.5秒眩晕。未撞上障碍时不造成范围伤害或眩晕。",
			}],
		},
		"visual": {
			"color": Color(0.72, 0.34, 0.12),
			"visual_radius": RADIUS_LARGE + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/ornn/ornn_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn", "idle": "Idle1_Base", "move": "Run_Base",
				"attack": ["Attack1", "Attack2", "Attack3"], "death": "Death", "death_duration": 1.0,
				"visual_actions": {
					"ornn_charge": {"animation": ["Spell3", "Spell3_Dash"], "durations": [0.35, 0.5], "kind": "skill", "priority": 30, "blend_in": 0.05, "blend_out": 0.08, "sequence_blend": 0.04},
					"ornn_charge_hit": {"animation": ["Spell3_Hit", "Spell3_hit_toIdle"], "durations": [0.3, 0.25], "kind": "skill", "priority": 30, "blend_in": 0.03, "blend_out": 0.08, "sequence_blend": 0.05},
					"ornn_charge_miss": {"animation": "Idle1_Base", "kind": "skill", "priority": 30, "blend_in": 0.12, "blend_out": 0.08},
				},
			},
			"active_skills": [{"icon_path": "res://assets/skills/ornn_e.png", "visual_action": "ornn_charge"}],
		},
		# BEGIN IMPORTED AUDIO ornn
		"audio": {
			"events": {
				"deploy:voice": {"pool": ["res://assets/audio/units/ornn/deploy_choose_zh_cn.wav", "res://assets/audio/units/ornn/deploy_quality_zh_cn.wav", "res://assets/audio/units/ornn/deploy_ban_zh_cn.wav"], "volume_db": -2.0, "bus": "Voice"},
				"death": {
					"pool": [
						"res://assets/audio/units/ornn/play_vo_ornn_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/ornn/play_vo_ornn_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/ornn/play_vo_ornn_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				},
				"charge:step": {"pool": ["res://assets/audio/units/ornn/charge_step_1.wav", "res://assets/audio/units/ornn/charge_step_2.wav", "res://assets/audio/units/ornn/charge_step_3.wav", "res://assets/audio/units/ornn/charge_step_4.wav", "res://assets/audio/units/ornn/charge_step_5.wav"], "volume_db": -7, "bus": "Combat"},
				"charge:trail_hit": {"pool": ["res://assets/audio/units/ornn/charge_trail_hit_1.wav", "res://assets/audio/units/ornn/charge_trail_hit_2.wav", "res://assets/audio/units/ornn/charge_trail_hit_3.wav", "res://assets/audio/units/ornn/charge_trail_hit_4.wav", "res://assets/audio/units/ornn/charge_trail_hit_5.wav"], "volume_db": -6, "bus": "Combat"},
				"charge:knockup": {"pool": ["res://assets/audio/units/ornn/charge_knockup_1.wav"], "volume_db": -6, "bus": "Combat"},
				"forge:arrive": {"pool": ["res://assets/audio/units/ornn/forge_arrive_1.wav"], "volume_db": -3, "bus": "Combat"},
				"forge:pulse": {
					"pool": [
						"res://assets/audio/units/ornn/forge_equipment.wav"
					],
					"volume_db": -7.0,
					"bus": "Combat"
				},
				"charge:start": {
					"pool": [
						"res://assets/audio/units/ornn/play_sfx_ornn_ornne_oncast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},

				"charge:impact": {
					"pool": [
						"res://assets/audio/units/ornn/play_sfx_ornn_ornne_buffonmoveend_explosion_r.wav"
					],
					"volume_db": -3.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack_oncast_r1_d.wav",
					"res://assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack_oncast_r2_d.wav",
					"res://assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack_oncast_r3_d.wav"
				],
				[
					"res://assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack2_oncast_r1.wav",
					"res://assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack2_oncast_r2.wav",
					"res://assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack2_oncast_r3.wav"
				],
				[
					"res://assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack3_oncast_r1_d.wav",
					"res://assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack3_oncast_r2_d.wav",
					"res://assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack3_oncast_r3_d.wav"
				]
			],
			"attack_swing_volume_db": -3.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack_onhit_1559186049_1153642577_r1_d.wav",
					"res://assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack_onhit_1559186049_1153642577_r2_d.wav",
					"res://assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack_onhit_1559186049_1153642577_r3_d.wav"
				],
				[
					"res://assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack2_onhit_1559186049_1153642577_r1.wav",
					"res://assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack2_onhit_1559186049_1153642577_r2.wav",
					"res://assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack2_onhit_1559186049_1153642577_r3.wav"
				],
				[
					"res://assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack3_onhit_1559186049_1153642577_r1_d.wav",
					"res://assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack3_onhit_1559186049_1153642577_r2_d.wav",
					"res://assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack3_onhit_1559186049_1153642577_r3_d.wav"
				]
			]
		},
		# END IMPORTED AUDIO ornn
		"card_art": {"path": "res://assets/cards/ornn_loading.jpg"},
	}
