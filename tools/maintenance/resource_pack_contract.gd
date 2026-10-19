extends SceneTree
## Executed in an isolated tiny PCK, with no source project filesystem fallback.
const PULSE = preload("res://tools/performance/safe_probe_heartbeat.gd")
const SAMPLES = preload("res://scripts/presentation/compact_particle_samples.gd")
const MANIFEST = preload("res://scripts/presentation/effect_resource_manifest.gd")
var pulse: RefCounted

func _initialize() -> void:
	pulse = PULSE.new(self)
	call_deferred("run")

func run() -> void:
	if not pulse.enabled: quit(2); return
	var errors := PackedStringArray()
	var files := MANIFEST.files({"provider": ("res" + "://fixture.gd"), "variant": "fixture"}, errors)
	var samples := SAMPLES.new()
	var source := "res://tools/source_assets/void_summoning/sampled.json"
	var passed: bool = not FileAccess.file_exists(source) and errors.is_empty() and files.raw.has("res://fixture.clps") and samples.read("res://fixture.clps", source) and samples.row(0) == [7, 1.0, 2.0, 3.0]
	print("[RESOURCE_PCK_CONTRACT] ", JSON.stringify({"passed": passed, "editable_source_absent": not FileAccess.file_exists(source), "errors": errors, "compact_errors": samples.errors}))
	pulse.set_phase("done", true)
	await process_frame
	quit(0 if passed else 1)
