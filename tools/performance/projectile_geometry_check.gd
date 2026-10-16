extends SceneTree
## 原投影逐顶点合同与Compatibility实际绘制配对；不运行权威模拟，不测FPS/GPU drawcall。
const HEARTBEAT = preload("res://tools/performance/safe_probe_heartbeat.gd")
const JINX = preload("res://scripts/presentation/jinx_projectile_effect.gd")
const CORKI = preload("res://scripts/presentation/corki_projectile_effect.gd")
const JINX_GEOMETRY = preload("res://assets/effects/jinx/rocket_geometry.gd")
const CORKI_GEOMETRY = preload("res://assets/effects/corki/missile_geometry.gd")
var failures: Array[String] = []
var checks := 0
var output := ""
var reference := ""
var viewport: SubViewport
var fixture: Fixture
var owners: Dictionary = {}
var renderers: Dictionary = {}
var inventories: Dictionary = {}
var heartbeat: RefCounted
var mode := "contracts"
var total := 12
var samples := 2

class Fixture extends Node2D:
	var projectiles: Dictionary = {}
	var impact_effects: Array[Dictionary] = []
	func visible_snapshot() -> Dictionary: return projectiles
	func visible_view() -> Dictionary: return projectiles
	func _direction(projectile: Dictionary) -> Vector2: return projectile.direction
	func _visual_position(projectile: Dictionary) -> Vector2: return projectile.pos

class MissileCanvas extends Node2D:
	var provider: GDScript
	var source: Fixture
	var timings: Array[float] = []
	func _draw() -> void:
		var started := Time.get_ticks_usec()
		for projectile in source.projectiles.values():
			if projectile.visual not in [&"corki_missile", &"corki_missile_big"]: continue
			provider.draw_flight(self, projectile.pos, projectile.direction, projectile.visual == &"corki_missile_big")
		timings.append((Time.get_ticks_usec() - started) / 1000.0)

func _initialize() -> void:
	Engine.max_fps = 30
	heartbeat = HEARTBEAT.new(self)
	_run.call_deferred()

func option(key: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(key + "="): return argument.trim_prefix(key + "=")
	return fallback

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _contracts() -> Dictionary:
	var before := OS.get_static_memory_usage()
	JINX.resource_manifest("rocket")
	CORKI.resource_manifest("missile")
	var retained := OS.get_static_memory_usage() - before
	var a: Array = JINX._projected_faces()
	var b: Array = CORKI._projected_faces()
	check(a.is_read_only() and b.is_read_only(), "projection face containers readonly")
	check(a.size() == JINX_GEOMETRY.FACES.size() and b.size() == CORKI_GEOMETRY.FACES.size(), "all original triangles retained in order")
	for index in a.size():
		check(a[index].is_read_only(), "Jinx cached face readonly")
		var face: Dictionary = JINX_GEOMETRY.FACES[index]
		for corner in 3:
			var v: Array = face.v[corner]
			check(a[index].points[corner] == Vector2(-float(v[0]), float(v[2]) * 0.85 - float(v[1]) * 0.53) * 0.25, "Jinx projection exact")
			check(a[index].uvs[corner] == Vector2(float(face.uv[corner][0]), float(face.uv[corner][1])), "Jinx UV exact")
	for index in b.size():
		check(b[index].is_read_only(), "Corki cached face readonly")
		var face: Dictionary = CORKI_GEOMETRY.FACES[index]
		for corner in 3:
			var v: Array = face.v[corner]
			for scale in [0.20, 0.25]:
				var points: PackedVector2Array = b[index].big_points if scale == 0.25 else b[index].points
				check(points[corner] == Vector2(float(v[0]), float(v[2]) * 0.85 - float(v[1]) * 0.53) * scale, "Corki each original scale exact")
			check(b[index].uvs[corner] == Vector2(float(face.uv[corner][0]), float(face.uv[corner][1])), "Corki UV exact")
	for repeat in 100:
		JINX.resource_manifest("rocket")
		CORKI.resource_manifest("missile")
		check(is_same(a, JINX._projected_faces()) and is_same(b, CORKI._projected_faces()), "repeated prepare reuses exact immutable cache")
	return {"jinx_triangles": a.size(), "corki_triangles": b.size(), "preparation_retained_static_bytes": retained,
		"old_packed_constructors_per_projectile": {"jinx_rocket": a.size() * 3, "corki_missile": b.size() * 3}, "current_warm_packed_constructors_per_projectile": 0,
		"allocation_scope": "constructor counts follow executed source loops; retained static bytes are not allocation traffic or malloc counts"}

func _instrument(path: String) -> GDScript:
	var source := FileAccess.get_file_as_string(path)
	check(source.contains("func _draw() -> void:"), "expected real draw entry: " + path)
	source = source.replace("func _draw() -> void:", "func _probe_original_draw() -> void:")
	source += "\nvar _probe_times: Array[float] = []\nfunc _draw() -> void:\n\tvar started := Time.get_ticks_usec()\n\t_probe_original_draw()\n\t_probe_times.append((Time.get_ticks_usec() - started) / 1000.0)\n"
	var script := GDScript.new()
	script.source_code = source
	check(script.reload() == OK, "instrumented source compiles: " + path)
	return script

func _make_owner(side: String) -> void:
	var owner := Node2D.new()
	viewport.add_child(owner)
	owners[side] = owner
	var base := reference if side == "old" else ProjectSettings.globalize_path("res://scripts/presentation")
	var jinx := _instrument(base.path_join("jinx_projectile_effect.gd"))
	var corki := _instrument(base.path_join("corki_projectile_effect.gd"))
	# Both sides hold identical texture paths and ResourceLoader objects before timing.
	var textures := {}
	for pair in [[jinx, "rocket"], [jinx, "bullet"], [corki, "missile"], [corki, "bullet"]]:
		for path in pair[0].resource_manifest(pair[1]).paths:
			textures[path] = pair[0].effect_texture(path).get_instance_id()
	var jinx_node: Node2D = jinx.new()
	owner.add_child(jinx_node)
	jinx_node.setup(fixture)
	var corki_node: Node2D = corki.new()
	owner.add_child(corki_node)
	corki_node.setup(fixture)
	var missiles := MissileCanvas.new()
	missiles.provider = corki
	missiles.source = fixture
	owner.add_child(missiles)
	# Same solid foreground strip verifies Canvas draw ordering/occlusion on both sides.
	var occluder := Polygon2D.new()
	occluder.polygon = PackedVector2Array([Vector2(230, 575), Vector2(490, 575), Vector2(490, 590), Vector2(230, 590)])
	occluder.color = Color(0.2, 0.24, 0.28)
	occluder.z_index = 1
	owner.add_child(occluder)
	renderers[side] = {"jinx": jinx_node, "corki": corki_node, "missiles": missiles}
	var descendants := owner.find_children("*", "", true, false)
	var materials := {}
	for node in descendants:
		if node is CanvasItem and node.material != null:
			var kind: String = node.material.get_class()
			materials[kind] = int(materials.get(kind, 0)) + 1
	inventories[side] = {"node_count": descendants.size() + 1, "material_classes": materials, "textures": textures, "jinx_children": jinx_node.get_child_count()}
	owner.hide()

func _fixture(stage: float) -> void:
	# Full-scene totals, not a per-type multiplier: heavy geometry is included.
	var counts := [2, 4, 4, 1, 1] if total == 12 else [4, 8, 8, 2, 2]
	var projectiles := {}
	var impacts: Array[Dictionary] = []
	if stage < 1.0:
		var id := 0
		for kind_index in counts.size():
			for index in counts[kind_index]:
				var visual: StringName = [&"jinx_rocket", &"jinx_bullet", &"corki_bullet", &"corki_missile", &"corki_missile_big"][kind_index]
				var position := Vector2(110 + kind_index * 115 + (index % 4) * 8, 200 + (index / 4) * 70 + stage * 280)
				projectiles[id] = {"visual": visual, "pos": position, "direction": Vector2.from_angle(-PI * 0.5 + float(index % 3 - 1) * 0.45), "radius": 4.0}
				id += 1
	elif stage < 2.0:
		for index in total:
			var kind_index := index % 3
			impacts.append({"visual": [&"jinx_explosion", &"corki_explosion", &"corki_explosion_big"][kind_index], "pos": Vector2(150 + kind_index * 205 + (index % 2) * 10, 280 + (index / 6) * 72), "radius": 45.0 if kind_index == 0 else 55.0, "duration": 0.6, "timer": (2.0 - stage) * 0.6})
	for projectile in projectiles.values(): projectile.make_read_only()
	projectiles.make_read_only()
	for impact in impacts: impact.make_read_only()
	impacts.make_read_only()
	fixture.projectiles = projectiles
	fixture.impact_effects = impacts
	check(projectiles.size() + impacts.size() <= total, "global scene budget")

func _render_frame(side: String, team: int) -> void:
	for key in owners: owners[key].visible = key == side
	viewport.canvas_transform = Transform2D(PI, Vector2(720, 1280)) if team == 1 else Transform2D.IDENTITY
	for frame in 2:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		for node in renderers[side].values(): node.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
	# No force_draw: normal 30FPS scheduling, and no image readback in timing.

func _last_cpu(side: String) -> float:
	var nodes: Dictionary = renderers[side]
	var total := 0.0
	for key in ["jinx", "corki"]:
		var times: Array = nodes[key]._probe_times
		check(not times.is_empty(), "real draw callback observed: " + side + key)
		if not times.is_empty(): total += float(times.back())
		times.clear()
	check(not nodes.missiles.timings.is_empty(), "real missile draw callback observed: " + side)
	if not nodes.missiles.timings.is_empty(): total += nodes.missiles.timings.back()
	nodes.missiles.timings.clear()
	return total

func _distribution(values: Array) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var sum := 0.0
	for value in sorted: sum += float(value)
	return {"samples": sorted.size(), "mean_ms": sum / maxf(sorted.size(), 1), "p50_ms": sorted[ceili(sorted.size() * 0.5) - 1], "p95_ms": sorted[ceili(sorted.size() * 0.95) - 1], "max_ms": sorted.back()}

func _pixel_difference(a: Image, b: Image) -> Dictionary:
	var first := a.get_data()
	var second := b.get_data()
	var dimensions_match := a.get_size() == b.get_size() and a.get_format() == b.get_format()
	check(dimensions_match, "paired image dimensions and format")
	# Packed array equality executes natively; no multi-million-channel GDScript loop.
	return {"exact": dimensions_match and first == second, "bytes": first.size()}

func _prepare_render() -> void:
	check(DisplayServer.get_name() != "headless", "render checks require real Compatibility renderer")
	check(RenderingServer.get_current_rendering_method() == "gl_compatibility", "Compatibility rendering method")
	if not failures.is_empty(): return
	# Keep the normal 9:16 project window; authoritative capture size stays 720x1280.
	viewport = SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.transparent_bg = false
	root.add_child(viewport)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	root.add_child(display)
	fixture = Fixture.new()
	root.add_child(fixture)
	_make_owner("old")
	_make_owner("current")
	check(inventories.old == inventories.current and inventories.old.jinx_children == 3, "same nodes, texture paths and shared texture resources on both sides")
	heartbeat.set_phase("ready", true)
	# Allow the external supervisor to establish a stable ready RSS baseline.
	for frame in 12: await process_frame

func _captures() -> Array:
	var rows: Array = []
	# Exactly two pairs per invocation; totals12+24 cover both cameras in both states.
	var flight_team := 0 if total == 12 else 1
	for item in [[flight_team, 0.5], [1 - flight_team, 1.4]]:
		var team: int = item[0]
		var stage: float = item[1]
		_fixture(stage)
		heartbeat.set_phase("capture-%d-%.1f" % [team, stage], true)
		await _render_frame("old", team)
		var old_image := viewport.get_texture().get_image()
		await _render_frame("current", team)
		var current_image := viewport.get_texture().get_image()
		var delta := _pixel_difference(old_image, current_image)
		check(delta.exact, "exact Compatibility pixels total=%d team=%d stage=%.1f" % [total, team, stage])
		var label := "%d-team%d-stage%.1f" % [total, team, stage]
		check(old_image.save_png(output.path_join(label + "-old.png")) == OK, "save reference capture")
		check(current_image.save_png(output.path_join(label + "-current.png")) == OK, "save current capture")
		rows.append({"team": team, "stage": stage, "difference": delta, "old": label + "-old.png", "current": label + "-current.png", "projectiles": fixture.projectiles.size(), "impacts": fixture.impact_effects.size()})
		if not failures.is_empty(): break
	return rows

func _timing() -> Array:
	var rows: Array = []
	_fixture(0.5)
	for team in [0, 1]:
		var times := {"old": [], "current": []}
		for side in ["old", "current"]:
			await _render_frame(side, team)
			_last_cpu(side)
		# A single AB then BA pair; small samples cannot imply stable tail quantiles.
		for order in [["old", "current"], ["current", "old"]]:
			for side in order:
				for sample in samples:
					heartbeat.set_phase("timing-team%d-%s-%d" % [team, side, sample], true)
					await _render_frame(side, team)
					times[side].append(_last_cpu(side))
		rows.append({"team": team, "projectiles": fixture.projectiles.size(), "round_order": [["old", "current"], ["current", "old"]], "old_draw_cpu": _distribution(times.old), "current_draw_cpu": _distribution(times.current), "old_samples_ms": times.old, "current_samples_ms": times.current})
	return rows

func _run() -> void:
	var seen := {}
	for argument in OS.get_cmdline_user_args():
		var key := argument.get_slice("=", 0)
		if not argument.contains("=") or key not in ["--mode", "--total", "--samples", "--output", "--reference"] or seen.has(key):
			push_error("Unsupported/duplicate argument; old --render/--counts/--rounds workloads retired: " + argument)
			quit(2)
			return
		seen[key] = true
	mode = option("--mode", "contracts")
	total = int(option("--total", "12"))
	samples = int(option("--samples", "2"))
	if mode not in ["contracts", "capture", "timing"] or option("--total", "12") not in ["12", "24"] or option("--samples", "2") not in ["1", "2", "3"]:
		push_error("Use contracts/capture/timing, global total12/24, samples1..3")
		quit(2)
		return
	if (mode != "contracts" or DisplayServer.get_name() != "headless") and not heartbeat.enabled:
		push_error("Rendering requires tools/performance/safe_probe.py supervision")
		quit(2)
		return
	output = option("--output", "")
	reference = option("--reference", "")
	if output.is_empty() or reference.is_empty():
		push_error("--output and --reference required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	heartbeat.set_phase("geometry-contracts")
	var geometry := _contracts()
	var results: Array = []
	if failures.is_empty() and mode != "contracts":
		await _prepare_render()
		if failures.is_empty():
			if mode == "capture": results = await _captures()
			else: results = await _timing()
	else:
		heartbeat.set_phase("contracts-ready", true)
		await process_frame
	var sources := {}
	for name in ["jinx_projectile_effect.gd", "corki_projectile_effect.gd"]:
		sources[name] = {"reference_sha256": FileAccess.get_sha256(reference.path_join(name)), "current_sha256": FileAccess.get_sha256("res://scripts/presentation/" + name)}
	var result := {"source_sha256": sources, "mode": mode, "total_budget": total, "heavy_geometry_included": 4 if total == 12 else 8, "max_fps": Engine.max_fps, "renderer": RenderingServer.get_current_rendering_method(), "inventories": inventories, "schema": 2, "engine": Engine.get_version_info().string, "checks": checks, "failures": failures, "geometry": geometry, "results": results,
		"scope": "draw callbacks CPU only; immutable fixture isolates geometry from shared-view optimization; timing has no image readback; capture has two pairs only; no simulation/FPS/GPU drawcall/allocator traffic claim; few samples do not establish tail performance",
		"inventory": "each side same Jinx parent+3 children, Corki additive node, missile Canvas, occluder and texture paths; global total includes all five types"}
	FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t") + "\n")
	print("[PROJECTILE_GEOMETRY_RESULT] " + JSON.stringify({"passed": failures.is_empty(), "checks": checks, "output": output}))
	quit(0 if failures.is_empty() else 1)
