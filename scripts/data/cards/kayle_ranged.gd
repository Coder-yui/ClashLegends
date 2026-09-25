extends "res://scripts/data/card_schema.gd"
## 高费部署结果，卡组仍只选择 kayle；两者共享原始模型与 W 定义。
static func definition() -> Dictionary:
	var data := preload("res://scripts/data/cards/kayle.gd").definition()
	data.gameplay.erase("deployment_upgrade_id")
	data.gameplay.merge({
		"name": "正义天使（远程）", "cost": 6, "selectable": false,
		"description": "6金币远程形态，对地对空；金色光剑造成单体伤害；每次普攻附带一道穿透焰浪，出手时锁定对空或对地，对同类别敌人造成55伤害。",
		"hp": 820, "damage": 105, "range": 190.0, "sight": 280.0,
		"interval": 1.5, "first_hit": snappedf(1.5 * (8.0 / 65.0), 0.01), "splash_radius": 0.0,
		"attack_wave_damage": 55, "attack_wave_delay": 0.1, "attack_wave_tail_distance": 40.0, "attack_wave_near_width": 48.0, "attack_wave_max_scale": 2.0, "attack_wave_speed": 420.0,
		"projectile_speed": 420.0, "projectile_spawn_at_edge": true,
		"projectile_spawn_offset": 7.5, "projectile_collision_radius": 4.0,
	}, true)
	data.visual.merge({
		"visual_scene_path": "res://assets/units/kayle/ranged_view.tscn",
		"attack_wave_visual": "kayle_wave", "attack_wave_visual_height": 50.0,
		"projectile_visual": "kayle_sword", "projectile_visual_height": 80.0,
		"projectile_colors": [Color(1.0, 0.79, 0.25), Color(1.0, 0.79, 0.25)],
	}, true)
	data.visual.visual_animations.idle = "IdlePassive"
	data.visual.visual_animations.move = "Kayle_RunPassive_anm"
	data.visual.visual_animations.attack = ["Kayle_Attack3_anm", "Kayle_Attack4_anm"]
	data.visual.visual_animations.transitions = {
		"Respawn>move": {"animation": "Kayle_RunInPassive_anm", "blend_in": 0.1, "blend_out": 0.0},
		"IdlePassive>move": {"animation": "Kayle_RunInPassive_anm", "blend_in": 0.0, "blend_out": 0.0},
		"Kayle_IdleInPassive_anm>move": {"animation": "Kayle_RunInPassive_anm", "blend_in": 0.0, "blend_out": 0.0},
		"Kayle_RunPassive_anm>idle": {"animation": "Kayle_IdleInPassive_anm", "blend_in": 0.0, "blend_out": 0.0},
		"Kayle_RunInPassive_anm>idle": {"animation": "Kayle_IdleInPassive_anm", "blend_in": 0.0, "blend_out": 0.0},
	}
	data.audio = {
		"events": {
			"attack_wave:launch": {"pool": ["res://assets/audio/units/kayle/wave_launch_r1.wav", "res://assets/audio/units/kayle/wave_launch_r2.wav", "res://assets/audio/units/kayle/wave_launch_r3.wav", "res://assets/audio/units/kayle/wave_launch_r4.wav"], "volume_db": -5.0},
			"attack_wave:hit": {"pool": ["res://assets/audio/units/kayle/wave_hit.wav"], "volume_db": -5.0},
			"deploy:voice": {
				"pool": [
					"res://assets/audio/units/kayle/deploy_ranged_1.wav",
					"res://assets/audio/units/kayle/deploy_ranged_2.wav",
					"res://assets/audio/units/kayle/deploy_ranged_3.wav"
				],
				"bus": "Voice",
				"volume_db": 0.0
			},
			"active:cast": {
				"pool": [
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylewheal_oncast_r1.wav",
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylewheal_oncast_r2.wav",
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylewheal_oncast_r3.wav",
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylewheal_oncast_r4.wav"
				],
				"bus": "Combat",
				"volume_db": -3.0
			},
			"death": {
				"pool": [
					"res://assets/audio/units/kayle/play_sfx_kayle_death3d_cast.wav"
				],
				"bus": "Combat",
				"volume_db": -3.0
			}
		},
		"attack_swing": [
			[
				"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack3_oncast_r1_d.wav",
				"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack3_oncast_r2_d.wav",
				"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack3_oncast_r3_d.wav",
				"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack3_oncast_r4_d.wav"
			],
			[
				"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack4_oncast_r1_d.wav",
				"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack4_oncast_r2_d.wav",
				"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack4_oncast_r3_d.wav",
				"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack4_oncast_r4_d.wav"
			]
		],
		"attack_swing_volume_db": -5.0,
		"attack_hit_by_segment": [
			[
				"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack3_onhit.wav"
			],
			[
				"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack4_onhit_d.wav"
			]
		],
		"attack_hit_volume_db": -5.0,
		"attack_launch_by_segment": [
			[
				"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack3_onmissilecast.wav"
			],
			[
				"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack4_onmissilecast_d.wav"
			]
		]
	}
	return data
