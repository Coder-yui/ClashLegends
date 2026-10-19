extends SceneTree
## Definition/dependency inventory only: no model instantiate, audio prepare or rendering.
const PLAN = preload("res://scripts/presentation/match_resource_plan.gd")
const HEAVY_BLUE := ["mirror", "sett", "void_summoning", "scuttle_crab", "void_gate", "aatrox", "kayn", "heavy_minion_squad"]
const HEAVY_RED := ["mirror", "anivia", "gwen", "sion", "aurelionsol", "olaf", "kayle", "stasis"]
const HEAVY_CHOICES := [{"sett": 0, "void_summoning": 0, "scuttle_crab": 0, "void_gate": 0, "aatrox": 0, "kayn": 0, "heavy_minion_squad": 0}, {"anivia": 0, "gwen": 1, "sion": 0, "aurelionsol": 0, "olaf": 0, "kayle": 0, "stasis": 0}]

# Fixed measurement profiles; inventory and actual startup share this definition.
const SUMMON_BLUE := ["mirror", "azir", "malzahar", "lulu", "belveth", "rift_herald", "tombstone", "voidfish_ranged_army"]
const SUMMON_RED := ["mirror", "kayn", "aatrox", "gnar", "jinx", "anivia", "kayle", "stasis"]
const DIVERSE_BLUE := ["mirror", "scuttle_crab", "void_scuttle_crab", "target_dummy", "tryndamere", "nocturne", "kassadin", "freeze"]
const DIVERSE_RED := ["mirror", "aurelionsol", "gwen", "missfortune", "olaf", "tristana", "corki", "corrosion"]

static func profile_config(id: String) -> Dictionary:
	var decks: Array
	var overrides: Dictionary
	match id:
		"heavy": decks = [HEAVY_BLUE, HEAVY_RED]; overrides = {"gwen": 1}
		"summon": decks = [SUMMON_BLUE, SUMMON_RED]; overrides = {"malzahar": 1}
		"diverse": decks = [DIVERSE_BLUE, DIVERSE_RED]; overrides = {"gwen": 1}
		_: return {}
	var choices := [{}, {}]
	for team in 2:
		for card in decks[team]:
			if card != "mirror": choices[team][card] = int(overrides.get(card, 0))
	return {"decks": decks.duplicate(true), "choices": choices, "profile": id}

func _initialize() -> void:
	call_deferred("run")

func inventory(decks: Array, choices: Array) -> Dictionary:
	var plan: RefCounted = PLAN.for_match(decks, choices)
	var resources := MatchResources.new()
	resources.plan = plan
	resources._collect_only = true
	resources.prepare(decks[0] + decks[1] + MatchResources.SYSTEM_UNIT_BUDGET.keys())
	var paths: Array = resources.resources.keys() + resources._pending.keys()
	paths.sort()
	var names := {}
	for id in plan.cards: names[id] = CardDB.get_card(id).get("name", id)
	var raw := {}
	var raw_bytes := 0
	for path in resources.raw_files:
		var file := FileAccess.open(path, FileAccess.READ)
		var size := file.get_length()
		raw[path] = size
		raw_bytes += size
	var specs := MatchModelPool.build_specs(resources.cards, plan)
	var capacity := 0
	var by_path := {}
	for path in specs:
		var count := 0
		for use in specs[path]: count += int(use.count)
		by_path[path] = count
		capacity += count
	return {"names": names, "paths_sha256": JSON.stringify(paths).sha256_text(), "decks": decks, "choices": choices, "legal": [MatchSession.valid_deck(decks[0], choices[0]), MatchSession.valid_deck(decks[1], choices[1])], "errors": Array(plan.errors) + Array(resources.errors), "cards": plan.cards.keys(), "skills": plan.skills, "resources": paths.size(), "paths": paths, "raw_bytes": raw_bytes, "raw": raw, "model_paths": specs.size(), "target_capacity": capacity, "capacity_by_path": by_path, "effects": plan.effects, "target_states": plan.target_states}

func run() -> void:
	var pulse := preload("res://tools/performance/safe_probe_heartbeat.gd").new(self)
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if output.is_empty() or not pulse.enabled: quit(1); return
	var reports := {}
	var valid := true
	for id in ["heavy", "summon", "diverse"]:
		pulse.set_phase(id)
		var config := profile_config(id)
		var item := inventory(config.decks, config.choices)
		reports[id] = item
		valid = valid and item.errors.is_empty() and item.legal == [true, true]
		print("[MATCH_LOADING_PLAN] ", id, " ", JSON.stringify({"cards": item.cards.size(), "resources": item.resources, "raw_bytes": item.raw_bytes, "model_paths": item.model_paths, "target_capacity": item.target_capacity, "recipes": item.effects.size(), "legal": item.legal, "errors": item.errors}))
		await process_frame
	FileAccess.open(output.path_join("inventory.json"), FileAccess.WRITE).store_string(JSON.stringify(reports, "\t"))
	pulse.set_phase("inventory_complete", true)
	await create_timer(0.3).timeout
	quit(0 if valid else 1)
