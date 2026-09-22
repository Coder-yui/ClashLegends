class_name WorkbenchSession
extends RefCounted
## 工作台会话只保存选择与操作模式；战斗通过注入的正式入口执行。
var enabled := false
var form := 0
var selection := "training_dummy"
var team := 1
var spell_active := false
var last_units: Dictionary = {}
var last_groups: Dictionary = {}
var skill_choices: Dictionary = {}
var preset_loading := false
var battle_active := false
var place: Callable
var clear_battle: Callable
var rebuild_arena: Callable
var selected_unit: Callable
var sync_view: Callable
var pause_battle: Callable

func select(item_id: String) -> void:
	selection = item_id
	form = 0
	spell_active = false
	sync_view.call()

func set_team(value: int) -> void:
	team = value
	sync_view.call()

func clear() -> void:
	last_units.clear()
	last_groups.clear()
	clear_battle.call()
	sync_view.call()

func set_battle_active(active: bool) -> void:
	if not enabled: return
	battle_active = active
	pause_battle.call(not active)

func run_scenario(action: String) -> void:
	if not enabled: return
	if action.begins_with("preset:"):
		load_preset(action.trim_prefix("preset:"))
		return
	var unit: Unit = selected_unit.call()
	match action:
		"spawn": place.call(Vector2(300, 780) if team == 0 else Vector2(300, 500))
		"target":
			var old_selection := selection
			var old_team := team
			selection = "training_dummy"
			team = 1 - old_team
			var origin := unit.position if unit != null else Vector2(300, 780 if old_team == 0 else 500)
			place.call(origin + Vector2(0, -100 if old_team == 0 else 100))
			selection = old_selection
			team = old_team
		"freeze":
			if unit != null: unit.freeze(2.0)
		"stun":
			if unit != null: unit.stun(2.0)
		"slow":
			if unit != null: unit.apply_slow(3.0, 0.5)
		"attack_slow":
			if unit != null: unit.apply_attack_speed_slow(3.0, 0.5)
		"death":
			if unit != null: unit.take_damage(unit.max_hp * 100.0)
	sync_view.call()

func load_preset(id: String) -> void:
	if not enabled or preset_loading: return
	var recipe := preload("res://scripts/ui/workbench/battle_scenarios.gd").placements(id, selection, team)
	if recipe.is_empty(): return
	preset_loading = true
	var saved_selection := selection
	var saved_team := team
	var enhanced := spell_active
	clear()
	await rebuild_arena.call()
	var saved_form := form
	for entry in recipe:
		form = saved_form if entry.card == saved_selection else 0
		selection = entry.card
		team = entry.team
		place.call(entry.pos)
	selection = saved_selection
	form = saved_form
	team = saved_team
	spell_active = enhanced
	preset_loading = false
	sync_view.call()
