extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

## 调整基础攻速只改这里；前摇与左右拳节奏按同一比例生成，局内倍率由 Unit 处理。
const BASE_ATTACK_INTERVAL := 1.0

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "腕豪", "cost": 4, "type": "unit",
			"description": "近战拳师，以快速双拳连招输出，第二拳造成更高伤害。",
			# 近战拳师：连招节奏——快速两拳→稍作停顿→再快速两拳→再停顿。
			"hp": 800, "damage": 72, "range": 40.0, # 1 格表面攻击距离。
			"speed": SPEED_MEDIUM, "interval": BASE_ATTACK_INTERVAL, "first_hit": BASE_ATTACK_INTERVAL * 0.3,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": RADIUS_SLIGHTLY_LARGE,
			"mass": 6.0, "sight": 210.0,
			"attack_pattern": [BASE_ATTACK_INTERVAL * 0.6, BASE_ATTACK_INTERVAL * 1.4, BASE_ATTACK_INTERVAL * 0.6, BASE_ATTACK_INTERVAL * 1.4],
			"attack_damage_multipliers": [1.0, 1.5, 1.0, 1.5],  # 左拳基础伤害，右拳为左拳的1.5倍
			# 两拳结束后没有下一次可攻击目标时立即追击，不播放被动段 Into_Idle 收势。
			"cancel_attack_recovery_without_target": true,
			# 豪意为通用技能资源：受实际生命伤害按 1:1、每次挥拳按固定值积攒；脱战后延迟衰减。
			"skill_resource_max": 200.0, "skill_resource_attack_gain": 20.0, "skill_resource_damage_gain_multiplier": 1.0,
			"skill_resource_decay_delay": 1.0, "skill_resource_decay_rate": 100.0,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skills": [{
					"name": "蓄意轰拳", "kind": "frontal", "shape": "trapezoid",
					"description": "消耗 2 金币。锁定移动、朝向和攻击后向前轰出梯形冲击波；豪意令伤害最高提高至 2 倍，中央区域再造成 1.5 倍伤害。释放瞬间按豪意获得护盾，0 豪意无护盾，满豪意 300 点并在 2 秒内衰减至 0。每个腕豪最多释放 1 次，冷却 8 秒。",
					"cost": 2, "max_uses": 1, "cooldown": 8.0,
					"length": 155.0, "near_width": 54.0, "far_width": 170.0,
					"center_ratio": 0.34, "center_damage_multiplier": 1.5,
					"damage": 130, "resource_damage_scale_max": 2.0,
					"resource_shield_max": 300, "shield_duration": 2.0, "shield_on_cast_start": true, "shield_decay": true,
					"uses_skill_resource": true,
					"impact_delay": 0.8, "cast_duration": 1.4,
					"cast_locks": ["movement", "attack", "facing"],
					"ground_only": true,
				}],
		},
		"visual": { "visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/sett/sett_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				# Respawn 只取原速前 1 秒；权威部署结束即交还移动 / 攻击。
				"deploy": "Respawn", "deploy_clip_ratio": 1.0 / 6.1666667, "idle": "Idle_Base", "move": "Run_Base",
				# 四次命中依次为：第一套左/右拳、第二套左/右拳；不再误用 Q 技能 Spell1。
				"attack": ["Attack1_Start", "Attack1_Passive_Start", "Attack2_Start", "Attack2_Passive_Start"],
				"attack_hit": ["Attack1_Hit", "Sett_Attack1_Passive_anm", "Attack2_Hit", "Sett_Attack2_Passive_anm"],
				"attack_recover": ["", "Attack1_Passive_Into_Idle", "", "Attack2_Passive_Into_Idle"],
				# 参考间隔下 Hit/收势按素材原速播放；下一次权威攻击可从任意阶段接管。
				"attack_reference_interval": 1.0,
				# 第二、第四拳没有下一目标而提前追击时，使用被动拳专用转跑片段。
				"attack_move": ["Run_Passive", "Run_Base", "Run_Passive", "Run_Base"],
				"transitions": {
					"Sett_Attack1_Passive_anm>move": "Sett_Passive_INTO_Run_anm",
					"Sett_Attack2_Passive_anm>move": "Sett_Passive_INTO_Run_anm",
					# 普通 W 完整结束已起身，从 ToRun 的对应姿态接入，避免重新蹲下。
					"Sett_spell2_anm>move": {"animation": "Sett_Spell2_INTO_Run_anm", "start_time": 0.4, "blend_in": 0.1},
					"Spell2_Strong>move": {"animation": "Sett_Spell2_INTO_Run_anm", "blend_in": 0.1},
					"Sett_spell2_anm>idle": "Spell2_Into_Idle",
					"Spell2_Strong>idle": "Spell2_Strong_Into_Idle",
				},
				"clip_blends": {
					"Respawn>Attack1_Start": 0.1, "Respawn>Attack2_Start": 0.1,
					"*>Attack1_Start": 0.1, "*>Attack2_Start": 0.1,
					"Attack1_Passive_Into_Idle>Attack1_Start": 0.15,
					"Attack1_Passive_Into_Idle>Attack2_Start": 0.15,
					"Attack1_Start>Attack1_Hit": 0.02,
					"Attack1_Passive_Start>Sett_Attack1_Passive_anm": 0.04,
					"Attack2_Start>Attack2_Hit": 0.0,
					"Attack2_Passive_Start>Sett_Attack2_Passive_anm": 0.0,
					"Sett_Attack1_Passive_anm>Attack1_Passive_Into_Idle": 0.0,
					"Sett_Attack2_Passive_anm>Attack2_Passive_Into_Idle": 0.0,
				},
				"visual_actions": {
					# 出拳前 0.8 秒均原速；剩余收尾各自适配 0.6 秒，保持共同 1.4 秒施法窗口。
					"active": {"animation": ["Sett_spell2_anm", "Sett_spell2_anm"], "kind": "skill", "durations": [0.8, 0.6], "clip_ranges": [[0.0, 0.8], [0.8, 1.5666666]], "sequence_blend": 0.0, "blend_in": 0.1, "blend_out": 0.1},
					"active_strong": {"animation": ["Spell2_Strong", "Spell2_Strong"], "kind": "skill", "durations": [0.8, 0.6], "clip_ranges": [[0.0, 0.8], [0.8, 1.1666666]], "sequence_blend": 0.0, "blend_in": 0.04, "blend_out": 0.1},
				},
				"death": "Death", "death_clip_end": 1.7, "death_duration": 0.8, # 只播放倒地前段
			},
			"skill_resource_full_color": Color(1.0, 0.82, 0.24, 0.96),
			"attack_interval_display": BASE_ATTACK_INTERVAL, # 完整左右拳循环的平均每拳间隔
			"color": Color(0.85, 0.55, 0.25),
			"active_skills": [{
					"visual_action": "active", "full_resource_visual_action": "active_strong",
				}],
		},
		# BEGIN IMPORTED AUDIO sett
		"audio": {
			"events": {
				"active:hit_center": {"pool": ["res://assets/audio/units/sett/play_sfx_sett_settw_hit_center_sweetener_r1.wav", "res://assets/audio/units/sett/play_sfx_sett_settw_hit_center_sweetener_r2.wav"], "volume_db": 0.0},
				"active_strong:hit_center": {"pool": ["res://assets/audio/units/sett/play_sfx_sett_settw_maxed_hit_center_sweetener_r1.wav", "res://assets/audio/units/sett/play_sfx_sett_settw_maxed_hit_center_sweetener_r2.wav"], "volume_db": 0.0},

				"deploy:start": {"pool": ["res://assets/audio/units/sett/play_sfx_sett_respawn3d_buffactivate_intro.wav"], "volume_db": 0.0, "bus": "Combat"},
				"active:sustain": {
					"pool": [
						"res://assets/audio/units/sett/play_sfx_sett_settw_cast_r1.wav",
						"res://assets/audio/units/sett/play_sfx_sett_settw_cast_r2.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"active:hit": {
					"pool": [
						"res://assets/audio/units/sett/play_sfx_sett_settw_hit_r1.wav",
						"res://assets/audio/units/sett/play_sfx_sett_settw_hit_r2.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"active_strong:sustain": {
					"pool": [
						"res://assets/audio/units/sett/play_sfx_sett_settw_maxed_cast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"active_strong:hit": {
					"pool": [
						"res://assets/audio/units/sett/play_sfx_sett_settw_maxed_hit_r1.wav",
						"res://assets/audio/units/sett/play_sfx_sett_settw_maxed_hit_r2.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/sett/play_vo_sett_death3d_r10_zh_cn.wav",
						"res://assets/audio/units/sett/play_vo_sett_death3d_r11_zh_cn.wav",
						"res://assets/audio/units/sett/play_vo_sett_death3d_r1_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack_cast_r1.wav",
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack_cast_r2.wav",
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack_cast_r3.wav"
				],
				[
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack2_cast_r1.wav",
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack2_cast_r2.wav",
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack2_cast_r3.wav"
				],
				[
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack_cast_r1.wav",
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack_cast_r2.wav",
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack_cast_r3.wav"
				],
				[
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack2_cast_r1.wav",
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack2_cast_r2.wav",
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack2_cast_r3.wav"
				]
			],
			"attack_swing_volume_db": -3.0,
			"attack_hit": [
				"res://assets/audio/units/sett/play_sfx_sett_settbasicattack_onhit_1559186049_1153642577_r1_d.wav",
				"res://assets/audio/units/sett/play_sfx_sett_settbasicattack_onhit_1559186049_1153642577_r2_d.wav",
				"res://assets/audio/units/sett/play_sfx_sett_settbasicattack_onhit_1559186049_1153642577_r3_d.wav"
			],
			"attack_hit_volume_db": -5.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack_onhit_1559186049_1153642577_r1_d.wav",
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack_onhit_1559186049_1153642577_r2_d.wav",
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack_onhit_1559186049_1153642577_r3_d.wav"
				],
				[
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack2_onhit_1559186049_1153642577_r1.wav",
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack2_onhit_1559186049_1153642577_r2.wav",
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack2_onhit_1559186049_1153642577_r3.wav"
				],
				[
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack3_onhit_1559186049_1153642577_r1.wav",
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack3_onhit_1559186049_1153642577_r2.wav",
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack3_onhit_1559186049_1153642577_r3.wav"
				],
				[
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack4_onhit_1559186049_1153642577_r1_d.wav",
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack4_onhit_1559186049_1153642577_r2_d.wav",
					"res://assets/audio/units/sett/play_sfx_sett_settbasicattack4_onhit_1559186049_1153642577_r3_d.wav"
				]
			],
		},
		# END IMPORTED AUDIO sett
		"card_art": {},
	}
