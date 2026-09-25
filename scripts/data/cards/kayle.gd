extends "res://scripts/data/card_schema.gd"

const BASE_ATTACK_INTERVAL := 1.5

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "正义天使", "cost": 3, "type": "unit",
			"description": "对地对空的飞行战士。金币不足6时花3金币部署近战形态；金币达到6时花6金币部署远程形态，弹体命中造成范围伤害。部署后形态固定。",
			"deployment_upgrade_id": "kayle_ranged",
			"hp": 520, "damage": 75, "range": 56.0,
			"speed": SPEED_MEDIUM, "interval": BASE_ATTACK_INTERVAL, "first_hit": snappedf(BASE_ATTACK_INTERVAL * (9.5 / 65.0), 0.01),
			"hit_haste_max_stacks": 4, "hit_haste_per_stack": 0.1, "hit_haste_duration": 3.0,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM, "mass": 4.0, "sight": 240.0,
			"is_air": true, "building_only": false, "can_attack_air": true,
			"active_skills": [{
				"name": "星界恩典", "kind": "buff", "cost": 0, "max_uses": 2, "cooldown": 6.0,
				"heal_amount": 160, "duration": 1.0, "speed_multiplier": 1.3,
				"cast_duration": 0.6, "impact_delay": 0.0, "cast_locks": ["attack"],
				"description": "回复自身160点生命，并获得1秒30%移速加成。0金币，6秒冷却，每次部署可使用2次。",
			}],
		},
		"visual": {
			"visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/kayle/melee_view.tscn", "visual_forward_yaw": 0.0,
			"color": Color(1.0, 0.79, 0.30),
			"visual_animations": {
				"deploy": "Respawn", "idle": "Idle1_Base", "move": "Run1",
				"attack": ["kayle_attack1_anm", "kayle_attack2_anm"],
				"transitions": {
					"Respawn>move": {"animation": "Run_In", "blend_in": 0.1, "blend_out": 0.0},
					"Idle1_Base>move": {"animation": "Run_In", "blend_in": 0.0, "blend_out": 0.0},
					"Idle_In>move": {"animation": "Run_In", "blend_in": 0.0, "blend_out": 0.0},
					"Run1>idle": {"animation": "Idle_In", "blend_in": 0.0, "blend_out": 0.1},
					"Run_In>idle": {"animation": "Idle_In", "blend_in": 0.0, "blend_out": 0.1},
				},
				"death": "Death", "death_duration": 1.0,
				"visual_actions": {"active": {"animation": "Spell2_0", "kind": "skill", "durations": [0.6], "blend_in": 0.06, "blend_out": 0.12}},
			},
			"active_skills": [{"icon_path": "res://assets/skills/kayle_w.png", "visual_action": "active"}],
		},
		"card_art": {"path": "res://assets/cards/kayle_loading.jpg"},
		"audio": {
			"events": {
				"deploy:voice": {
					"pool": [
						"res://assets/audio/units/kayle/deploy_melee_1.wav",
						"res://assets/audio/units/kayle/deploy_melee_2.wav",
						"res://assets/audio/units/kayle/deploy_melee_3.wav"
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
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack_oncast_r1_d.wav",
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack_oncast_r2_d.wav",
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack_oncast_r3_d.wav",
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack_oncast_r4_d.wav"
				],
				[
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack2_oncast_r1.wav",
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack2_oncast_r2.wav",
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack2_oncast_r3.wav",
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack2_oncast_r4.wav"
				]
			],
			"attack_swing_volume_db": -5.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack_onhit_r1_d.wav",
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack_onhit_r2_d.wav",
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack_onhit_r3_d.wav",
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack_onhit_r4_d.wav"
				],
				[
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack2_onhit_r1.wav",
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack2_onhit_r2.wav",
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack2_onhit_r3.wav",
					"res://assets/audio/units/kayle/play_sfx_kayle_kaylebasicattack2_onhit_r4.wav"
				]
			],
			"attack_hit_volume_db": -5.0
		},
	}
