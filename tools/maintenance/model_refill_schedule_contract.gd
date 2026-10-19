extends SceneTree
## 纯调度合同：虚拟frame/work/step clock，小Node只用于取消/信号清理，不加载模型。
const SCHEDULER = preload("res://scripts/presentation/model_refill_scheduler.gd")
var checks := 0
var failures := []
var output := ""
var pulse: RefCounted

class VirtualPool extends MatchModelPool:
	var now := 10000
	var foreground := 0
	var cost := 100
	var order: Array = []
	func _ensure_refill_clock() -> bool: return true
	func _foreground_work_usec() -> int: return foreground
	func _refill_now_usec() -> int: return now
	func _run_refill_step(path: String) -> void:
		order.append([_refill_frame_id, path, _refill.stage])
		now += cost
		if int(_refill.stage) == 0: _refill.stage = 1
		else:
			instances[path].append("ready")
			_refill.clear()
			refill_metrics.completed += 1

class ClearWitness extends RefCounted:
	var calls := 0
	func clear() -> void: calls += 1

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("[FAIL] ", label)
func _initialize() -> void: call_deferred("run")

func run() -> void:
	pulse = preload("res://tools/performance/safe_probe_heartbeat.gd").new(self)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty() or not pulse.enabled: quit(1); return
	var results := {}
	for interval in [16667, 33333]:
		var scheduler := SCHEDULER.new()
		var allowed := 0
		for frame in 12:
			# interval只推进虚拟墙钟，实际本帧工作固定500us。调度器没有delta入口。
			if scheduler.allow_step(frame, 500): allowed += 1; scheduler.finished_step(100)
			check(not scheduler.allow_step(frame, 500), "one attempt/step per frame: " + str(interval))
		check(allowed == 12, "stable cadence has no starvation: " + str(interval))
		results[str(interval)] = scheduler.metrics.duplicate()
	var burst := SCHEDULER.new()
	check(not burst.allow_step(1, 12000), "occasional real foreground overload defers")
	check(burst.allow_step(2, 500), "normal work restores next frame independent of delta")
	burst.finished_step(5000)
	for frame in [3, 4, 5]: check(not burst.allow_step(frame, 500), "long step bounded cooldown")
	check(burst.allow_step(6, 500), "long step never permanently disables path")
	var overloaded := SCHEDULER.new()
	var progress := 0
	for frame in 24:
		if overloaded.allow_step(frame, 20000): progress += 1; overloaded.finished_step(6000)
	check(progress >= 3 and overloaded.metrics.forced_steps == progress, "sustained foreground and long steps still make bounded progress")
	results.overload = overloaded.metrics.duplicate()
	var world := Node3D.new()
	root.add_child(world)
	var pool := VirtualPool.new()
	pool._world = world
	pool._refill_ready = true
	for path in ["a", "b", "c"]:
		pool.instances[path] = []
		pool.initial_capacity[path] = 1
		pool.capacity[path] = 2
		pool._runtime_safe[path] = true
		pool._metric(path).active = 100 # 活跃数不能永久阻止初始闲置目标补货。
	for frame in 6:
		pool._refill_frame_id = frame + 1
		pool.advance_refill(0.033333)
		pool.advance_refill(0.016667) # 同帧重复消费者调用不得再做step。
	check(pool.order == [[1,"a",0],[2,"a",1],[3,"b",0],[4,"b",1],[5,"c",0],[6,"c",1]], "round-robin complete tasks, one atomic step per frame")
	check(pool.refill_metrics.completed == 3 and pool.refill_metrics.max_slice_usec == 100, "actual step clock bounds recorded; active>capacity still refills idle")
	pool.order.clear()
	var intervals := [0.016667, 0.150, 0.033333, 0.016667]
	for index in intervals.size():
		pool.instances.a.clear()
		pool._refill_frame_id = index + 10
		pool.advance_refill(intervals[index])
	check(pool.order.size() == 4, "occasional long interval with low real work does not defer")
	# 热路径a持续耗尽，不能饿死b/c。
	for path in ["a", "b", "c"]: pool.instances[path].clear()
	pool.order.clear()
	for frame in 12:
		pool.instances.a.clear()
		pool._refill_frame_id = frame + 20
		pool.advance_refill(0.033333)
	check(not pool.instances.b.is_empty() and not pool.instances.c.is_empty(), "continuously consumed path cannot starve peer paths")
	pool.initial_capacity.a = 5
	pool.capacity.a = 2
	check(pool._idle_target("a") == 2, "idle target is clamped to cache capacity, not active budget")
	pool.release_sources()
	var stop := MatchModelPool.new()
	stop._world = world
	stop._refill_ready = true
	stop._ensure_refill_clock()
	var pending := Node3D.new()
	world.add_child(pending)
	var owner := ClearWitness.new()
	stop._refill = {"path": "pending", "stage": 3, "node": pending, "owner": owner}
	check(process_frame.is_connected(stop._refill_begin_frame), "real frame hook installed")
	stop.cancelled = true
	check(owner.calls == 1 and not is_instance_valid(pending) and stop._refill.is_empty(), "cancel explicitly clears partial owner and node")
	check(not process_frame.is_connected(stop._refill_begin_frame), "cancel disconnects frame hook; no signal-held pool lifetime")
	stop.refill_step_observer = func(_step): pass
	stop.advance_refill(0.016667)
	stop.release_sources()
	check(not stop.refill_step_observer.is_valid(), "release drops optional diagnostic observer")
	check(owner.calls == 1 and not stop._refill_ready, "stop/release idempotent; no resumed work")
	world.free()
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "results": results, "scope": "virtual schedule/work clocks, no models or Runtime; real signal/partial-node cleanup only"}
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	pulse.set_phase("complete", true)
	print("[REFILL_SCHEDULER] ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
