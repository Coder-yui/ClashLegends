extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "龙王", "cost": 4, "type": "unit",
			"description": "空中持续输出单位，吐息能够同时压制目标及其周围敌人。",
			# 空中远程单位：持续喷吐龙息（DPS模式）
			"hp": 580, "damage": 55, "range": 130.0,
			"speed": SPEED_EXTREMELY_SLOW, "interval": 0.0, "first_hit": 0.0,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": RADIUS_SLIGHTLY_LARGE,
			"mass": 5.0, "sight": 250.0,
			"splash_radius": 34.0,
			"skill_resource_max": 5.0, "skill_resource_kill_gain": 1.0,
			"is_air": true, "building_only": false, "can_attack_air": true,
			"is_continuous_attack": true,  # 持续伤害：固定Tick累计 damage*dt，按目标保留余量
			"active_skills": [{
					"name": "星落/天瀑", "kind": "forward_area",
					"cost": 2, "max_uses": 1, "cooldown": 10.0,
					"description": "击杀敌方单位充能，最多 5 层。向前方圆形区域降下星辰并眩晕；满层升级为伤害和眩晕提高 50% 的天瀑，且只有天瀑落地后会产生扩散至全场的冲击波。",
					"uses_skill_resource": true,
					"forward_distance": 175.0, "radius": 92.0,
					"damage": 120, "stun_duration": 1.2,
					"resource_full_damage_multiplier": 1.5, "resource_full_stun_multiplier": 1.5,
					"shockwave_damage": 55, "shockwave_duration": 2.8, "shockwave_end_radius": 1500.0,
					"shockwave_slow_duration": 2.0, "shockwave_slow_multiplier": 0.60, "shockwave_full_only": true,
					"impact_delay": 1.15, "cast_duration": 1.93,
					"full_resource_impact_delay": 1.12, "full_resource_cast_duration": 1.90,
					"cast_locks": ["movement", "attack", "facing"],
				}],
		},
		"visual": { "visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/aurelionsol/aurelionsol_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				# 只取 Respawn 前半段翻滚；后半段由普通状态机接管，不做龙王专用保护。
				"deploy": "Respawn", "deploy_clip_ratio": 0.5, "idle": "Idle1_Base",
				# RunIn 是部署、待机或无专用转跑素材的普攻进入移动时共用的通用衔接。
				"move": "Run1B", "move_enter": "RunIn",
				"move_cycle": ["Run1B", "Run1C", "Run1D", "Run1A"],
				# 移动后首次攻击用 newtst；原地击败目标并直接换目标时用 new_looptoin。
				"attack_enter": "AurelionSol_Spell1_newtst_anm",
				"attack_retarget_enter": ["AurelionSol_Spell1_new_looptoin_anm", "AurelionSol_Spell1_newtst_anm"],
				"attack_loop": "AurelionSol_Spell1_loop_anm",
				# 吐息后进入移动：Spell1_2Run 后摇 → Run1B→C→D→A。
				"transitions": {
					"attack>move": "Spell1_2Run",
					"AurelionSol_Spell1_newtst_anm>idle": "Spell1_2Idle",
					"AurelionSol_Spell1_loop_anm>idle": "Spell1_2Idle",
				},
				# 只覆盖原图中已核验的实际路径，不替换无明确条目的全局回退。
				"clip_blends": {
					"RunIn>Run1B": 0.0,
					"Run1B>Run1C": 0.0, "Run1C>Run1D": 0.0,
					"Run1D>Run1A": 0.0, "Run1A>Run1B": 0.0,
					"Spell1_2Run>Run1B": 0.6,
					"Idle1_Base>AurelionSol_Spell1_newtst_anm": 0.0,
					"Respawn>AurelionSol_Spell1_newtst_anm": 0.0,
					"RunIn>AurelionSol_Spell1_newtst_anm": 0.0,
					"Run1A>AurelionSol_Spell1_newtst_anm": 0.0,
					"Run1B>AurelionSol_Spell1_newtst_anm": 0.0,
					"Run1C>AurelionSol_Spell1_newtst_anm": 0.0,
					"Run1D>AurelionSol_Spell1_newtst_anm": 0.0,
					"Spell1_2Run>AurelionSol_Spell1_newtst_anm": 0.0,
					"Spell1_2Idle>AurelionSol_Spell1_newtst_anm": 0.0,
					"Spell4>AurelionSol_Spell1_newtst_anm": 0.0,
					"AurelionSol_Spell4_base_anm>AurelionSol_Spell1_newtst_anm": 0.0,
				},
				"visual_actions": {
					"active": {"animation": "Spell4", "durations": [1.9333328], "kind": "skill", "blend_in": 0.25},
					"active_strong": {"animation": "AurelionSol_Spell4_base_anm", "durations": [1.8999995], "kind": "skill", "blend_in": 0.25},
				},
				"death": "Death", "death_duration": 0.8,
			},
			"skill_resource_full_color": Color(0.58, 0.42, 1.0, 0.96),
			"color": Color(0.95, 0.75, 0.25),
			# 正式吐息素材接入前，用嘴部窄、目标端宽的半透明浅蓝梯形光柱占位。
			# 这些字段只控制 2D 表现，不参与持续伤害、范围或命中判定。
			"continuous_beam_color": Color(0.42, 0.84, 1.0, 0.70),
			"continuous_beam_start_width": 4.0,
			"continuous_beam_end_width": 14.0,
			"continuous_beam_origin_height": 78.0,
			"continuous_beam_forward_offset": 20.0,
			"active_skills": [{
					"visual_action": "active", "full_resource_visual_action": "active_strong",
				}],
		},
		# BEGIN IMPORTED AUDIO aurelionsol
		"audio": {
			"events": {
				"continuous_attack:release": {"pool": ["res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolq_missilecast_r1.wav", "res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolq_missilecast_r2.wav", "res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolq_missilecast_r3.wav"], "volume_db": 0.0, "bus": "Combat"},
				"active:start": {"pool": ["res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolrmissile_missilelaunch.wav"], "volume_db": 0.0, "bus": "Combat"},
				"active:impact": {"pool": ["res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolrmissile_hit_r1.wav", "res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolrmissile_hit_r2.wav", "res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolrmissile_hit_r3.wav"], "volume_db": 0.0, "bus": "Combat"},
				"active_strong:start": {"pool": ["res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolr2missile_missilelaunch_super.wav"], "volume_db": 0.0, "bus": "Combat"},
				"active_strong:impact": {"pool": ["res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolr2missile_hit_super_s.wav"], "volume_db": 0.0, "bus": "Combat"},
				"active_strong:wave_hit": {"pool": ["res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolr_hit_shockwave_r1.wav", "res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolr_hit_shockwave_r2.wav", "res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolr_hit_shockwave_r3.wav"], "volume_db": 0.0, "bus": "Combat"},

				"continuous_attack:start": {
					"pool": [
						"res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolq_oncast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"continuous_attack:sustain": {
					"pool": [
						"res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolq_missilelaunch.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"continuous_attack:end": {
					"pool": [
						"res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolq_buffdeactivate_r1.wav",
						"res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolq_buffdeactivate_r2.wav",
						"res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolq_buffdeactivate_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"active:sustain": {
					"pool": [
						"res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolr_oncast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"active_strong:sustain": {
					"pool": [
						"res://assets/audio/units/aurelionsol/play_sfx_aurelionsol_aurelionsolr2_oncast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/aurelionsol/play_vo_aurelionsol_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/aurelionsol/play_vo_aurelionsol_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/aurelionsol/play_vo_aurelionsol_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				}
			},
		},
		# END IMPORTED AUDIO aurelionsol
		"card_art": {},
	}
