extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "未来守护者", "cost": 4, "type": "unit",
			"description": "杰斯以远程形态部署，每8秒切换锤炮形态；到时打断普攻换形，硬控结束后补换形。远程首击额外40伤害，近战首击对主目标额外造成8%最大生命值伤害，对塔与水晶改为60。",
			"hp": 650, "damage": 65, "range": 180.0, "speed": SPEED_MEDIUM,
			"interval": 1.4, "first_hit": 0.10, "size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM,
			"mass": 4.0, "sight": 240.0, "projectile_speed": 520.0, "splash_radius": 0.0,
			"projectile_spawn_at_edge": true, "projectile_spawn_offset": 0.0, "projectile_collision_radius": 4.0,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"form_cycle_interval": 8.0, "transform_duration": 0.0,
			"form_first_attack_damage": 40,
			"transformed_stats": {
				"name": "未来守护者·战锤", "hp": 650, "damage": 80, "range": MELEE_RANGE_MIN,
				"speed": SPEED_MEDIUM, "interval": 1.1, "first_hit": 0.24,
				"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "mass": 4.0, "sight": 240.0,
				"projectile_speed": 0.0, "splash_radius": 0.0,
				"is_air": false, "building_only": false, "can_attack_air": false,
				"form_first_attack_health_ratio": 0.08, "form_first_attack_tower_damage": 60,
			},
			"active_skills": [{"name": "超能电荷 / 闪电领域", "kind": "attack_burst", "form_kinds": ["attack_burst", "continuous_area"], "persistent_area": true, "radius": 95.0, "duration": 4.0, "tick_interval": 0.5, "damage": 10, "cost": 1, "max_uses": 2, "cooldown": 10.0,
				"description": "炮形态：4秒内接下来3次普攻获得3倍攻速，次数用完或时间到期即结束。锤形态：开启4秒电场，每0.5秒对周围敌军造成10伤害。两种效果换形后均保留。", "attack_count": 3, "attack_speed_multiplier": 3.0}],
		},
		"visual": {
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/jayce/player.gd", "variant": "stance_m"}, {"provider": "res://assets/effects/jayce/player.gd", "variant": "swap_m"}, {"provider": "res://assets/effects/jayce/player.gd", "variant": "swap_r"}, {"provider": "res://assets/effects/jayce/player.gd", "variant": "stance_r"}, {"provider": "res://assets/effects/jayce/player.gd", "variant": "stance_hammer"}, {"provider": "res://assets/effects/jayce/player.gd", "variant": "bullet"}, {"provider": "res://assets/effects/jayce/player.gd", "variant": "first_hit_m"}, {"provider": "res://assets/effects/jayce/player.gd", "variant": "first_hit_r"}, {"provider": "res://assets/effects/jayce/player.gd", "variant": "ready_m"}, {"provider": "res://assets/effects/jayce/player.gd", "variant": "ready_r"}]},
			"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/jayce/jayce_view.tscn", "visual_forward_yaw": 0.0,
			"color": Color(0.3, 0.65, 0.95), "attack_hit_visual": "jayce", "projectile_visual": "jayce_bullet", "projectile_visual_height": 38.0,
			"visual_animations": {"idle": "jayce_ranged_idle1_anm", "move": "Ranged_Run", "attack": ["Ranged_Attack1", "Ranged_Attack2"], "first_strike_attack": "Ranged_Attack2", "active_buff_attack": ["Ranged_Spell2_Attack1", "Ranged_Spell2_Attack2"],
				"death": "Death", "death_duration": 0.8,
				"visual_actions": {"transform": {"animation": "Ranged_Passive", "kind": "transform", "durations": [0.3]}}},
			"transformed_stats": {
				"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING, "attack_hit_visual": "jayce",
				"visual_scene_path": "res://assets/units/jayce/jayce_view.tscn", "visual_forward_yaw": 0.0,
				"visual_animations": {"idle": "jayce_melee_idle1_anm", "move": "Run", "attack": ["Attack1", "Attack2"], "first_strike_attack": "Crit",
					"death": "Death", "death_duration": 0.8,
					"visual_actions": {"transform": {"animation": "Melee_Passive", "kind": "transform", "durations": [0.3]}}},
			},
			"active_skills": [{"icon_path": "res://assets/skills/jayce_w.png", "impact_visual_shape": "jayce_field_hit", "impact_visual_duration": 1.0, "form_icon_paths": ["res://assets/skills/jayce_w.png", "res://assets/skills/jayce_w_melee.png"], "resource_dependencies": {"effects": [{"provider": "res://assets/effects/jayce/player.gd", "variant": "w_ready2"}, {"provider": "res://assets/effects/jayce/player.gd", "variant": "field"}, {"provider": "res://assets/effects/jayce/player.gd", "variant": "field_hit"}]}}],
		},
		# BEGIN IMPORTED AUDIO jayce
		"audio": {
	"events": {
		"transform:start": {
			"pool": [
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycestancehtg_oncast.wav"
			],
			"volume_db": 0.0,
			"bus": "Combat"
		},
		"burst:start": {
			"pool": [
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycehypercharge_oncast.wav"
			],
			"volume_db": 0.0,
			"bus": "Combat"
		},
		"burst:end": {
			"pool": [
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycehypercharge_onbuffdeactivate.wav"
			],
			"volume_db": 0.0,
			"bus": "Combat"
		},
		"death": {
			"pool": [
				"res://assets/audio/units/jayce/play_sfx_jayce_death3d_cast.wav"
			],
			"volume_db": 0.0,
			"bus": "Combat"
		},
		"death:voice": {
			"pool": [
				"res://assets/audio/units/jayce/play_vo_jayce_death3d_r1_zh_cn.wav",
				"res://assets/audio/units/jayce/play_vo_jayce_death3d_r2_zh_cn.wav",
				"res://assets/audio/units/jayce/play_vo_jayce_death3d_r3_zh_cn.wav"
			],
			"volume_db": 0.0,
			"bus": "Voice"
		},
		"deploy:voice": {
			"pool": [
				"res://assets/audio/units/jayce/champion_choose_126_zh_cn.ogg"
			],
			"volume_db": 0.0,
			"bus": "Voice",
			"clip_volume_db": {
				"res://assets/audio/units/jayce/champion_choose_126_zh_cn.ogg": -8.0
			}
		},
		"first_strike:cast": {
			"pool": [
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycepassiverangedattack_oncast_r1.wav",
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycepassiverangedattack_oncast_r2.wav",
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycepassiverangedattack_oncast_r3.wav"
			],
			"volume_db": 0.0,
			"bus": "Combat"
		},
		"first_strike:missile_launch": {
			"pool": [
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycepassiverangedattack_onmissilelaunch_r1.wav",
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycepassiverangedattack_onmissilelaunch_r2.wav",
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycepassiverangedattack_onmissilelaunch_r3.wav"
			],
			"volume_db": 0.0,
			"bus": "Combat"
		},
		"active_buff:attack_swing": {
			"pool": [
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycehyperchargerangedattack_oncast_r1.wav",
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycehyperchargerangedattack_oncast_r2.wav",
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycehyperchargerangedattack_oncast_r3.wav"
			],
			"volume_db": 0.0,
			"bus": "Combat"
		},
		"active_buff:attack_launch": {
			"pool": [
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycehyperchargerangedattack_onmissilelaunch_r1.wav",
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycehyperchargerangedattack_onmissilelaunch_r2.wav",
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycehyperchargerangedattack_onmissilelaunch_r3.wav"
			],
			"volume_db": 0.0,
			"bus": "Combat"
		},
		"active_buff:attack_hit": {
			"pool": [
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycehyperchargerangedattack_onhit_r1.wav",
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycehyperchargerangedattack_onhit_r2.wav",
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycehyperchargerangedattack_onhit_r3.wav"
			],
			"volume_db": 0.0,
			"bus": "Combat"
		},
		"active_buff:sustain": {
			"pool": [
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycehypercharge_onbuffactivate.wav"
			],
			"volume_db": 0.0,
			"bus": "Combat"
		},
		"persistent_area:sustain": {
			"pool": [
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycestaticfield_onbuffactivate.wav"
			],
			"volume_db": 0.0,
			"bus": "Combat",
			"fade_out": 0.15
		},
		"persistent_area:end": {
			"pool": [
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycestaticfield_onbuffdeactivate.wav"
			],
			"volume_db": 0.0,
			"bus": "Combat"
		}
	},
	"attack_swing": [
		[
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycerangedattack_oncast_r1_d.wav",
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycerangedattack_oncast_r2_d.wav",
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycerangedattack_oncast_r3_d.wav"
		],
		[
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycerangedattack_oncast_r1_d.wav",
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycerangedattack_oncast_r2_d.wav",
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycerangedattack_oncast_r3_d.wav"
		]
	],
	"attack_swing_volume_db": 0.0,
	"attack_launch_by_segment": [
		[
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycerangedattack_onmissilelaunch_r1_d.wav",
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycerangedattack_onmissilelaunch_r2_d.wav",
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycerangedattack_onmissilelaunch_r3_d.wav"
		],
		[
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycerangedattack_onmissilelaunch_r1_d.wav",
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycerangedattack_onmissilelaunch_r2_d.wav",
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycerangedattack_onmissilelaunch_r3_d.wav"
		]
	],
	"attack_hit_by_segment": [
		[
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycerangedattack_onhit_r1_d.wav",
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycerangedattack_onhit_r2_d.wav",
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycerangedattack_onhit_r3_d.wav"
		],
		[
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycerangedattack_onhit_r1_d.wav",
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycerangedattack_onhit_r2_d.wav",
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycerangedattack_onhit_r3_d.wav"
		]
	],
	"transformed_stats": {
		"attack_swing": [
			[
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycebasicattack_oncast_r1_d.wav",
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycebasicattack_oncast_r2_d.wav",
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycebasicattack_oncast_r3_d.wav"
			],
			[
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycebasicattack_oncast_r1_d.wav",
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycebasicattack_oncast_r2_d.wav",
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycebasicattack_oncast_r3_d.wav"
			]
		],
		"attack_hit_by_segment": [
			[
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycebasicattack_onhit_1559186049_1153642577_r1_d.wav",
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycebasicattack_onhit_1559186049_1153642577_r2_d.wav",
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycebasicattack_onhit_1559186049_1153642577_r3_d.wav"
			],
			[
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycebasicattack_onhit_1559186049_1153642577_r1_d.wav",
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycebasicattack_onhit_1559186049_1153642577_r2_d.wav",
				"res://assets/audio/units/jayce/play_sfx_jayce_jaycebasicattack_onhit_1559186049_1153642577_r3_d.wav"
			]
		],
		"events": {
			"transform:start": {
				"pool": [
					"res://assets/audio/units/jayce/play_sfx_jayce_jaycestancegth_oncast.wav"
				],
				"bus": "Combat",
				"volume_db": 0.0
			},
			"burst:start": {
				"pool": [
					"res://assets/audio/units/jayce/play_sfx_jayce_jaycehypercharge_oncast.wav"
				],
				"volume_db": 0.0,
				"bus": "Combat"
			},
			"burst:end": {
				"pool": [
					"res://assets/audio/units/jayce/play_sfx_jayce_jaycehypercharge_onbuffdeactivate.wav"
				],
				"volume_db": 0.0,
				"bus": "Combat"
			},
			"death": {
				"pool": [
					"res://assets/audio/units/jayce/play_sfx_jayce_death3d_cast.wav"
				],
				"volume_db": 0.0,
				"bus": "Combat"
			},
			"death:voice": {
				"pool": [
					"res://assets/audio/units/jayce/play_vo_jayce_death3d_r1_zh_cn.wav",
					"res://assets/audio/units/jayce/play_vo_jayce_death3d_r2_zh_cn.wav",
					"res://assets/audio/units/jayce/play_vo_jayce_death3d_r3_zh_cn.wav"
				],
				"volume_db": 0.0,
				"bus": "Voice"
			},
			"deploy:voice": {
				"pool": [
					"res://assets/audio/units/jayce/champion_choose_126_zh_cn.ogg"
				],
				"volume_db": 0.0,
				"bus": "Voice",
				"clip_volume_db": {
					"res://assets/audio/units/jayce/champion_choose_126_zh_cn.ogg": -8.0
				}
			},
			"first_strike:cast": {
				"pool": [
					"res://assets/audio/units/jayce/play_sfx_jayce_jaycepassivemeleeattack_oncast.wav"
				],
				"volume_db": 0.0,
				"bus": "Combat"
			},
			"active:cast": {
				"pool": [
					"res://assets/audio/units/jayce/play_sfx_jayce_jaycestaticfield_oncast.wav"
				],
				"volume_db": 0.0,
				"bus": "Combat"
			},
			"active_buff:sustain": {
				"pool": [
					"res://assets/audio/units/jayce/play_sfx_jayce_jaycehypercharge_onbuffactivate.wav"
				],
				"volume_db": 0.0,
				"bus": "Combat"
			},
			"persistent_area:sustain": {
				"pool": [
					"res://assets/audio/units/jayce/play_sfx_jayce_jaycestaticfield_onbuffactivate.wav"
				],
				"volume_db": 0.0,
				"bus": "Combat",
				"fade_out": 0.15
			},
			"persistent_area:end": {
				"pool": [
					"res://assets/audio/units/jayce/play_sfx_jayce_jaycestaticfield_onbuffdeactivate.wav"
				],
				"volume_db": 0.0,
				"bus": "Combat"
			}
		},
		"first_strike_hit": [
			"res://assets/audio/units/jayce/play_sfx_jayce_jaycepassivemeleeattack_onhit_r.wav"
		]
	},
	"first_strike_hit": [
		"res://assets/audio/units/jayce/play_sfx_jayce_jaycepassiverangedattack_hit.wav"
	]
},
		# END IMPORTED AUDIO jayce
		"card_art": {"path": "res://assets/cards/jayce_loading.png"},
	}
