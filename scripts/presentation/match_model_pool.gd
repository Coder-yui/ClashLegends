class_name MatchModelPool
extends RefCounted
signal resource_failed(errors: PackedStringArray)
## 本场持有的预建模型；在加载遮罩后实际绘制，使用时移交给正式表现代理。
var instances: Dictionary = {}
var rendered_paths: Dictionary = {}
var _sample_sources: Array[Unit] = []
var _warmed_materials: Array[Material] = []
const LOADING_SLICE_USEC := 32000
const REFILL_SLICE_USEC := 1000
var capacity := {}
var initial_capacity := {}
var _packed := {}
var _clips := {}
var _material_states := {}
var strict_materials := false
var viewer_team := 0
var _runtime_safe := {}
var _refill := {}
var _refill_ready := false
var _refill_failure_reported := false
const REFILL_SCHEDULER = preload("res://scripts/presentation/model_refill_scheduler.gd")
var _refill_scheduler := REFILL_SCHEDULER.new()
var _refill_cursor := 0
var _refill_frame_tree: SceneTree
var _refill_frame_id := 0
var _refill_frame_started := 0
var refill_step_observer: Callable # 仅诊断入口设置；普通对局不保存逐step数组。
var refill_metrics := {"completed": 0, "steps": 0, "max_step_usec": 0, "max_slice_usec": 0, "busy_frames": 0, "by_path": {}, "max_create_usec": 0, "max_prepare_usec": 0, "max_begin_bind_usec": 0, "budget_overruns": 0}

var errors := PackedStringArray()
var metrics := {}
var preparation_by_path := {}
var _world: Node3D
var _render_samples: Array[Node3D] = []
var cancelled := false:
	set(value):
		cancelled = value
		if value:
			_stop_refill()
			for sample in _render_samples:
				if is_instance_valid(sample): sample.hide()
var preparation_times := {"instantiate_usec": 0, "animation_usec": 0, "render_usec": 0, "frame_wait_usec": 0, "sample_prepare_usec": 0, "draws": 0, "animation_draws_skipped": 0, "stasis_samples": 0, "stealth_samples": 0, "predeployment_samples": 0, "overlay_draws_skipped": 0}

const DEMAND = preload("res://scripts/presentation/match_model_demand.gd")
var demand_plan: RefCounted
var construction := {}

## 同path总量由来源账单唯一持有；use仍完整保留形态/阵营采样配置。
static func build_specs(cards: Dictionary, plan: RefCounted = null) -> Dictionary:
	return specs_from_demand(DEMAND.build(cards, plan))

static func specs_from_demand(demand: RefCounted) -> Dictionary:
	var specs := {}
	for path in demand.paths:
		var uses: Array = demand.paths[path].uses.duplicate(true)
		for index in uses.size():
			uses[index].count = int(demand.paths[path].capacity) if index == 0 else 0
			uses[index].initial = int(demand.paths[path].initial) if index == 0 else 0
		specs[path] = uses
	return specs

## 序列化在场景根，schema只允许明确的加载期构造或分步绑定。
## step-bind的脚本目录必须逐个匹配，未知包装绝不因模板存在自动获得资格。
static func construction_contract(packed: PackedScene) -> Dictionary:
	var state := packed.get_state()
	for property in state.get_node_property_count(0):
		if state.get_node_property_name(0, property) == &"metadata/model_pool_construction":
			var value: Variant = state.get_node_property_value(0, property)
			if valid_construction_declaration(value):
				return value
	return {}

static func valid_construction_declaration(value: Variant) -> bool:
	return value is Dictionary and value.size() == 3 and value.get("version") is int and value.version == 1 and value.get("mode") in ["loading-only", "step-bind"] and value.get("scripts") is Array and value.scripts.all(func(path): return path is String and path.begins_with("res://") and path.ends_with(".gd"))

static func construction_matches(node: Node, contract: Dictionary) -> bool:
	var scripts := {}
	_collect_scripts(node, scripts)
	var expected := {}
	for path in contract.get("scripts", []): expected[path] = true
	return scripts == expected

static func _collect_scripts(node: Node, scripts: Dictionary) -> void:
	if node.get_script() != null: scripts[node.get_script().resource_path] = true
	for child in node.get_children(): _collect_scripts(child, scripts)

## 同路径所有阵营/形态取并集；cards来自变形、召唤、复活和镜像技能可达闭包。
## 控制状态可作用于双方及衍生物，不能只看当前单位是否已被冻结。
static func material_states_for(uses: Array, plan: RefCounted = null, viewer: int = 0) -> Dictionary:
	var result := {"mode": "match" if plan != null else "tool", "freeze": not uses.is_empty() and plan != null and plan.target_states.has("freeze"), "stasis": not uses.is_empty() and plan != null and plan.target_states.has("stasis"), "stealth": false, "building": not uses.is_empty(), "buffs": []}
	for use in uses:
		var stats: Dictionary = use.get("stats", {})
		result.stealth = result.stealth or float(stats.get("stealth_delay", 0.0)) > 0.0
		result.building = result.building and String(stats.get("type", "")) == "building"
		var scene := String(stats.get("visual_active_buff_scene", ""))
		if not scene.is_empty():
			var radius := float(stats.get("visual_radius", stats.get("radius", 0.0)))
			var team := viewer if int(use.team) == 0 else 1 - viewer
			var key := ModelVisualResources.buff_key(scene, radius, team)
			if not result.buffs.any(func(entry): return entry.key == key): result.buffs.append({"key": key, "scene": scene, "radius": radius, "team": team})
	return result

func _metric(path: String) -> Dictionary:
	if not metrics.has(path): metrics[path] = {"hits": 0, "misses": 0, "recycled": 0, "active": 0, "peak": 0, "instantiate_usec": 0, "unplanned": 0, "exhausted": 0, "unsupported_recycle": 0, "prepare_animation_usec": 0, "prepare_wrapper_usec": 0, "max_sync_create_usec": 0}
	return metrics[path]


func prepare(resources: Dictionary, world: Node3D, camera: Camera3D, cards: Dictionary, plan: RefCounted = null) -> void:
	if cancelled: return
	_world = world
	strict_materials = plan != null
	viewer_team = 1 if bool(camera.get_meta("canvas_flipped", false)) else 0
	var tree := world.get_tree()
	demand_plan = DEMAND.build(cards, plan)
	errors.append_array(demand_plan.errors)
	if not errors.is_empty(): return
	var specs := specs_from_demand(demand_plan)
	for required_path in specs:
		if not resources.has(required_path): errors.append("Missing planned model resource: " + String(required_path))
	if not errors.is_empty(): return
	var slice_started := Time.get_ticks_usec()
	for path in resources:
		if not (String(path).begins_with("res://assets/units/") or String(path).begins_with("res://assets/effects/")) or not String(path).ends_with(".tscn") or instances.has(path):
			continue
		var path_started := Time.get_ticks_usec()
		var before_times := preparation_times.duplicate()
		var packed := resources[path] as PackedScene
		if packed == null:
			errors.append("模型池资源必须是PackedScene: " + String(path))
			return
		var batch: Array[Node3D] = []
		var uses: Array = specs.get(path, [])
		# 附属/入场场景由各自消费者管理；仍保留原绘制采样，不制造无人领取的库存。
		var count := int(demand_plan.paths.get(path, {}).get("capacity", 0))
		var initial := int(demand_plan.paths.get(path, {}).get("initial", 0))
		if count > 0:
			var contract := construction_contract(packed)
			if contract.is_empty():
				errors.append("Missing/unsupported model construction contract: " + String(path))
				return
			construction[path] = contract
			_runtime_safe[path] = contract.mode == "step-bind"
			if not _runtime_safe[path]: initial = count
		capacity[path] = count
		initial_capacity[path] = initial
		_packed[path] = packed
		_material_states[path] = material_states_for(uses, plan, viewer_team)
		_clips[path] = {}
		for use in uses: ModelVisualResources.collect_clip_names(use.stats.get("visual_animations", {}), _clips[path])
		while batch.size() < int(initial_capacity[path]):
			var node := _prepare_stock_instance(path)
			if node == null: return
			batch.append(node)
			# 不把场景树交给后台线程；以完整实例为最小单元分帧让出主线程。
			if Time.get_ticks_usec() - slice_started >= LOADING_SLICE_USEC:
				await _wait_frame(tree)
				if cancelled or not is_instance_valid(world): return
				slice_started = Time.get_ticks_usec()
		if uses.is_empty(): uses = [{}]
		var warmed_configs := {}
		for spec in uses:
			var signature := _warm_signature(spec)
			if warmed_configs.has(signature): continue
			warmed_configs[signature] = true
			var sample_started := Time.get_ticks_usec()
			var sample: Node3D
			var source: Unit
			if not spec.is_empty() and not bool(spec.get("auxiliary", false)):
				# 使用离树的只读源，不生成权威单位、不派发出生事件或音频。
				source = Unit.new()
				source.setup(int(spec.team), spec.stats, String(spec.id))
				_sample_sources.append(source)
				source.form_index = int(spec.form)
				source.net_form_index = int(spec.form)
				source.card_id = String(spec.id)
				source.position = Vector2(360, 640)
				sample = UnitModel3D.new()
				sample.model_factory = instantiate_visual
				sample.material_states = _material_states.get(path, {})
				sample.process_mode = Node.PROCESS_MODE_DISABLED
				world.add_child(sample)
				if not sample.setup(source, packed, camera, spec.stats.get("visual_animations", {}), float(spec.stats.get("visual_forward_yaw", 0.0)), String(spec.stats.get("visual_active_buff_scene", ""))):
					errors.append_array(sample._model_resources.errors)
					if errors.is_empty(): errors.append("Strict sample setup failed: " + String(path))
					return
			else:
				sample = instantiate_visual(packed) as Node3D
				sample.process_mode = Node.PROCESS_MODE_DISABLED
				world.add_child(sample)
			_render_samples.append(sample)
			preparation_times.sample_prepare_usec += Time.get_ticks_usec() - sample_started
			# 实例的脚下光圈和蒙皮材质同样需要首次绘制。
			sample.position += Vector3(0, 3, 0)
			if sample is UnitModel3D: sample._sync_prepared_buff_transform()
			for mesh in sample.find_children("*", "GeometryInstance3D", true, false): mesh.show()
			await _wait_frame(tree)
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
						if Time.get_ticks_usec() - slice_started >= LOADING_SLICE_USEC:
							await _wait_frame(tree)
							if cancelled or not is_instance_valid(world): return
							slice_started = Time.get_ticks_usec()
				if is_instance_valid(sample._active_buff_visual):
					if sample._active_buff_visual.has_method("prepare_resource_sample"):
						var result: Variant = sample._active_buff_visual.prepare_resource_sample(spec.stats.get("active_skills", []), _draw_sample)
						if result != null:
							if not result is PackedStringArray:
								errors.append("附属效果准备返回未知错误合同")
								return
							if not result.is_empty():
								errors.append_array(result)
								return
					else: sample._active_buff_visual.advance(true, 0.1)
				# 仅跳过资源所有者明确构造为基础三态别名的强化三态。
				# 不比较材质身份来猜测等价；有任何强化材质时仍完整绘制六态。
				for state in range(6):
					if plan != null and state % 3 == 2 and not plan.target_states.has("freeze"): continue
					sample._model_resources.apply_overlays(state % 3 == 1, state % 3 == 2, state >= 3)
					for mesh in sample._model_resources.meshes():
						if mesh.material_overlay != null: _warmed_materials.append(mesh.material_overlay)
					if sample._model_resources.overlay_state_repeats_base(state):
						preparation_times.overlay_draws_skipped += 1
					else:
						_draw_sample()
				for mesh in sample._model_resources.meshes(): mesh.show()
				if plan == null or plan.target_states.has("stasis"):
					preparation_times.stasis_samples += 1
					sample._model_resources.apply_overlays(false, false, false, true)
					_draw_sample()
				if bool(sample.material_states.get("stealth", false)):
					preparation_times.stealth_samples += 1
					sample._model_resources.apply_overlays(false, false, false, false, true)
					_draw_sample()
				if not sample._model_resources.errors.is_empty():
					errors.append_array(sample._model_resources.errors)
					return
				sample._model_resources.reset_overlays()
			elif sample is PreDeploymentVisual3D:
				sample.position = Vector3.ZERO
				sample.setup(camera, Vector2(360, 640), 0)
				for progress in [0.0, 0.1, 0.25, 0.5, 0.75, 0.99]:
					preparation_times.predeployment_samples += 1
					sample.advance_visual(progress)
					_draw_sample()
					await _wait_frame(tree)
					if cancelled or not is_instance_valid(world): return
			rendered_paths[path] = true
			# 保留绘制资源/骨骼/材质实例；样本不再播放，不需持有独立的巨大动画副本。
			for player in sample.find_children("*", "AnimationPlayer", true, false):
				player.stop()
				for library in player.get_animation_library_list(): player.remove_animation_library(library)
			sample.hide()
		instances[path] = batch
		var path_times := {"total_usec": Time.get_ticks_usec() - path_started, "instances": batch.size(), "capacity": count, "runtime_safe": _runtime_safe.get(path, false)}
		for key in preparation_times: path_times[key] = int(preparation_times[key]) - int(before_times[key])
		preparation_by_path[path] = path_times
	if not cancelled and is_instance_valid(world):
		for id in cards:
			if float(CardDB.get_card(String(id)).get("stealth_delay", 0.0)) > 0.0:
				StealthTransition3D.prepare_visual(world)
				break

	if not cancelled and is_instance_valid(world):
		_refill_ready = true
		_ensure_refill_clock()

func _prepare_stock_instance(path: String) -> Node3D:
	var started := Time.get_ticks_usec()
	var node := instantiate_visual(_packed[path])
	if not node is Node3D:
		node.free()
		errors.append("模型根节点必须是Node3D: " + String(path))
		return null
	node.process_mode = Node.PROCESS_MODE_DISABLED
	_world.add_child(node)
	node.hide()
	var instantiate_usec := Time.get_ticks_usec() - started
	preparation_times.instantiate_usec += instantiate_usec
	if bool(_runtime_safe.get(path, false)) and not construction_matches(node, construction[path]):
		errors.append("Step-bind construction script contract changed: " + String(path))
		node.free()
		return null
	started = Time.get_ticks_usec()
	errors.append_array(ModelVisualResources.prepare_visual_root(node))
	if not errors.is_empty():
		node.free()
		return null
	_metric(path).prepare_wrapper_usec += Time.get_ticks_usec() - started
	var bind_started := Time.get_ticks_usec()
	var model_resources := ModelVisualResources.new()
	var player := model_resources.bind_model(node, _allowed_clips(path, node), _material_states.get(path, {}))
	if not model_resources.errors.is_empty():
		errors.append_array(model_resources.errors)
		node.free()
		return null
	_metric(path).prepare_animation_usec += Time.get_ticks_usec() - bind_started
	node.set_meta("prepared_model_resources", model_resources)
	node.set_meta("prepared_animation_player", player)
	preparation_times.animation_usec += Time.get_ticks_usec() - started
	node.set_meta("pool_path", path)
	if _can_recycle(node): node.set_meta("pool_state", _capture_state(node))
	return node

func _allowed_clips(path: String, node: Node) -> Dictionary:
	return _clips.get(path, {}) if ModelVisualResources.supports_clip_filter(node) else {}

## capacity是闲置缓存上限，不是活体额度；活跃单位不能使周期补货永久失效。
func _idle_target(path: String) -> int:
	return mini(int(initial_capacity.get(path, 0)), int(capacity.get(path, 0)))

func _needs_refill(path: String) -> bool:
	return bool(_runtime_safe.get(path, false)) and instances.get(path, []).size() < _idle_target(path)

## 每个完整任务后按路径轮转；不反复选择相同低水位路径饿死其他队列。
func _select_refill_path() -> String:
	var paths := initial_capacity.keys()
	for offset in paths.size():
		var index := (_refill_cursor + offset) % paths.size()
		var path: String = paths[index]
		if _needs_refill(path):
			_refill_cursor = (index + 1) % paths.size()
			return path
	return ""

func _refill_now_usec() -> int:
	return Time.get_ticks_usec()

func _ensure_refill_clock() -> bool:
	if is_instance_valid(_refill_frame_tree): return true
	if not is_instance_valid(_world) or not _world.is_inside_tree(): return false
	_refill_frame_tree = _world.get_tree()
	_refill_frame_tree.process_frame.connect(_refill_begin_frame)
	return false # 当前帧没有起点观测；从下一真实process_frame开始。

func _refill_begin_frame() -> void:
	_refill_frame_id += 1
	_refill_frame_started = _refill_now_usec()

func _foreground_work_usec() -> int:
	return maxi(0, _refill_now_usec() - _refill_frame_started)

func advance_refill(_delta: float) -> void:
	if cancelled or not _refill_ready or not is_instance_valid(_world): return
	if not errors.is_empty():
		_fail_refill()
		return
	if not _ensure_refill_clock(): return
	if _refill.is_empty():
		var selected := _select_refill_path()
		if selected.is_empty(): return
		_refill = {"path": selected, "stage": 0}
	var path: String = _refill.path
	if not _needs_refill(path):
		_discard_refill()
		return
	var foreground := _foreground_work_usec()
	if not _refill_scheduler.allow_step(_refill_frame_id, foreground):
		refill_metrics.busy_frames = int(_refill_scheduler.metrics.foreground_deferrals)
		return
	var stage: int = _refill.stage
	var started := _refill_now_usec()
	_run_refill_step(path) # 每个真实帧至多一个不可抢占步骤；不在本帧循环补完动画/实例。
	var elapsed := _refill_now_usec() - started
	_refill_scheduler.finished_step(elapsed)
	refill_metrics.scheduler = _refill_scheduler.metrics
	refill_metrics.by_path[path] = maxi(int(refill_metrics.by_path.get(path, 0)), elapsed)
	if elapsed > REFILL_SLICE_USEC: refill_metrics.budget_overruns += 1
	refill_metrics.steps += 1
	refill_metrics.max_slice_usec = maxi(refill_metrics.max_slice_usec, elapsed)
	if refill_step_observer.is_valid(): refill_step_observer.call({"frame": _refill_frame_id, "path": path, "stage": stage, "foreground_usec": foreground, "wall_usec": elapsed})
	if not errors.is_empty(): _fail_refill()

## 局中故障先停止/清半成品，再通知正式失败入口；后续帧不得重试构造。
func _fail_refill() -> void:
	if _refill_failure_reported: return
	_refill_failure_reported = true
	cancelled = true
	resource_failed.emit(errors)

func _run_refill_step(path: String) -> void:
	var started := _refill_now_usec()
	match int(_refill.stage):
		0:
			var node := instantiate_visual(_packed[path]) as Node3D
			if node == null:
				errors.append("Refill model root must be Node3D: " + path)
				_discard_refill()
				return
			node.hide()
			node.process_mode = Node.PROCESS_MODE_DISABLED
			_world.add_child(node)
			if not construction_matches(node, construction[path]):
				node.free()
				errors.append("Refill construction contract failed: " + path)
				_discard_refill()
				return
			_refill.node = node
			_refill.stage = 1
			refill_metrics.max_create_usec = maxi(refill_metrics.max_create_usec, _refill_now_usec() - started)
		1:
			errors.append_array(ModelVisualResources.prepare_visual_root(_refill.node))
			if not errors.is_empty():
				_discard_refill()
				return
			_refill.stage = 2
			refill_metrics.max_prepare_usec = maxi(refill_metrics.max_prepare_usec, _refill_now_usec() - started)
		2:
			var owner := ModelVisualResources.new()
			owner.begin_bind(_refill.node, _allowed_clips(path, _refill.node), _material_states.get(path, {}))
			_refill.owner = owner
			if not owner.errors.is_empty():
				errors.append_array(owner.errors)
				_discard_refill()
				return
			_refill.stage = 3
			refill_metrics.max_begin_bind_usec = maxi(refill_metrics.max_begin_bind_usec, _refill_now_usec() - started)
		3:
			var done: bool = _refill.owner.step_bind()
			refill_metrics.max_step_usec = maxi(refill_metrics.max_step_usec, _refill_now_usec() - started)
			if done:
				if not _refill.owner.errors.is_empty():
					errors.append_array(_refill.owner.errors)
					_discard_refill()
					return
				var node: Node3D = _refill.node
				node.set_meta("prepared_model_resources", _refill.owner)
				node.set_meta("prepared_animation_player", _refill.owner.animation_player())
				node.set_meta("pool_path", path)
				if _can_recycle(node): node.set_meta("pool_state", _capture_state(node))
				instances[path].append(node)
				_refill.clear()
				refill_metrics.completed += 1

func _discard_refill() -> void:
	if _refill.has("owner"): _refill.owner.clear()
	if _refill.has("node") and is_instance_valid(_refill.node): _refill.node.free()
	_refill.clear()

func _stop_refill() -> void:
	_refill_ready = false
	_discard_refill()
	if is_instance_valid(_refill_frame_tree) and _refill_frame_tree.process_frame.is_connected(_refill_begin_frame):
		_refill_frame_tree.process_frame.disconnect(_refill_begin_frame)
	_refill_frame_tree = null
	_refill_frame_started = 0
	_refill_frame_id = 0
	_refill_scheduler.reset_clock()

func states_for_path(path: String) -> Dictionary:
	return _material_states.get(path, {})

func take(packed: PackedScene) -> Node:
	var path := packed.resource_path
	if strict_materials and (not _material_states.has(path) or int(capacity.get(path, 0)) <= 0):
		errors.append("Unplanned model path: " + path)
		return null
	var metric := _metric(path)
	var batch: Array = instances.get(path, [])
	if batch.is_empty():
		metric.misses += 1
		if capacity.has(path): metric.exhausted += 1
		else: metric.unplanned += 1
		var started := Time.get_ticks_usec()
		var fresh := instantiate_visual(packed)
		fresh.set_meta("pool_path", path)
		if fresh is Node3D and is_instance_valid(_world) and capacity.has(path):
			_world.add_child(fresh)
			errors.append_array(ModelVisualResources.prepare_visual_root(fresh))
			if not errors.is_empty():
				fresh.free()
				return null
			var owner := ModelVisualResources.new()
			fresh.set_meta("prepared_animation_player", owner.bind_model(fresh, _allowed_clips(path, fresh), _material_states.get(path, {})))
			if not owner.errors.is_empty():
				errors.append_array(owner.errors)
				fresh.free()
				return null
			fresh.set_meta("prepared_model_resources", owner)
			if _can_recycle(fresh): fresh.set_meta("pool_state", _capture_state(fresh))
			_world.remove_child(fresh)
		metric.max_sync_create_usec = maxi(metric.max_sync_create_usec, Time.get_ticks_usec() - started)
		metric.instantiate_usec += Time.get_ticks_usec() - started
		metric.active += 1
		metric.peak = maxi(metric.peak, metric.active)
		fresh.tree_exiting.connect(_returned.bind(path), CONNECT_ONE_SHOT)
		return fresh
	metric.hits += 1
	metric.active += 1
	metric.peak = maxi(metric.peak, metric.active)
	var instance: Node3D = batch.pop_back()
	instance.get_parent().remove_child(instance)
	instance.process_mode = Node.PROCESS_MODE_INHERIT
	instance.show()
	instance.tree_exiting.connect(_returned.bind(path), CONNECT_ONE_SHOT)
	return instance

## 只回收已审计的无脚本模型；包装必须显式提供重置接口。未支持者保留正确性后备。
func _can_recycle(node: Node) -> bool:
	if node.is_in_group("prepared_buff_bank") or node.is_in_group("prepared_buff_aux"): return true
	if node.get_script() != null and not node.has_method("reset_pool_visual"): return false
	for child in node.get_children():
		if not _can_recycle(child): return false
	return true

func _capture_state(node: Node) -> Array:
	if node.is_in_group("prepared_buff_bank") or node.is_in_group("prepared_buff_aux"): return []
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
	refill_step_observer = Callable()
	_refill_ready = false
	_discard_refill()
	_packed.clear()
	_clips.clear()
	_material_states.clear()
	construction.clear()
	demand_plan = null
	for source in _sample_sources:
		if is_instance_valid(source): source.free()
	_sample_sources.clear()
	instances.clear()
	_warmed_materials.clear()
	_render_samples.clear()
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
	return var_to_str([stats.get("visual_animations", {}), stats.get("visual_forward_yaw", 0.0), buff, stats.get("visual_radius", stats.get("radius", 0.0)), spec.get("form", 0), spec.get("team", 0) if not buff.is_empty() else -1])

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

func _wait_frame(tree: SceneTree) -> void:
	var started := Time.get_ticks_usec()
	await tree.process_frame
	preparation_times.frame_wait_usec += Time.get_ticks_usec() - started

## 池创建延后活体动画到统一bind；直接摄影包装器同步完成同一契约。
func instantiate_visual(packed: PackedScene) -> Node:
	var node := packed.instantiate()
	if node.has_method("visual_animation_contract"):
		node.set_meta("defer_animation_ownership", true)
	return node
