extends SceneTree
## Fixed single Quad only. No sand rendering, Main, full world or provider batch.
const PLAYER = preload("res://assets/effects/malzahar/nether_grasp/player.gd")
const WARMUP = preload("res://scripts/presentation/spell_effect_warmup.gd")
const TESTS = preload("res://tests/suites/presentation/spell_warmup_suite.gd")
const HEARTBEAT = preload("res://tools/performance/safe_probe_heartbeat.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
var pulse: RefCounted
var output := ""
var world: Node3D
var camera: Camera3D
var failures: Array[String] = []
var images := {}

func _initialize() -> void:
	Engine.max_fps = 30
	pulse = HEARTBEAT.new(self)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if not pulse.enabled or output.is_empty(): quit(2); return
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func draw_frame() -> int:
	var started := Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	return Time.get_ticks_usec() - started

func formal(label: String, contract: Dictionary) -> Dictionary:
	pulse.set_phase(label + ":formal", true)
	var started := Time.get_ticks_usec()
	var player := PLAYER.new()
	world.add_child(player)
	player.load_kind("beam")
	# The exact pair used by malzahar_effect_3d's formal consumer, no native scale.
	var start := PROJECTION.ground(camera, Vector2(280, 640)) + Vector3.UP
	var end := PROJECTION.ground(camera, Vector2(440, 640)) + Vector3.UP
	player.set_endpoints(start, end, camera)
	player.seek(0.1, 5.0)
	var cpu_usec := Time.get_ticks_usec() - started
	var errors := PackedStringArray()
	var states := WARMUP.COVERAGE.inspect(player, contract, contract.samples[0], errors)
	var wait_usec := await draw_frame()
	var first_total := Time.get_ticks_usec() - started
	images[label] = root.get_texture().get_image()
	var footprint := TESTS.beam_footprint(player, camera)
	check(errors.is_empty(), label + ": " + str(errors))
	player.free()
	return {"create_endpoints_seek_usec": cpu_usec, "first_frame_wait_usec": wait_usec, "first_total_usec": first_total, "states": states, "footprint": footprint, "pool_transferred": false}

func reference(recipe: Dictionary) -> Dictionary:
	# Same corrected endpoint context, old four ages/force/retain algorithm.
	# This is NOT the old subpixel .01 native setup performance baseline.
	var warm := WARMUP.new()
	var started := Time.get_ticks_usec()
	var player := PLAYER.new()
	world.add_child(player)
	player.load_kind("beam")
	player.setup_resource_sample(camera)
	var setup_usec := Time.get_ticks_usec() - started
	var seek_usec := 0
	var retain_usec := 0
	for age in recipe.times:
		var stage := Time.get_ticks_usec()
		player.seek(age)
		seek_usec += Time.get_ticks_usec() - stage
		stage = Time.get_ticks_usec()
		warm._retain(player)
		retain_usec += Time.get_ticks_usec() - stage
		await warm._draw_resources(player, self)
	player.free()
	var result := {"prepare_usec": Time.get_ticks_usec() - started, "setup_usec": setup_usec, "seek_usec": seek_usec, "retain_usec": retain_usec, "scan_usec": warm.resource_scan_usec, "frame_wait_usec": warm.frame_wait_usec, "draws": warm.draws, "retained": warm.retained.size(), "ages": recipe.times}
	result.formal = await formal("reference-formal", recipe.coverage)
	warm.release_retained_resources()
	return result

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 9, 11)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.0
	camera.current = true
	# All CPU sand fixtures are freed synchronously before the first rendered frame.
	var contracts: Dictionary = TESTS.check_coverage_revision(world, camera)
	check(contracts.passed, str(contracts.failures))
	var result := {"contracts": contracts, "declarations": []}
	for pair in [["res://assets/effects/sand_ward/player.gd", "ward"], ["res://assets/effects/malzahar/nether_grasp/player.gd", "beam"]]:
		result.declarations.append({"provider": pair[0], "variant": pair[1], "selection": {"sample": load(pair[0]).resource_manifest(pair[1]).sample}})
	if "--contracts" in OS.get_cmdline_user_args() or not failures.is_empty():
		await finish(result)
		return
	if DisplayServer.get_name() == "headless": quit(2); return
	root.world_3d.environment = Environment.new()
	root.world_3d.environment.background_mode = Environment.BG_COLOR
	root.world_3d.environment.background_color = Color(0.045, 0.055, 0.08)
	await draw_frame()
	pulse.set_phase("beam-ready", true)
	var recipe: Dictionary = PLAYER.resource_manifest("beam").sample
	var warm := WARMUP.new()
	var started := Time.get_ticks_usec()
	await warm._sample("beam", recipe, world, camera, Callable())
	var prepared_usec := Time.get_ticks_usec() - started
	check(warm.errors.is_empty(), str(warm.errors))
	result.declared = {"prepare_usec": prepared_usec, "setup_usec": warm.timings["beam/beam/setup_usec"], "draws": warm.draws, "frame_wait_usec": warm.frame_wait_usec, "coverage": warm.coverage_reports, "retained": warm.retained.size()}
	result.declared.formal = await formal("declared-formal", recipe.coverage)
	warm.release_retained_resources()
	pulse.set_phase("corrected-reference", true)
	result.reference_corrected_endpoints = await reference(recipe)
	check(result.declared.draws == 1 and result.reference_corrected_endpoints.draws == 4, "1 declared versus 4 old age samples")
	check(world.get_child_count() == 1, "all temporary/formal players freed")
	result.order = ["declared", "declared-formal", "corrected-old-ages", "reference-formal"]
	result.context = {"renderer": RenderingServer.get_current_rendering_method(), "window": DisplayServer.window_get_size(), "viewport": root.get_visible_rect().size, "frame_cap": Engine.max_fps, "scope": "same process, new first; corrected endpoint reference; not cold/stable or full battle"}
	await finish(result)

func finish(result: Dictionary) -> void:
	result.passed = failures.is_empty()
	result.failures = failures
	for label in images: images[label].save_png(output.path_join(label + ".png"))
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	world.free()
	pulse.set_phase("done", true)
	await process_frame
	quit(0 if failures.is_empty() else 1)
