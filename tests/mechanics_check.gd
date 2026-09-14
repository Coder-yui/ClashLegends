extends SceneTree
## 每个套件拥有独立场景与固定种子；完成标记只在套件返回及清理检查后写出。
const CATALOG_PATH := "res://tests/suite_catalog.json"
var _completed_suites: Array[String] = []
var _failed := 0
var _checks := 0
var _verbose := "--verbose-checks" in OS.get_cmdline_user_args()
var _main: Node2D
var _suite_root_ids: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--network-case="):
			await preload("res://tests/suites/network_boundary_suite.gd").new().run(self, argument.trim_prefix("--network-case="))
			return
	if "--network-smoke" in OS.get_cmdline_user_args():
		await preload("res://tests/suites/network_integration_suite.gd").new().run(self)
		return
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	var selected: Array[String] = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--suite="):
			selected.append(argument.trim_prefix("--suite="))
	var ids: Array = catalog.map(func(entry): return entry.id)
	if "--list-suites" in OS.get_cmdline_user_args():
		for id in ids: print(id)
		quit(0)
		return
	for id in selected:
		if not ids.has(id):
			push_error("未知套件：" + id)
			quit(2)
			return
	if "--reverse-suites" in OS.get_cmdline_user_args(): catalog.reverse()
	for entry in catalog:
		if not selected.is_empty() and not selected.has(entry.id): continue
		seed(12345)
		await _prepare_suite(entry.scene)
		print("[套件] " + entry.id)
		var script = load(entry.script)
		if script == null or not script.can_instantiate():
			_expect(false, "套件脚本无法实例化：" + entry.id)
			await _clear_suite()
			continue
		var suite = script.new()
		if entry.scene == "none":
			await suite.call(entry.method, self)
		else:
			await suite.call(entry.method, self, _main)
		await _clear_suite()
		_completed_suites.append(entry.id)
	if "--profile-maintenance" in OS.get_cmdline_user_args():
		await _prepare_suite("battle")
		preload("res://tests/suites/maintenance_suite.gd").new().profile(self, _main)
		await _clear_suite()
	if _failed == 0:
		print("[机制检查] 全部通过（%d 项断言）" % _checks)
	else:
		push_error("[机制检查] %d 项失败" % _failed)
	await create_timer(0.25).timeout
	print("[MECHANICS_RESULT] " + JSON.stringify({"schema": 1, "checks": _checks, "failed": _failed, "completed_suites": _completed_suites}))
	quit(_failed)

func _prepare_suite(scene_kind: String) -> void:
	_suite_root_ids = root.get_children().map(func(node): return node.get_instance_id())
	_expect(get_nodes_in_group("combatants").is_empty(), "套件起点没有上一套件遗留的战斗对象")
	if scene_kind == "none": return
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main
	await process_frame
	# Main._ready 调用了 randomize；场景创建后重新固定套件初始化的随机流。
	seed(12345)
	if scene_kind == "battle":
		_main._start_local()
		_main.set_process(false)
		_main._ai.enabled = false
		_main._minion_waves_enabled = false

func _clear_suite() -> void:
	if is_instance_valid(_main): _main.free()
	_main = null
	await process_frame
	_expect(get_nodes_in_group("combatants").is_empty(), "套件结束释放所有战斗对象及其场景")
	_expect(root.get_children().map(func(node): return node.get_instance_id()) == _suite_root_ids, "套件未遗留根节点、音频管理器或额外场景")

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		if _verbose: print("[通过] ", message)
	else:
		_failed += 1
		push_error("[失败] " + message)
