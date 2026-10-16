extends SceneTree
## One fresh-process match through the real Solo/DeckBuilder controls.
const DECK := ["anivia", "gwen", "tristana", "stasis", "lightning", "sun_disc", "gnar", "tombstone"]
const DECK_PLANS = preload("res://tools/performance/match_loading_plan.gd")
const HEARTBEAT = preload("res://tools/performance/safe_probe_heartbeat.gd")
var output := ""
var pulse: RefCounted
var phase := ""
var profile := "representative"
var audit: RefCounted
var audit_stages := []

class FixedOpponentMain extends "res://scripts/main.gd":
	var fixed_deck: Array = []
	var fixed_choices := {}
	func _setup_battle_presentation() -> void:
		_remote_deck = fixed_deck.duplicate()
		_remote_active_skill_choices = fixed_choices.duplicate()
		super._setup_battle_presentation()

func _initialize() -> void:
	pulse = HEARTBEAT.new(self)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument.begins_with("--profile="): profile = argument.trim_prefix("--profile=")
	call_deferred("run")

func button(parent: Node, text: String) -> Button:
	for child in parent.find_children("*", "Button", true, false):
		if child.text == text and child.is_visible_in_tree(): return child
	return null

func run() -> void:
	if output.is_empty() or not pulse.enabled: quit(1); return
	audit = preload("res://tools/performance/match_resource_audit.gd").new()
	audit_stages.append(audit.snapshot("before_menu"))
	if profile == "heavy":
		# main.tscn contains exactly this Node2D and Main script; only AI deck selection is fixed.
		var fixed := FixedOpponentMain.new()
		fixed.name = "Main"
		fixed.fixed_deck = DECK_PLANS.HEAVY_RED.duplicate()
		fixed.fixed_choices = DECK_PLANS.HEAVY_CHOICES[1].duplicate()
		root.add_child(fixed)
		current_scene = fixed
	else:
		change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var main: Node2D = current_scene
	main._deck = DECK_PLANS.HEAVY_BLUE.duplicate() if profile == "heavy" else DECK.duplicate()
	main._active_skill_choices = DECK_PLANS.HEAVY_CHOICES[0].duplicate() if profile == "heavy" else {"anivia": 0, "gwen": 0, "tristana": 0, "gnar": 0}
	button(main, "单机对战 AI").pressed.emit()
	await process_frame
	audit_stages.append(audit.snapshot("deck_browser"))
	seed(246813579)
	var started := Time.get_ticks_usec()
	main._deck_builder._deck_confirm.pressed.emit()
	var checkpoint_msec := -1000
	while main._battle_loading:
		var next := "scene"
		for key in ["scene_usec", "plan_usec", "resource_stage_usec", "audio_usec", "model_pool_usec", "ground_usec", "effects_usec"]:
			if main.preparation_metrics.has(key): next = key
		if next != phase:
			phase = next
			if main._resources.plan != null:
				audit_stages.append(audit.snapshot(phase, main._resources))
			pulse.set_phase(phase)
			print("[LOADING_PHASE] ", phase, " ", Time.get_ticks_usec() - started)
		if Time.get_ticks_msec() - checkpoint_msec >= 500:
			checkpoint_msec = Time.get_ticks_msec()
			var checkpoint := {"elapsed_usec": Time.get_ticks_usec() - started, "phase": phase, "main": main.preparation_metrics, "cards": main._resources.cards.size(), "resources": main._resources.resources.size(), "static_bytes": OS.get_static_memory_usage()}
			if is_instance_valid(main._battle_presentation):
				checkpoint.model_times = main._battle_presentation.model_pool.preparation_times
				checkpoint.model_by_path = main._battle_presentation.model_pool.preparation_by_path
				checkpoint.effects = main._battle_presentation.spell_warmup.timings
			FileAccess.open(output.path_join("progress.json"), FileAccess.WRITE).store_string(JSON.stringify(checkpoint, "\t"))
		await process_frame
	pulse.set_phase("loaded", true)
	audit.describe_plan(main._resources.plan)
	audit_stages.append(audit.snapshot("loaded", main._resources))
	FileAccess.open(output.path_join("resource-audit.json"), FileAccess.WRITE).store_string(JSON.stringify({"stages": audit_stages, "origins": audit.origins}, "\t"))
	# Capture counters before advancing gameplay. No injected units or spells.
	var pool: MatchModelPool = main._battle_presentation.model_pool
	var warm: RefCounted = main._battle_presentation.spell_warmup
	var specs := MatchModelPool.build_specs(main._resources.cards, main._resources.plan)
	var spec_counts := {}
	for path in specs:
		spec_counts[path] = []
		for spec in specs[path]: spec_counts[path].append({"id": spec.id, "team": spec.team, "form": spec.form, "count": spec.count})
	var paths: Array = main._resources.resources.keys()
	paths.sort()
	var report := {"profile": profile, "engine": Engine.get_version_info().string, "display": DisplayServer.get_name(), "rendering": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(), "audio_driver": AudioServer.get_driver_name(), "deck": main._deck, "remote_deck": main._remote_deck, "choices": main._active_skill_choices, "remote_choices": main._remote_active_skill_choices, "confirm_to_loaded_usec": Time.get_ticks_usec() - started, "main": main.preparation_metrics, "resources": paths.size(), "paths_sha256": JSON.stringify(paths).sha256_text(), "cards": main._resources.cards, "raw_files": main._resources.raw_files.keys(), "model_times": pool.preparation_times, "model_by_path": pool.preparation_by_path, "model_metrics": pool.metrics, "wrapper_templates": pool._wrapper_templates.size(), "retained_by_recipe": warm.retained_by_recipe, "specs": spec_counts, "effects": warm.timings, "effect_draws": warm.draws, "effect_draws_skipped": warm.repeated_draws_skipped, "effect_drawn_resources": warm._drawn_resources.size(), "sampled_layers": warm.sampled_layers, "retained": warm.retained.size(), "errors": Array(main._resources.errors) + Array(pool.errors) + Array(warm.errors), "static_bytes": OS.get_static_memory_usage(), "static_peak_bytes": OS.get_static_memory_peak_usage()}
	FileAccess.open(output.path_join("loading.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	# One natural battle frame and one screenshot, outside preparation timing.
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("battle.png"))
	print("[MATCH_LOADING_RESULT] ", JSON.stringify({"errors": report.errors.size(), "total_usec": report.confirm_to_loaded_usec}))
	quit(0 if report.errors.is_empty() else 1)
