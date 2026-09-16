class_name MatchModelPool
extends RefCounted
## 本场持有的预建模型；在加载遮罩后实际绘制，使用时移交给正式表现代理。
var instances: Dictionary = {}
var rendered_paths: Dictionary = {}
var _sample_sources: Array[Unit] = []
var _warmed_materials: Array[Material] = []
var warmed_particle_systems: Array[String] = []
var capacity := {}
var errors := PackedStringArray()
var metrics := {}
var _world: Node3D
var cancelled := false
var preparation_times := {"instantiate_usec": 0, "animation_usec": 0, "render_usec": 0, "sample_prepare_usec": 0, "draws": 0, "animation_draws_skipped": 0}

## 每卡/阵营只有一个并发来源；同卡互斥形态同路径取最大，独立来源累加。
## 两轮爆发窗口有界保留；循环依赖只扫描已去重闭包一次，不按整场累计数量扩张。
static func build_specs(cards: Dictionary) -> Dictionary:
	var demand := {}
	for id in cards:
		demand[id] = maxi(int(MatchResources.SYSTEM_UNIT_BUDGET.get(id, 2)), int(CardDB.get_card(String(id)).get("deployment_count", 1)))
	var summoned := {}
	for id in cards:
		var base := CardDB.get_card(String(id))
		var per_source := {}
		for form in range(2 if base.has("transformed_stats") else 1):
			var per_form := {}
			var stats := PresentationConfig.for_form(base, form).duplicate()
			stats.erase("transformed_stats")
			_collect_demand(stats, per_form)
			for child in per_form: per_source[child] = maxi(int(per_source.get(child, 0)), int(per_form[child]))
		for child in per_source: summoned[child] = int(summoned.get(child, 0)) + int(per_source[child]) * int(base.get("deployment_count", 1))
	for child in summoned: demand[child] = maxi(int(demand.get(child, 2)), mini(32, int(summoned[child]) * 2))
	var specs := {}
	for id in cards:
		var base := CardDB.get_card(String(id))
		for team in range(2):
			var seen := {}
			for form in range(2 if base.has("transformed_stats") else 1):
				var stats := PresentationConfig.for_form(base, form)
				var path := PresentationConfig.scene_path(stats, team)
				if path.is_empty(): continue
				if not specs.has(path): specs[path] = []
				# 两个形态仍分别预热映射，但相同路径不重复计算库存。
				specs[path].append({"id": id, "stats": stats, "team": team, "form": form, "count": 0 if seen.has(path) else demand[id]})
				seen[path] = true
	return specs

static func _collect_demand(value: Variant, demand: Dictionary) -> void:
	if value is Dictionary:
		for field in MatchResources.REFERENCES:
			if value.has(field):
				var id := String(value[field])
				var count := int(value.get(String(field).trim_suffix("_id") + "_count", 1))
				demand[id] = int(demand.get(id, 0)) + count
		for child in value.values(): _collect_demand(child, demand)
	elif value is Array:
		for child in value: _collect_demand(child, demand)

func _metric(path: String) -> Dictionary:
	if not metrics.has(path): metrics[path] = {"hits": 0, "misses": 0, "recycled": 0, "active": 0, "peak": 0, "instantiate_usec": 0, "unplanned": 0, "exhausted": 0, "unsupported_recycle": 0}
	return metrics[path]


func prepare(resources: Dictionary, world: Node3D, camera: Camera3D, cards: Dictionary) -> void:
	_world = world
	var tree := world.get_tree()
	var specs := build_specs(cards)
	for path in resources:
		if not (String(path).begins_with("res://assets/units/") or String(path).begins_with("res://assets/effects/")) or not String(path).ends_with(".tscn") or instances.has(path):
			continue
		var packed := resources[path] as PackedScene
		if packed == null: continue
		var batch: Array[Node3D] = []
		# 首波/编队按数量预建；常规卡保留两份，双方不同模型分别准备。
		var uses: Array = specs.get(path, [])
		var count := 2
		if not uses.is_empty():
			count = 0
			for use in uses: count += int(use.count)
		count = mini(count, 64)
		capacity[path] = count
		for index in range(count):
			var started := Time.get_ticks_usec()
			var node := packed.instantiate()
			if not node is Node3D:
				node.free()
				errors.append("模型根节点必须是Node3D: " + String(path))
				return
			node.process_mode = Node.PROCESS_MODE_DISABLED
			world.add_child(node)
			node.hide()
			preparation_times.instantiate_usec += Time.get_ticks_usec() - started
			started = Time.get_ticks_usec()
			if node.has_method("prepare_visual_animations"): node.call("prepare_visual_animations")
			var model_resources := ModelVisualResources.new()
			var player := model_resources.bind_model(node)
			node.set_meta("prepared_model_resources", model_resources)
			node.set_meta("prepared_animation_player", player)
			preparation_times.animation_usec += Time.get_ticks_usec() - started
			node.set_meta("pool_path", path)
			if _can_recycle(node): node.set_meta("pool_state", _capture_state(node))
			batch.append(node)
		if batch.is_empty(): continue
		if uses.is_empty(): uses = [{}]
		var warmed_configs := {}
		for spec in uses:
			var signature := _warm_signature(spec)
			if warmed_configs.has(signature): continue
			warmed_configs[signature] = true
			var sample_started := Time.get_ticks_usec()
			var sample: Node3D
			var source: Unit
			if not spec.is_empty():
				# 使用离树的只读源，不生成权威单位、不派发出生事件或音频。
				source = Unit.new()
				source.setup(int(spec.team), spec.stats, String(spec.id))
				_sample_sources.append(source)
				source.form_index = int(spec.form)
				source.net_form_index = int(spec.form)
				source.card_id = String(spec.id)
				source.position = Vector2(360, 640)
				sample = UnitModel3D.new()
				sample.process_mode = Node.PROCESS_MODE_DISABLED
				world.add_child(sample)
				sample.setup(source, packed, camera, spec.stats.get("visual_animations", {}), float(spec.stats.get("visual_forward_yaw", 0.0)), String(spec.stats.get("visual_active_buff_scene", "")))
			else:
				sample = packed.instantiate() as Node3D
				sample.process_mode = Node.PROCESS_MODE_DISABLED
				world.add_child(sample)
			preparation_times.sample_prepare_usec += Time.get_ticks_usec() - sample_started
			# 实例的脚下光圈和蒙皮材质同样需要首次绘制。
			sample.position += Vector3(0, 3, 0)
			for mesh in sample.find_children("*", "GeometryInstance3D", true, false): mesh.show()
			await tree.process_frame
			if cancelled or not is_instance_valid(world): return
			for player in sample.find_children("*", "AnimationPlayer", true, false):
				if player.is_playing(): player.advance(0.0)
			_draw_sample()
			var sample_meshes := sample.find_children("*", "MeshInstance3D", true, false)
			var drawn_geometry := {mesh_configuration(sample_meshes): true}
			if sample is UnitModel3D:
				# 动作仍全部采样；相同网格/材质的不同骨骼姿势无需重复绘制整场。
				for player in sample.find_children("*", "AnimationPlayer", true, false):
					for animation in player.get_animation_list():
						sample._set_model_visual_clip(animation)
						player.play(animation, 0.0)
						player.advance(0.0)
						var configuration := mesh_configuration(sample_meshes)
						if not drawn_geometry.has(configuration):
							_draw_sample()
							drawn_geometry[configuration] = true
						else: preparation_times.animation_draws_skipped += 1
				if is_instance_valid(sample._active_buff_visual):
					sample._active_buff_visual.advance(true, 0.1)
				for state in range(6):
					sample._model_resources.apply_overlays(state % 3 == 1, state % 3 == 2, state >= 3)
					for mesh in sample._model_resources.meshes():
						if mesh.material_overlay != null: _warmed_materials.append(mesh.material_overlay)
					# force_draw提交当前状态，不额外等待一个垂直同步帧。
					_draw_sample()
			rendered_paths[path] = true
			# 保留绘制资源/骨骼/材质实例；样本不再播放，不需持有独立的巨大动画副本。
			for player in sample.find_children("*", "AnimationPlayer", true, false):
				player.stop()
				for library in player.get_animation_library_list(): player.remove_animation_library(library)
			sample.hide()
		instances[path] = batch

	# 原生粒子在代码中按名称选择，不是卡牌字段里的场景引用。
	# 预播全部已接入系统，加载纹理/网格并保留材质缓存；不接入战斗事件。
	for system_name in LolParticleEffect3D.dependencies_for(cards):
		if String(system_name) in warmed_particle_systems: continue
		var effect := LolParticleEffect3D.new()
		effect.process_mode = Node.PROCESS_MODE_DISABLED
		world.add_child(effect)
		effect.position = Vector3(0, 3, 0)
		effect.setup(String(system_name))
		effect.advance(0.1)
		await tree.process_frame
		if cancelled or not is_instance_valid(world): return
		_draw_sample()
		effect.hide()
		warmed_particle_systems.append(String(system_name))

func take(packed: PackedScene) -> Node:
	var path := packed.resource_path
	var metric := _metric(path)
	metric.active += 1
	metric.peak = maxi(metric.peak, metric.active)
	var batch: Array = instances.get(path, [])
	if batch.is_empty():
		metric.misses += 1
		if capacity.has(path): metric.exhausted += 1
		else: metric.unplanned += 1
		var started := Time.get_ticks_usec()
		var fresh := packed.instantiate()
		fresh.set_meta("pool_path", path)
		if fresh is Node3D and is_instance_valid(_world) and capacity.has(path):
			_world.add_child(fresh)
			if fresh.has_method("prepare_visual_animations"): fresh.call("prepare_visual_animations")
			var owner := ModelVisualResources.new()
			fresh.set_meta("prepared_animation_player", owner.bind_model(fresh))
			fresh.set_meta("prepared_model_resources", owner)
			if _can_recycle(fresh): fresh.set_meta("pool_state", _capture_state(fresh))
			_world.remove_child(fresh)
		metric.instantiate_usec += Time.get_ticks_usec() - started
		fresh.tree_exiting.connect(_returned.bind(path), CONNECT_ONE_SHOT)
		return fresh
	metric.hits += 1
	var instance: Node3D = batch.pop_back()
	instance.get_parent().remove_child(instance)
	instance.process_mode = Node.PROCESS_MODE_INHERIT
	instance.show()
	instance.tree_exiting.connect(_returned.bind(path), CONNECT_ONE_SHOT)
	return instance

## 只回收已审计的无脚本模型；包装必须显式提供重置接口。未支持者保留正确性后备。
func _can_recycle(node: Node) -> bool:
	if node.get_script() != null and not node.has_method("reset_pool_visual"): return false
	for child in node.get_children():
		if not _can_recycle(child): return false
	return true

func _capture_state(node: Node) -> Array:
	var result := []
	if node is Node3D:
		result.append([node, node.transform, node.visible, node.mesh if node is MeshInstance3D else null])
	for child in node.get_children(): result.append_array(_capture_state(child))
	return result

func recycle(node: Node3D, owner: ModelVisualResources, player: AnimationPlayer) -> bool:
	var path := String(node.get_meta("pool_path", ""))
	if path.is_empty(): return false
	var metric := _metric(path)
	if not is_instance_valid(_world) or not node.has_meta("pool_state") or not instances.has(path) or instances[path].size() >= int(capacity.get(path, 0)):
		if not node.has_meta("pool_state"): metric.unsupported_recycle += 1
		return false
	owner.reset_overlays()
	if player != null:
		player.stop()
		player.speed_scale = 1.0
		player.reset_section()
	for state in node.get_meta("pool_state"):
		var child: Node3D = state[0]
		child.transform = state[1]
		child.visible = state[2]
		if child is MeshInstance3D: child.mesh = state[3]
		if child is Skeleton3D: child.reset_bone_poses()
		if child.has_method("reset_pool_visual"): child.call("reset_pool_visual")
	node.get_parent().remove_child(node)
	_world.add_child(node)
	node.hide()
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.set_meta("prepared_model_resources", owner)
	node.set_meta("prepared_animation_player", player)
	instances[path].append(node)
	metric.recycled += 1
	return true

func release_sources() -> void:
	cancelled = true
	for source in _sample_sources:
		if is_instance_valid(source): source.free()
	_sample_sources.clear()
	instances.clear()
	_warmed_materials.clear()
	_world = null

func _draw_sample() -> void:
	if DisplayServer.get_name() == "headless": return
	var started := Time.get_ticks_usec()
	# 加载遮罩内只需完成绘制，不为每个预热状态交换屏幕缓冲。
	RenderingServer.force_draw(false)
	preparation_times.draws += 1
	preparation_times.render_usec += Time.get_ticks_usec() - started

func _returned(path: String) -> void:
	var metric := _metric(path)
	metric.active = maxi(0, metric.active - 1)

static func _warm_signature(spec: Dictionary) -> String:
	var stats: Dictionary = spec.get("stats", {})
	var buff := String(stats.get("visual_active_buff_scene", ""))
	return var_to_str([stats.get("visual_animations", {}), stats.get("visual_forward_yaw", 0.0), buff, spec.get("form", 0), spec.get("team", 0) if not buff.is_empty() else -1])

## 只在加载时使用：骨骼姿势/位置不改变渲染资源，换网格、可见性、材质则必须绘制。
static func mesh_configuration(meshes: Array) -> String:
	var configuration := []
	for mesh: MeshInstance3D in meshes:
		configuration.append(mesh.is_visible_in_tree())
		for resource in [mesh.mesh, mesh.material_override, mesh.material_overlay]:
			configuration.append(resource.get_instance_id() if resource != null else 0)
		if mesh.mesh != null:
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface)
				configuration.append(material.get_instance_id() if material != null else 0)
	return var_to_str(configuration)
