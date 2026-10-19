extends RefCounted
## 通用效果准备执行器：选择归卡牌，资源和采样配方归效果提供者。
const MANIFEST = preload("res://scripts/presentation/effect_resource_manifest.gd")
const COVERAGE = preload("res://scripts/presentation/effect_warmup_coverage.gd")
var retained: Array[Resource] = []
# The Array pins identities for this warmup's lifetime; paths do not identify instances.
var _retained_ids: Dictionary = {}
var prepared: Array[String] = []
var draws := 0
var sampled_layers: Dictionary = {}
var errors := PackedStringArray()
var timings := {}
var retained_by_recipe := {}
var draw_usec := 0
var frame_wait_usec := 0
var repeated_draws_skipped := 0
var resource_scan_usec := 0
var _drawn_resources := {}
var _completed: Dictionary = {}
var coverage_reports := {}
# Optional observation only; the normal path never installs this callback.
var diagnostic_observer: Callable

func _observe(stage: String, detail: Dictionary = {}) -> void:
	if diagnostic_observer.is_valid(): diagnostic_observer.call(stage, detail)


static func dependency_paths(cards: Dictionary, plan: RefCounted = null) -> Array[String]:
	var paths: Array[String] = []
	var failures := PackedStringArray()
	for request in MANIFEST.requests(cards, plan, CardDB.all()):
		for path in MANIFEST.files(request, failures).resources:
			if path not in paths: paths.append(path)
	for failure in failures: push_error(failure)
	return paths

class Samples extends RefCounted:
	var shield_effects: Array[Dictionary] = []
	var lightning_effects: Array[Dictionary] = []
	var stasis_effects: Array[Dictionary] = []
	var cask_effects: Array[Dictionary] = []
	var cask_hits: Array[Dictionary] = []

func prepare(cards: Dictionary, world: Node3D, camera: Camera3D, stop: Callable = Callable(), plan: RefCounted = null) -> void:
	var grouped := {}
	for request in MANIFEST.requests(cards, plan, CardDB.all()):
		if not grouped.has(request.card): grouped[request.card] = []
		grouped[request.card].append(request)
	for card in grouped:
		if card in prepared: continue
		var drew := false
		for request in grouped[card]:
			if stop.is_valid() and bool(stop.call()): return
			var manifest := MANIFEST.resolve(request, errors)
			if not errors.is_empty(): return
			var key: String = request.provider + ":" + request.variant
			if manifest.has("sample") or manifest.has("view"): drew = true
			if _completed.has(key): continue
			_observe("recipe_begin", {"card": card, "recipe": key, "age_index": -1, "age_count": 0, "age": -1.0})
			var started := Time.get_ticks_usec()
			var draws_before := draws
			var draw_before := draw_usec
			var wait_before := frame_wait_usec
			var retained_before := retained.size()
			if manifest.has("sample"):
				var recipe: Dictionary = manifest.sample
				if recipe.get("fixed_sampled_layers", false):
					recipe = MANIFEST.files(request, errors).get("selection", {}).get("sample", {})
					if not recipe.get("fixed_sampled_layers", false) or not recipe.has("coverage"):
						errors.append("固定采样层缺少生成产物")
						return
				await _sample(card, recipe, world, camera, stop)
			elif manifest.has("view"): await _view(manifest.view, world, camera, stop)
			if not errors.is_empty(): return
			if stop.is_valid() and bool(stop.call()): return
			var types := {}
			for index in range(retained_before, retained.size()):
				var kind := retained[index].get_class()
				types[kind] = int(types.get(kind, 0)) + 1
			retained_by_recipe[key] = types
			timings[key] = {"total_usec": Time.get_ticks_usec() - started, "draws": draws - draws_before, "draw_usec": draw_usec - draw_before, "frame_wait_usec": frame_wait_usec - wait_before}
			_completed[key] = true
			_observe("recipe_done")
		if drew: prepared.append(card)

func _sample(card: String, recipe: Dictionary, world: Node3D, camera: Camera3D, stop: Callable) -> void:
	if recipe.get("fixed_sampled_layers", false):
		await _sample_fixed_layers(card, recipe, world, camera, stop)
		return
	var kind := String(recipe.kind)
	var coverage := COVERAGE.plan(recipe, errors)
	if coverage.is_empty(): return
	var setup_started := Time.get_ticks_usec()
	var player: Node = load(recipe.player).new()
	if recipe.setup == "2d":
		world.get_parent().add_child(player)
		player.position = Vector2(360, 640)
		player.setup(kind)
		if "wave_radius" in player: player.wave_radius = 80.0
	else:
		world.add_child(player)
		player.position = preload("res://scripts/presentation/spell_effect_projection.gd").ground(camera, Vector2(360, 640))
		if recipe.setup == "native_kind": player.setup_native(0.01, kind)
		else:
			player.load_kind(kind)
			if recipe.setup == "provider_sample":
				if coverage.strategy != COVERAGE.STATIC or not player.has_method("setup_resource_sample"):
					errors.append("声明覆盖缺少提供者代表样本setup")
					player.free()
					return
				player.setup_resource_sample(camera)
			else: player.setup_native(0.01)
	if "preparation_errors" in player and not player.preparation_errors.is_empty():
		errors.append_array(player.preparation_errors)
		player.free()
		return
	var setup_usec := Time.get_ticks_usec() - setup_started
	timings[card + "/" + kind + "/setup_usec"] = setup_usec
	# 采样粒子从数据补齐出生帧；程序化 Shader 效果由提供者声明采样时刻。
	_observe("ages_before", {"player_id": player.get_instance_id()})
	var declared: bool = coverage.strategy == COVERAGE.STATIC
	var ages: Array = coverage.samples.map(func(sample): return sample.age) if declared else (player.resource_sample_ages() if player.has_method("resource_sample_ages") else (sample_ages(player._data) if "_data" in player else recipe.times))
	var report := {"strategy": coverage.strategy, "ages": ages, "seek_usec": 0, "retain_usec": 0, "scan_usec": 0, "samples": [], "temporary_player_freed": false}
	coverage_reports[card + "/" + kind] = report
	_observe("ages_after", {"age_count": ages.size()})
	for age_index in ages.size():
		var age: Variant = ages[age_index]
		if stop.is_valid() and bool(stop.call()): break
		_observe("seek_before", {"age_index": age_index, "age": age})
		var started := Time.get_ticks_usec()
		if player is Node2D: player.sample(age, 1.0)
		else: player.seek(age)
		report.seek_usec += Time.get_ticks_usec() - started
		_observe("seek_after")
		if declared:
			started = Time.get_ticks_usec()
			var states := COVERAGE.inspect(player, coverage, coverage.samples[age_index], errors)
			report.scan_usec += Time.get_ticks_usec() - started
			report.samples.append({"age": age, "states": states})
			if not errors.is_empty(): break
		_observe("retain_before")
		started = Time.get_ticks_usec()
		_retain(player)
		report.retain_usec += Time.get_ticks_usec() - started
		_observe("retain_after")
		# A declared sample is a complete audited state, always actually drawn once.
		# It does not use private material identity to infer more work or reuse.
		if declared: await _draw(world.get_tree())
		else:
			var scan_before := resource_scan_usec
			await _draw_resources(player, world.get_tree())
			report.scan_usec += resource_scan_usec - scan_before
	if "_pools" in player:
		sampled_layers[card + "/" + kind] = player._pools.filter(func(pool): return not pool.is_empty()).size()
	player.free()
	report.temporary_player_freed = true

func _view(recipe: Dictionary, world: Node3D, camera: Camera3D, stop: Callable) -> void:
	var view: Node3D = load(recipe.script).new()
	world.add_child(view)
	var samples := Samples.new()
	var duration := float(recipe.duration)
	var effect := {"id": 1, "kind": recipe.kind, "origin": Vector2(360, 1000), "pos": Vector2(360, 640), "radius": 110.0,
		"start_tick": 0, "impact_tick": 20, "progress": 0.0, "impacted": false, "duration": duration, "timer": duration}
	samples.get(recipe.collection).append(effect)
	for step in 32:
		if stop.is_valid() and bool(stop.call()): break
		var age := float(step) * 0.1
		effect.progress = minf(age, 1.0)
		effect.impacted = age >= 1.0
		effect.timer = duration - (maxf(age - 1.0, 0.0) if recipe.flight else age)
		if recipe.has("hits"):
			var hits: Array = samples.get(recipe.hits)
			if step == 10: hits.append({"id": 1, "pos": effect.pos, "timer": 0.7})
			if not hits.is_empty(): hits[0].timer = maxf(0.0, 0.7 - maxf(age - 1.0, 0.0))
		view.sync_effects(samples, camera)
		_retain(view)
		await _draw_resources(view, world.get_tree())
	view.free()

func prepare_ground(presentation: Node, plan: RefCounted, stop: Callable) -> void:
	for request in plan.effects:
		if stop.is_valid() and bool(stop.call()): return
		var manifest := MANIFEST.resolve(request, errors)
		if not manifest.has("ground"): continue
		var recipe: Dictionary = manifest.ground
		var ground: Node = presentation.get(recipe.slot)
		await ground.prepare_resource_variant(presentation._camera, request.radius, recipe.variant, stop)

## 只复用同一实例资源的已提交绘制；所有年龄仍 seek/保留，新增粒子材质/网格仍绘制。
## 当前播放器只对静态ArrayMesh更新数值uniform；可变网格、多遍、未知/标准材质及2D保持逐样本绘制。
func _draw_resources(node: Node, tree: SceneTree) -> void:
	_observe("resource_scan_before")
	var started := Time.get_ticks_usec()
	var resources := visible_shader_resources(node)
	resource_scan_usec += Time.get_ticks_usec() - started
	_observe("resource_scan_after", {"resource_keys": resources.size(), "force": resources.has("force")})
	if DisplayServer.get_name() != "headless" and not resources.has("force") and resources.keys().all(func(key): return _drawn_resources.has(key)):
		repeated_draws_skipped += 1
		_observe("draw_skipped")
		return
	await _draw(tree)
	_drawn_resources.merge(resources)

static func visible_shader_resources(node: Node) -> Dictionary:
	var result := {}
	if node is GeometryInstance3D and not node is MeshInstance3D: result["force"] = true
	if node is CanvasItem: result["force"] = true
	if node is MeshInstance3D and node.is_visible_in_tree() and node.mesh != null:
		# ImmediateMesh拖尾在同RID内重建顶点，不能省去新缓冲的提交；仅放行已审计静态ArrayMesh。
		if not node.mesh is ArrayMesh or node.mesh.get_script() != null: result["force"] = true
		for surface in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(surface)
			if not material is ShaderMaterial or material.shader == null or node.material_overlay != null or material.next_pass != null:
				result["force"] = true
			else:
				result[var_to_str([node.mesh.get_rid(), surface, material.get_rid(), material.shader.get_rid()])] = true
	for child in node.get_children(): result.merge(visible_shader_resources(child))
	return result

func _draw(tree: SceneTree) -> void:
	var started := Time.get_ticks_usec()
	_observe("draw_wait")
	if DisplayServer.get_name() == "headless":
		await tree.process_frame
	else:
		# 每个原采样仍实际提交绘制；使用自然帧，避免强制画完整战场后又自然画一遍。
		await RenderingServer.frame_post_draw
		draws += 1
	frame_wait_usec += Time.get_ticks_usec() - started
	_observe("draw_resumed")

## 固定持续阶段之外，逐层补首个出生帧，避免短暂/延迟层落在采样间隙。
static func sample_ages(data: Dictionary) -> Array[float]:
	var ages: Array[float] = []
	for age in [0.025, 0.05, 0.1, 0.2, 0.4, 0.8, 1.5, 2.5, 4.0]:
		if age <= float(data.duration): ages.append(age)
	var pending: Array = range(data.emitters.size())
	for index in data.frames.size():
		for layer in pending.duplicate():
			if data.frames[index][layer].is_empty(): continue
			# 拖尾至少两点才形成一段；普通粒子一项即可绘制。
			if data.emitters[layer].get("trail") != null and data.frames[index][layer].size() < 2: continue
			var age := minf((float(index) + 0.25) / float(data.fps), float(data.duration))
			if age not in ages: ages.append(age)
			pending.erase(layer)
		if pending.is_empty(): break
	ages.sort()
	return ages

func _retain(node: Node) -> void:
	if node is Polygon2D:
		for resource in [node.texture, node.material]:
			_retain_resource(resource)
	if node is MeshInstance3D:
		for resource in [node.mesh, node.material_override]:
			_retain_resource(resource)
	for child in node.get_children(): _retain(child)

func _retain_resource(resource: Resource) -> void:
	if resource == null: return
	var identity := resource.get_instance_id()
	if _retained_ids.has(identity): return
	_retained_ids[identity] = true
	retained.append(resource)

func release_retained_resources() -> void:
	_retained_ids.clear()
	retained.clear()

## Generated layer representatives have their own owner, never a formal instance pool.
func _sample_fixed_layers(card: String, recipe: Dictionary, world: Node3D, camera: Camera3D, stop: Callable) -> void:
	const FIXED = preload("res://scripts/presentation/sampled_effect_coverage.gd")
	if not FIXED.valid(recipe.get("coverage", {})):
		errors.append("固定采样层覆盖契约损坏"); return
	var started := Time.get_ticks_usec()
	var player: Node3D = load(recipe.player).new()
	world.add_child(player)
	player.load_kind(recipe.kind)
	var loaded := Time.get_ticks_usec()
	FIXED.prepare(player, recipe.coverage, camera, errors)
	var built := Time.get_ticks_usec()
	if errors.is_empty() and not (stop.is_valid() and bool(stop.call())):
		_retain(player)
		var retained_at := Time.get_ticks_usec()
		await _draw(world.get_tree())
		coverage_reports[card + "/" + recipe.kind] = {"strategy": FIXED.STRATEGY, "layers": recipe.coverage.layers.size(), "template_load_usec": loaded - started, "representatives_usec": built - loaded, "retain_usec": retained_at - built, "pool_transferred": false}
	player.free()
