extends SceneTree
## 单项恢复检查：虚拟调度、纯数据需求与一个真实小兵模型的补货生命周期。
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
func _expect(ok: bool, label: String) -> void: check(ok, label)
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
	check_demand()
	preload("res://tests/suites/presentation/match_loading_suite.gd").new().run(self)
	var lifecycle := await check_real_refill()
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "results": results, "lifecycle": lifecycle, "scope": "virtual schedule, data-only demand, one melee minion path; no full match, effects, audio, ports or rendering acceptance"}
	FileAccess.open(output.path_join("checks.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	pulse.set_phase("complete", true)
	print("[REFILL_SCHEDULER] ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func check_demand() -> void:
	# 构建计划仅解析简单卡组的声明，不加载模型/声音/整个对局。
	var planner = preload("res://scripts/presentation/match_resource_plan.gd")
	var plan: RefCounted = planner.for_match([["minion_squad", "mirror", "garen"], ["ashe"]], [{}, {}])
	var demand: RefCounted = MatchModelPool.DEMAND.build(plan.cards, plan)
	check(demand.errors.is_empty(), "bounded demand accepts real deployment/mirror/system definitions")
	var path := PresentationConfig.scene_path(CardDB.get_card("melee_minion"), 0)
	var entry: Dictionary = demand.paths[path]
	var members: int = CardDB.get_card("minion_squad").spawn_plan.members.count("melee_minion")
	var deck_source: Dictionary = entry.sources.filter(func(item): return item.source == "deck:0:minion_squad")[0]
	check(deck_source.initial == members, "same-path merge preserves repeated deployed members")
	check(entry.sources.any(func(item): return item.source == "mirror:0:minion_squad"), "mirror expands actual own deck source")
	check(not demand.sources.any(func(item): return item.source == "mirror:0:ashe" or item.source.begins_with("mirror:1:")), "mirror does not create enemy or unrelated sources")
	check(entry.sources.any(func(item): return item.kind == "system" and item.initial == 2 and item.capacity == 4), "system wave stock independent of copied deck")
	check(entry.first_burst <= entry.initial and entry.initial <= entry.capacity, "first burst, initial preparation and idle reserve stay distinct")
	var base: RefCounted = planner.for_match([["garen"], ["ashe"]], [{}, {}])
	var plain: RefCounted = MatchModelPool.DEMAND.build(base.cards, base)
	var garen_path := PresentationConfig.scene_path(CardDB.get_card("garen"), 0)
	check(plain.paths[garen_path].initial == 1 and plain.paths[garen_path].capacity == 2, "single source has one first deployment and finite reserve")
	var bad := {"huge": {"deployment_count": 1000}}
	check(not MatchModelPool.DEMAND.validate_development_definitions(bad).is_empty(), "oversized declaration reports error rather than truncating legal population")

func check_real_refill() -> Dictionary:
	pulse.set_phase("single-model-lifecycle", true)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 4, 7)
	camera.look_at(Vector3.ZERO)
	var path := PresentationConfig.scene_path(CardDB.get_card("melee_minion"), 0)
	var packed := load(path) as PackedScene
	var pool := MatchModelPool.new()
	var plan: RefCounted = preload("res://scripts/presentation/match_resource_plan.gd").for_match([[], []], [{}, {}])
	await pool.prepare({path: packed}, world, camera, plan.cards, plan)
	check(pool.errors.is_empty() and not pool.instances[path].is_empty(), "single real model prepares with old animation owner")
	var supported := bool(pool._runtime_safe.get(path, false))
	var stock: int = pool.instances[path].size()
	check(supported or stock == pool.capacity[path], "nonincremental/slow path keeps necessary full stock")
	# 测试真实补货只允许实际初始测量认可的路径；不绕过能力判定。
	if not supported:
		pool.release_sources()
		world.free()
		check(false, "real model was not approved for incremental refill; lifecycle remains unverified")
		return {"supported": false, "stock": stock}
	var live := Node3D.new()
	world.add_child(live)
	var model: Node3D = pool.take(packed)
	live.add_child(model)
	check(pool._metric(path).active == 1, "taking model transfers to real live owner")
	var steps := []
	pool.refill_step_observer = func(step): steps.append(step)
	for frame in 90:
		await process_frame
		pool.advance_refill(1.0 / 30.0)
		pool.advance_refill(1.0 / 30.0)
		if pool.refill_metrics.completed == 1: break
	check(pool.refill_metrics.completed == 1 and pool.instances[path].size() == stock, "real background refill completes at 30 FPS with an active model")
	var frame_ids := {}
	for step in steps: frame_ids[step.frame] = true
	check(frame_ids.size() == steps.size(), "real lifecycle executes at most one step in a frame")
	var owner: ModelVisualResources = model.get_meta("prepared_model_resources")
	var player: AnimationPlayer = model.get_meta("prepared_animation_player")
	check(pool.recycle(model, owner, player), "real model returns and restores animation/material state")
	check(pool._metric(path).active == 0 and pool.instances[path].size() <= pool.capacity[path], "recycle counts inactive cache only")
	# 再领取直至缺一个闲置槽；不新建活体，半成品绑定后取消。
	var borrowed := []
	while pool.instances[path].size() >= int(pool.initial_capacity[path]):
		var item := pool.take(packed) as Node3D
		live.add_child(item)
		borrowed.append(item)
	for frame in 15:
		await process_frame
		pool.advance_refill(1.0 / 30.0)
		if int(pool._refill.get("stage", 0)) == 3: break
	var pending: Node = pool._refill.get("node")
	var partial: ModelVisualResources = pool._refill.get("owner")
	check(is_instance_valid(pending) and partial != null, "cancellation reaches real partially bound model")
	pool.cancelled = true
	check(not is_instance_valid(pending) and partial._copy_jobs.is_empty() and partial.animation_player() == null, "cancel frees real partial node and animation references")
	check(not process_frame.is_connected(pool._refill_begin_frame), "real cancellation disconnects frame clock")
	var result := {"supported": supported, "initial": stock, "capacity": pool.capacity[path], "steps": steps, "metrics": pool.refill_metrics.duplicate(true)}
	pool.release_sources()
	live.free()
	world.free()
	check(pool._world == null and pool.instances.is_empty() and pool._refill.is_empty(), "exit releases pool and real scene owners")
	return result
