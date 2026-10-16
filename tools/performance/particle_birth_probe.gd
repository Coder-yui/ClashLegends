extends SceneTree
## 仅对照虚空兽trail出生索引；不启动Main、不推进战斗、不度量FPS。
const PLAYER = preload("res://assets/effects/void_spawn/player.gd")
const HEARTBEAT = preload("res://tools/performance/safe_probe_heartbeat.gd")
const DEFAULT_REFERENCE := "res://ClashLegends-开发素材库/04-中间产物/architecture_refactor/batch2b/reference/void_spawn_player.gd"
const EMISSION_END := 34.0 / 30.0
var failures: Array[String] = []
var checks := 0
var output := ""
var legacy: GDScript
var rounds := 1
var samples := 2
var heartbeat: RefCounted

func _initialize() -> void:
	Engine.max_fps = 30
	heartbeat = HEARTBEAT.new(self)
	if (DisplayServer.get_name() != "headless" or "--render" in OS.get_cmdline_user_args()) and not heartbeat.enabled:
		push_error("Rendering probe requires tools/performance/safe_probe.py supervision")
		quit(2)
		return
	call_deferred("run")

func option(key: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(key + "="): return argument.trim_prefix(key + "=")
	return fallback

func check(value: bool, message: String) -> void:
	checks += 1
	if value: return
	failures.append(message)
	push_error(message)

func source_script(source: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		check(false, "对照脚本无法编译")
		return null
	return script

func player(script: GDScript, parent: Node = null) -> Node3D:
	var effect: Node3D = script.new()
	if parent != null: parent.add_child(effect)
	effect.load_kind("trail")
	return effect

func distribution(values: Array) -> Dictionary:
	var ordered := values.duplicate()
	ordered.sort()
	var total := 0.0
	for value in ordered: total += float(value)
	var result := {"samples": ordered.size(), "total_ms": total, "mean_ms": total / ordered.size(), "max_ms": ordered.back()}
	for percentile in [50, 95, 99]:
		result["p%d_ms" % percentile] = ordered[mini(ceili(ordered.size() * percentile / 100.0) - 1, ordered.size() - 1)]
	return result

func warm_batch(script: GDScript, count: int) -> int:
	var checksum := 0
	var live: Array[Node3D] = []
	for index in count:
		var effect := player(script)
		checksum += effect._particle_births.size()
		live.append(effect)
	for effect in live: effect.free()
	return checksum

func check_index_keys() -> void:
	var data := {"fps": 2, "frames": [[[[1], [2]], [[1]]], [[[1], [3]], [[2]]]]}
	var indexed: Dictionary = PLAYER._index_particle_births(data)
	check(indexed == {Vector2i(0, 1): 0.0, Vector2i(0, 2): 0.0, Vector2i(1, 1): 0.0, Vector2i(0, 3): 0.5, Vector2i(1, 2): 0.5},
		"小夹具：首次出现决定出生时间，同一serial跨发射器保持独立键")

func measure_warm(count: int) -> Dictionary:
	var times := {"old": [], "current": []}
	var orders: Array = []
	var equivalent := true
	for round_index in rounds:
		heartbeat.set_phase("birth-warm-%d-round-%d" % [count, round_index], true)
		var order := ["old", "current"] if round_index % 2 == 0 else ["current", "old"]
		orders.append(order)
		var checksums := {"old": [], "current": []}
		for side in order:
			for sample in samples:
				var started := Time.get_ticks_usec()
				var checksum := warm_batch(legacy if side == "old" else PLAYER, count)
				times[side].append((Time.get_ticks_usec() - started) / 1000.0)
				checksums[side].append(checksum)
		equivalent = equivalent and checksums.old == checksums.current
		await process_frame
	check(equivalent, "配对warm批次必须产生相同出生索引数量")
	var result := {"instances_per_sample": count, "order": orders, "equivalent": equivalent, "old": distribution(times.old), "current": distribution(times.current)}
	print("[PARTICLE_BIRTH] count=%d old_p50=%.4fms current_p50=%.4fms" % [count, result.old.p50_ms, result.current.p50_ms])
	return result

func visible_state(effect: Node3D) -> Array:
	var result: Array = []
	for pool in effect._pools:
		var emitter: Array = []
		for item in pool:
			emitter.append([item.visible, item.transform, item.material_override.get_shader_parameter("p") if item.visible else null])
		result.append(emitter)
	return result

func check_motion_and_stop() -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	var old := player(legacy, world)
	var current := player(PLAYER, world)
	old.setup_native(PLAYER.native_scale("trail"))
	current.setup_native(PLAYER.native_scale("trail"))
	old.emission_end = EMISSION_END
	current.emission_end = EMISSION_END
	check(old._data == current._data and old._particle_births == current._particle_births, "原始帧与全部出生时间逐项等价")
	var data_before := var_to_bytes(current._data)
	var same := true
	var excluded := 0
	var frame_count: int = current._data.frames.size()
	for frame in frame_count:
		var age := float(frame) / float(current._data.fps)
		var position := Vector3(age * 0.5, sin(age * 2.0) * 0.1, 0.0)
		for effect in [old, current]:
			effect.position = position
			effect.seek(age)
		same = same and visible_state(old) == visible_state(current) and old._birth_positions == current._birth_positions
		var expected := 0
		for sample in current._data.frames[frame][0]:
			if float(current._particle_births[Vector2i(0, int(sample[0]))]) <= EMISSION_END: expected += 1
			else: excluded += 1
		var visible := 0
		for item in current._pools[0]:
			if item.visible: visible += 1
		same = same and visible == expected
	check(same and excluded > 0, "全部193个采样帧的移动、世界出生点、停止发射过滤与材质参数等价")
	for age in [0.8, 0.2, 0.5]:
		for effect in [old, current]:
			effect.position = Vector3(age, 0.0, 0.0)
			effect.seek(age)
		check(visible_state(old) == visible_state(current) and old._birth_positions == current._birth_positions, "回退seek清理实例出生点后重新播放等价：%.2f" % age)
	var other := player(PLAYER, world)
	other.position = Vector3(3.0, 0.0, 0.0)
	other.setup_native(PLAYER.native_scale("trail"))
	other.seek(0.5)
	var other_births: Dictionary = other._birth_positions.duplicate()
	check(is_same(current._particle_births, other._particle_births) and current._particle_births.is_read_only(), "同kind共享同一只读出生索引")
	check(not is_same(current._birth_positions, other._birth_positions) and current._birth_positions != other._birth_positions, "移动实例共享时间索引但世界出生坐标独立")
	current.position += Vector3(5.0, 0.0, 0.0)
	current.seek(0.1)
	check(other._birth_positions == other_births and data_before == var_to_bytes(current._data), "单实例移动/回退不污染其他实例或共享采样帧")
	var result := {"frames_compared": frame_count, "births": current._particle_births.size(), "samples_excluded_after_stop": excluded, "shared_data_bytes": data_before.size()}
	world.free()
	return result

func check_shared_index_lifetime() -> Dictionary:
	# 只在测试脚本副本中插入计数；正式播放器不增加诊断状态。
	var source := FileAccess.get_file_as_string("res://assets/effects/void_spawn/player.gd")
	source = source.replace("static var _cache: Dictionary = {}", "static var _cache: Dictionary = {}\nstatic var birth_index_builds := 0")
	source = source.replace("static func _index_particle_births(data: Dictionary) -> Dictionary:\n", "static func _index_particle_births(data: Dictionary) -> Dictionary:\n\tbirth_index_builds += 1\n")
	var counted := source_script(source)
	if counted == null: return {}
	var memory: Array = []
	var cache_sizes: Array = []
	var shared := {}
	var all_released := true
	var all_shared := true
	var cycles := 3
	var instances := 2
	for match_index in cycles:
		var live: Array[Node3D] = []
		var weak: Array[WeakRef] = []
		for index in instances:
			var effect := player(counted)
			if shared.is_empty(): shared = effect._particle_births
			all_shared = all_shared and is_same(shared, effect._particle_births)
			live.append(effect)
			weak.append(weakref(effect))
		for effect in live: effect.free()
		live.clear()
		for reference in weak: all_released = all_released and reference.get_ref() == null
		weak.clear()
		cache_sizes.append(counted._cache.size())
		memory.append(int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	check(counted.birth_index_builds == 1 and all_shared, "多轮多实例仅首次构建一次索引且全部共享")
	check(all_released and cache_sizes.all(func(size): return size == 1), "反复清场释放所有实例，既有进程级缓存维持一个kind不增长")
	return {"cycles": cycles, "instances_per_cycle": instances, "index_builds": counted.birth_index_builds, "cache_kind_counts": cache_sizes, "all_instances_released": all_released, "static_memory_after_cycles": memory, "policy": "低负载正确性检查：与现有采样/材质缓存同寿命，索引固定每kind一份；清场释放实例和世界出生坐标，未新增独立永久缓存；不证明压力或长期内存无增长"}

func make_render_world(script: GDScript) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(448, 320)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.025, 0.035, 0.06)
	world.add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.8
	world.add_child(camera)
	camera.position = Vector3(0.4, 1.6, 4.0)
	camera.look_at(Vector3(0.4, 0.1, 0.0))
	camera.current = true
	var effect := player(script, world)
	effect.setup_native(PLAYER.native_scale("trail"))
	effect.emission_end = EMISSION_END
	return {"viewport": viewport, "effect": effect}

func capture_equivalence() -> Array:
	var old := make_render_world(legacy)
	var current := make_render_world(PLAYER)
	var result: Array = []
	# 连续移动后分别取中段、发射停止后及消散边界，不能只首帧静态截图。
	for frame in 193:
		heartbeat.set_phase("capture-trail-%d" % frame)
		var age := float(frame) / 120.0
		for entry in [old, current]:
			entry.effect.position = Vector3(age * 0.5, sin(age * 2.0) * 0.1, 0.0)
			entry.effect.seek(age)
		if frame not in [36, 72, 144, 180]: continue
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var before: Image = old.viewport.get_texture().get_image()
		var after: Image = current.viewport.get_texture().get_image()
		before.convert(Image.FORMAT_RGBA8)
		after.convert(Image.FORMAT_RGBA8)
		var old_bytes := before.get_data()
		var new_bytes := after.get_data()
		var absolute_error := 0
		var maximum_error := 0
		var signal_sum := 0
		for index in old_bytes.size():
			var error := absi(int(old_bytes[index]) - int(new_bytes[index]))
			absolute_error += error
			maximum_error = maxi(maximum_error, error)
			if index % 4 != 3: signal_sum += absi(int(new_bytes[index]) - int(new_bytes[index % 4]))
		var old_path := output.path_join("trail-before-%03d.png" % frame)
		var current_path := output.path_join("trail-after-%03d.png" % frame)
		check(before.save_png(old_path) == OK and after.save_png(current_path) == OK, "保存Compatibility逐对截图")
		check(maximum_error <= 1, "Compatibility同采样帧的像素差不超过一个8bit级别")
		if frame in [36, 72]: check(signal_sum > 0, "中段截图包含真实粒子，不能用全空画面证明等价")
		result.append({"frame": frame, "age": age, "max_channel_error_8bit": maximum_error, "mean_channel_error_8bit": float(absolute_error) / old_bytes.size(), "signal_from_background_8bit": signal_sum, "before": old_path, "after": current_path})
	old.viewport.free()
	current.viewport.free()
	return result

func run() -> void:
	output = option("--output", "")
	if output.is_empty():
		push_error("必须指定新的 --output=目录，输出限开发素材库或临时目录")
		quit(2)
		return
	if DirAccess.dir_exists_absolute(output) or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("输出目录必须不存在且可以创建")
		quit(2)
		return
	rounds = int(option("--rounds", "1"))
	samples = int(option("--samples", "2"))
	if rounds < 1 or rounds > 3 or samples < 1 or samples > 3:
		push_error("Diagnostic rounds/samples must each be in 1..3")
		quit(2)
		return
	var reference := option("--reference", DEFAULT_REFERENCE)
	legacy = source_script(FileAccess.get_file_as_string(reference))
	if legacy == null:
		quit(2)
		return
	check_index_keys()
	var primed: Array[Node3D] = []
	for script in [legacy, PLAYER]: primed.append(player(script))
	for effect in primed: effect.free()
	primed.clear()
	heartbeat.set_phase("birth-primed", true)
	await process_frame
	var result := {"schema": 1, "engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(), "video_adapter": RenderingServer.get_video_adapter_name(), "source_sha256": {"reference": FileAccess.get_sha256(reference), "current": FileAccess.get_sha256("res://assets/effects/void_spawn/player.gd"), "sampled_data": FileAccess.get_sha256(PLAYER.ROOT + "trail/sampled.json")}, "note": "仅C出生索引的warm实例初始化与销毁CPU配对；不含JSON首载、实际粒子绘制或完整帧，不是FPS。两侧同一sampled.json/材质/纹理，轮流先测；默认单轮少样本只作低负载诊断，不支持稳定分位数/收益结论。", "rounds": rounds, "samples_per_round": samples, "warm": []}
	for raw in option("--counts", "1,8").split(","):
		var count := int(raw)
		if count < 1 or count > 512:
			check(false, "实例数量须在1..512")
			continue
		result.warm.append(await measure_warm(count))
	heartbeat.set_phase("birth-motion-contract")
	result.correctness = check_motion_and_stop()
	await process_frame
	heartbeat.set_phase("birth-lifetime-contract")
	result.lifetime = check_shared_index_lifetime()
	await process_frame
	if "--render" in OS.get_cmdline_user_args(): result.render = await capture_equivalence()
	result.checks = checks
	result.failures = failures
	var file := FileAccess.open(output.path_join("result.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result, "\t") + "\n")
	else: check(false, "无法写结果JSON")
	print("[PARTICLE_BIRTH_RESULT] " + JSON.stringify({"checks": checks, "failed": failures.size(), "output": output}))
	quit(0 if failures.is_empty() else 1)
