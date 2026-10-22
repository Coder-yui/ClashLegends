extends "res://scripts/data/card_schema.gd"

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "战争之影", "cost": 4, "type": "unit",
			"description": "旋斩攻击四周地面敌人。连续自主移动3格后加速，下一击可从2格内突进到目标面前并眩晕1.5秒；蓄势时受阻会重置；突进可穿障，硬控会打断。",
			"hp": 850, "damage": 80, "range": 32.0, "attack_self_radius": 85.0,
			"speed": SPEED_FAST, "interval": 1.2, "first_hit": 0.15,
			"size_tier": SIZE_SLIGHTLY_LARGE, "radius": RADIUS_SLIGHTLY_LARGE,
			"mass": 6.0, "sight": 240.0,
			"is_air": false, "building_only": false, "can_attack_air": false,
			"charge_distance": 120.0, "charge_speed_multiplier": 1.5,
			"charge_attack_range": 80.0, "charge_dash_speed": 420.0, "charge_stun_duration": 1.5,
			"active_skills": [{
				"name": "恐惧之灵", "kind": "continuous_area", "cost": 2, "max_uses": 1, "cooldown": 15.0,
				"description": "开启4秒领域，每0.5秒对周围地面敌人造成20伤害。领域伤害和普通攻击按实际生命伤害的30%治疗自身；期间可以移动和攻击。",
				"radius": 120.0, "damage": 20, "duration": 4.0, "tick_interval": 0.5,
				"heal_ratio": 0.3, "ground_only": true, "impact_delay": 0.0, "cast_duration": 4.0, "cast_locks": [],
			}],
		},
		"visual": {
			"visual_radius": RADIUS_SLIGHTLY_LARGE + VISUAL_RADIUS_PADDING,
			"color": Color(0.16, 0.75, 0.67), "visual_forward_yaw": 0.0,
			"visual_scene_path": "res://assets/units/hecarim/hecarim_view.tscn",
			"visual_animations": {
				"idle": "Hecarim_idle1_anm", "move": "Run", "charge_move": "Spell3run", "attack": ["Hecarim_Spell1_anm"],
				"death": "Death", "death_duration": 0.8,
				"visual_actions": {
					"charge_strike": {"animation": "Spell3", "kind": "skill", "durations": [1.0]},
					"active:cast": {"animation": "Hecarim_Spell2_anm", "kind": "skill", "priority": 10, "durations": [1.566667]},
				},
			},
			"attack_hit_visual": "hecarim_q",
			"resource_dependencies": {"effects": [{"provider": "res://assets/effects/hecarim/player.gd", "variant": "qcas"}, {"provider": "res://assets/effects/hecarim/player.gd", "variant": "qbuf"}, {"provider": "res://assets/effects/hecarim/player.gd", "variant": "qtar"}]},
			"visual_active_buff_scene": "res://assets/effects/hecarim/buff.tscn",
			"active_skills": [{"resource_dependencies": {"fields": ["visual_active_buff_scene"], "effects": [{"provider": "res://assets/effects/hecarim/player.gd", "variant": "aoe"}, {"provider": "res://assets/effects/hecarim/player.gd", "variant": "cas"}, {"provider": "res://assets/effects/hecarim/player.gd", "variant": "eff"}]}, "icon_path": "res://assets/skills/hecarim_w.png"}],
		},
		# BEGIN IMPORTED AUDIO hecarim
		"audio": {
			"events": {
				"charge:start": {
					"pool": [
						"res://assets/audio/units/hecarim/play_sfx_hecarim_hecarimrampattack_oncast_r1.wav",
						"res://assets/audio/units/hecarim/play_sfx_hecarim_hecarimrampattack_oncast_r2.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"charge:hit": {
					"pool": [
						"res://assets/audio/units/hecarim/play_sfx_hecarim_hecarimrampattack_onhit_r1.wav",
						"res://assets/audio/units/hecarim/play_sfx_hecarim_hecarimrampattack_onhit_r2.wav",
						"res://assets/audio/units/hecarim/play_sfx_hecarim_hecarimrampattack_onhit_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/hecarim/play_sfx_hecarim_death3d_cast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death:voice": {
					"pool": [
						"res://assets/audio/units/hecarim/play_vo_hecarim_death3d_r1_zh_cn.wav",
						"res://assets/audio/units/hecarim/play_vo_hecarim_death3d_r2_zh_cn.wav",
						"res://assets/audio/units/hecarim/play_vo_hecarim_death3d_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				},
				"deploy:voice": {
					"pool": [
						"res://assets/audio/units/hecarim/play_vo_hecarim_move2dstandard_r1_zh_cn.wav",
						"res://assets/audio/units/hecarim/play_vo_hecarim_move2dstandard_r2_zh_cn.wav",
						"res://assets/audio/units/hecarim/play_vo_hecarim_move2dstandard_r3_zh_cn.wav"
					],
					"volume_db": 0.0,
					"bus": "Voice"
				},
				"active:cast": {
					"pool": [
						"res://assets/audio/units/hecarim/play_sfx_hecarim_hecarimw_oncast_r1.wav",
						"res://assets/audio/units/hecarim/play_sfx_hecarim_hecarimw_oncast_r2.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"active_buff:sustain": {
					"pool": [
						"res://assets/audio/units/hecarim/play_sfx_hecarim_hecarimw_onbuffactivate_r1.wav",
						"res://assets/audio/units/hecarim/play_sfx_hecarim_hecarimw_onbuffactivate_r2.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"active_buff:end": {
					"pool": [
						"res://assets/audio/units/hecarim/play_sfx_hecarim_hecarimw_onbuffdeactivate_r1.wav",
						"res://assets/audio/units/hecarim/play_sfx_hecarim_hecarimw_onbuffdeactivate_r2.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/hecarim/play_sfx_hecarim_hecarimrapidslash_oncast_r1.wav",
					"res://assets/audio/units/hecarim/play_sfx_hecarim_hecarimrapidslash_oncast_r2.wav",
					"res://assets/audio/units/hecarim/play_sfx_hecarim_hecarimrapidslash_oncast_r3.wav"
				]
			],
			"attack_swing_volume_db": 0.0,
			"attack_hit": [
				"res://assets/audio/units/hecarim/play_sfx_hecarim_hecarimrapidslash_hit_r1.wav",
				"res://assets/audio/units/hecarim/play_sfx_hecarim_hecarimrapidslash_hit_r2.wav",
				"res://assets/audio/units/hecarim/play_sfx_hecarim_hecarimrapidslash_hit_r3.wav"
			],
			"attack_hit_volume_db": 0.0
		},
		# END IMPORTED AUDIO hecarim
		"card_art": {"path": "res://assets/cards/hecarim_loading.png"},
	}
