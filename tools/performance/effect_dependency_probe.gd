extends SceneTree
## Dependency-only CPU versus original parser; player parsing and residency remain.
const MANIFEST = preload("res://scripts/presentation/effect_resource_manifest.gd")
const HEARTBEAT = preload("res://tools/performance/safe_probe_heartbeat.gd")
var failures: Array = []
var output := ""
var reference: Script
var heartbeat: RefCounted

func _initialize() -> void:
	Engine.max_fps = 30
	heartbeat = HEARTBEAT.new(self)
	if DisplayServer.get_name() != "headless" and not heartbeat.enabled:
		push_error("Compatibility probe requires tools/performance/safe_probe.py supervision")
		quit(2)
		return
	call_deferred("run")
func option(key: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--" + key + "="): return argument.trim_prefix("--" + key + "=")
	return fallback
func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func distribution(values: Array) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted: total += float(value)
	return {"samples": sorted.size(), "mean_ms": total / maxf(sorted.size(), 1.0) / 1000.0, "p50_ms": sorted[maxi(ceili(sorted.size() * 0.50) - 1, 0)] / 1000.0, "p95_ms": sorted[maxi(ceili(sorted.size() * 0.95) - 1, 0)] / 1000.0, "p99_ms": sorted[maxi(ceili(sorted.size() * 0.99) - 1, 0)] / 1000.0}
func request_for(kind: String) -> Dictionary:
	return {"provider": "res://assets/effects/anivia/player.gd", "variant": "storm"} if kind == "typical" else {"provider": "res://assets/effects/void_summoning/player.gd", "variant": "zone"}
func same_dependencies(old: Dictionary, current: Dictionary) -> bool:
	var old_resources: Array = old.resources.duplicate()
	var new_resources: Array = current.resources.duplicate()
	old_resources.sort(); new_resources.sort()
	var old_raw: Array = old.raw.duplicate()
	var new_raw: Array = current.raw.filter(func(path): return not String(path).ends_with(".dependencies.json"))
	old_raw.sort(); new_raw.sort()
	return old_resources == new_resources and old_raw == new_raw
func measure(script: Script, request: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	var before := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var started := Time.get_ticks_usec()
	var result: Dictionary = script.files(request, errors)
	var usec := Time.get_ticks_usec() - started
	expect(errors.is_empty(), "dependency parsing errors: " + str(errors))
	return {"usec": usec, "static_after_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)) - before, "result": result}
func paired(kind: String) -> Dictionary:
	var request := request_for(kind)
	# Keep parser first-use visible; do not repeatedly parse the pressure source
	# for warmup/final diagnostics outside the measured pair.
	var times := {"old": [], "current": []}
	var residuals := {"old": [], "current": []}
	var rounds := int(option("rounds", "1"))
	var samples := int(option("samples", "1"))
	var last_results := {}
	for round_index in rounds:
		var order := ["old", "current"] if round_index % 2 == 0 else ["current", "old"]
		for side in order:
			for sample_index in samples:
				heartbeat.set_phase("dependencies-" + kind + "-" + side, true)
				var measured := measure(reference if side == "old" else MANIFEST, request)
				times[side].append(measured.usec)
				residuals[side].append(measured.static_after_bytes)
				last_results[side] = measured.result
				measured.clear()
				await process_frame
			expect(not last_results.has("old") or not last_results.has("current") or same_dependencies(last_results.old, last_results.current), "paired dependency closure equivalence: " + kind)
	var old: Dictionary = last_results.old
	var current: Dictionary = last_results.current
	var resources: Array = current.resources.duplicate(); resources.sort()
	return {"kind": kind, "request": request, "old": distribution(times.old), "current": distribution(times.current), "rounds": rounds, "samples_per_round": samples, "resource_paths": resources, "raw_old": old.raw, "raw_current": current.raw, "live_result_deltas_bytes": residuals, "scope": "CPU files() only, parser first-use included; no data warmup/final reparse, no simulation or draw; one sample per side by default, quantiles do not support stable performance claims"}
func cold(kind: String, side: String) -> Dictionary:
	var request := request_for(kind)
	var script: Script = reference if side == "old" else MANIFEST
	var started := Time.get_ticks_usec()
	heartbeat.set_phase("cold-dependencies-" + kind + "-" + side, true)
	var dependency := measure(script, request)
	var dependency_usec: int = dependency.usec
	var result: Dictionary = dependency.result
	var resources: Array = result.resources.duplicate(); resources.sort()
	var raw: Array = result.raw.duplicate(); raw.sort()
	dependency.clear(); result = {}
	await process_frame
	heartbeat.set_phase("cold-player-" + kind + "-" + side)
	var before_player := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var provider: Script = load(request.provider)
	var player_started := Time.get_ticks_usec()
	if provider.has_method("prewarm"): provider.prewarm()
	else:
		var instance: Node3D = provider.new()
		instance.load_kind(request.variant)
		instance.free()
	var player_usec := Time.get_ticks_usec() - player_started
	return {"kind": kind, "side": side, "dependency_ms": dependency_usec / 1000.0, "player_ms": player_usec / 1000.0, "largest_main_thread_fragment_ms": maxf(dependency_usec, player_usec) / 1000.0, "total_ms": (Time.get_ticks_usec() - started) / 1000.0, "static_before_player_bytes": before_player, "static_after_player_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)), "static_peak_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)), "resource_count": resources.size(), "resource_paths_sha256": JSON.stringify(resources).sha256_text(), "raw": raw, "scope": "fresh process/first parser use, warm OS file pages possible; full original player data/materials retained; not actual GPU warmup time"}
func run() -> void:
	output = option("output", "")
	DirAccess.make_dir_recursive_absolute(output)
	reference = load(option("reference", "res://ClashLegends-开发素材库/04-中间产物/architecture_refactor/batch2b/reference/scripts/presentation/effect_resource_manifest.gd"))
	var phase := option("phase", "paired")
	var kind := option("kind", "typical")
	var rounds := int(option("rounds", "1"))
	var samples := int(option("samples", "1"))
	if phase not in ["paired", "cold"] or kind not in ["typical", "pressure", "all"] or rounds < 1 or rounds > 3 or samples < 1 or samples > 3 or (phase == "cold" and kind == "all") or option("side", "current") not in ["old", "current"]:
		push_error("Invalid diagnostic phase/kind/rounds/samples")
		quit(2)
		return
	var results: Array = []
	if phase == "paired":
		for selected in (["typical", "pressure"] if kind == "all" else [kind]): results.append(await paired(selected))
	else: results.append(await cold(kind, option("side", "current")))
	var report := {"schema": 1, "passed": failures.is_empty(), "failures": failures, "engine": Engine.get_version_info().string, "display_server": DisplayServer.get_name(), "rendering_method": RenderingServer.get_current_rendering_method(), "phase": phase, "results": results}
	FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("[EFFECT_DEPENDENCIES_RESULT] " + JSON.stringify({"passed": failures.is_empty(), "output": output}))
	reference = null
	quit(0 if failures.is_empty() else 1)
