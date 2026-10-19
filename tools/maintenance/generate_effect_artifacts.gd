extends SceneTree
## CPU declarations only: no player instances, prewarm, simulation or rendering.
const BUILDER = preload("res://tools/maintenance/effect_manifest_builder.gd")
const MANIFEST = preload("res://scripts/presentation/effect_resource_manifest.gd")
const HEARTBEAT = preload("res://tools/performance/safe_probe_heartbeat.gd")
var pulse: RefCounted

func _initialize() -> void:
	Engine.max_fps = 30
	pulse = HEARTBEAT.new(self)
	call_deferred("run")

func run() -> void:
	if not pulse.enabled: quit(2); return
	var args := OS.get_cmdline_user_args()
	if args.size() != 3: quit(2); return
	var jobs: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[2]))
	if not jobs is Dictionary or not jobs.get("models") is Array: quit(2); return
	BUILDER.source_data = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var requests: Array[Dictionary] = []
	var definitions := CardDB.all()
	for id in definitions: MANIFEST.collect_requests(definitions[id], id, requests)
	var result := {}
	var errors := PackedStringArray()
	for request in requests:
		var key := MANIFEST.artifact_path(request).get_file()
		if result.has(key): continue
		pulse.set_phase("declarations:" + request.variant)
		var declaration := MANIFEST.resolve(request, errors)
		var files := BUILDER.files(request, errors)
		var selection := {}
		for field in ["json", "dependency_json", "systems", "sample", "emitter_source", "shader_providers"]:
			if declaration.has(field): selection[field] = declaration[field]
		if selection.get("sample", {}).get("fixed_sampled_layers", false):
			selection.sample = selection.sample.duplicate(true)
			selection.sample.coverage = preload("res://tools/maintenance/sampled_coverage_builder.gd").compile(selection.sample, declaration.json[0], errors)
		result[key] = {"provider": request.provider, "variant": request.variant, "selection": selection, "resources": files.resources, "raw": files.raw}
		await process_frame
	if not errors.is_empty():
		for error in errors: push_error(error)
		quit(1); return
	var models := await preload("res://tools/maintenance/model_template_builder.gd").generate(pulse, self, errors, jobs.models)
	if not errors.is_empty():
		for error in errors: push_error(error)
		quit(1); return
	FileAccess.open(args[1], FileAccess.WRITE).store_string(JSON.stringify({"definitions": definitions.size(), "entries": result, "model_templates": models}))
	pulse.set_phase("done", true)
	await process_frame
	quit()
