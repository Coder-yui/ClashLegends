extends "res://scripts/data/card_schema.gd"
static func definition() -> Dictionary:
	var data := preload("res://scripts/data/cards/kayn.gd").definition()
	for key in ["growth_ranged_id", "growth_melee_id", "growth_ranged_hits", "growth_melee_hits"]: data.gameplay.erase(key)
	data.gameplay.merge({"selectable": false, "name": "影流之镰·蓝凯", "hp": 650, "damage": 110, "speed": SPEED_EXTREMELY_FAST, "interval": 0.85, "first_hit": 0.12, "terrain_entry_heal": 120, "terrain_entry_speed_multiplier": 1.3, "description": "蓝凯：高速高伤，进入地形回复120生命并加速30%持续1秒。巨镰横扫仅需1金币。"}, true)
	data.gameplay.active_skills[0].cost = 1
	data.visual.color = Color(0.15, 0.6, 1.0)
	data.visual.visual_scene_path = "res://assets/units/kayn/kayn_assassin_view.tscn"
	data.visual.visual_animations.idle = "Kayn_Idle1_Assassin_anm"
	data.visual.visual_animations.deploy = "Deploy_Assassin"
	data.visual.visual_animations.move = "Run_Assassin"
	data.visual.visual_animations.transitions = {"Spell1_Circle>terrain_move": "Spell1_Exit_To_Run", "Spell1_Circle>move": "Spell1_Exit_To_Run"}
	data.visual.active_skills[0].icon_path = "res://assets/skills/kayn_q_ass.png"
	data.audio = {
		"events": {
			"active:cast": {
				"pool": [
					"res://assets/audio/units/kayn/kayn_assassin_q_cast_1.wav"
				],
				"volume_db": -4.0,
				"bus": "Combat"
			},
			"active:spin": {
				"pool": [
					"res://assets/audio/units/kayn/kayn_assassin_q_spin_1.wav"
				],
				"volume_db": -4.0,
				"bus": "Combat"
			},
			"active:hit": {
				"pool": [
					"res://assets/audio/units/kayn/kayn_assassin_q_hit_1.wav"
				],
				"volume_db": -4.0,
				"bus": "Combat"
			},
			"terrain:enter": {
				"pool": [
					"res://assets/audio/units/kayn/kayn_assassin_terrain_1.wav"
				],
				"volume_db": -4.0,
				"bus": "Combat"
			},
			"death": {
				"pool": [
					"res://assets/audio/units/kayn/kayn_assassin_death_1.wav"
				],
				"volume_db": -4.0,
				"bus": "Combat"
			}
		},
		"attack_swing": [
			[
				"res://assets/audio/units/kayn/kayn_assassin_attack1_1.wav",
				"res://assets/audio/units/kayn/kayn_assassin_attack1_2.wav"
			],
			[
				"res://assets/audio/units/kayn/kayn_assassin_attack2_1.wav",
				"res://assets/audio/units/kayn/kayn_assassin_attack2_2.wav"
			],
			[
				"res://assets/audio/units/kayn/kayn_assassin_attack3_1.wav",
				"res://assets/audio/units/kayn/kayn_assassin_attack3_2.wav"
			]
		],
		"attack_swing_volume_db": -5.0,
		"attack_hit_volume_db": -5.0,
		"attack_hit": [
			"res://assets/audio/units/kayn/kayn_assassin_attack_hit_1.wav",
			"res://assets/audio/units/kayn/kayn_assassin_attack_hit_2.wav"
		]
	}
	data.card_art.path = "res://assets/cards/kayn_assassin_loading.png"
	return data
