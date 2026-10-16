extends SceneTree
## Definition/dependency inventory only: no model instantiate, audio prepare or rendering.
const PLAN = preload("res://scripts/presentation/match_resource_plan.gd")
const HEAVY_BLUE := ["mirror", "sett", "void_summoning", "scuttle_crab", "void_gate", "aatrox", "kayn", "heavy_minion_squad"]
const HEAVY_RED := ["mirror", "anivia", "gwen", "sion", "aurelionsol", "olaf", "kayle", "stasis"]
const HEAVY_CHOICES := [{"sett": 0, "void_summoning": 0, "scuttle_crab": 0, "void_gate": 0, "aatrox": 0, "kayn": 0, "heavy_minion_squad": 0}, {"anivia": 0, "gwen": 1, "sion": 0, "aurelionsol": 0, "olaf": 0, "kayle": 0, "stasis": 0}]

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
		by_path[path] = mini(count, 64)
		capacity += mini(count, 64)
	return {"decks": decks, "choices": choices, "legal": [MatchSession.valid_deck(decks[0], choices[0]), MatchSession.valid_deck(decks[1], choices[1])], "errors": Array(plan.errors) + Array(resources.errors), "cards": plan.cards.keys(), "skills": plan.skills, "resources": paths.size(), "paths": paths, "raw_bytes": raw_bytes, "raw": raw, "model_paths": specs.size(), "target_capacity": capacity, "capacity_by_path": by_path, "effects": plan.effects, "target_states": plan.target_states}

func run() -> void:
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	var baseline := inventory([["anivia", "gwen", "tristana", "stasis", "lightning", "sun_disc", "gnar", "tombstone"], ["kayle", "freeze", "malzahar", "xin", "masteryi", "ranged_minion_squad", "tombstone", "pix"]], [{"anivia": 0, "gwen": 0, "tristana": 0, "gnar": 0}, {"freeze": 0, "kayle": 0}])
	var heavy := inventory([HEAVY_BLUE, HEAVY_RED], HEAVY_CHOICES)
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"baseline": baseline, "heavy": heavy}, "\t"))
	print("[MATCH_LOADING_PLAN] ", JSON.stringify({"baseline": [baseline.cards.size(), baseline.resources, baseline.raw_bytes, baseline.model_paths, baseline.target_capacity, baseline.effects.size()], "heavy": [heavy.cards.size(), heavy.resources, heavy.raw_bytes, heavy.model_paths, heavy.target_capacity, heavy.effects.size()], "legal": heavy.legal, "errors": heavy.errors}))
	quit(0 if heavy.errors.is_empty() and heavy.legal == [true, true] else 1)
