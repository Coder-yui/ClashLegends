extends "res://tests/suites/battle_suite.gd"
const WARMUP = preload("res://scripts/presentation/spell_effect_warmup.gd")

static func check_coverage_revision(parent: Node, camera: Camera3D) -> Dictionary:
	var checks := [0]
	var failures: Array[String] = []
	var check := func(ok: bool, label: String):
		checks[0] += 1
		if not ok: failures.append(label)
	var coverage = WARMUP.COVERAGE
	var sand: Node3D = load("res://assets/effects/sand_ward/player.gd").new()
	parent.add_child(sand)
	sand.setup_native(0.01)
	sand.seek(0.08)
	var declaration: Dictionary = sand.warmup_coverage()
	for bad in [INF, NAN]:
		sand._grains[0].material_override.set_shader_parameter("opacity", bad)
		var errors := PackedStringArray()
		coverage.inspect(sand, declaration, declaration.samples[0], errors)
		check.call(not errors.is_empty(), "reject nonfinite float uniform")
	sand.seek(0.08)
	var host := Node3D.new()
	parent.add_child(host)
	host.position = Vector3(1, 2, 3)
	var skeleton := Skeleton3D.new()
	host.add_child(skeleton)
	skeleton.add_bone("Root")
	skeleton.set_bone_pose_position(0, Vector3(0.2, 0.3, 0.4))
	sand.bind_model(host)
	sand.status_state = Vector2(0.0, 0.08)
	sand.advance_status(true, true, 0.0)
	var expected: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(0)).origin
	check.call(sand.global_position.is_equal_approx(expected), "attached effect follows formal skeleton root anchor")
	var original := StandardMaterial3D.new()
	check.call(sand.make_overlay(original) == original and original.next_pass == null and sand.overlay_instances.is_empty(), "sand does not modify host material chain")
	var draw_calls := [0]
	var errors: PackedStringArray = sand.prepare_resource_sample([], func(): draw_calls[0] += 1)
	check.call(errors.is_empty() and draw_calls[0] == 1, "model context consumes same declaration with exactly one owned draw")
	var invalid: Dictionary = declaration.duplicate(true)
	invalid.states[0].count = 2
	draw_calls[0] = 0
	errors = coverage.prepare_attached(sand, invalid, func(): draw_calls[0] += 1)
	check.call(not errors.is_empty() and draw_calls[0] == 0, "attached mismatch refuses drawing and returns errors")
	sand.free()
	host.free()

	var provider = load("res://assets/effects/malzahar/nether_grasp/player.gd")
	var recipe: Dictionary = provider.resource_manifest("beam").sample
	errors = PackedStringArray()
	var contract: Dictionary = coverage.plan(recipe, errors)
	coverage.validate_sources(contract, errors)
	check.call(errors.is_empty(), "beam declaration/source audit")
	var beam: Node3D = provider.new()
	parent.add_child(beam)
	beam.load_kind("beam")
	beam.setup_resource_sample(camera)
	beam.seek(0.1)
	var counts: Dictionary = coverage.inspect(beam, contract, contract.samples[0], errors)
	check.call(errors.is_empty() and counts == {"beam": 1}, "beam fixed untextured Quad state")
	var footprint := beam_footprint(beam, camera)
	check.call(footprint.size.x > 32.0 and footprint.size.y > 2.0, "representative sample has a real visible footprint, not .01 native scale")
	for age in [0.025, 0.1, 0.5, 1.5]:
		beam.seek(age)
		errors = PackedStringArray()
		coverage.inspect(beam, contract, contract.samples[0], errors)
		check.call(errors.is_empty(), "beam old age keeps audited state " + str(age))
	beam._material.set_shader_parameter("strength", 0.0)
	errors = PackedStringArray()
	coverage.inspect(beam, contract, contract.samples[0], errors)
	check.call(not errors.is_empty(), "representative strength must be positive, not just float")
	beam.set_endpoints(Vector3.ZERO, Vector3.ZERO, camera)
	check.call(not beam.visible, "zero-length formal beam is hidden")
	var camera_transform := camera.global_transform
	camera.position = Vector3(3, 0, 0)
	camera.look_at(Vector3.ZERO)
	beam.set_endpoints(Vector3(-1, 0, 0), Vector3(1, 0, 0), camera)
	check.call(beam.global_transform.is_finite() and absf(beam.global_basis.determinant()) > 0.000001, "view-parallel endpoint fallback remains nondegenerate")
	camera.global_transform = camera_transform
	beam.free()
	return {"passed": failures.is_empty(), "checks": checks[0], "failures": failures, "beam_footprint": footprint}

static func beam_footprint(beam: Node3D, camera: Camera3D) -> Rect2:
	var bounds := Rect2(camera.unproject_position(beam._mesh.to_global(Vector3(-0.5, -0.5, 0))), Vector2.ZERO)
	for point in [Vector3(-0.5, 0.5, 0), Vector3(0.5, -0.5, 0), Vector3(0.5, 0.5, 0)]:
		bounds = bounds.expand(camera.unproject_position(beam._mesh.to_global(point)))
	return bounds

## Standalone CPU probe calls only this method, not the broad full-suite setup.
static func check_static_coverage(parent: Node) -> Dictionary:
	var provider = load("res://assets/effects/sand_ward/player.gd")
	var contract = WARMUP.COVERAGE
	var failures: Array[String] = []
	var checks := [0]
	var check := func(ok: bool, label: String):
		checks[0] += 1
		if not ok: failures.append(label)
	var errors := PackedStringArray()
	var recipe: Dictionary = provider.resource_manifest("ward").sample
	var coverage: Dictionary = contract.plan(recipe, errors)
	contract.validate_sources(coverage, errors)
	check.call(not coverage.is_empty() and errors.is_empty(), "valid provider declaration + shader source audit")
	check.call(contract.plan({}, errors).strategy == contract.LEGACY and errors.is_empty(), "explicit migration policy for undeclared old providers")
	for bad in [null, [], {}, {"strategy": "unknown"}, {"strategy": contract.STATIC, "version": []}]:
		var rejected := PackedStringArray()
		check.call(contract.plan({"coverage": bad}, rejected).is_empty() and not rejected.is_empty(), "reject malformed/unknown declaration")
	var missing: Dictionary = coverage.duplicate(true)
	missing.samples[0].states = ["shell"]
	var rejected := PackedStringArray()
	check.call(contract.plan({"coverage": missing}, rejected).is_empty() and not rejected.is_empty(), "reject uncovered declared state")
	var wrong_modes: Dictionary = coverage.duplicate(true)
	wrong_modes.states[0].render_modes.erase("cull_back")
	rejected = PackedStringArray()
	contract.validate_sources(wrong_modes, rejected)
	check.call(not rejected.is_empty(), "reject mismatched shader render modes")
	var player: Node3D = provider.new()
	parent.add_child(player)
	player.setup_native(0.01)
	var legacy_ages: Array = WARMUP.sample_ages(player._data)
	check.call(legacy_ages == [0.025, 0.05, 0.1, 0.2, 0.4, 0.8, 1.5], "original age coverage is seven visible samples")
	for age in [0.0, 0.08, 0.38, 1.999] + legacy_ages:
		player.seek(age)
		errors = PackedStringArray()
		var counts: Dictionary = contract.inspect(player, coverage, coverage.samples[0], errors)
		check.call(errors.is_empty() and counts == {"shell": 1, "grain": 24}, "all lifecycle/old ages keep exactly the two declared states: " + str(age) + str(errors))
		if not errors.is_empty():
			player.free()
			return {"passed": false, "checks": checks[0], "failures": failures, "legacy_ages": legacy_ages}
	player.seek(2.0)
	check.call(not player.visible, "terminal lifecycle is hidden, no new drawing state")
	player.seek(0.08)
	var grain: MeshInstance3D = player._grains[0]
	var material: Material = grain.material_override
	var reject_actual := func(label: String):
		var actual_errors := PackedStringArray()
		contract.inspect(player, coverage, coverage.samples[0], actual_errors)
		check.call(not actual_errors.is_empty(), label)
	grain.material_overlay = ShaderMaterial.new()
	reject_actual.call("reject material overlay")
	grain.material_overlay = null
	material.next_pass = ShaderMaterial.new()
	reject_actual.call("reject next_pass")
	material.next_pass = null
	grain.skin = Skin.new()
	reject_actual.call("reject skin")
	grain.skin = null
	grain.hide()
	reject_actual.call("reject missing/hidden representative")
	grain.show()
	grain.mesh.size *= 2.0
	reject_actual.call("reject changed primitive geometry")
	grain.mesh.size /= 2.0
	var extra := MeshInstance3D.new()
	extra.mesh = ImmediateMesh.new()
	player.add_child(extra)
	reject_actual.call("reject dynamic/extra/late mesh even when hidden")
	extra.free()
	# Real consumption reconstructs the player and follows status, not the warmup seek API.
	var live: Node3D = provider.new()
	parent.add_child(live)
	live.configure(18.0)
	live.status_state = Vector2(0.0, 0.4)
	live.advance_status(true, true, 0.0)
	errors = PackedStringArray()
	contract.inspect(live, coverage, coverage.samples[0], errors)
	check.call(errors.is_empty() and live._shell.mesh != player._shell.mesh and live._shell.material_override != player._shell.material_override, "formal instance uses distinct geometry/materials but same audited states")
	live.advance_status(true, false, 0.0)
	check.call(not live.visible, "temporarily hidden status")
	live.advance_status(true, true, 0.0)
	check.call(live.visible, "resume status")
	live.advance_status(false, true, 0.0)
	check.call(not live.visible, "status removal")
	live.free()
	player.free()
	return {"passed": failures.is_empty(), "checks": checks[0], "failures": failures, "legacy_ages": legacy_ages}

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var retention := check_retained_identity()
	_expect(retention.passed, "保留资源身份、顺序、晚出现资源及会话释放与线性参考一致：" + str(retention.failures))
	var coverage := check_static_coverage(main.get_tree().root)
	_expect(coverage.passed, "静态覆盖契约/生命周期及拒绝边界：" + str(coverage.failures))
	var revision := check_coverage_revision(main._battle_presentation._world_root, main._battle_presentation._camera)
	_expect(revision.passed, "覆盖有限值、附属所有权与端点合同：" + str(revision.failures))
	await _selection_boundaries()
	_declaration_contract()
	_sett_selection()
	_deployment_plans()
	var cards := {"target_dummy": true, "sett": true, "anivia": true, "sion": true, "aurelionsol": true, "kayle_ranged": true, "gwen": true, "tristana": true, "sun_disc": true, "lightning": true, "zap": true, "stasis": true, "explosive_cask": true, "malzahar": true}
	var resources := MatchResources.new()
	resources.prepare(cards.keys())
	_expect(resources.errors.is_empty(), "调整后的法术资源完整加载")
	var paths := WARMUP.dependency_paths(cards)
	_expect(paths.size() > 20, "JSON内部纹理依赖纳入收集")
	for path in paths: _expect(resources.resources.has(path), "本局强引用法术依赖：" + path)
	_expect(WARMUP.dependency_paths({"garen": true}).is_empty(), "非本局法术不额外收集")
	var presentation: BattlePresentation3D = main._battle_presentation
	var warm = WARMUP.new()
	var child_count := presentation._world_root.get_child_count()
	var viewport_children := presentation._viewport.get_child_count()
	var event_id: int = main._presentation_event_id
	await warm.prepare(cards, presentation._world_root, presentation._camera)
	_expect(warm.prepared.size() == cards.size() and not warm.retained.is_empty(), "法术与烈阳技能播放器完成绘制准备并保留资源")
	_expect(presentation._world_root.get_child_count() == child_count, "预热样本清理无残留节点")
	_expect(main._presentation_event_id == event_id and main._spell_system.stasis_effects.is_empty() and main._spell_system.cask_effects.is_empty() and main._skill_presentation.shield_effects.is_empty(), "预热不发布战斗事件或权威法术")
	_expect(presentation._viewport.get_child_count() == viewport_children, "天使2D预热样本清理无残留")
	var failures := PackedStringArray()
	for request in WARMUP.MANIFEST.requests(cards, null, CardDB.all()):
		var manifest: Dictionary = WARMUP.MANIFEST.resolve(request, failures)
		if not manifest.has("sample"): continue
		var recipe: Dictionary = manifest.sample
		var player: Script = load(recipe.player)
		if not manifest.has("json"):
			_expect(not recipe.times.is_empty(), "程序化效果声明预热采样时刻：" + recipe.kind)
			for path in manifest.paths:
				_expect(warm.retained.any(func(resource): return resource is ShaderMaterial and resource.shader.resource_path == path), "程序化效果实际采样并保留Shader材质：" + path)
			continue
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest.json[0]))
		var expected := 0
		for layer in data.emitters.size():
			if player.has_method("layer_enabled") and not player.layer_enabled(recipe.kind, String(data.emitters[layer].name)): continue
			var minimum := 2 if data.emitters[layer].get("trail") != null else 1
			if data.frames.any(func(frame): return frame[layer].size() >= minimum): expected += 1
		var key: String = request.card + "/" + recipe.kind
		_expect(int(warm.sampled_layers.get(key, -1)) == expected, "原版层逐层完成预热：" + key)
	_expect(failures.is_empty(), "效果声明全部可解析")
	var retained_count: int = warm.retained.size()
	await warm.prepare(cards, presentation._world_root, presentation._camera)
	_expect(warm.retained.size() == retained_count, "重复准备不重建粒子资源")
	var partial = WARMUP.new()
	var calls := [0]
	await partial.prepare({"anivia":true}, presentation._world_root, presentation._camera, func(): calls[0] += 1; return calls[0] > 4)
	_expect(partial.prepared.is_empty() and presentation._viewport.get_child_count() == viewport_children and presentation._world_root.get_child_count() == child_count, "采样中途取消清理2D/3D节点且不标为完成")
	var cancelled = WARMUP.new()
	await cancelled.prepare(cards, presentation._world_root, presentation._camera, func(): return true)
	_expect(cancelled.prepared.is_empty() and cancelled.retained.is_empty(), "取消加载不创建预热资源")
	var shader_cancelled = WARMUP.new()
	var shader_calls := [0]
	var shader_recipe: Dictionary = preload("res://assets/effects/malzahar/nether_grasp/player.gd").resource_manifest("beam").sample
	await shader_cancelled._sample("malzahar", shader_recipe, presentation._world_root, presentation._camera, func(): shader_calls[0] += 1; return shader_calls[0] > 1)
	_expect(not shader_cancelled.retained.is_empty() and shader_calls[0] == 2, "程序化效果实际采样后响应取消")
	_expect(presentation._world_root.get_child_count() == child_count, "程序化效果取消后清理节点且不读取粒子池")

## Narrow resource-only contract; also callable without the heavy suite fixture.
func check_retained_identity() -> Dictionary:
	var failures: Array[String] = []
	var snapshots: Array = []
	var linear: Array[Resource] = []
	var warm = WARMUP.new()
	var root := Node.new()
	var mesh := MeshInstance3D.new()
	var geometry := ArrayMesh.new()
	var material := ShaderMaterial.new()
	mesh.mesh = geometry
	mesh.material_override = material
	root.add_child(mesh)
	var polygon := Polygon2D.new()
	var texture := PlaceholderTexture2D.new()
	var canvas_material := ShaderMaterial.new()
	polygon.texture = texture
	polygon.material = canvas_material
	root.add_child(polygon)
	var duplicate := MeshInstance3D.new()
	duplicate.mesh = geometry
	duplicate.material_override = material
	root.add_child(duplicate)
	_retention_snapshot("first_age", root, linear, warm, snapshots, failures)
	_retention_snapshot("repeated_age", root, linear, warm, snapshots, failures)
	var late_geometry := ArrayMesh.new()
	var late_material := ShaderMaterial.new()
	var late_texture := PlaceholderTexture2D.new()
	var same_path_distinct_identity := late_material.resource_path == material.resource_path and late_material.get_instance_id() != material.get_instance_id()
	if not same_path_distinct_identity:
		failures.append("fixture must contain distinct resources with the same empty path")
	mesh.mesh = late_geometry
	mesh.material_override = late_material
	polygon.texture = late_texture
	var late_child := MeshInstance3D.new()
	late_child.mesh = ImmediateMesh.new()
	late_child.material_override = material
	late_child.hide()
	mesh.add_child(late_child)
	_retention_snapshot("late_material_mesh_texture_and_child", root, linear, warm, snapshots, failures)
	# Mutating an existing dynamic mesh must not make a later traversal skip its new child.
	var immediate: ImmediateMesh = late_child.mesh
	immediate.clear_surfaces()
	var surface_material: ShaderMaterial = ShaderMaterial.new()
	var surface_weak: WeakRef = weakref(surface_material)
	immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES, surface_material)
	immediate.surface_add_vertex(Vector3.ZERO)
	immediate.surface_add_vertex(Vector3.RIGHT)
	immediate.surface_add_vertex(Vector3.UP)
	immediate.surface_end()
	surface_material = null
	var late_surface_material_owned := surface_weak.get_ref() != null
	if not late_surface_material_owned: failures.append("retained mutable mesh did not own its later surface material")
	var last_child := Polygon2D.new()
	last_child.texture = texture
	last_child.material = ShaderMaterial.new()
	late_child.add_child(last_child)
	_retention_snapshot("late_descendant_under_seen_dynamic_mesh", root, linear, warm, snapshots, failures)
	var replacement_surface := ShaderMaterial.new()
	immediate.surface_set_material(0, replacement_surface)
	_retention_snapshot("later_surface_material_on_same_mesh", root, linear, warm, snapshots, failures)
	if immediate.surface_get_material(0) != replacement_surface or not warm.retained.has(immediate):
		failures.append("later surface material no longer reachable through the retained mesh")
	warm.release_retained_resources()
	if not warm.retained.is_empty() or not warm._retained_ids.is_empty(): failures.append("session release did not clear both containers")
	linear.clear()
	_retention_snapshot("new_session_after_release", root, linear, warm, snapshots, failures)
	root.free()
	linear.clear()
	warm.release_retained_resources()
	# Only the retained Array should keep this resource alive after its node and local ref disappear.
	var lifetime = WARMUP.new()
	var weak: WeakRef = _retention_lifetime_fixture(lifetime)
	var strong_until_release := _retention_weak_alive(weak)
	if not strong_until_release: failures.append("retained Array failed to keep resource alive")
	lifetime.release_retained_resources()
	var freed_after_release := not _retention_weak_alive(weak)
	if not freed_after_release: failures.append("resource remained referenced after session release")
	return {"passed": failures.is_empty(), "failures": failures, "snapshots": snapshots,
		"same_path_distinct_identity": same_path_distinct_identity, "late_surface_material_owned": late_surface_material_owned, "strong_until_release": strong_until_release, "freed_after_release": freed_after_release}

func _retention_lifetime_fixture(warm: RefCounted) -> WeakRef:
	# Drop node/resource locals in this frame before checking the weak reference.
	var node := MeshInstance3D.new()
	var material := ShaderMaterial.new()
	var weak: WeakRef = weakref(material)
	node.material_override = material
	warm._retain(node)
	node.free()
	return weak

func _retention_weak_alive(weak: WeakRef) -> bool:
	# The temporary Resource returned by get_ref must not survive in the caller's frame.
	return weak.get_ref() != null

func _retention_snapshot(label: String, node: Node, linear: Array[Resource], warm: RefCounted, snapshots: Array, failures: Array[String]) -> void:
	var old_before := linear.size()
	var new_before: int = warm.retained.size()
	_linear_retain_reference(node, linear)
	warm._retain(node)
	var old_ids := linear.map(func(resource): return resource.get_instance_id())
	var new_ids: Array = warm.retained.map(func(resource): return resource.get_instance_id())
	var old_types := {}
	var new_types := {}
	for resource in linear.slice(old_before): old_types[resource.get_class()] = int(old_types.get(resource.get_class(), 0)) + 1
	for resource in warm.retained.slice(new_before): new_types[resource.get_class()] = int(new_types.get(resource.get_class(), 0)) + 1
	if old_ids != new_ids: failures.append(label + ": identity or order differs")
	if old_types != new_types or old_ids.slice(old_before) != new_ids.slice(new_before): failures.append(label + ": appended resource/statistics differ")
	snapshots.append({"stage": label, "old_ids": old_ids, "new_ids": new_ids,
		"appended_ids": new_ids.slice(new_before), "appended_types": new_types})

func _linear_retain_reference(node: Node, result: Array[Resource]) -> void:
	# Frozen pre-optimization algorithm, operating on the exact same resource instances.
	if node is Polygon2D:
		for resource in [node.texture, node.material]:
			if resource != null and resource not in result: result.append(resource)
	if node is MeshInstance3D:
		for resource in [node.mesh, node.material_override]:
			if resource != null and resource not in result: result.append(resource)
	for child in node.get_children(): _linear_retain_reference(child, result)

func _selection_boundaries() -> void:
	var planner = load("res://scripts/presentation/match_resource_plan.gd")
	var blue := ["gwen", "tristana", "sion", "anivia", "freeze", "sun_disc", "aatrox", "mirror"]
	var red := ["gwen", "nocturne", "kayle", "jinx", "darius", "tombstone", "gnar", "garen"]
	var plan: RefCounted = planner.for_match([blue, red], [{"gwen": 0}, {"gwen": 1, "nocturne": 1}])
	_expect(plan.allows("gwen", 0) and plan.allows("gwen", 1), "双方同卡不同技能取并集")
	_expect(not plan.allows("sion") and not plan.allows("freeze"), "普通槽镜像不扩展任何技能")
	_expect(plan.cards.has("kayle_ranged") and plan.cards.has("anivia_egg") and plan.cards.has("imp"), "升级、死亡替身与召唤物闭包保留")
	_expect(not plan.definition("aatrox").has("transformed_stats") and not plan.definition("jinx").has("transformed_stats"), "未携带主动不加载主动专属形态")
	_expect(plan.definition("gnar").has("transformed_stats") and plan.definition("sion").has("transformed_stats"), "被动变形与复活仍保留")
	_expect(plan.definition("darius").has("visual_active_buff_scene") and plan.definition("jinx").has("visual_active_buff_scene"), "被动表现不随主动资格移除")
	_expect(not plan.definition("melee_minion").has("visual_active_buff_scene"), "系统兵线不预热未携带的男爵之力")
	var resources := MatchResources.new()
	resources.plan = plan
	resources.prepare(blue + red + MatchResources.SYSTEM_UNIT_BUDGET.keys())
	_expect(resources.errors.is_empty(), "有限计划资源完整加载")
	_expect(resources.cards.size() == plan.cards.size(), "资源收集与可达闭包一致")
	_expect(not resources.resources.has("res://assets/units/aatrox/ultimate_view.tscn"), "未选主动形态未进入实际资源集合")
	var forbidden := {"sion": true, "sun_disc": true}
	var planned_paths := WARMUP.dependency_paths(plan.cards, plan)
	for path in WARMUP.dependency_paths(forbidden):
		# 允许其他本局特效引用同一文件；按资源路径去重，不按技能强删共享素材。
		if path not in planned_paths:
			_expect(not resources.resources.has(path), "未携带技能独占依赖未加载：" + path)
	_expect(not plan.definition("anivia").audio.events.has("frost_storm:start"), "未选风暴的专属声音不加载")
	_expect(plan.definition("anivia").audio.events.has("attack_launch"), "普通攻击声音保留")
	_expect(not plan.definition("gwen", 0).audio.events.has("sanctuary:sustain") and plan.definition("gwen", 1).audio.events.has("sanctuary:sustain"), "双方技能声音按各自选择过滤")
	_expect("res://assets/effects/stasis/bard_swirl.png" not in planned_paths, "没有凝滞不加载金身纹理")
	var gold_plan: RefCounted = planner.for_match([["gwen", "tristana", "stasis"], []], [{}, {}])
	_expect(not gold_plan.allows("stasis") and "res://assets/effects/stasis/bard_swirl.png" in WARMUP.dependency_paths(gold_plan.cards, gold_plan), "普通槽凝滞也需要金身资源")
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var owner := ModelVisualResources.new()
	owner.bind_model(root, {}, ModelVisualResources.tool_material_states())
	_expect(owner._gold == null and owner._gold_overlays.is_empty(), "模型初始化不创建金身材质")
	owner.apply_overlays(false, false, false, true)
	_expect(owner._gold != null and owner._gold_overlays.size() == 1, "凝滞采样时才创建金身材质")
	owner.clear()
	root.free()
	var presentation: BattlePresentation3D = _main._battle_presentation
	var warm = WARMUP.new()
	await warm.prepare(plan.cards, presentation._world_root, presentation._camera, Callable(), plan)
	_expect(not warm.sampled_layers.has("sion/Cas") and not warm.sampled_layers.has("anivia/storm"), "未携带技能未创建实际预热粒子")
	_expect(warm.sampled_layers.has("tristana/missile") and warm.sampled_layers.has("tristana/rapid") and warm.sampled_layers.has("anivia/missile"), "普攻始终保留而主动按槽选择")
	_expect(not warm.prepared.has("sun_disc"), "未携带烈阳不预热护盾")
	var specs := MatchModelPool.build_specs(resources.cards, plan)
	_expect(not specs.has("res://assets/units/aatrox/ultimate_view.tscn"), "模型池同样排除不可达形态")
	for uses in specs.values():
		for use in uses:
			_expect(int(use.team) in plan.cards[use.id], "模型池仅准备可出现的阵营")
	blue = ["mirror", "tristana", "sion", "anivia", "freeze", "sun_disc", "aatrox", "gwen"]
	var mirrored: RefCounted = planner.for_match([blue, red], [{"gwen": 1}, {"gwen": 0, "nocturne": 1}])
	_expect(mirrored.allows("sion", 0) and mirrored.allows("freeze", 0) and mirrored.allows("gwen", 1), "主动槽镜像扩展本方各卡确定的技能选择")
	_expect(not mirrored.allows("jinx") and not mirrored.allows("nocturne", 0), "主动镜像不扩展敌方牌或未选候选")
	_expect(mirrored.definition("aatrox").has("transformed_stats"), "主动镜像可达形态进入加载")
	var squad: RefCounted = planner.for_match([["melee_minion_squad", "kayn", "kayle"], []], [{}, {}])
	_expect(squad.allows("melee_minion") and squad.allows("kayn_assassin") and squad.allows("kayn_slayer"), "编队与成长继承主动资格")
	_expect(not squad.allows("kayle_ranged"), "普通槽升级卡不会凭空获得主动资格")
	_expect(CardDB.get_card("aatrox").has("transformed_stats") and CardDB.active_skills_for("gwen").size() == 2, "资源过滤不修改共享战斗定义")

func _declaration_contract() -> void:
	var planner = load("res://scripts/presentation/match_resource_plan.gd")
	var ordinary: RefCounted = planner.for_match([["garen", "ashe", "stasis", "tombstone"], ["gnar"]], [{}, {}])
	_expect(ordinary.errors.is_empty() and ordinary.target_states.has("stasis") and not ordinary.target_states.has("freeze"), "普通槽凝滞声明全场金身能力，不依赖主动资格")
	_expect(ordinary.cards.imp == [0] and not ordinary.allows("imp"), "墓碑依赖自动展开本方雾行者且不赋予主动技能")
	var without: RefCounted = planner.for_match([["garen", "ashe", "tombstone"], ["gnar"]], [{}, {}])
	_expect(without.target_states.is_empty(), "没有状态来源时不准备金身或冰冻")
	var resources := MatchResources.new()
	resources.plan = ordinary
	resources.prepare(ordinary.cards.keys())
	_expect(resources.errors.is_empty() and resources.raw_files.has("res://assets/effects/stasis/native/flight/sampled.json"), "原始JSON也进入本局可检查文件清单")
	var before := resources.resources.size()
	resources.prepare(["anivia"])
	_expect(not resources.cards.has("anivia") and resources.resources.size() == before and not resources.errors.is_empty(), "固定计划拒绝局中静默扩展未声明卡牌")
	var validator = load("res://scripts/data/card_validator.gd")
	var shapes = load("res://scripts/data/card_shape_validator.gd")
	var failures := PackedStringArray()
	shapes.validate("bad", {"resource_dependencies": {"effects": [{"provider": 3, "variant": "default"}]}}, failures)
	_expect(not failures.is_empty(), "效果提供者类型错误被前置校验拒绝")
	failures.clear()
	validator._validate_resource_dependencies("bad", {"resource_dependencies": {"effects": [{"provider": "res://scripts/presentation/stasis_spell_effect_3d.gd", "variant": "missing"}]}}, failures, true)
	_expect(not failures.is_empty(), "不存在的效果变体不能静默漏加载")
	failures.clear()
	validator._validate_resource_dependencies("bad", {"resource_dependencies": {"fields": ["hp"]}}, failures, false, {"hp": 100}, true)
	_expect(not failures.is_empty(), "资源字段所有权不能修改权威生命字段")
	failures.clear()
	validator._validate_resource_dependencies("bad", {"resource_dependencies": {"effects": [{"provider": "res://scripts/presentation/match_resource_plan.gd", "variant": "default"}]}}, failures, true)
	_expect(not failures.is_empty(), "没有提供者接口的脚本声明被拒绝")
	# 不以英雄名单识别金身来源：同一效果模块可由新的能力声明引用。
	var declared: Array[Dictionary] = []
	WARMUP.MANIFEST.collect_requests({"resource_dependencies": {"effects": [{"provider": "res://scripts/presentation/stasis_spell_effect_3d.gd", "variant": "default"}]}}, "future_card", declared)
	failures.clear()
	_expect("stasis" in WARMUP.MANIFEST.resolve(declared[0], failures).target_states and failures.is_empty(), "新卡复用效果契约即可声明金身，不修改中央规划器")
	var presentation: BattlePresentation3D = _main._battle_presentation
	presentation.prepare_target_states(ordinary.target_states)
	var towers := 0
	for child in presentation._world_root.get_children():
		if child is TowerModel3D and not child._source.is_king:
			towers += 1
			_expect(not child._stasis_visible and not CombatInteraction.in_stasis(child._source), "防御塔金身预热不修改战斗状态")
			for materials in child._surface_materials_by_name.values():
				for material in materials:
					_expect(material.get_shader_parameter("stasis_swirl") != null and is_zero_approx(float(material.get_shader_parameter("stasis_amount"))), "防御塔金身纹理准备后恢复正常显示")
	_expect(towers == 4, "双方四座防御塔参与金身准备，水晶排除")

func _sett_selection() -> void:
	var planner = load("res://scripts/presentation/match_resource_plan.gd")
	var inactive: RefCounted = planner.for_match([["garen", "anivia", "sett"], []], [{}, {}])
	var active: RefCounted = planner.for_match([["sett", "garen"], []], [{}, {}])
	var off := WARMUP.dependency_paths(inactive.cards, inactive)
	var on := WARMUP.dependency_paths(active.cards, active)
	_expect(not off.any(func(path): return path.begins_with("res://assets/effects/sett/")), "普通槽腕豪不预热不可达的豪意/W特效")
	for kind in ["warning", "min", "max", "full_body", "cast_body"]:
		_expect(active.effects.any(func(request): return request.variant == kind and request.provider == "res://assets/effects/sett/player.gd"), "主动腕豪声明特效：" + kind)
	for shader in ["body_mix", "body_add", "body_add_overlay", "body_pure_add", "add_overlay", "mix_overlay", "warp_overlay"]:
		_expect("res://assets/effects/sett/" + shader + ".gdshader" in on, "运行时着色器路径进入资源计划：" + shader)

func _deployment_plans() -> void:
	var groups := ["minion_squad", "melee_minion_squad", "ranged_minion_squad", "heavy_minion_squad", "super_minion_squad", "siege_minion_squad"]
	var planner = load("res://scripts/presentation/match_resource_plan.gd")
	var plan: RefCounted = planner.for_match([groups, []], [{}, {}])
	var expected := groups + ["melee_minion", "ranged_minion", "super_minion", "siege_minion"]
	_expect(CardDB.all().size() == 77 and CardDB.selectable_ids().size() == 64 and plan.errors.is_empty() and plan.cards.size() == expected.size() and expected.all(func(id): return plan.cards.has(id)), "六编队改为生成计划后保持77定义/64可选及相同四种成员可达闭包")
	var resources := MatchResources.new()
	resources.plan = plan
	# 不把成员作为额外根传入，避免系统兵线恰好兜底掩盖递归收集失效。
	resources.prepare(groups)
	_expect(resources.errors.is_empty() and resources.cards.size() == plan.cards.size(), "实际资源收集递归生成计划成员，与计划闭包一致")
	var specs := MatchModelPool.build_specs(resources.cards, plan)
	var targets := {"melee_minion": 18, "ranged_minion": 16, "super_minion": 10, "siege_minion": 12}
	for id in targets:
		for team in [0, 1]:
			var path := PresentationConfig.scene_path(CardDB.get_card(id), team)
			_expect(resources.resources.has(path) and specs.has(path) and specs[path].any(func(use): return use.id == id and use.team == team and use.count == (targets[id] if team == 0 else 4)), "成员模型与两波库存按生成数量进入预热：%s 阵营%d" % [id, team])
	for id in groups:
		var single: RefCounted = planner.for_match([[id], []], [{}, {}])
		for member in CardDB.get_card(id).spawn_plan.members:
			_expect(single.cards.has(member) and single.allows(member, 0, 0), "主动槽编队保留成员的技能/音频/效果可达资格：" + id)
		_expect(not specs.values().any(func(uses): return uses.any(func(use): return use.id == id)), "生成计划本身不预建伪实体模型：" + id)
	var melee_path := PresentationConfig.scene_path(CardDB.get_card("melee_minion"), 0)
	var active: RefCounted = planner.for_match([["melee_minion_squad"], []], [{}, {}])
	var inactive: RefCounted = planner.for_match([["garen", "ashe", "melee_minion_squad"], []], [{}, {}])
	_expect(active.definition("melee_minion", 0).has("visual_active_buff_scene") and not inactive.definition("melee_minion", 0).has("visual_active_buff_scene") and resources.resources.has(melee_path), "成员基础模型始终准备，男爵覆层仍只随主动资格进入闭包")
