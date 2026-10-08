extends RefCounted
## 通用效果准备执行器：选择归卡牌，资源和采样配方归效果提供者。
const MANIFEST = preload("res://scripts/presentation/effect_resource_manifest.gd")
var retained: Array[Resource] = []
var prepared: Array[String] = []
var draws := 0
var sampled_layers: Dictionary = {}
var errors := PackedStringArray()
var _completed: Dictionary = {}

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
			var key: String = request.provider + ":" + request.variant
			if manifest.has("sample") or manifest.has("view"): drew = true
			if _completed.has(key): continue
			if manifest.has("sample"): await _sample(card, manifest.sample, world, camera, stop)
			elif manifest.has("view"): await _view(manifest.view, world, camera, stop)
			if stop.is_valid() and bool(stop.call()): return
			_completed[key] = true
		if drew: prepared.append(card)

func _sample(card: String, recipe: Dictionary, world: Node3D, camera: Camera3D, stop: Callable) -> void:
	var kind := String(recipe.kind)
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
			player.setup_native(0.01)
	for age in sample_ages(player._data):
		if stop.is_valid() and bool(stop.call()): break
		if player is Node2D: player.sample(age, 1.0)
		else: player.seek(age)
		_retain(player)
		_draw()
		await world.get_tree().process_frame
	sampled_layers[card + "/" + kind] = player._pools.filter(func(pool): return not pool.is_empty()).size()
	player.free()

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
		_draw()
		await world.get_tree().process_frame
	view.free()

func prepare_ground(presentation: Node, plan: RefCounted, stop: Callable) -> void:
	for request in plan.effects:
		if stop.is_valid() and bool(stop.call()): return
		var manifest := MANIFEST.resolve(request, errors)
		if not manifest.has("ground"): continue
		var recipe: Dictionary = manifest.ground
		var ground: Node = presentation.get(recipe.slot)
		await ground.prepare_resource_variant(presentation._camera, request.radius, recipe.variant, stop)

func _draw() -> void:
	if DisplayServer.get_name() == "headless": return
	RenderingServer.force_draw(false)
	draws += 1

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
			if resource != null and resource not in retained: retained.append(resource)
	if node is MeshInstance3D:
		for resource in [node.mesh, node.material_override]:
			if resource != null and resource not in retained: retained.append(resource)
	for child in node.get_children(): _retain(child)
