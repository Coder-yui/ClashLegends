extends SceneTree
## 第四阶段收敛专项：纯账单、有限构造能力、单次真实Runtime轨迹分别选择。
const DEMAND = preload("res://scripts/presentation/match_model_demand.gd")
const PLAN = preload("res://scripts/presentation/match_resource_plan.gd")
const PROFILES = preload("res://tools/performance/match_loading_plan.gd")
var output := ""
var pulse: RefCounted
var checks := 0
var failures := []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("[FAIL] ", label)
func _expect(ok: bool, label: String) -> void: check(ok, label)

func declaration(path: String) -> Dictionary:
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("metadata/model_pool_construction = "):
			var value: Variant = str_to_var(line.trim_prefix("metadata/model_pool_construction = "))
			if value is Dictionary: return value
	return {}

func static_checks() -> Dictionary:
	var profiles := {}
	for name in ["heavy", "summon", "diverse"]:
		var config := PROFILES.profile_config(name)
		var plan: RefCounted = PLAN.for_match(config.decks, config.choices)
		var bill: RefCounted = DEMAND.build(plan.cards, plan)
		check(plan.errors.is_empty() and bill.errors.is_empty(), "profile plan gates: " + name)
		var capacity := 0
		var initial := 0
		var rows := {}
		for path in bill.paths:
			var row: Dictionary = bill.paths[path].duplicate()
			row.erase("uses")
			row.mode = declaration(path).get("mode", "")
			row.initial = row.capacity if row.mode == "loading-only" else row.initial
			capacity += int(row.capacity)
			initial += int(row.initial)
			rows[path] = row
		profiles[name] = {"capacity": capacity, "initial": initial, "paths": rows, "limitations": bill.limitations}
		pulse.set_phase(name)
	var definition_cases := 0
	var paths := {}
	for id in CardDB.all():
		for option in maxi(1, CardDB.active_skills_for(id).size()):
			definition_cases += 1
			var plan: RefCounted = PLAN.for_match([[id], [id]], [{id: option}, {id: option}])
			check(plan.errors.is_empty(), "definition/selected-skill development gate: %s/%d" % [id, option])
			var bill: RefCounted = DEMAND.build(plan.cards, plan)
			check(bill.errors.is_empty(), "definition finite bill: " + id)
			for path in bill.paths:
				paths[path] = declaration(path)
				check(MatchModelPool.valid_construction_declaration(paths[path]), "construction declaration: " + path)
				check(int(bill.paths[path].capacity) >= int(bill.paths[path].first_burst), "first demand not clipped: " + path)
		pulse.set_phase(id)
	var plan: RefCounted = PLAN.for_match([["mirror", "malzahar"], []], [{"malzahar": 1}, {}])
	var bill: RefCounted = DEMAND.build(plan.cards, plan)
	var path := PresentationConfig.scene_path(CardDB.get_card("voidling"), 0)
	check(bill.paths[path].capacity == 24 and bill.paths[path].first_burst == 12, "voidling retains old24 policy; no2-generations x2-waves x3-uses")
	var revival: RefCounted = PLAN.for_match([["mirror", "anivia"], []], [{}, {}])
	var revival_bill: RefCounted = DEMAND.build(revival.cards, revival)
	var revival_path := PresentationConfig.scene_path(CardDB.get_card("anivia"), 0)
	check(revival_bill.paths[revival_path].first_burst == 2 and revival_bill.paths[revival_path].capacity == 4, "replacement skips original death body; revival/followup not doubled")
	var ordinary: RefCounted = PLAN.for_match([["tombstone", "garen", "mirror"], []], [{}, {}])
	bill = DEMAND.build(ordinary.cards, ordinary)
	path = PresentationConfig.scene_path(CardDB.get_card("imp"), 0)
	check(bill.paths[path].first_burst == 12, "ordinary mirror excludes copied active4 from source8+copy4")
	for id in MatchResources.SYSTEM_UNIT_BUDGET:
		for team in 2:
			path = PresentationConfig.scene_path(CardDB.get_card(id), team)
			check(bill.paths[path].capacity == 4 and bill.paths[path].initial == 2, "system independent mirror correction")
	for bad in [{"a": {"deployment_count": 65}}, {"a": {"spawn_id": "a", "spawn_count": 1, "spawn_interval": 1.0}}, {"a": {"spawn_id": "b", "spawn_count": 64}, "b": {"spawn_id": "c", "spawn_count": 64}, "c": {}}]:
		check(not DEMAND.validate_development_definitions(bad).is_empty(), "huge declaration/cycle/nested multiplication explicitly fails")
	var deep := {}
	for index in 11: deep[str(index)] = {"spawn_id": str(index + 1)} if index < 10 else {}
	check(not DEMAND.validate_development_definitions(deep).is_empty(), "deep dependency explicitly fails")
	check(DEMAND.validate_development_definitions({"a": {"death_replacement_id": "egg", "death_replacement_charges": 1}, "egg": {"timed_revival_id": "a", "timed_revival_death_replacement_charges": 0}}).is_empty(), "bounded charge-zero revival cycle accepted")
	preload("res://tests/suites/presentation/match_loading_suite.gd").new().run(self)
	return {"profiles": profiles, "definition_skill_cases": definition_cases, "declarations": paths, "scope": "assertions are not battle scenarios; no model loads"}

func capability_checks() -> Dictionary:
	var rows := {}
	var selected := ["res://assets/units/belveth/belveth_view.tscn", "res://assets/units/sion/sion_view.tscn", "res://assets/units/gnar/gnar_small_view.tscn", "res://assets/units/gnar/gnar_mega_view.tscn", "res://assets/units/voidfish/voidfish_view.tscn", "res://assets/units/voidfish_ranged/voidfish_ranged_view.tscn"]
	for path in selected:
		pulse.set_phase(path)
		var world := Node3D.new()
		root.add_child(world)
		var pool := MatchModelPool.new()
		var packed := load(path) as PackedScene
		var contract := MatchModelPool.construction_contract(packed)
		var start := Time.get_ticks_usec()
		var node := pool.instantiate_visual(packed) as Node3D
		node.process_mode = Node.PROCESS_MODE_DISABLED
		world.add_child(node)
		var create_usec := Time.get_ticks_usec() - start
		check(contract.mode == "step-bind" and MatchModelPool.construction_matches(node, contract), "reviewed constructor directory matches: " + path)
		start = Time.get_ticks_usec()
		var prepare_errors := ModelVisualResources.prepare_visual_root(node)
		var prepare_usec := Time.get_ticks_usec() - start
		var owner := ModelVisualResources.new()
		start = Time.get_ticks_usec()
		owner.begin_bind(node, {}, {"mode": "match", "buffs": []})
		var begin_usec := Time.get_ticks_usec() - start
		var longest := 0
		var steps := 0
		while true:
			start = Time.get_ticks_usec()
			var complete := owner.step_bind()
			longest = maxi(longest, Time.get_ticks_usec() - start)
			steps += 1
			if complete: break
		check(prepare_errors.is_empty() and owner.errors.is_empty(), "complete per-instance binding: " + path)
		var before := owner.material_creations.duplicate()
		check(ModelVisualResources.prepare_visual_root(node).is_empty() and owner.material_creations == before, "repeat wrapper preparation idempotent: " + path)
		rows[path] = {"create_and_ready_usec": create_usec, "prepare_usec": prepare_usec, "begin_bind_usec": begin_usec, "max_clip_step_usec": longest, "steps": steps, "material_creations": before}
		owner.clear()
		world.free()
		pool.release_sources()
		await process_frame
	return {"constructors": rows, "scope": "one instance at a time; current source audited; no universal hardware cost guarantee"}

class RuntimeWitness extends "res://tests/fixtures/authority_battle.gd":
	var birth_observer: Callable
	func _spawn_unit(request: UnitSpawnRequest) -> Unit:
		var unit: Unit = super._spawn_unit(request)
		if unit != null and birth_observer.is_valid(): birth_observer.call(unit)
		return unit

class RefillDriver extends Node:
	var pool: MatchModelPool
	var deltas: Array = []
	func _process(delta: float) -> void:
		deltas.append(delta)
		pool.advance_refill(delta) # 真实process delta；不伪造60FPS使30FPS探针补货。

var _trace_main: RuntimeWitness
var _trace_pool: MatchModelPool
var _trace_world: Node3D
var _trace_camera: Camera3D
var _trace_births: Array = []
var _trace_owners: Array = []
var _trace_step_walls: Array = []

func _observe_birth(unit: Unit) -> void:
	var stats := CardDB.get_card(unit.card_id)
	var path := PresentationConfig.scene_path(stats, unit.team)
	var view := UnitModel3D.new()
	view.model_factory = _trace_pool.take
	view.model_recycler = _trace_pool.recycle
	view.material_states = _trace_pool.states_for_path(path)
	_trace_world.add_child(view)
	var ok := view.setup(unit, _trace_pool._packed[path], _trace_camera, stats.get("visual_animations", {}), float(stats.get("visual_forward_yaw", 0.0)), String(stats.get("visual_active_buff_scene", "")))
	check(ok, "real factory birth enters production UnitModel3D: " + unit.card_id)
	_trace_births.append({"id": unit.card_id, "tick": _trace_main.runtime._sim_tick_id, "ability": unit.active_ability_id, "path": path, "metrics": _trace_pool._metric(path).duplicate()})
	_trace_owners.append({"id": unit.card_id, "owner": view._model_resources, "counts": view._model_resources.material_creations.duplicate()})

func _imp_count() -> int:
	var count := 0
	for item in _trace_births:
		if item.id == "imp": count += 1
	return count

func _drive_to_imp_count(target: int, max_ticks: int) -> void:
	for index in max_ticks:
		if _imp_count() >= target: return
		_trace_main.runtime.step(FixedStepClock.STEP)
		if index % 10 == 0: pulse.set_phase("runtime:tick:" + str(_trace_main.runtime._sim_tick_id))
		await process_frame

func runtime_checks() -> Dictionary:
	var deck := ["tombstone", "heal", "zap", "freeze", "stasis", "corrosion", "lightning", "explosive_cask"]
	check(MatchSession.valid_deck(deck, {}), "real eight-card deck valid")
	var plan: RefCounted = PLAN.for_match([deck, []], [{}, {}])
	var bill: RefCounted = DEMAND.build(plan.cards, plan)
	check(plan.errors.is_empty() and bill.errors.is_empty(), "runtime plan passes development gates before resource load")
	_trace_world = Node3D.new()
	root.add_child(_trace_world)
	_trace_camera = Camera3D.new()
	_trace_world.add_child(_trace_camera)
	_trace_camera.position = Vector3(0, 4, 8)
	_trace_camera.look_at(Vector3.ZERO)
	_trace_pool = MatchModelPool.new()
	_trace_pool._world = _trace_world
	_trace_pool.strict_materials = true
	var initial := {}
	for id in ["tombstone", "imp"]:
		var path := PresentationConfig.scene_path(CardDB.get_card(id), 0)
		var packed := load(path) as PackedScene
		var contract := MatchModelPool.construction_contract(packed)
		_trace_pool._packed[path] = packed
		_trace_pool.construction[path] = contract
		_trace_pool._runtime_safe[path] = contract.mode == "step-bind"
		_trace_pool._material_states[path] = MatchModelPool.material_states_for(bill.paths[path].uses, plan)
		_trace_pool._clips[path] = {}
		for use in bill.paths[path].uses: ModelVisualResources.collect_clip_names(use.stats.get("visual_animations", {}), _trace_pool._clips[path])
		var count: int = bill.paths[path].capacity if contract.mode == "loading-only" else bill.paths[path].initial
		_trace_pool.initial_capacity[path] = count
		_trace_pool.capacity[path] = bill.paths[path].capacity
		_trace_pool.instances[path] = []
		for index in count:
			var node := _trace_pool._prepare_stock_instance(path)
			if node != null: _trace_pool.instances[path].append(node)
		initial[path] = {"seeded": count, "first_burst": bill.paths[path].first_burst, "legacy_reserve": bill.paths[path].legacy_reserve, "capacity": bill.paths[path].capacity}
	check(_trace_pool.errors.is_empty(), "exact planned path inventories prepared through production helper")
	_trace_pool._refill_ready = true
	_trace_pool._ensure_refill_clock() # 与正式prepare末尾一致，在驱动协程注册前观测帧起点。
	_trace_pool.refill_step_observer = func(item): _trace_step_walls.append(item.duplicate())
	var driver := RefillDriver.new()
	driver.pool = _trace_pool
	_trace_world.add_child(driver)
	_trace_main = RuntimeWitness.new()
	root.add_child(_trace_main)
	_trace_main.birth_observer = _observe_birth
	var runtime = _trace_main.runtime
	runtime._deck = deck.duplicate()
	runtime._remote_deck = deck.duplicate()
	for team in 2:
		var wallet := ElixirManager.new()
		_trace_main.add_child(wallet)
		runtime.bind_account(team, wallet)
		runtime._authoritative_card_cycles[team] = CardCycle.new(deck, false)
	runtime._match_started = true
	pulse.set_phase("runtime:prepared", true)
	check(runtime.play_card(0, "tombstone", Vector2(300, 900)), "real MatchRuntime.play_card accepts and pays")
	await _drive_to_imp_count(2, 65)
	check(_imp_count() == 2, "real Unit passive first wave drives two model births")
	var source: Unit
	for unit in _trace_main.world.authoritative_units_snapshot().values():
		if unit.card_id == "tombstone": source = unit
	check(source != null and source.is_deployed() and source.active_ability_id >= 0, "real deployment establishes active qualification")
	if source != null:
		check(_trace_main.use_active_skill(source.active_ability_id, 0), "real active request accepted; no direct effect call")
		await _drive_to_imp_count(6, 30)
		check(_imp_count() == 6, "command buffer and production active effect spawn four")
		await _drive_to_imp_count(8, 125)
		check(_imp_count() == 8, "real periodic timer creates second passive wave")
		source.take_damage(100000) # 正式伤害/死亡入口；不手调亡语或手写出生事件。
		await process_frame
		check(_imp_count() == 10, "real damage/death lifecycle creates two death summons")
	for item in _trace_owners:
		if item.id == "imp": check(item.owner.material_creations == item.counts, "existing imp candidate creation remains unchanged after real attach")
	var metrics := _trace_pool.metrics.duplicate(true)
	var errors := Array(_trace_pool.errors)
	check(errors.is_empty() and not runtime.game_over, "real chain completes without model or runtime failure")
	var imp_path := PresentationConfig.scene_path(CardDB.get_card("imp"), 0)
	check(int(metrics[imp_path].hits) + int(metrics[imp_path].misses) == 10, "every authority-created imp consumes exactly one real pooled/fallback model")
	var report := {"deck": deck, "initial": initial, "births": _trace_births, "metrics": metrics, "refill": _trace_pool.refill_metrics.duplicate(true), "refill_step_walls": _trace_step_walls, "real_process_deltas": driver.deltas, "gold": runtime.account(0).elixir, "tick": runtime._sim_tick_id, "errors": errors, "scope": "real MatchRuntime commands/qualification/passive/active/periodic/death; only tombstone+imp models; no UI/audio/render/full match; refill observes actual process_frame work clock; real30FPS delta recorded, never used as work budget"}
	driver.set_process(false)
	for child in _trace_world.get_children():
		if child is UnitModel3D:
			child._release_model()
			child.free()
	_trace_main.world.clear_units()
	_trace_main.free()
	for batch in _trace_pool.instances.values():
		for node in batch:
			if is_instance_valid(node): node.get_meta("prepared_model_resources").clear(); node.free()
	_trace_pool.release_sources()
	_trace_world.free()
	return report

func run() -> void:
	pulse = preload("res://tools/performance/safe_probe_heartbeat.gd").new(self)
	var mode := "static"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument.begins_with("--mode="): mode = argument.trim_prefix("--mode=")
	if output.is_empty() or not pulse.enabled: quit(1); return
	var report := {}
	match mode:
		"static": report = static_checks()
		"capabilities": report = await capability_checks()
		"runtime": report = await runtime_checks()
		"compile-runtime": check(true, "runtime witness and all direct consumers compile")
		_: check(false, "unknown probe mode")
	report.merge({"passed": failures.is_empty(), "checks": checks, "failures": failures})
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	pulse.set_phase("complete", true)
	print("[MODEL_INVENTORY_REVISION] ", JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
