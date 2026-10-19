extends SceneTree
## One provider only; new preparation precedes its first formal instance, then legacy reference.
const WARMUP = preload("res://scripts/presentation/spell_effect_warmup.gd")
const PROVIDER = preload("res://assets/effects/sand_ward/player.gd")
const CONTRACTS = preload("res://tests/suites/presentation/spell_warmup_suite.gd")
const HEARTBEAT = preload("res://tools/performance/safe_probe_heartbeat.gd")
var pulse: RefCounted
var output := ""
var world: Node3D
var camera: Camera3D
var pictures := {}
var failures: Array[String] = []

func _initialize() -> void:
	Engine.max_fps = 30
	pulse = HEARTBEAT.new(self)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if not pulse.enabled or output.is_empty(): quit(2); return
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func frame() -> int:
	var started := Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	return Time.get_ticks_usec() - started

func consume(label: String, coverage: Dictionary) -> Dictionary:
	pulse.set_phase(label + ":formal-create", true)
	var started := Time.get_ticks_usec()
	var live := PROVIDER.new()
	world.add_child(live)
	live.configure(18.0)
	# Same interface used by UnitModel3D, on a new formal instance. No warmup pool reuse.
	var anchor := Node3D.new()
	world.add_child(anchor)
	live.bind_model(anchor)
	live.status_state = Vector2(0.0, 0.08)
	live.advance_status(true, true, 0.0)
	var create_usec := Time.get_ticks_usec() - started
	var errors := PackedStringArray()
	var states := WARMUP.COVERAGE.inspect(live, coverage, coverage.samples[0], errors)
	var first_wait := await frame()
	var first_total := Time.get_ticks_usec() - started
	pictures[label + "-formal"] = root.get_texture().get_image()
	var phases: Array = []
	for age in [0.38, 1.5]:
		started = Time.get_ticks_usec()
		live.status_state.y = age
		live.advance_status(true, true, 0.0)
		var cpu_usec := Time.get_ticks_usec() - started
		WARMUP.COVERAGE.inspect(live, coverage, coverage.samples[0], errors)
		phases.append({"age": age, "advance_usec": cpu_usec, "frame_wait_usec": await frame()})
	live.advance_status(false, true, 0.0)
	check(not live.visible, label + ": status end hidden")
	await frame()
	live.free()
	anchor.free()
	check(errors.is_empty(), label + ": formal structural coverage " + str(errors))
	return {"create_configure_bind_advance_usec": create_usec, "first_frame_wait_usec": first_wait, "first_consumption_total_usec": first_total, "states": states, "phases": phases, "errors": errors, "pool_transferred": false}

func run() -> void:
	var contracts: Dictionary = CONTRACTS.check_static_coverage(root)
	check(contracts.passed, "contracts: " + str(contracts.failures))
	if "--contracts" in OS.get_cmdline_user_args():
		await finish({"contracts": contracts})
		return
	if DisplayServer.get_name() == "headless": quit(2); return
	if not failures.is_empty(): await finish({"contracts": contracts}); return
	world = Node3D.new()
	root.add_child(world)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 9, 11)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.0
	camera.current = true
	root.world_3d.environment = Environment.new()
	root.world_3d.environment.background_mode = Environment.BG_COLOR
	root.world_3d.environment.background_color = Color(0.045, 0.055, 0.08)
	await frame()
	pulse.set_phase("ready", true)
	var recipe: Dictionary = PROVIDER.resource_manifest("ward").sample
	var results := {"contracts": contracts, "order": ["declared", "legacy"], "renderer": RenderingServer.get_current_rendering_method(), "display": DisplayServer.get_name(), "window_size": DisplayServer.window_get_size(), "viewport_size": root.get_visible_rect().size, "engine": Engine.get_version_info().string, "frame_cap": Engine.max_fps, "scope": "one provider, same process, ordered diagnostic; frame waits include natural draw/sync/cap, not GPU timing"}
	for strategy in ["declared", "legacy"]:
		var sample: Dictionary = recipe.duplicate(true)
		if strategy == "legacy": sample.erase("coverage")
		var warm := WARMUP.new()
		pulse.set_phase(strategy + ":prepare", true)
		var started := Time.get_ticks_usec()
		await warm._sample("probe", sample, world, camera, Callable())
		var prepare_usec := Time.get_ticks_usec() - started
		check(warm.errors.is_empty(), strategy + ": preparation errors " + str(warm.errors))
		check(world.get_child_count() == 1, strategy + ": temporary player freed")
		# Capture the selected visible state after timing, using the production status interface.
		var formal := await consume(strategy, recipe.coverage)
		results[strategy] = {"prepare_usec": prepare_usec, "setup_usec": warm.timings["probe/ward/setup_usec"], "draws": warm.draws, "frame_wait_usec": warm.frame_wait_usec, "coverage": warm.coverage_reports, "retained": warm.retained.size(), "formal": formal}
		warm.release_retained_resources()
		check(warm.retained.is_empty(), strategy + ": retained release")
	check(results.declared.draws == 1 and results.legacy.draws == 7, "one complete state versus seven original draws")
	# Production dispatcher rejects a bad declaration, without marking it completed.
	var bad := WARMUP.new()
	var before := world.get_child_count()
	var broken: Dictionary = recipe.duplicate(true)
	broken.coverage.strategy = "unknown"
	await bad._sample("bad", broken, world, camera, Callable())
	check(not bad.errors.is_empty() and bad.draws == 0 and world.get_child_count() == before, "invalid declaration has no fallback or sample side effects")
	world.free()
	await finish(results)

func finish(result: Dictionary) -> void:
	result.passed = failures.is_empty()
	result.failures = failures
	# No PNG writes inside any timed segment.
	for label in pictures: pictures[label].save_png(output.path_join(label + ".png"))
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	pulse.set_phase("done", true)
	await process_frame
	quit(0 if failures.is_empty() else 1)
