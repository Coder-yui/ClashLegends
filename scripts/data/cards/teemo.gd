extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "提莫", "cost": 2, "type": "unit",
			"description": "灵活的远程射手，移速较快，擅长用毒针干扰敌人。",
			"hp": 230, "damage": 38, "range": 160.0,
			"speed": SPEED_FAST, "interval": 1.0, "first_hit": 0.25,
			"size_tier": SIZE_SMALL, "radius": RADIUS_SMALL,
			"mass": 2.0, "sight": 210.0,
			"projectile_speed": 380.0,
			"projectile_spawn_at_edge": true, "projectile_spawn_offset": 7.5, "projectile_collision_radius": 4.0,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{
					"name": "致盲", "kind": "empowered_attack",
					"cost": 0, "max_uses": 2, "cooldown": 4.0,
					"description": "强化下一次普通攻击；命中单位后使其接下来的两次普通攻击（包括强化普攻）不造成伤害。技能不改变攻击间隔。",
					"empowered_damage_multiplier": 1.0, "blind_charges": 2,
				}],
		},
		"visual": { "visual_radius": RADIUS_SMALL + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/teemo/teemo_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn", "idle": "Idle1_Base", "move": "Run_Base", "move_enter": "Run_In_ASU_Teemo_anm",
				# Attack1 播放完的离弦点创建弹体，随后切入 Attack1_ToIdle 完成后摇。
				"attack": ["Attack1_ASU_Teemo_anm"], "attack_hit": ["Attack1_ToIdle"],
				# 原表将 ToIdle 作为可中断收势；保留原速，不再把 1.667 秒强压成 0.75 秒。
				"attack_reference_interval": 1.0,
				"empowered_attack": "Spell1", "empowered_attack_hit": "Spell1_ToIdle",
				"empowered_attack_to_move": "Spell1_ToRun",
				"transitions": {
					"Attack1_ASU_Teemo_anm>idle": "Attack1_ToIdle",
					"Attack1_ToIdle>idle": "Idle_In",
					"Run_Base>idle": "Idle_In",
					"Run_In_ASU_Teemo_anm>idle": "Idle_In",
					"Spell1>idle": "Spell1_ToIdle",
					"Spell1_ToRun>idle": "Idle_In",
					"Respawn>idle": "Spawn_toIdle_ASU_Teemo_anm",
				},
				"clip_blends": {
					"Attack1_ASU_Teemo_anm>Attack1_ToIdle": 0.05,
					"Attack1_ASU_Teemo_anm>Attack1_ASU_Teemo_anm": 0.05,
					"Attack1_ToIdle>Attack1_ASU_Teemo_anm": 0.05,
					"Attack1_ASU_Teemo_anm>Spell1": 0.05,
					"Attack1_ToIdle>Spell1": 0.05,
					"Idle1_Base>Spell1": 0.05,
					"Idle_In>Spell1": 0.05,
					"Run_Base>Spell1": 0.05,
					"Run_In_ASU_Teemo_anm>Spell1": 0.05,
					"Spell1>Spell1": 0.05,
					"Spell1_ToIdle>Spell1": 0.05,
					"Spell1_ToRun>Spell1": 0.05,
				},
				"death": "Death", "death_duration": 0.8,
			},
			"projectile_visual": "needle",
			# 提莫身形较矮，吹箭从约 28px 高的吹管口出现；暂用短绿色线段代替正式毒针素材。
			"projectile_visual_height": 28.0 * CHARACTER_SCALE_MULTIPLIER,
			"color": Color(0.60, 0.80, 0.30),
		},
		# BEGIN IMPORTED AUDIO teemo
		"audio": {
			"events": {
				"deploy:start": {"pool": ["res://assets/audio/units/teemo/play_sfx_teemo_respawn3d_buffactivate.wav"], "volume_db": 0.0, "bus": "Combat"},
				"attack_launch": {"pool": ["res://assets/audio/units/teemo/play_sfx_teemo_teemobasicattack_onmissilelaunch_r1.wav", "res://assets/audio/units/teemo/play_sfx_teemo_teemobasicattack_onmissilelaunch_r2.wav"], "volume_db": 0.0, "bus": "Combat"},
				"empowered_launch": {"pool": ["res://assets/audio/units/teemo/play_sfx_teemo_teemoq_onmissilelaunch_r1.wav", "res://assets/audio/units/teemo/play_sfx_teemo_teemoq_onmissilelaunch_r2.wav"], "volume_db": 0.0, "bus": "Combat"},

				"empowered_swing": {
					"pool": [
						"res://assets/audio/units/teemo/play_sfx_teemo_teemoq_oncast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/teemo/play_vo_teemo_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/teemo/play_vo_teemo_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/teemo/play_vo_teemo_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/teemo/play_sfx_teemo_teemobasicattack_oncast_r1.wav",
					"res://assets/audio/units/teemo/play_sfx_teemo_teemobasicattack_oncast_r2.wav"
				]
			],
			"attack_swing_volume_db": -3.0,
			"attack_hit": [
				"res://assets/audio/units/teemo/play_sfx_teemo_teemobasicattack_onhit_r1.wav",
				"res://assets/audio/units/teemo/play_sfx_teemo_teemobasicattack_onhit_r2.wav"
			],
			"attack_hit_volume_db": -5.0,
			"empowered_hit": [
				"res://assets/audio/units/teemo/play_sfx_teemo_teemoq_onhit_r1.wav",
				"res://assets/audio/units/teemo/play_sfx_teemo_teemoq_onhit_r2.wav"
			],
		},
		# END IMPORTED AUDIO teemo
		"card_art": {},
	}
