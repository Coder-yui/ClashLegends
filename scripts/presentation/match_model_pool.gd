class_name MatchModelPool
extends RefCounted
## 本场持有的预建模型；在加载遮罩后实际绘制，使用时移交给正式表现代理。
var instances: Dictionary = {}
var rendered_paths: Dictionary = {}
var _sample_sources: Array[Unit] = []
var _warmed_materials: Array[Material] = []
var warmed_particle_systems: Array[String] = []

func prepare(resources: Dictionary, world: Node3D, camera: Camera3D, cards: Dictionary) -> void:
	var specs := {}
	for id in cards:
		var base := CardDB.get_card(String(id))
		for form in range(2):
			var stats := PresentationConfig.for_form(base, form)
			for team in range(2):
				var path := PresentationConfig.scene_path(stats, team)
				if not path.is_empty(): specs[path] = {"id": id, "stats": stats, "team": team}
	for path in resources:
		if not (String(path).begins_with("res://assets/units/") or String(path).begins_with("res://assets/effects/")) or not String(path).ends_with(".tscn") or instances.has(path):
			continue
		var packed := resources[path] as PackedScene
		if packed == null: continue
		var batch: Array[Node3D] = []
		# 首波/编队按数量预建；常规卡保留两份，双方不同模型分别准备。
		var spec: Dictionary = specs.get(path, {})
		var count := 2
		if not spec.is_empty(): count = maxi(4 if String(spec.id).ends_with("minion") else 2, int(spec.stats.get("deployment_count", 1)))
		for index in range(count):
			var node := packed.instantiate()
			if not node is Node3D:
				node.free()
				break
			node.process_mode = Node.PROCESS_MODE_DISABLED
			world.add_child(node)
			node.hide()
			if not node.has_method("configure_unit_visual"):
				if node.has_method("prepare_visual_animations"): node.call("prepare_visual_animations")
				var model_resources := ModelVisualResources.new()
				var player := model_resources.bind_model(node)
				node.set_meta("prepared_model_resources", model_resources)
				node.set_meta("prepared_animation_player", player)
			batch.append(node)
		if batch.is_empty(): continue
		var sample: Node3D
		var source: Unit
		if not spec.is_empty():
			# 使用离树的只读源，不生成权威单位、不派发出生事件或音频。
			source = Unit.new()
			source.setup(int(spec.team), spec.stats, String(spec.id))
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
		# 实例的脚下光圈和蒙皮材质同样需要首次绘制。
		sample.position += Vector3(0, 3, 0)
		for mesh in sample.find_children("*", "GeometryInstance3D", true, false): mesh.show()
		await world.get_tree().process_frame
		for player in sample.find_children("*", "AnimationPlayer", true, false):
			if player.is_playing(): player.advance(0.0)
		if DisplayServer.get_name() != "headless": RenderingServer.force_draw()
		if sample is UnitModel3D:
			# 提前采样所有技能/死亡动作；只处理离树源对应的展示样本。
			for player in sample.find_children("*", "AnimationPlayer", true, false):
				for animation in player.get_animation_list():
					player.play(animation, 0.0)
					player.advance(0.0)
			if is_instance_valid(sample._active_buff_visual):
				sample._active_buff_visual.advance(true, 0.1)
			for state in range(3):
				sample._model_resources.apply_overlays(state == 0, state == 1, state == 2)
				for mesh in sample._model_resources.meshes():
					if mesh.material_overlay != null: _warmed_materials.append(mesh.material_overlay)
				await world.get_tree().process_frame
				if DisplayServer.get_name() != "headless": RenderingServer.force_draw()
		rendered_paths[path] = true
		sample.hide()
		if source != null: _sample_sources.append(source)
		instances[path] = batch

	# 原生粒子在代码中按名称选择，不是卡牌字段里的场景引用。
	# 预播全部已接入系统，加载纹理/网格并保留材质缓存；不接入战斗事件。
	for system_name in LolParticleEffect3D.system_names():
		if String(system_name) in warmed_particle_systems: continue
		var effect := LolParticleEffect3D.new()
		effect.process_mode = Node.PROCESS_MODE_DISABLED
		world.add_child(effect)
		effect.position = Vector3(0, 3, 0)
		effect.setup(String(system_name))
		effect.advance(0.1)
		await world.get_tree().process_frame
		if DisplayServer.get_name() != "headless": RenderingServer.force_draw()
		effect.hide()
		warmed_particle_systems.append(String(system_name))

func take(packed: PackedScene) -> Node:
	var batch: Array = instances.get(packed.resource_path, [])
	if batch.is_empty(): return packed.instantiate()
	var instance: Node3D = batch.pop_back()
	instance.get_parent().remove_child(instance)
	instance.process_mode = Node.PROCESS_MODE_INHERIT
	instance.show()
	return instance

func release_sources() -> void:
	for source in _sample_sources:
		if is_instance_valid(source): source.free()
	_sample_sources.clear()
