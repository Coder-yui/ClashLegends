extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "格温", "cost": 4, "type": "unit",
			"description": "普攻与每次剪切额外造成目标最大生命值 5% 的伤害，对防御塔和水晶固定附加 20 点。",
			# 百分比被动独立于基础伤害倍率，实际结算四舍五入。
			"hp": 580, "damage": 62, "range": MELEE_RANGE_MIN,
			"speed": SPEED_FAST, "interval": 0.85, "first_hit": 0.28,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM,
			"mass": 4.0, "sight": 210.0,
			"on_hit_max_health_ratio": 0.05, "on_hit_tower_damage": 20,
			"skill_resource_max": 3.0, "skill_resource_hit_gain": 1.0,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"active_skills": [{
					"name": "快刀乱剪", "kind": "frontal", "shape": "fan",
					"cost": 2, "max_uses": 1, "cooldown": 8.0,
					"description": "普通攻击命中充能，最多 3 层；必定先剪 40 点、最后剪 60 点，每层充能在中间追加一次 20 点剪切。每剪附带被动，中央仅提升基础伤害；满层且本次技能实际命中时，结束回复 100 点生命值。",
					"uses_skill_resource": true,
					"length": 135.0, "arc_degrees": 78.0, "projectile_count": 0,
					"center_width": 30.0, "center_damage_multiplier": 1.2,
					"damage": 40,
					"resource_hit_damage_sequences": [[40, 60], [40, 20, 60], [40, 20, 20, 60], [40, 20, 20, 20, 60]],
					"resource_hit_delay_sequences": [[0.09, 1.04], [0.09, 0.95, 1.04], [0.09, 0.78, 0.95, 1.04], [0.09, 0.62, 0.78, 0.95, 1.04]],
					"impact_delay": 0.09, "cast_duration": 1.5,
					"cast_locks": ["movement", "attack", "facing"],
					"full_resource_cast_end_heal": 100, "cast_end_heal_requires_hit": true,
					"applies_on_hit_passive": true,
					"ground_only": true,
				}],
		},
		"visual": { "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/gwen/gwen_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn", "idle": "Idle_anm", "move": "Run_anm", "move_enter": "Into_Run",
				"attack": ["Attack1", "Attack2", "Attack3"],
				# 原方向参数图的0°分支；单位朝向已由表现层对齐移动方向，不叠加原版TURN轨道。
				"attack_to_move": ["Into_Run", "INTO_Run_-90_anm", "INTO_Run_180_anm"],
				"clip_blends": {
					# 当前基础动作进入普攻均为0；保留原表唯一的Stunned入口例外。
					"*>Attack1": 0.0, "*>Attack2": 0.0, "*>Attack3": 0.0,
					"Stunned>Attack1": 0.05, "Stunned>Attack2": 0.05, "Stunned>Attack3": 0.05,
					"Idle_anm>Into_Run": 0.05, "Respawn>Into_Run": 0.05,
					"Attack1>Into_Run": 0.05,
					"Attack2>INTO_Run_-90_anm": 0.05,
					"Attack3>INTO_Run_180_anm": 0.05,
					"Spell1_C_anm>Spell1_C_to_Idle_anm": 0.0,
					"Spell1_C_to_Run_anm>Run_anm": 0.0,
				},
				"death": "Death", "death_duration": 0.8,
				"visual_actions": {
					# Spell1_B 保持素材原本的 0.1667 秒，并从 Spell1_0 尾部持姿区占用等量时间；四档总时长固定为 1.5 秒。
					# 原表 Spell1_0→Spell1_B、B→B、B→Spell1_C 的 TimeBlend 均为 0；采用其分段与衔接。
					# 原表未包含按层数调度的脚本；上述裁剪/时长是本项目固定 1.5 秒的适配，不是原版时间表。
					"active_0": {"animation": ["Spell1_0", "Spell1_C_anm"], "durations": [0.9493669, 0.5506331], "kind": "skill", "blend_in": 0.0, "sequence_blend": 0.0},
					"active_1": {"animation": ["Spell1_0", "Spell1_B", "Spell1_C_anm"], "durations": [0.7827002, 0.1666667, 0.5506331], "clip_ranges": [[0.0, 1.3740740], [0.0, 0.1666667], [0.0, 0.9666671]], "kind": "skill", "blend_in": 0.0, "sequence_blend": 0.0},
					"active_2": {"animation": ["Spell1_0", "Spell1_B", "Spell1_B", "Spell1_C_anm"], "durations": [0.6160335, 0.1666667, 0.1666667, 0.5506331], "clip_ranges": [[0.0, 1.0814813], [0.0, 0.1666667], [0.0, 0.1666667], [0.0, 0.9666671]], "kind": "skill", "blend_in": 0.0, "sequence_blend": 0.0},
					"active_3": {"animation": ["Spell1_0", "Spell1_B", "Spell1_B", "Spell1_B", "Spell1_C_anm"], "durations": [0.4493668, 0.1666667, 0.1666667, 0.1666667, 0.5506331], "clip_ranges": [[0.0, 0.7888886], [0.0, 0.1666667], [0.0, 0.1666667], [0.0, 0.1666667], [0.0, 0.9666671]], "kind": "skill", "blend_in": 0.0, "sequence_blend": 0.0},
				},
				"transitions": {
					"Attack1>idle": "Attack1_To_Idle",
					"Attack2>idle": "Attack2_To_Idle",
					"Attack3>idle": "Attack3_To_Idle",
					"Spell1_C_anm>move": "Spell1_C_to_Run_anm",
					"Spell1_C_anm>idle": "Spell1_C_to_Idle_anm",
				},
			},
			"skill_resource_full_color": Color(0.28, 0.72, 1.0, 0.96),
			"color": Color(0.95, 0.75, 0.85),
			"active_skills": [{
					"visual_action": "active_0", "resource_visual_actions": ["active_0", "active_1", "active_2", "active_3"],
				}],
		},
		# BEGIN IMPORTED AUDIO gwen
		"audio": {
			"events": {
				"active_0:hit_first_center": {"bus": "Combat", "pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r3.wav"], "volume_db": 3.0},
				"active_0:hit_last_center": {"pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_center_r.wav"], "volume_db": 0.0},
				"active_1:hit_first_center": {"bus": "Combat", "pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r3.wav"], "volume_db": 3.0},
				"active_1:hit_middle_center": {"bus": "Combat", "pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r3.wav"], "volume_db": 3.0},
				"active_1:hit_last_center": {"pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_center_r.wav"], "volume_db": 0.0},
				"active_2:hit_first_center": {"bus": "Combat", "pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r3.wav"], "volume_db": 3.0},
				"active_2:hit_middle_center": {"bus": "Combat", "pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r3.wav"], "volume_db": 3.0},
				"active_2:hit_last_center": {"pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_center_r.wav"], "volume_db": 0.0},
				"active_3:hit_first_center": {"bus": "Combat", "pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r3.wav"], "volume_db": 3.0},
				"active_3:hit_middle_center": {"bus": "Combat", "pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r3.wav"], "volume_db": 3.0},
				"active_3:hit_last_center": {"pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_center_r.wav"], "volume_db": 0.0},

				"resource_full": {"pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenq_max_stacks_buffactivate_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenq_max_stacks_buffactivate_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenq_max_stacks_buffactivate_r3.wav"], "volume_db": 0.0},


				"active_0:hit_first": {"pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r3.wav"], "volume_db": 0.0, "bus": "Combat"},
				"active_1:hit_first": {"pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r3.wav"], "volume_db": 0.0, "bus": "Combat"},
				"active_2:hit_first": {"pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r3.wav"], "volume_db": 0.0, "bus": "Combat"},
				"active_3:hit_first": {"pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqfirst_hit_r3.wav"], "volume_db": 0.0, "bus": "Combat"},
				"active_1:hit_middle": {"pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r3.wav"], "volume_db": 0.0, "bus": "Combat"},
				"active_2:hit_middle": {"pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r3.wav"], "volume_db": 0.0, "bus": "Combat"},
				"active_3:hit_middle": {"pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqmiddle_hit_r3.wav"], "volume_db": 0.0, "bus": "Combat"},
				"active_0:hit_last": {"pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_r3.wav"], "volume_db": 0.0, "bus": "Combat"},
				"active_1:hit_last": {"pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_r3.wav"], "volume_db": 0.0, "bus": "Combat"},
				"active_2:hit_last": {"pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_r3.wav"], "volume_db": 0.0, "bus": "Combat"},
				"active_3:hit_last": {"pool": ["res://assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_r1.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_r2.wav", "res://assets/audio/units/gwen/play_sfx_gwen_gwenqlast_hit_r3.wav"], "volume_db": 0.0, "bus": "Combat"},

				"death": {
					"pool": [
						"res://assets/audio/units/gwen/play_vo_gwen_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/gwen/play_vo_gwen_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/gwen/play_vo_gwen_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				},
				"active_0:sustain": {
					"pool": [
						"res://assets/audio/units/gwen/gwen_q_active_0.wav"
					],
					"volume_db": 0.0
				},
				"active_1:sustain": {
					"pool": [
						"res://assets/audio/units/gwen/gwen_q_active_1.wav"
					],
					"volume_db": 0.0
				},
				"active_2:sustain": {
					"pool": [
						"res://assets/audio/units/gwen/gwen_q_active_2.wav"
					],
					"volume_db": 0.0
				},
				"active_3:sustain": {
					"pool": [
						"res://assets/audio/units/gwen/gwen_q_active_3.wav"
					],
					"volume_db": 0.0
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_swipe_cast_r1.wav",
					"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_swipe_cast_r2.wav",
					"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_swipe_cast_r3.wav"
				],
				[
					"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_stab_cast_r1.wav",
					"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_stab_cast_r2.wav",
					"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_stab_cast_r3.wav"
				],
				[
					"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_swipe_cast_r1.wav",
					"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_swipe_cast_r2.wav",
					"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_swipe_cast_r3.wav"
				]
			],
			"attack_swing_volume_db": -3.0,
			"attack_hit": [
				"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_swipe_hit_r1.wav",
				"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_swipe_hit_r2.wav",
				"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_swipe_hit_r3.wav"
			],
			"attack_hit_volume_db": -5.0,
			"attack_hit_by_segment": [
				[
					"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_swipe_hit_r1.wav",
					"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_swipe_hit_r2.wav",
					"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_swipe_hit_r3.wav"
				],
				[
					"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_stab_hit_r1.wav",
					"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_stab_hit_r2.wav",
					"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_stab_hit_r3.wav"
				],
				[
					"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_swipe_hit_r1.wav",
					"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_swipe_hit_r2.wav",
					"res://assets/audio/units/gwen/play_sfx_gwen_gwenbasicattack_swipe_hit_r3.wav"
				]
			],
		},
		# END IMPORTED AUDIO gwen
		"card_art": {},
	}
