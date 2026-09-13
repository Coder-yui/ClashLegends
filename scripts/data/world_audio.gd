extends RefCounted
## 系统建筑音频；原始事件见 assets/audio/event_expansion_manifest.json。
const DEFINITIONS = {
	"world_tower_order": {
		"audio": {
			"attack_hit": [
				"res://assets/audio/world/order/play_sfx_env_map11_orderturretminionbasicattack_hit_r1.wav",
				"res://assets/audio/world/order/play_sfx_env_map11_orderturretminionbasicattack_hit_r2.wav"
			],
			"attack_hit_volume_db": 0.0,
			"events": {
				"attack:cast": {
					"pool": [
						"res://assets/audio/world/order/play_sfx_env_map11_orderturretminionbasicattack_cast_r1.wav",
						"res://assets/audio/world/order/play_sfx_env_map11_orderturretminionbasicattack_cast_r2.wav",
						"res://assets/audio/world/order/play_sfx_env_map11_orderturretminionbasicattack_cast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"attack:launch": {
					"pool": [
						"res://assets/audio/world/order/play_sfx_env_map11_orderturretminionbasicattack_missilelaunch_r1.wav",
						"res://assets/audio/world/order/play_sfx_env_map11_orderturretminionbasicattack_missilelaunch_r2.wav",
						"res://assets/audio/world/order/play_sfx_env_map11_orderturretminionbasicattack_missilelaunch_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"damage:stage1": {
					"pool": [
						"res://assets/audio/world/order/play_sfx_env_orderturret_break01_r1.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"damage:stage2": {
					"pool": [
						"res://assets/audio/world/order/play_sfx_env_orderturret_break02_r1.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/world/order/play_sfx_env_orderturret_break03_r1.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			}
		}
	},
	"world_nexus_order": {
		"audio": {
			"events": {
				"spawn:start": {
					"pool": [
						"res://assets/audio/world/order/play_sfx_env_sruap_order_nexus_spawn_r1.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"idle:sustain": {
					"pool": [
						"res://assets/audio/world/order/play_sfx_env_sruap_order_nexus_alive_loop_r1.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/world/order/play_sfx_env_global_eog_ordernexus_death_oc_r1.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			}
		}
	},
	"world_tower_chaos": {
		"audio": {
			"attack_hit": [
				"res://assets/audio/world/chaos/play_sfx_env_map11_chaosturretminionbasicattack_hit_r1.wav",
				"res://assets/audio/world/chaos/play_sfx_env_map11_chaosturretminionbasicattack_hit_r2.wav",
				"res://assets/audio/world/chaos/play_sfx_env_map11_chaosturretminionbasicattack_hit_r3.wav",
				"res://assets/audio/world/chaos/play_sfx_env_map11_chaosturretminionbasicattack_hit_r4.wav"
			],
			"attack_hit_volume_db": 0.0,
			"events": {
				"attack:cast": {
					"pool": [
						"res://assets/audio/world/chaos/play_sfx_env_map11_chaosturretminionbasicattack_cast_r1.wav",
						"res://assets/audio/world/chaos/play_sfx_env_map11_chaosturretminionbasicattack_cast_r2.wav",
						"res://assets/audio/world/chaos/play_sfx_env_map11_chaosturretminionbasicattack_cast_r3.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"attack:launch": {
					"pool": [
						"res://assets/audio/world/chaos/play_sfx_env_map11_chaosturretminionbasicattack_missilelaunch_r1.wav",
						"res://assets/audio/world/chaos/play_sfx_env_map11_chaosturretminionbasicattack_missilelaunch_r2.wav",
						"res://assets/audio/world/chaos/play_sfx_env_map11_chaosturretminionbasicattack_missilelaunch_r3.wav",
						"res://assets/audio/world/chaos/play_sfx_env_map11_chaosturretminionbasicattack_missilelaunch_r4.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"damage:stage1": {
					"pool": [
						"res://assets/audio/world/chaos/play_sfx_env_chaosturret_break01_r1.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"damage:stage2": {
					"pool": [
						"res://assets/audio/world/chaos/play_sfx_env_chaosturret_break02_r1.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/world/chaos/play_sfx_env_chaosturret_break03_r1.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			}
		}
	},
	"world_nexus_chaos": {
		"audio": {
			"events": {
				"spawn:start": {
					"pool": [
						"res://assets/audio/world/chaos/play_sfx_env_sruap_chaos_nexus_spawn_r1.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"idle:sustain": {
					"pool": [
						"res://assets/audio/world/chaos/play_sfx_env_sruap_chaos_nexus_alive_loop_r1.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				},
				"death": {
					"pool": [
						"res://assets/audio/world/chaos/play_sfx_env_global_eog_chaosnexus_death_cast_r1.wav"
					],
					"volume_db": 0.0,
					"bus": "Combat"
				}
			}
		}
	}
}
