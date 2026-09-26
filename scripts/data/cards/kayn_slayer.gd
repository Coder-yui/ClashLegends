extends "res://scripts/data/card_schema.gd"
static func definition() -> Dictionary:
	var data := preload("res://scripts/data/cards/kayn.gd").definition()
	for key in ["growth_ranged_id", "growth_melee_id", "growth_ranged_hits", "growth_melee_hits"]: data.gameplay.erase(key)
	data.gameplay.merge({"selectable": false, "heal_on_hit_name": "暗裔汲取", "on_hit_passive_name": "暗裔重创", "name": "影流之镰·红凯", "hp": 950, "damage": 80, "heal_every_hits": 1, "heal_amount": 35, "on_hit_max_health_ratio": 0.03, "on_hit_tower_damage": 35, "description": "红凯保留穿地形能力，进入地形回复70生命，地形中普攻前须离开。普攻命中回复35生命，附加目标最大生命3%伤害（塔、水晶固定35）。Q每段同样附伤，每段命中至少一人回复50生命。"}, true)
	data.gameplay.active_skills[0].merge({"on_hit_max_health_ratio": 0.03, "on_hit_tower_damage": 35, "hit_heal": 50}, true)
	data.gameplay.active_skills[0].description = "向前突进120像素，随后旋转；每段造成90加目标最大生命3%的伤害（塔、水晶附伤固定35）。每段至少命中一人回复50生命，多人不叠加，空放不回血。"
	data.visual.color = Color(0.8, 0.15, 0.15)
	data.visual.visual_scene_path = "res://assets/units/kayn/kayn_slayer_view.tscn"
	data.visual.visual_animations.idle = "Idle1_Slayer"
	data.visual.visual_animations.deploy = "Deploy_Slayer"
	data.visual.visual_animations.move = "Run_Slayer"
	data.visual.visual_animations.transitions = {"Spell1_Circle>terrain_move": "Spell1_Exit_To_Run", "Spell1_Circle>move": "Spell2_Slayer_Run"}
	data.visual.active_skills[0].icon_path = "res://assets/skills/kayn_q_slay.png"
	data.audio = {
		"events": {
				"deploy:voice": {"pool": ["res://assets/audio/units/kayn/kayn_slayer_deploy_voice_1.wav", "res://assets/audio/units/kayn/kayn_slayer_deploy_voice_2.wav", "res://assets/audio/units/kayn/kayn_slayer_deploy_voice_3.wav"], "volume_db": 3.0, "bus": "Voice"},
			"active:cast": {
				"pool": [
					"res://assets/audio/units/kayn/kayn_slayer_q_cast_1.wav"
				],
				"volume_db": 2.0,
				"bus": "Combat"
			},
			"active:spin": {
				"pool": [
					"res://assets/audio/units/kayn/kayn_slayer_q_spin_1.wav"
				],
				"volume_db": 2.0,
				"bus": "Combat"
			},
			"active:hit": {
				"pool": [
					"res://assets/audio/units/kayn/kayn_slayer_q_hit_1.wav"
				],
				"volume_db": 2.0,
				"bus": "Combat"
			},
			"terrain:sustain": {"pool": ["res://assets/audio/units/kayn/kayn_slayer_terrain_sustain.wav"], "volume_db": 2.0, "bus": "Combat"},
				"terrain:exit": {"pool": ["res://assets/audio/units/kayn/kayn_slayer_terrain_exit.wav"], "volume_db": 2.0, "bus": "Combat"},
				"terrain:enter": {
				"pool": [
					"res://assets/audio/units/kayn/kayn_slayer_terrain_1.wav"
				],
				"volume_db": 2.0,
				"bus": "Combat"
			},
			"death": {
				"pool": [
					"res://assets/audio/units/kayn/kayn_slayer_death_1.wav"
				],
				"volume_db": 2.0,
				"bus": "Combat"
			}
		},
		"attack_swing": [
			[
				"res://assets/audio/units/kayn/kayn_slayer_attack1_1.wav",
				"res://assets/audio/units/kayn/kayn_slayer_attack1_2.wav"
			],
			[
				"res://assets/audio/units/kayn/kayn_slayer_attack2_1.wav",
				"res://assets/audio/units/kayn/kayn_slayer_attack2_2.wav"
			],
			[
				"res://assets/audio/units/kayn/kayn_slayer_attack3_1.wav",
				"res://assets/audio/units/kayn/kayn_slayer_attack3_2.wav"
			]
		],
		"attack_swing_volume_db": 1.0,
		"attack_hit_volume_db": 1.0,
		"attack_hit": [
			"res://assets/audio/units/kayn/kayn_slayer_attack_hit_1.wav",
			"res://assets/audio/units/kayn/kayn_slayer_attack_hit_2.wav"
		]
	}
	data.card_art.path = "res://assets/cards/kayn_slayer_loading.png"
	return data
