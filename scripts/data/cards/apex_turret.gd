extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "H-28Q尖端炮台", "cost": 5, "type": "building",
			"description": "强力的远程防守建筑。炮弹只攻击地面目标并造成小范围伤害，可额外发射两次穿透激光弹。",
			# 3x3 格部署占地，权威碰撞半径仍为 40；无外部伤害时，1450 生命会在 45 秒寿命内匀速衰减到 0。
			"hp": 1450, "damage": 130, "range": 220.0,
			"speed": 0.0, "interval": 1.5, "first_hit": 0.55,
			"radius": 40.0,
			"footprint_tiles": Vector2i(3, 3),
			"lifespan": 45.0, "lifespan_hp_decay": true,
			"projectile_speed": 420.0, "projectile_visual": "orb",
			"projectile_visual_height": 46.75, "projectile_visual_forward_offset": 46.75,
			"projectile_visual_scale": 2.25, "projectile_impact_visual": "splash_wave",
			"projectile_colors": [Color(1.0, 0.34, 0.08), Color(1.0, 0.22, 0.055)],
			"splash_radius": 32.0,
			"color": Color(0.20, 0.72, 0.86),
			"is_air": false, "building_only": false, "can_attack_air": false,
			"is_building": true, "show_team_ring": false,
			"active_skills": [{
					"name": "海克斯穿透激光", "kind": "frontal", "shape": "trapezoid",
					"cost": 1, "max_uses": 2, "cooldown": 2.0,
					"description": "沿当前朝向发射一枚可穿透的激光弹，对 270（4.5格）长路径上的所有地面敌人造成 240 点伤害。",
					"length": 270.0, "near_width": 28.8, "far_width": 28.8,
					"damage": 240, "ground_only": true,
					# 激光在动作 0.45 秒时离开炮口，0.30 秒飞完路径；途中逐目标穿透结算。
					"projectile_piercing": true, "projectile_count": 1, "projectile_visual": "electromagnetic_wave", "projectile_visual_width": 28.8,
					"projectile_visual_height": 46.75, "projectile_visual_forward_offset": 46.75,
					"projectile_launch_delay": 0.45, "projectile_flight_duration": 0.30,
					"impact_delay": 0.45, "cast_duration": 1.67,
					"cast_locks": ["movement", "attack", "facing"], "visual_action": "laser",
				}],
		},
		"visual": { "visual_radius": 55.0,
			"visual_scene_path": "res://assets/units/apex_turret/apex_turret_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				# 当前实际片段对的原表 TimeBlendData；缺失边仍用项目通用混合。
				"clip_blends": {
					"Spawn>Death": 0.0,
					"Attack1>Death": 0.0,
					"Idle1>Death": 0.0,
				},
				"deploy": "Spawn", "idle": "Idle1", "attack": "Attack1",
				"visual_actions": {
					"laser": {"animation": "Attack_Beam", "durations": [1.6666664], "kind": "skill"},
				},
				"death": "Death", "death_duration": 0.8,
			},
		},
		# BEGIN IMPORTED AUDIO apex_turret
		"audio": {
			"events": {
				"death": {"pool": ["res://assets/audio/units/apex_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffdeactivate_r1.wav", "res://assets/audio/units/apex_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffdeactivate_r2.wav", "res://assets/audio/units/apex_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffdeactivate_r3.wav"], "volume_db": 0.0, "bus": "Combat"},
				"deploy:start": {"pool": ["res://assets/audio/units/apex_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffactivate_r1.wav", "res://assets/audio/units/apex_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffactivate_r2.wav", "res://assets/audio/units/apex_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffactivate_r3.wav"], "volume_db": 0.0, "bus": "Combat"},
				"idle:sustain": {"pool": ["res://assets/audio/units/apex_turret/play_sfx_heimertblue_heimerdingerrqengineaudio_onbuffactivate.wav"], "volume_db": 0.0},
				"laser:release": {"pool": ["res://assets/audio/units/apex_turret/play_sfx_heimertblue_heimerdingerturretbigenergyblast_onmissilelaunch.wav"], "volume_db": 0.0, "bus": "Combat"},

				"attack_launch": {
					"pool": [
						"res://assets/audio/units/apex_turret/play_sfx_heimertblue_heimertbluebasicattack_onmissilelaunch_r1.wav",
						"res://assets/audio/units/apex_turret/play_sfx_heimertblue_heimertbluebasicattack_onmissilelaunch_r2.wav",
						"res://assets/audio/units/apex_turret/play_sfx_heimertblue_heimertbluebasicattack_onmissilelaunch_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"laser:sustain": {
					"pool": [
						"res://assets/audio/units/apex_turret/play_sfx_heimertblue_heimerdingerturretbigenergyblast_oncast.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"laser:hit": {
					"pool": [
						"res://assets/audio/units/apex_turret/play_sfx_heimertblue_heimerdingerturretbigenergyblast_onhit.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
			"attack_swing": [
				[
					"res://assets/audio/units/apex_turret/play_sfx_heimertblue_heimertbluebasicattack_oncast_r1.wav",
					"res://assets/audio/units/apex_turret/play_sfx_heimertblue_heimertbluebasicattack_oncast_r2.wav",
					"res://assets/audio/units/apex_turret/play_sfx_heimertblue_heimertbluebasicattack_oncast_r3.wav"
				]
			],
			"attack_swing_volume_db": -3.0,
			"attack_hit": [
				"res://assets/audio/units/apex_turret/play_sfx_heimertblue_heimertbluebasicattack_onhit_r1.wav",
				"res://assets/audio/units/apex_turret/play_sfx_heimertblue_heimertbluebasicattack_onhit_r2.wav",
				"res://assets/audio/units/apex_turret/play_sfx_heimertblue_heimertbluebasicattack_onhit_r3.wav"
			],
			"attack_hit_volume_db": -5.0
		},
		# END IMPORTED AUDIO apex_turret
		"card_art": {}, # 默认 assets/cards/<card_id>_loading.*
	}
