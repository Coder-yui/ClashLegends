extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "艾尼维亚（冰晶凤凰）", "cost": 5, "type": "unit",
			"description": "远程空中单位，攻速较慢；施放冰雪风暴在身前制造持续伤害与减速区域。被动可化为蛋，3秒未被击破后满血复活。",
			"hp": 620, "damage": 78, "range": 190.0,
			"speed": SPEED_EXTREMELY_SLOW, "interval": 1.7, "first_hit": 0.68,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": 20.0, "custom_radius": true,
			"mass": 5.0, "sight": 270.0,
			"projectile_speed": 420.0, "projectile_visual": "ice_cone", "projectile_visual_height": 62.0,
			"color": Color(0.45, 0.82, 1.0),
			"is_air": true, "building_only": false, "can_attack_air": true,
			"death_replacement_id": "anivia_egg", "death_replacement_charges": 1, "death_replacement_visual_transition": "drop",
			"active_skills": [{
					"name": "冰雪风暴", "kind": "forward_area",
					"cost": 2, "max_uses": 1, "cooldown": 10.0,
					"description": "使用 Spell4 在身前创造冰雪风暴；落地造成伤害，区域持续 3 秒并周期性造成伤害与减速。施法期间锁定攻击、移动和朝向。",
					"forward_distance": 125.0, "radius": 86.0,
					"damage": 90, "stun_duration": 0.0, "slow_duration": 1.0, "slow_multiplier": 0.65,
					"zone_duration": 3.0, "zone_tick_interval": 1.0, "zone_damage": 42,
					"zone_slow_duration": 1.1, "zone_slow_multiplier": 0.60,
					"impact_delay": 0.72, "cast_duration": 1.17,
					"cast_locks": ["movement", "attack", "facing"], "visual_action": "frost_storm",
				}],
		},
		"visual": { "visual_radius": (RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING) * 1.15,
			"visual_scene_path": "res://assets/units/anivia/anivia_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Idle1", "idle": "Idle1", "move": "Run",
				"attack": ["Attack1", "Attack2"],
				# 原表仅明确这些死亡入口；其他切换保留通用混合。
				"clip_blends": {
					"Idle1>Death": 0.0, "Run>Death": 0.0,
					"Attack1>Death": 0.0, "Attack2>Death": 0.0, "Spell4>Death": 0.0,
				},
				"visual_actions": {
					"frost_storm": {"animation": "Spell4", "durations": [1.166667], "kind": "skill"},
				},
				"death": "Death", "death_duration": 2.4,
			},
		},
		# BEGIN IMPORTED AUDIO anivia
		"audio": {
			# 原片长 1.133333s → 攻击周期 1.7s：0.4s 挥翼映射到 0.6s，0.45s 出弹映射到 0.675s。
			"attack_swing_lead_time": 0.075,
			"events": {
				"frost_storm:zone_sustain": {"pool": ["res://assets/audio/units/anivia/play_sfx_anivia_glacialstorm_zone_sustain.wav"], "volume_db": 0.0},
				"frost_storm:zone_end": {"pool": ["res://assets/audio/units/anivia/play_sfx_anivia_glacialstorm_onbuffdeactivate.wav"], "volume_db": 0.0},
				"attack_launch": {
					"pool": [
						"res://assets/audio/units/anivia/play_sfx_anivia_aniviabasicattack_onmissilelaunch_r1_d.wav",
						"res://assets/audio/units/anivia/play_sfx_anivia_aniviabasicattack_onmissilelaunch_r2_d.wav",
						"res://assets/audio/units/anivia/play_sfx_anivia_aniviabasicattack_onmissilelaunch_r3_d.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"frost_storm:start": {
					"pool": [
						"res://assets/audio/units/anivia/play_sfx_anivia_glacialstorm_buffactivate_m_onset.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/anivia/play_vo_anivia_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/anivia/play_vo_anivia_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/anivia/play_vo_anivia_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/anivia/play_sfx_anivia_aniviabasicattack_oncast_d.wav"
				],
				[
					"res://assets/audio/units/anivia/play_sfx_anivia_aniviabasicattack_oncast_d.wav"
				]
			],
			"attack_swing_volume_db": -3.0,
			"attack_hit": [
				"res://assets/audio/units/anivia/play_sfx_anivia_aniviabasicattack_onhit_r1_d.wav",
				"res://assets/audio/units/anivia/play_sfx_anivia_aniviabasicattack_onhit_r2_d.wav",
				"res://assets/audio/units/anivia/play_sfx_anivia_aniviabasicattack_onhit_r3_d.wav"
			],
			"attack_hit_volume_db": -5.0
		},
		# END IMPORTED AUDIO anivia
		"card_art": {}, # 默认 assets/cards/<card_id>_loading.*
	}
