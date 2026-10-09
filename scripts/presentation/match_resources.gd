class_name MatchResources
extends RefCounted
## 本局强引用资源集合；覆盖双方卡组、衍生形态/召唤物及世界音频。模型实例由 MatchModelPool 预建。
const EFFECTS = preload("res://scripts/presentation/effect_resource_manifest.gd")
var resources: Dictionary = {}
var raw_files: Dictionary = {}
var cards: Dictionary = {}
var plan: RefCounted # null 仅用于工作台/全卡审查；正式对局在准备前固定计划。
var preparation_usec := 0
var _world_prepared := false
var errors := PackedStringArray()
var _collect_only := false
var _pending: Dictionary = {}
var _active: Array[String] = []
var _cancelled := false
var _drain: Node
var threaded_requests := 0
var threaded_wait_usec := 0
# 系统兵线每种单位可占两路；准备两波重叠窗口，根集合与预算使用同一声明。
const SYSTEM_UNIT_BUDGET := {"melee_minion": 4, "ranged_minion": 4, "siege_minion": 4, "super_minion": 4}
const LOADING_REQUEST_WINDOW := 128 # 引擎任务队列窗口，不是创建128条线程。
const REFERENCES := ["assist_conversion_unit_id", "assist_conversion_building_id", "growth_ranged_id", "growth_melee_id", "deployment_upgrade_id", "spawn_id", "death_spawn_id", "death_replacement_id", "timed_revival_id", "rush_spawn_id"]

func prepare(card_ids: Array) -> void:
	var started := Time.get_ticks_usec()
	var previous_count := cards.size()
	for id in card_ids:
		_prepare_card(String(id))
	if cards.size() == previous_count and _world_prepared:
		preparation_usec += Time.get_ticks_usec() - started
		return
	if not _world_prepared:
		_collect(CardDB.PRINCESS_TOWER_VISUAL_CONFIG)
		_collect(CardDB.NEXUS_VISUAL_CONFIG)
		_collect(preload("res://scripts/data/world_audio.gd").DEFINITIONS)
		_collect(preload("res://scripts/data/match_audio.gd").EVENTS, &"AudioStream")
		_collect("res://assets/arena/rift_arena/rift_arena.tscn")
		_world_prepared = true
	for request in EFFECTS.requests(cards, plan, CardDB.all()):
		var files := EFFECTS.files(request, errors)
		_collect(files.resources)
		for path in files.raw:
			if not FileAccess.file_exists(path): errors.append("本局原始资源不存在: " + path)
			else: raw_files[path] = true
	preparation_usec += Time.get_ticks_usec() - started

## 只在线程读取资源；定义遍历、类型检查和场景实例化仍属于主线程。
## 有界请求避免加载线程争抢全部 CPU；只在完成后 get，不阻塞等待未完成资源。
func prepare_async(card_ids: Array, tree: SceneTree, stop: Callable = Callable()) -> void:
	_collect_only = true
	prepare(card_ids)
	_collect_only = false
	var started := Time.get_ticks_usec()
	var waiting: Array = _pending.keys()
	var active: Array[String] = _active
	while not waiting.is_empty() or not active.is_empty():
		var stopping := _cancelled or (stop.is_valid() and bool(stop.call()))
		if stopping: waiting.clear()
		for index in range(active.size() - 1, -1, -1):
			var path := active[index]
			var status := ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				var resource := ResourceLoader.load_threaded_get(path)
				for expected in _pending[path]: _accept(path, resource, expected)
			else:
				errors.append("本局后台加载失败: " + path)
			active.remove_at(index)
		while not waiting.is_empty() and active.size() < LOADING_REQUEST_WINDOW:
			var path: String = waiting.pop_front()
			# 前一个场景可能已带入后续依赖，直接保留缓存而非再排队一帧。
			var cached := ResourceLoader.get_cached_ref(path)
			if cached != null:
				for expected in _pending[path]: _accept(path, cached, expected)
				continue
			if ResourceLoader.load_threaded_request(path) != OK:
				errors.append("本局后台加载请求失败: " + path)
			else:
				active.append(path)
				threaded_requests += 1
		if not waiting.is_empty() or not active.is_empty(): await tree.process_frame
	_pending.clear()
	threaded_wait_usec += Time.get_ticks_usec() - started

## 调用方场景被释放后，其协程不能负责收尾；将已发出的请求移交给短命节点。
class RequestDrain extends Node:
	var paths: Array[String] = []
	func _process(_delta: float) -> void:
		for index in range(paths.size() - 1, -1, -1):
			var status := ResourceLoader.load_threaded_get_status(paths[index])
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
			if status == ResourceLoader.THREAD_LOAD_LOADED: ResourceLoader.load_threaded_get(paths[index])
			paths.remove_at(index)
		if paths.is_empty(): queue_free()

func cancel_async(tree: SceneTree) -> void:
	_cancelled = true
	if _active.is_empty(): return
	var drain := RequestDrain.new()
	_drain = drain
	drain.paths.assign(_active)
	drain.process_mode = Node.PROCESS_MODE_ALWAYS
	_active.clear()
	# _exit_tree 内不修改正在退出的场景树分支。
	tree.root.call_deferred("add_child", drain)

func _accept(path: String, resource: Resource, expected: StringName) -> void:
	if resource == null: errors.append("本局资源加载失败: " + path)
	elif expected != &"" and not resource.is_class(expected): errors.append("本局资源类型错误（期望%s）: %s" % [expected, path])
	else: resources[path] = resource

func _prepare_card(id: String) -> void:
	if cards.has(id) or not CardDB.has_card(id):
		return
	if plan != null and not plan.cards.has(id):
		errors.append("本局资源计划外卡牌: " + id)
		return
	cards[id] = true
	_collect(plan.definition(id) if plan != null else CardDB.get_card(id))
	if _collect_only:
		# 正式卡面由定义收集；保留旧卡面命名的兼容发现，但不在此同步读取。
		if String(CardDB.get_card(id).get("card_art", {}).get("path", "")).is_empty():
			for extension in CardArt.CARD_ART_EXTENSIONS:
				var path := "%s%s_loading.%s" % [CardArt.CARD_ART_DIR, id, extension]
				if ResourceLoader.exists(path):
					_collect(path, &"Texture2D")
					break
		return
	var art := CardArt.texture_for(id)
	if art != null:
		resources[art.resource_path] = art

func _collect(value: Variant, expected: StringName = &"") -> void:
	if value is Dictionary:
		for key in value:
			if key == "resource_dependencies": continue
			if key in REFERENCES:
				_prepare_card(String(value[key]))
			elif key == "deployment_member_ids" and value[key] is Array:
				for member_id in value[key]:
					_prepare_card(String(member_id))
			var child_type := expected
			if key == "audio": child_type = &"AudioStream"
			elif key == "card_art": child_type = &"Texture2D"
			elif key in ["visual_scene_path", "visual_scene_paths", "visual_pre_deploy_scene", "visual_active_buff_scene", "death_followup_scene_path"]: child_type = &"PackedScene"
			_collect(value[key], child_type)
	elif value is Array or value is PackedStringArray:
		for child in value:
			_collect(child, expected)
	elif value is String and value.begins_with("res://"):
		var resource: Resource = resources.get(value)
		if resource == null: resource = ResourceLoader.get_cached_ref(value)
		if resource == null:
			if not ResourceLoader.exists(value):
				errors.append("本局资源不存在: " + value)
				return
			if _collect_only:
				if not _pending.has(value): _pending[value] = []
				if expected not in _pending[value]: _pending[value].append(expected)
				return
			resource = load(value)
		_accept(value, resource, expected)
