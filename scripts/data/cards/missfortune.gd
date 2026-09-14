extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "赏金猎人", "cost": 3, "type": "unit",
			"description": "远程双枪射手，对每个敌方目标的首次攻击造成1.5倍伤害；主动技大步流星可短时提升移速与攻速。",
			# 远程双枪：Attack1/2 举枪射击的出手点在动作前段（约 12%），first_hit 按此调校。
			"hp": 380, "damage": 62, "range": 165.0,
			"speed": SPEED_MEDIUM, "interval": 0.95, "first_hit": 0.12,
			# 先声夺人：对每个敌方目标的首次普通攻击造成 1.5 倍伤害。
			"first_strike_damage_multiplier": 1.5,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM,
			"mass": 3.0, "sight": 230.0,
			"projectile_speed": 500.0,
			"projectile_spawn_at_edge": false, "projectile_spawn_offset": 0.0, "projectile_collision_radius": 4.0,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{
					"name": "大步流星", "kind": "buff", "cost": 0, "max_uses": 1, "cooldown": 5.0,
					"duration": 3.0, "speed_multiplier": 1.5, "damage_multiplier": 1.0, "attack_speed_multiplier": 1.3,
				}],
		},
		"visual": { "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"visual_scene_path": "res://assets/units/missfortune/missfortune_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Respawn", "idle": "Idle1_Base", "move": "Run",
				# 大步流星生效期间（移速倍率 > 1）移动表现切换为 Run2，由通用 haste_move 机制驱动。
				"haste_move": "Run2",
				"attack": ["Attack1", "Attack2"],
				# 原图 Run_Base / Run2 → Idle1_Base 均经过 Idle_In；导入资源 Run 对应 Run_Base。
				"transitions": {"Run>idle": "Idle_In", "Run2>idle": "Idle_In"},
				"death": "Death", "death_duration": 0.8,
			}, "projectile_visual": "orb",
			# 双枪枪口约在身高中段偏上；高度只影响弹体绘制起点，不参与权威判定。
			"projectile_visual_height": 52.0,
			"color": Color(0.80, 0.35, 0.60),
		},
		"card_art": {}, # 默认 assets/cards/<card_id>_loading.*
		"audio": {
			"attack_swing": [
				[
					"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_oncast_r1_d.wav",
					"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_oncast_r2_d.wav",
					"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_oncast_r3_d.wav",
				],
				[
					"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack2_oncast_r1.wav",
					"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack2_oncast_r2.wav",
					"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack2_oncast_r3.wav",
				],
			],
			# BasicAttack2_OnHit 与 BasicAttack_OnHit 使用同一套 Switch/随机素材；项目命中入口按普攻共享池消费。
			"attack_hit": [
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_1153642577_r1_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_1153642577_r2_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_1153642577_r3_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_1153642577_r4_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_1153642577_r5_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_1153642577_r6_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_1216965916_r1_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_1216965916_r2_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_1216965916_r3_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_1216965916_r4_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_1216965916_r5_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_1216965916_r6_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_2058049674_r1_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_2058049674_r2_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_2058049674_r3_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_2058049674_r4_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_2058049674_r5_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_2058049674_r6_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_2473969246_r1_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_2473969246_r2_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_2473969246_r3_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_2473969246_r4_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_2473969246_r5_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onhit_1559186049_2473969246_r6_d.wav",
			],
			# 赏金猎人被动“先声夺人”：首次对每个目标的真实命中替换普通命中音。
			"first_strike_hit": [
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunepassiveattack_onhit_1559186049_1153642577_r1_d.wav",
				"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunepassiveattack_onhit_1559186049_1153642577_r2_d.wav",
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit_volume_db": 0.0,
			"events": {
				# 用户指定：部署动作使用赏金猎人 Move2DStandard 短语音。
				"deploy:voice": {"pool": ["res://assets/audio/units/missfortune/play_vo_missfortune_move2dstandard_r1_zh_cn.wav"], "volume_db": 0.0, "bus": "Voice"},
				"attack_missile_cast": {"pool": ["res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onmissilecast_r1_d.wav", "res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onmissilecast_r2_d.wav", "res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onmissilecast_r3_d.wav"], "volume_db": 0.0, "bus": "Combat"},

				"attack_launch": {"pool": [
						"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onmissilelaunch_r1_d.wav",
						"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onmissilelaunch_r2_d.wav",
						"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunebasicattack_onmissilelaunch_r3_d.wav",
					], "volume_db": 0.0},
				# 首击在攻击起手、弹体准备和离弦阶段使用 LOL PassiveAttack 音效链；
				# 这些事件只由权威攻击变体派发，不改变伤害或弹体时序。
				"first_strike:cast": {"pool": [
						"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunepassiveattack_oncast_r1_d.wav",
						"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunepassiveattack_oncast_r2_d.wav",
					], "volume_db": 0.0},
				"first_strike:missile_cast": {"pool": [
						"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunepassiveattack_onmissilecast_r1_d.wav",
						"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunepassiveattack_onmissilecast_r2_d.wav",
					], "volume_db": 0.0},
				"first_strike:missile_launch": {"pool": [
						"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunepassiveattack_onmissilelaunch_r1_d.wav",
						"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunepassiveattack_onmissilelaunch_r2_d.wav",
					], "volume_db": 0.0},
				"first_strike:hit_location": {"pool": [
						"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortunepassiveattack_onhitlocation_d.wav",
					], "volume_db": 0.0},
				# 大步流星按 LOL W 的 ViciousStrikes 事件接入：施放、持续层、结束分别独立播放。
				"active_buff:start": {"pool": [
						"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortuneviciousstrikes_oncast_r1.wav",
						"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortuneviciousstrikes_oncast_r2.wav",
					], "volume_db": 0.0},
				"active_buff:sustain": {"pool": [
						"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortuneviciousstrikes_onbuffactivate_r1.wav",
						"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortuneviciousstrikes_onbuffactivate_r2.wav",
					], "volume_db": 0.0},
				"active_buff:end": {"pool": [
						"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortuneviciousstrikes_onbuffdeactivate_r1.wav",
						"res://assets/audio/units/missfortune/play_sfx_missfortune_missfortuneviciousstrikes_onbuffdeactivate_r2.wav",
					], "volume_db": 0.0},
				"death": {"pool": [
						"res://assets/audio/units/missfortune/play_vo_missfortune_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/missfortune/play_vo_missfortune_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/missfortune/play_vo_missfortune_death3d_r3_zh_cn.wav",
						"res://assets/audio/units/missfortune/play_vo_missfortune_death3d_r4_zh_cn.wav",
					], "volume_db": 0.0, "bus": "Voice"},
			},
		},
	}
