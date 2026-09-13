class_name PresentationConfig
extends RefCounted
## 模型、声音共享形态选择；无第二套回退规则。
static func for_form(base: Dictionary, form: int) -> Dictionary:
	if form == 1:
		var transformed: Dictionary = base.get("transformed_stats", {})
		if not transformed.is_empty():
			return transformed
	return base

static func attack_source(unit: Node2D) -> Dictionary:
	if unit is Tower:
		return {"unit_id": unit.get_instance_id(), "card_id": world_card_id(unit), "team": unit.team, "form": 0, "serial": 0}
	return {"unit_id": unit.net_id if unit.net_id >= 0 else unit.get_instance_id(), "card_id": unit.card_id, "team": unit.team, "form": unit.get_form_index(),
		"serial": unit.get_attack_visual_serial(), "first_strike": unit.is_attack_visual_first_strike(),
		"empowered": unit.get_attack_visual_serial() > 0 and unit.get_empowered_attack_visual_serial() == unit.get_attack_visual_serial()}

static func scene_path(stats: Dictionary, team: int) -> String:
	var paths: Array = stats.get("visual_scene_paths", [])
	if team >= 0 and team < paths.size():
		return String(paths[team])
	return String(stats.get("visual_scene_path", ""))

static func audio_for(stats: Dictionary, team: int = 0, form: int = 0) -> Dictionary:
	var audio: Dictionary = for_form(stats, form).get("audio", {})
	var overrides: Array = audio.get("team_overrides", [])
	if team >= 0 and team < overrides.size():
		var selected := audio.duplicate(true)
		selected.erase("team_overrides")
		selected.merge(overrides[team], true)
		return selected
	return audio

static func world_card_id(tower: Tower) -> String:
	return "world_" + ("nexus_" if tower.is_king else "tower_") + ("order" if tower.team == 0 else "chaos")

static func audio_stats(card_id: String) -> Dictionary:
	var world: Dictionary = preload("res://scripts/data/world_audio.gd").DEFINITIONS
	return world[card_id] if world.has(card_id) else CardDB.get_card(card_id)

static func structure_damage_stage(hp: float, max_hp: float) -> int:
	if max_hp <= 0.0: return 0
	if hp / max_hp <= 1.0 / 3.0: return 2
	if hp / max_hp <= 2.0 / 3.0: return 1
	return 0
