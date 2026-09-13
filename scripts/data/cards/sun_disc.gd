extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "太阳圆盘", "cost": 4, "type": "building",
			"description": "建立在防御塔废墟之上的远程建筑，可攻击空中与地面目标。主动为攻击范围内的友军提供护盾；建于塔墟时不再随时间失去生命。",
			# 普通地面部署时使用 40 秒建筑寿命；中心落在已毁防御塔九格内时，
			# tower_ruin_foundation 会保留完整生命且取消寿命倒计时。
			"hp": 1200, "damage": 105, "range": 220.0,
			"speed": 0.0, "interval": 1.4, "first_hit": 0.5,
			"radius": 40.0,
			"footprint_tiles": Vector2i(3, 3),
			"lifespan": 40.0, "lifespan_hp_decay": true,
			"tower_ruin_foundation": true,
			"projectile_speed": 440.0, "projectile_visual": "orb",
			# 圆盘中心约在权威地面点上方 154px；不沿目标方向偏移，保证双方镜像一致。
			"projectile_visual_height": 154.0, "projectile_visual_forward_offset": 0.0,
			"projectile_visual_scale": 1.65,
			"projectile_colors": [Color(1.0, 0.78, 0.18), Color(1.0, 0.52, 0.10)],
			"color": Color(0.96, 0.72, 0.16),
			"is_air": false, "building_only": false, "can_attack_air": true,
			"is_building": true, "show_team_ring": false,
			"active_skills": [{
					"name": "日耀庇护", "kind": "area_shield",
					"cost": 1, "max_uses": 1, "cooldown": 0.0,
					"radius": 220.0, "shield": 180, "shield_duration": 6.0,
					"description": "立即为太阳圆盘攻击范围内的所有存活友军、友方建筑、防御塔与水晶提供 180 点护盾，持续 6 秒。每个圆盘只能使用 1 次。",
				}],
		},
		"visual": { "visual_radius": 60.0,
			"visual_scene_paths": [
				"res://assets/units/sun_disc/sun_disc_blue_view.tscn",
				"res://assets/units/sun_disc/sun_disc_red_view.tscn",
			],
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				"deploy": "Spawn",
				"idle": "Idle1_Base",
				"idle_cycle": ["Idle1_Base", "Idle1_Base", "Idle1_Base", "Idle1_Base", "Idle2_Base", "Idle1_Base", "Idle1_Base", "Idle2_Base", "Idle1_Base"],
				"clip_blends": {"Spawn>Idle1_Base": 0.0, "Spawn>Attack1_BASE": 0.0, "Idle1_Base>Idle2_Base": 0.0, "Idle2_Base>Idle1_Base": 0.0, "Idle1_Base>Attack1_BASE": 0.0, "Idle1_Base>Attack2_BASE": 0.0, "Attack1_BASE>Idle1_Base": 0.0, "Attack2_BASE>Idle1_Base": 0.0, "Attack1_BASE>Attack2_BASE": 0.0, "Attack2_BASE>Attack1_BASE": 0.0},
				"attack": ["Attack1_BASE", "Attack2_BASE"],
				"death": "Death", "death_duration": 0.8, "death_clip_end": 2.0,
			},
		},
		# BEGIN EVENT AUDIO sun_disc
		"audio": {
			# BEGIN DISC ATTACK AUDIO
			"attack_swing": [["res://assets/audio/units/sun_disc/play_sfx_env_map11_chaosturretchampionbasicattack_cast_r1.wav", "res://assets/audio/units/sun_disc/play_sfx_env_map11_chaosturretchampionbasicattack_cast_r2.wav", "res://assets/audio/units/sun_disc/play_sfx_env_map11_chaosturretchampionbasicattack_cast_r3.wav", "res://assets/audio/units/sun_disc/play_sfx_env_map11_chaosturretchampionbasicattack_cast_r4.wav"], ["res://assets/audio/units/sun_disc/play_sfx_env_map11_chaosturretchampionbasicattack_cast_r1.wav", "res://assets/audio/units/sun_disc/play_sfx_env_map11_chaosturretchampionbasicattack_cast_r2.wav", "res://assets/audio/units/sun_disc/play_sfx_env_map11_chaosturretchampionbasicattack_cast_r3.wav", "res://assets/audio/units/sun_disc/play_sfx_env_map11_chaosturretchampionbasicattack_cast_r4.wav"]],
			"attack_hit": ["res://assets/audio/units/sun_disc/play_sfx_env_turretbasicattack_hit_r1.wav", "res://assets/audio/units/sun_disc/play_sfx_env_turretbasicattack_hit_r2.wav", "res://assets/audio/units/sun_disc/play_sfx_env_turretbasicattack_hit_r3.wav", "res://assets/audio/units/sun_disc/play_sfx_env_turretbasicattack_hit_r4.wav"],
			"attack_swing_volume_db": -6.0,
			"attack_hit_volume_db": -6.0,
			# END DISC ATTACK AUDIO
			"events": {
				# BEGIN BUILDING AUDIO sun_disc
				"deploy:start": {"pool": ["res://assets/audio/units/sun_disc/play_sfx_azir_azirobelisksound_onbuffcast_r1.wav"], "volume_db": 0.0, "bus": "Combat"},
				"death": {"pool": ["res://assets/audio/units/sun_disc/play_sfx_azir_azirobelisksound_onbuffdeactivate_r1.wav", "res://assets/audio/units/sun_disc/play_sfx_azir_azirobelisksound_onbuffdeactivate_r2.wav"], "volume_db": 0.0, "bus": "Combat"},
				"attack_launch": {"pool": ["res://assets/audio/units/sun_disc/play_sfx_env_turretbasicattack_missilelaunch_r1.wav", "res://assets/audio/units/sun_disc/play_sfx_env_turretbasicattack_missilelaunch_r2.wav", "res://assets/audio/units/sun_disc/play_sfx_env_turretbasicattack_missilelaunch_r3.wav"], "volume_db": -6.0, "bus": "Combat"},
				# END BUILDING AUDIO sun_disc
				"shield:cast": {
					"pool": [
						"res://assets/audio/units/sun_disc/play_sfx_3190active_oncast_r1.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			}
		},
		# END EVENT AUDIO sun_disc
		"card_art": {}, # 默认 assets/cards/<card_id>_loading.*
	}
