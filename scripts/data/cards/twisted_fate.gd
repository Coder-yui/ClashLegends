extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "卡牌大师", "cost": 4, "type": "unit",
			"description": "远程法师，可攻击地面与空中目标；能在河道外的全图地面落点部署。",
			"hp": 460, "damage": 62, "range": 190.0,
			"speed": SPEED_MEDIUM, "interval": 1.2, "first_hit": 0.25,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM,
			"mass": 3.0, "sight": 250.0,
			"projectile_speed": 520.0,
			"projectile_spawn_at_edge": false, "projectile_spawn_offset": 0.0, "projectile_collision_radius": 4.0,
			# deploy_time 是单位出现后的部署锁定；pre_deploy_time 是出现前只显示卡牌落点提示的阶段。
			"deploy_time": 0.45, "pre_deploy_time": 1.3, "deploy_zone": "global",
			# 第五次普攻使用 Spell3 动作，并在同一个弹体附带 50% 额外伤害。
			"attack_damage_multipliers": [1.0, 1.0, 1.0, 1.0, 1.5],
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{
					"name": "万能牌", "kind": "frontal", "shape": "fan",
					"cost": 1, "max_uses": 2, "cooldown": 8.0,
					"description": "朝前方扇出 3 张穿透牌，飞行命中地面或空中敌人时造成伤害；同一敌人每次施法只受伤一次。",
					"length": 190.0, "arc_degrees": 54.0, "projectile_count": 3,
					# Spell1 出手生成三张权威穿透牌，沿路径碰撞结算；同次施法每目标只伤害一次。
					"projectile_piercing": true, "projectile_launch_delay": 0.25, "projectile_flight_duration": 0.72,
					"damage": 100, "impact_delay": 0.25, "cast_duration": 0.97,
					"cast_locks": ["movement", "attack", "facing"],
				}],
		},
		"visual": { "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/twisted_fate/twisted_fate_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "twistedfate_2012_idle_enter_anm", "idle": "twistedfate_2012_idle1_anm",
				"move": "Run1",
				"attack": ["Attack1", "Attack2", "Attack3", "Attack4", "Spell3"],
				"visual_actions": {
					"wild_cards": {"animation": "Spell1", "durations": [0.9677415], "kind": "skill", "blend_in": 0.06, "blend_out": 0.10},
				},
				"death": "Death", "death_duration": 0.8,
			}, "projectile_visual": "orb", "projectile_visual_height": 60.0,
			"color": Color(0.34, 0.56, 0.92),
			"active_skills": [{ "projectile_visual": "card", "visual_action": "wild_cards",
				}],
		},
		# BEGIN IMPORTED AUDIO twisted_fate
		"audio": {
			"attack_launch_by_segment": [
				[
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onmissilelaunch_r1_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onmissilelaunch_r2_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onmissilelaunch_r3_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onmissilelaunch_r4_d.wav"
				],
				[
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onmissilelaunch_r1_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onmissilelaunch_r2_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onmissilelaunch_r3_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onmissilelaunch_r4_d.wav"
				],
				[
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onmissilelaunch_r1_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onmissilelaunch_r2_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onmissilelaunch_r3_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onmissilelaunch_r4_d.wav"
				],
				[
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onmissilelaunch_r1_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onmissilelaunch_r2_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onmissilelaunch_r3_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onmissilelaunch_r4_d.wav"
				],
				[
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_cardmasterstack_missilelaunch_r1.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_cardmasterstack_missilelaunch_r2.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_cardmasterstack_missilelaunch_r3.wav"
				]
			],
			"events": {
				"pre_deploy:start": {
					"pool": [
						"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_gate_marker_r1_first_1_75s.wav",
						"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_gate_marker_r2_first_1_75s.wav",
						"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_gate_marker_r3_first_1_75s.wav"
					],
					"volume_db": 0.0, "bus": "Combat"
				},
				"wild_cards:hit": {
					"pool": ["res://assets/audio/units/twisted_fate/play_sfx_twistedfate_sealfatemissile_onhit_r.wav"],
					"volume_db": 0.0, "bus": "Combat"
				},
				"wild_cards:release": {
					"pool": [
						"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_sealfatemissile_onmissilelaunch_r1.wav",
						"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_sealfatemissile_onmissilelaunch_r2.wav",
						"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_sealfatemissile_onmissilelaunch_r3.wav",
						"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_sealfatemissile_onmissilelaunch_r4.wav"
					],
					"volume_db": 0.0, "bus": "Combat"
				},
				"wild_cards:sustain": {
					"pool": [
						"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_wildcards_oncast_r1.wav",
						"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_wildcards_oncast_r2.wav",
						"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_wildcards_oncast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/twisted_fate/play_vo_twistedfate_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/twisted_fate/play_vo_twistedfate_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/twisted_fate/play_vo_twistedfate_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_oncast_r1_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_oncast_r2_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_oncast_r3_d.wav"
				],
				[
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack2_oncast_r1.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack2_oncast_r2.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack2_oncast_r3.wav"
				],
				[
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack3_oncast_r1_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack3_oncast_r2_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack3_oncast_r3_d.wav"
				],
				[
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack4_oncast_r1_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack4_oncast_r2_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack4_oncast_r3_d.wav"
				],
				[
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_cardmasterstack_cast_r1.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_cardmasterstack_cast_r2.wav"
				]
			],
			"attack_swing_volume_db": -3.0,
			"attack_hit": [
				"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onhit_r1_d.wav",
				"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onhit_r2_d.wav",
				"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onhit_r3_d.wav"
			],
			"attack_hit_volume_db": -5.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onhit_r1_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onhit_r2_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack_onhit_r3_d.wav"
				],
				[
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack2_onhit_r1.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack2_onhit_r2.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack2_onhit_r3.wav"
				],
				[
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack3_onhit_r1_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack3_onhit_r2_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack3_onhit_r3_d.wav"
				],
				[
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack4_onhit_r1_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack4_onhit_r2_d.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_twistedfatebasicattack4_onhit_r3_d.wav"
				],
				[
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_cardmasterstack_hit_r1.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_cardmasterstack_hit_r2.wav",
					"res://assets/audio/units/twisted_fate/play_sfx_twistedfate_cardmasterstack_hit_r3.wav"
				]
			],
		},
		# END IMPORTED AUDIO twisted_fate
		"card_art": {},
	}
