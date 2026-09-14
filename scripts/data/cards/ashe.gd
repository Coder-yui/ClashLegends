extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "艾希", "cost": 3, "type": "unit",
			"description": "远程射手，能攻击空中和地面目标，在安全距离持续输出。",
			"hp": 340, "damage": 58, "range": 170.0,
			# Attack1/2 原片 64/30 秒，源 0.30 秒离弦；完整压到基础 1 秒攻击周期。
			"speed": SPEED_SLIGHTLY_SLOW, "interval": 1.0, "first_hit": 0.14,
			"size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM,
			"mass": 3.0, "sight": 240.0,
			"projectile_speed": 480.0,
			"projectile_spawn_at_edge": true, "projectile_spawn_offset": 7.5, "projectile_collision_radius": 3.0,
			"is_air": false, "building_only": false, "can_attack_air": true,
			"active_skills": [{
					"name": "万箭齐发", "kind": "frontal", "shape": "fan",
					"cost": 2, "max_uses": 1, "cooldown": 10.0,
					"description": "使用 Spell2 朝前方扇形区域射出 8 根非穿透箭矢，每支命中首个敌人后消失；同次施法对每个目标最多造成 70 点伤害并减速 1 秒。",
					"length": 210.0, "arc_degrees": 72.0, "projectile_count": 8, "fan_inner_arc": true,
					"projectile_stop_on_hit": true,
					"damage": 70, "slow_duration": 1.0, "slow_multiplier": 0.55,
					"impact_delay": 0.16, "cast_duration": 1.0,
					"cast_locks": ["movement", "attack", "facing"],
					# 箭矢表现也等待源离弦点；保留既有约 0.2 秒的飞行表现。
					"projectile_launch_delay": 0.16, "projectile_flight_duration": 0.20,
				}],
		},
		"visual": { "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
			"projectile_visual": "arrow",
			# 只影响弹体绘制高度：弓位于地面原点上方约 30px。
			"projectile_visual_height": 30.0 * CHARACTER_SCALE_MULTIPLIER,
			"visual_scene_path": "res://assets/units/ashe/ashe_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Idle1", "idle": "Idle1", "move": "Run",
				"attack": ["Attack1", "Attack2"],
				"visual_actions": {
					# Spell2 原片 55/30 秒压至 1 秒；源 0.30 秒离弦，对应约 0.163636 秒。
					"active": {"animation": "Spell2", "kind": "skill", "durations": [1.0], "blend_in": 0.05, "blend_out": 0.10},
				},
				"death": "Death", "death_duration": 0.8,
			},
			"color": Color(0.50, 0.85, 0.95),
			"active_skills": [{ "visual_action": "active",
				}],
		},
		"card_art": {}, # 默认 assets/cards/<card_id>_loading.*
		"audio": {
			"attack_swing": [
				[
					"res://assets/audio/units/ashe/play_sfx_ashe_ashebasicattack_oncast_r1_d.wav",
					"res://assets/audio/units/ashe/play_sfx_ashe_ashebasicattack_oncast_r2_d.wav",
				],
				[
					"res://assets/audio/units/ashe/play_sfx_ashe_ashebasicattack_oncast_r1_d.wav",
					"res://assets/audio/units/ashe/play_sfx_ashe_ashebasicattack_oncast_r2_d.wav",
				],
			],
			"attack_hit": [
				"res://assets/audio/units/ashe/play_sfx_ashe_ashebasicattack_onhit_r1_d.wav",
				"res://assets/audio/units/ashe/play_sfx_ashe_ashebasicattack_onhit_r2_d.wav",
				"res://assets/audio/units/ashe/play_sfx_ashe_ashebasicattack_onhit_r3_d.wav",
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit_volume_db": 0.0,
			"events": {
				"attack_launch": {"pool": [
						"res://assets/audio/units/ashe/play_sfx_ashe_ashebasicattack_onmissilelaunch_r1_d.wav",
						"res://assets/audio/units/ashe/play_sfx_ashe_ashebasicattack_onmissilelaunch_r2_d.wav",
						"res://assets/audio/units/ashe/play_sfx_ashe_ashebasicattack_onmissilelaunch_r3_d.wav",
					], "volume_db": 0.0},
				"death": {"pool": [
						"res://assets/audio/units/ashe/play_vo_ashe_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/ashe/play_vo_ashe_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/ashe/play_vo_ashe_death3d_r3_zh_cn.wav",
					], "volume_db": 0.0, "bus": "Voice"},
				"active:start": {"pool": [
						"res://assets/audio/units/ashe/play_sfx_ashe_volley_oncast_r1_d.wav",
						"res://assets/audio/units/ashe/play_sfx_ashe_volley_oncast_r2_d.wav",
					], "volume_db": 0.0},
				"active:release": {"pool": [
						"res://assets/audio/units/ashe/play_sfx_ashe_volleyattackwithsound_onmissilelaunch.wav",
					], "volume_db": 0.0},
				"active:hit": {"pool": [
						"res://assets/audio/units/ashe/play_sfx_ashe_volleyattack_onhit_r1.wav",
						"res://assets/audio/units/ashe/play_sfx_ashe_volleyattack_onhit_r2.wav",
						"res://assets/audio/units/ashe/play_sfx_ashe_volleyattack_onhit_r3.wav",
					], "volume_db": 0.0},
			},
		},
	}
