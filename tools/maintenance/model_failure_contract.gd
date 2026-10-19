extends SceneTree
## 三处收口修复的CPU故障合同；只建小节点/夹具，不启动对局或效果播放器。
const FIXTURE := "res://tests/fixtures/material_plan_model.tscn"
var output := ""
var pulse: RefCounted
var checks := 0
var failures: Array[String] = []
var results := {}

class MainWitness extends "res://scripts/main.gd":
	var failures_seen: Array[String] = []
	# 保留生产_fail_preparation/_fail_startup路由，只截住需要UI/完整世界的末端。
	func _fail_with_error(message: String, _overlay_name: String, _title: String) -> void:
		failures_seen.append(message)

class BrokenPreparation extends Node3D:
	func prepare_visual_animations() -> PackedStringArray:
		return PackedStringArray(["Injected wrapper preparation failure"])

func _initialize() -> void:
	Engine.max_fps = 30
	pulse = preload("res://tools/performance/safe_probe_heartbeat.gd").new(self)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("[FAIL] ", label)

func prepare_pool(presentation: BattlePresentation3D, world: Node3D) -> MatchModelPool:
	var pool := presentation.model_pool
	pool._world = world
	pool.instances[FIXTURE] = []
	pool.initial_capacity[FIXTURE] = 1
	pool.capacity[FIXTURE] = 1
	pool._runtime_safe[FIXTURE] = true
	pool._refill_ready = true
	pool._ensure_refill_clock()
	return pool

func refill_failure(stage: int) -> void:
	var world := Node3D.new()
	root.add_child(world)
	var presentation := BattlePresentation3D.new()
	var main := MainWitness.new()
	presentation.resource_failed.connect(main._fail_preparation)
	var pool := prepare_pool(presentation, world)
	var pending: Node3D
	var owner: ModelVisualResources
	if stage == 0:
		pool._packed[FIXTURE] = load(FIXTURE)
		# 合法schema，但实际目录为空而声明含脚本：生产构造匹配必须拒绝。
		pool.construction[FIXTURE] = {"version": 1, "mode": "step-bind", "scripts": ["res://scripts/presentation/model_template_view.gd"]}
	else:
		pending = BrokenPreparation.new() if stage == 1 else Node3D.new()
		world.add_child(pending)
		pool._refill = {"path": FIXTURE, "stage": stage, "node": pending}
		if stage == 3:
			owner = ModelVisualResources.new()
			owner.begin_bind(pending, {}, {}) # 生产显式材质mode检查失败，step_bind传播原错误。
			pool._refill.owner = owner
	await process_frame
	presentation._process(1.0 / 30.0)
	var original := pool.errors.duplicate()
	check(not original.is_empty(), "refill records original failure stage=" + str(stage))
	check(main.failures_seen.size() == 1 and main.failures_seen[0].contains(original[0]), "pool -> presentation -> real Main failure route exactly once stage=" + str(stage))
	check(presentation.material_errors == original, "presentation preserves original failure stage=" + str(stage))
	check(pool.cancelled and not pool._refill_ready and pool._refill.is_empty(), "failure cancels and discards partial task stage=" + str(stage))
	check(world.get_child_count() == 0 and not is_instance_valid(pending), "partial model freed stage=" + str(stage))
	check(not process_frame.is_connected(pool._refill_begin_frame), "failure disconnects actual frame signal stage=" + str(stage))
	if owner != null: check(owner.errors.is_empty() and owner.animation_player() == null, "partial resource owner cleared")
	var steps: int = pool.refill_metrics.steps
	for index in 8: presentation._process(1.0 / 30.0)
	check(pool.refill_metrics.steps == steps and main.failures_seen.size() == 1 and pool.errors == original, "later frames never reconstruct or report twice stage=" + str(stage))
	results["refill_stage_" + str(stage)] = {"errors": Array(original), "notifications": main.failures_seen.size(), "steps": steps}
	pool.release_sources()
	presentation.free()
	main.free()
	world.free()

func death_factory_failure(with_errors: bool) -> void:
	var view := UnitModel3D.new()
	var presentation := BattlePresentation3D.new()
	var main := MainWitness.new()
	presentation.resource_failed.connect(main._fail_preparation)
	view.resource_failed.connect(presentation._material_failure)
	view._animation_names = {"death_followup_scene_path": FIXTURE, "death_followup_animation": "Death"}
	var pool := presentation.model_pool
	if with_errors:
		pool.strict_materials = true
		view.model_factory = pool.take # 真实未计划路径返回null并记录具体原因。
		view.model_factory_errors = func(): return pool.errors
	else:
		view.model_factory = func(_packed): return null
	check(not view._start_death_followup(), "null death factory returns false safely: " + str(with_errors))
	check(main.failures_seen.size() == 1, "null death factory reaches Main failure: " + str(with_errors))
	check(not view._death_followup_started and view._model_root == null, "failed followup never claims started")
	if with_errors:
		check(pool.errors.size() == 1 and pool.errors[0].begins_with("Unplanned model path:"), "real strict factory keeps original pool cause")
		check(view._model_resources.errors == pool.errors and main.failures_seen[0].contains(pool.errors[0]), "original factory error preserved through UnitModel/Main")
	else:
		check(view._model_resources.errors.size() == 1 and view._model_resources.errors[0].contains(FIXTURE), "factory without error source gets explicit scene context")
	results["death_with_errors_" + str(with_errors)] = {"errors": Array(view._model_resources.errors), "notifications": main.failures_seen.size()}
	view.free()
	pool.release_sources()
	presentation.free()
	main.free()

func run() -> void:
	if not pulse.enabled or output.is_empty(): quit(2); return
	await refill_failure(0)
	await refill_failure(1)
	await refill_failure(2)
	pulse.set_phase("bind-failure")
	await refill_failure(3)
	death_factory_failure(true)
	death_factory_failure(false)
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "results": results, "scope": "CPU fault injection; tiny fixture only; real pool/presentation/Main routing with terminal UI stub; no match, sampled family or rendering"}
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("[MODEL_FAILURE_CONTRACT] ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}))
	pulse.set_phase("complete", true)
	quit(0 if failures.is_empty() else 1)
