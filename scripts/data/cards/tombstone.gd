extends "res://scripts/data/card_schema.gd"
## 定义域在注册时编译为稳定字段；资源不参与权威规则。

static func definition() -> Dictionary:
	return {
		"gameplay": {
			"name": "墓碑", "cost": 3, "type": "building",
			"description": "持续召唤小鬼的建筑，适合建立防守屏障并拖延敌军。",
			# 建筑卡：3x3 格部署占地；权威碰撞仍使用 radius=40 的圆柱，不可移动。
			# 完成部署立即生成两个小鬼，之后每 5 秒在地图中心线对应的一侧生成两个。
			"hp": 400, "damage": 0, "range": 0.0,
			"speed": 0.0, "interval": 1.0, "radius": 40.0,
			"footprint_tiles": Vector2i(3, 3),
			"is_air": false, "building_only": false, "can_attack_air": false,
			"is_building": true,
			"lifespan": 10.0,       # 存活时间（秒），到时自动消失
			"spawn_id": "imp",
			"spawn_interval": 5.0,  # 每隔多久生成一批小鬼
			"spawn_count": 2,
			"spawn_side": "map_side",
			"death_spawn_id": "imp",
			"death_spawn_count": 2,
			"active_skills": [{"name": "亡者集结", "kind": "summon", "cost": 1, "max_uses": 1, "cooldown": 10.0, "spawn_id": "imp", "spawn_count": 4,
				}],
		},
		"visual": {
			"visual_radius": 50.0,
			"visual_scene_path": "res://assets/units/tombstone/tombstone_view.tscn",
			"visual_forward_yaw": 0.0,
			"visual_animations": {
				# 当前实际片段对的原表 TimeBlendData；缺失边仍用项目通用混合。
				"clip_blends": {
					"Spawn>Idle1": 0.0,
				},
				"deploy": "Spawn", "idle": "Idle1", "death": "Death", "death_duration": 0.8,
			},
			"color": Color(0.45, 0.40, 0.35),
			"show_team_ring": false,
		},
		# BEGIN EVENT AUDIO tombstone
		"audio": {
			"events": {
				"active:cast": {"pool": ["res://assets/audio/units/tombstone/play_sfx_yorick_yorickw_oncast_r1.wav"], "volume_db": 0.0, "bus": "Combat"},
				# BEGIN BUILDING AUDIO tombstone
				"idle:sustain": {"pool": ["res://assets/audio/units/tombstone/play_sfx_yorick_yorickwwalllife_onbuffactivate_r1.wav"], "volume_db": 0.0, "bus": "Combat"},
				# END BUILDING AUDIO tombstone
				"deploy:start": {
					"pool": [
						"res://assets/audio/units/tombstone/play_sfx_yorick_yorickw_onhitlocation_r1.wav",
						"res://assets/audio/units/tombstone/play_sfx_yorick_yorickw_onhitlocation_r2.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/units/tombstone/play_sfx_yorick_yorickw_death_r1.wav",
						"res://assets/audio/units/tombstone/play_sfx_yorick_yorickw_death_r2.wav",
						"res://assets/audio/units/tombstone/play_sfx_yorick_yorickw_death_r3.wav",
						"res://assets/audio/units/tombstone/play_sfx_yorick_yorickw_death_r4.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			},
		},
		# END EVENT AUDIO tombstone
		"card_art": {},
	}
