extends SceneTree
## Limited mechanism representatives; no full catalogue loading or Main.
const FIXED = preload("res://scripts/presentation/sampled_effect_coverage.gd")
const BUILDER = preload("res://tools/maintenance/sampled_coverage_builder.gd")
const WARM = preload("res://scripts/presentation/spell_effect_warmup.gd")
const TESTS = preload("res://tests/suites/presentation/spell_warmup_suite.gd")
const HEARTBEAT = preload("res://tools/performance/safe_probe_heartbeat.gd")
var pulse: RefCounted
var output := ""
var world: Node3D
var camera: Camera3D
var failures: Array[String] = []
var checks := 0
var images := {}
const FAMILIES := {"azir": ["cast1", "cast2", "hit", "spawn"], "anivia": ["storm"], "gwen_tristana": ["rapid", "missile", "mist"], "malzahar": ["cast", "portal_start", "portal_end"]}

func _initialize() -> void:
	Engine.max_fps = 30
	pulse = HEARTBEAT.new(self)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func declaration(provider: String, kind: String) -> Dictionary:
	var errors := PackedStringArray()
	var manifest: Dictionary = load(provider).resource_manifest(kind)
	manifest.sample.fixed_sampled_layers = true
	manifest.sample.coverage = BUILDER.compile(manifest.sample, manifest.json[0], errors)
	check(errors.is_empty(), provider + kind + str(errors))
	return {"provider": provider, "variant": kind, "selection": manifest, "resources": [], "raw": []}

func contracts(entry: Dictionary) -> void:
	var sample: Dictionary = entry.selection.sample
	var errors := PackedStringArray()
	var player: Node3D = load(sample.player).new()
	world.add_child(player)
	player.load_kind(sample.kind)
	FIXED.prepare(player, sample.coverage, camera, errors)
	check(errors.is_empty(), "representative preparation " + str(errors))
	check(player.get_child_count() == sample.coverage.layers.size(), "one representative per complete active layer")
	check(player._pools.is_empty(), "no formal pool built")
	for layer in sample.coverage.layers:
		var found := false
		for node in player.get_children():
			if node.get_meta("coverage_layer") != int(layer.index): continue
			check(FIXED.signature(node, layer.signature) == layer.signature, "mesh/material/texture/branch chain")
			var material: ShaderMaterial = node.material_override
			for name in layer.signature.defaults:
				if material.get_shader_parameter(name) == null:
					material.set_shader_parameter(name, bytes_to_var(String(layer.signature.defaults[name].bits).hex_decode()))
			check(FIXED.signature(node, layer.signature) == layer.signature, "exact default materialization preserves effective contract")
			material.set_shader_parameter("mult_address", 1)
			check(FIXED.signature(node, layer.signature) != layer.signature, "nondefault int rejected")
			material.set_shader_parameter("mult_address", 0)
			material.set_shader_parameter("warp_strength", 0.000000000001)
			check(FIXED.signature(node, layer.signature) != layer.signature, "tiny nondefault float rejected without tolerance")
			material.set_shader_parameter("warp_strength", 0.0)
			var source_texture: Variant = material.get_shader_parameter("source_texture")
			material.set_shader_parameter("source_texture", PlaceholderTexture2D.new())
			check(FIXED.signature(node, layer.signature) != layer.signature, "texture class/path/size change rejected")
			material.set_shader_parameter("source_texture", source_texture)
			material.render_priority += 1
			check(FIXED.signature(node, layer.signature) != layer.signature, "priority change rejected")
			material.render_priority -= 1
			var wrong: Dictionary = layer.signature.duplicate(true)
			wrong.engine = "unreviewed-engine"
			check(FIXED.signature(node, wrong).is_empty(), "engine identity mismatch rejected")
			wrong = layer.signature.duplicate(true)
			wrong.uniform_types.address_mode.variant = TYPE_FLOAT
			check(FIXED.signature(node, wrong).is_empty(), "uniform type/layout mismatch rejected")
			node.material_overlay = StandardMaterial3D.new()
			check(FIXED.signature(node, layer.signature).is_empty(), "overlay rejected")
			node.material_overlay = null
			var mesh: Mesh = node.mesh
			node.mesh = QuadMesh.new()
			check(FIXED.signature(node, layer.signature).is_empty(), "changed vertex layout rejected")
			node.mesh = mesh
			material.next_pass = StandardMaterial3D.new()
			check(FIXED.signature(node, layer.signature).is_empty(), "reject material chain")
			material.next_pass = null
			material.set_shader_parameter("has_soft", true)
			check(FIXED.signature(node, layer.signature).is_empty(), "reject active depth")
			material.set_shader_parameter("has_soft", false)
			found = true
		check(found, "late layer represented")
	player.free()
	var dropped: Dictionary = sample.coverage.duplicate(true)
	dropped.layers.pop_back()
	var empty: Node3D = load(sample.player).new(); world.add_child(empty); empty.load_kind(sample.kind)
	FIXED.prepare(empty, dropped, camera, errors)
	check(not errors.is_empty() and empty.get_child_count() == 0, "missing late layer rejected before draw")
	empty.free()
	var bad: Dictionary = sample.coverage.duplicate(true)
	bad.layers[0].row[4] = 0.0
	check(not FIXED.valid(bad), "reject invisible geometry")
	bad = sample.coverage.duplicate(true)
	bad.layers[0].row[10] = NAN
	check(not FIXED.valid(bad), "reject nonfinite sample")
	# Real source seek at generated rows' frames, independently of representative construction.
	var formal: Node3D = load(sample.player).new()
	world.add_child(formal)
	formal.load_kind(sample.kind)
	formal.setup_native(0.01)
	for layer in sample.coverage.layers:
		formal.seek((float(layer.first_frame) + 0.25) / float(formal._data.fps))
		check(not formal._pools[int(layer.index)].is_empty(), "production first-visible pool exists")
		formal.seek((float(layer.frame) + 0.25) / float(formal._data.fps))
		var item: MeshInstance3D = formal._pools[int(layer.index)][int(layer.particle)]
		check(FIXED.signature(item, layer.signature) == layer.signature, "independent production material/geometry signature")
		check(item.material_override.get_shader_parameter("p") == PackedFloat32Array(layer.row), "exact production representative row")
	formal.seek(float(formal._data.duration) + 0.1)
	check(formal.get_children().all(func(item): return not item.visible), "production end hides layers")
	formal.free()

func run() -> void:
	if not pulse.enabled or output.is_empty(): quit(2); return
	world = Node3D.new(); root.add_child(world)
	camera = Camera3D.new(); world.add_child(camera)
	camera.position = Vector3(0, 9, 11); camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 9.0; camera.current = true
	pulse.set_phase("contracts-ready", true)
	var entries := []
	var targeted := "--targeted" in OS.get_cmdline_user_args()
	var families := {"azir": ["cast1"]} if targeted else FAMILIES
	for family in families:
		for kind in families[family]:
			pulse.set_phase("compile:" + family + "/" + kind, true)
			entries.append(declaration("res://assets/effects/" + family + "/player.gd", kind))
			await process_frame
	var result := {"declarations": entries, "order": ["driver-chain" if targeted else "CPU-contracts"], "scope": "azir/cast1 two layers only" if targeted else "11 declarations, 3 CPU representatives"}
	if targeted:
		result.material_chain = driver_chain(entries[0])
	else:
		for index in [0, 4, 7]: contracts(entries[index])
		var previous: Dictionary = TESTS.check_static_coverage(world)
		check(previous.passed, "unchanged primitive contracts " + str(previous))
		previous = TESTS.check_coverage_revision(world, camera)
		check(previous.passed, "unchanged beam/attached contracts " + str(previous))
	if "--contracts" not in OS.get_cmdline_user_args() and failures.is_empty():
		await render_probe(entries[0], result)
	result.checks = checks; result.failures = failures; result.passed = failures.is_empty()
	for key in images: images[key].save_png(output.path_join(key + ".png"))
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	world.free(); pulse.set_phase("done", true)
	await process_frame
	quit(0 if failures.is_empty() else 1)

func formal(recipe: Dictionary, label: String) -> Dictionary:
	var started := Time.get_ticks_usec()
	var player: Node3D = load(recipe.player).new(); world.add_child(player)
	player.load_kind(recipe.kind); player.setup_native(0.01); player.seek(0.4)
	var cpu := Time.get_ticks_usec() - started
	await RenderingServer.frame_post_draw
	var total := Time.get_ticks_usec() - started
	images[label] = root.get_texture().get_image()
	var nodes := player.get_child_count()
	player.free()
	return {"cpu_usec": cpu, "first_wait_total_usec": total, "nodes": nodes, "pool_transferred": false}

func render_probe(entry: Dictionary, result: Dictionary) -> void:
	var recipe: Dictionary = entry.selection.sample
	root.world_3d.environment = Environment.new()
	root.world_3d.environment.background_mode = Environment.BG_COLOR
	root.world_3d.environment.background_color = Color(0.045, 0.055, 0.08)
	await RenderingServer.frame_post_draw
	pulse.set_phase("new-representatives", true)
	var warm := WARM.new()
	var started := Time.get_ticks_usec()
	await warm._sample("probe", recipe, world, camera, Callable())
	check(warm.errors.is_empty(), str(warm.errors))
	result.declared = {"wall_usec": Time.get_ticks_usec() - started, "draws": warm.draws, "wait_usec": warm.frame_wait_usec, "coverage": warm.coverage_reports, "retained": warm.retained.size()}
	result.representatives = await representative_pair(recipe)
	result.declared.formal = await formal(recipe, "declared-formal")
	warm.release_retained_resources()
	pulse.set_phase("old-ages", true)
	var old: Dictionary = recipe.duplicate(true); old.erase("coverage"); old.erase("fixed_sampled_layers")
	warm = WARM.new(); started = Time.get_ticks_usec()
	await warm._sample("probe", old, world, camera, Callable())
	check(warm.errors.is_empty(), str(warm.errors))
	result.legacy = {"wall_usec": Time.get_ticks_usec() - started, "draws": warm.draws, "wait_usec": warm.frame_wait_usec, "coverage": warm.coverage_reports, "retained": warm.retained.size()}
	result.legacy.formal = await formal(recipe, "legacy-formal")
	warm.release_retained_resources()
	check(images["declared-formal"].get_data() == images["legacy-formal"].get_data(), "unchanged formal image exact equality")
	result.order = ["CPU contracts/loads", "declared", "new formal", "old ages", "new formal"]
	result.context = {"renderer": RenderingServer.get_current_rendering_method(), "viewport": root.size, "frame_cap": Engine.max_fps, "limitation": "ordered warm-process wall/wait diagnostics; no GPU timing or cold-cache claim"}

func representative_pair(recipe: Dictionary) -> Dictionary:
	var viewports := []
	for side in 2:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(720, 1280); viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
		viewport.world_3d.environment = root.world_3d.environment
		var host := Node3D.new(); viewport.add_child(host)
		var eye := Camera3D.new(); host.add_child(eye)
		eye.transform = camera.transform; eye.projection = camera.projection; eye.size = camera.size; eye.current = true
		var player: Node3D = load(recipe.player).new(); host.add_child(player); player.load_kind(recipe.kind)
		if side == 0:
			var errors := PackedStringArray(); FIXED.prepare(player, recipe.coverage, eye, errors)
			check(errors.is_empty(), "representative pair " + str(errors))
		else:
			# Keep the real production-created node/row for each generated frame, no helper material cloning.
			player.setup_native(0.01)
			var bucket := Node3D.new(); host.add_child(bucket); bucket.scale = player.scale
			for layer in recipe.coverage.layers:
				player.seek((float(layer.frame) + 0.25) / float(player._data.fps))
				var item: MeshInstance3D = player._pools[int(layer.index)][int(layer.particle)]
				player.remove_child(item); bucket.add_child(item)
				item.transform = Transform3D.IDENTITY
				var target := Vector2(180 + (int(layer.index) % 4) * 120, 400 + (int(layer.index) / 4) * 80)
				var center: Vector3 = player.projection_basis * Vector3(layer.row[1], layer.row[2], layer.row[3])
				item.position = bucket.to_local(preload("res://scripts/presentation/spell_effect_projection.gd").ground(eye, target)) - center
				item.sorting_offset = 0.0
				player._pools[int(layer.index)].remove_at(int(layer.particle))
			player.free()
		viewports.append(viewport)
	await RenderingServer.frame_post_draw
	images["generated-representatives"] = viewports[0].get_texture().get_image()
	images["production-representatives"] = viewports[1].get_texture().get_image()
	var equal: bool = images["generated-representatives"].get_data() == images["production-representatives"].get_data()
	check(equal, "same-frame production representative image equality")
	for viewport in viewports: viewport.free()
	return {"same_frame_equal": equal, "layers": recipe.coverage.layers.size()}

func snapshot(material: ShaderMaterial) -> Dictionary:
	var result := {}
	for uniform in material.shader.get_shader_uniform_list():
		if uniform.type == TYPE_NIL: continue
		var value: Variant = material.get_shader_parameter(uniform.name)
		result[String(uniform.name)] = {"encoded": FIXED.encoded(value), "display": var_to_str(value) if not value is Resource else value.resource_path}
	return result

func driver_chain(entry: Dictionary) -> Array:
	var result := []
	var recipe: Dictionary = entry.selection.sample
	var provider: Script = load(recipe.player)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(entry.selection.json[0]))
	for layer in recipe.coverage.layers:
		pulse.set_phase("driver-chain:" + layer.name, true)
		var original: ShaderMaterial = provider._material(data.emitters[int(layer.index)])
		var before := snapshot(original)
		original.get_property_list() # Resource.duplicate() performs this exact enumeration first.
		var enumerated := snapshot(original)
		var duplicate: ShaderMaterial = original.duplicate()
		var copied := snapshot(duplicate)
		for name in before:
			if name in FIXED.VARIABLE: continue
			var expected: Dictionary = layer.signature.defaults[name] if before[name].encoded.type == TYPE_NIL else before[name].encoded
			check(enumerated[name].encoded == expected, "enumeration exact declared default or unchanged override: " + name)
			check(copied[name].encoded == expected, "duplicate exact effective value: " + name)
		var item := MeshInstance3D.new(); item.mesh = provider._mesh(data.emitters[int(layer.index)].mesh_path)
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		item.material_override = duplicate
		check(FIXED.signature(item, layer.signature) == layer.signature, "real duplicate typed complete signature")
		item.free()
		result.append({"layer": layer.name, "factory": before, "enumerated": enumerated, "duplicate": copied, "expected": layer.signature})
	return result
