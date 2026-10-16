extends SceneTree
## 配对CPU微基准；不推进战斗，不测FPS。旧实现只从本次归档加载。
const SNAP := preload("res://scripts/battle/network_snapshot_system.gd")
const DECK := ["kayn", "corki", "garen", "ashe", "freeze", "tombstone", "melee_minion_squad", "heavy_minion_squad"]
const GROWTH := {0: {"kayn": {"ranged": 2, "melee": 1, "unlocked": "kayn"}}, 1: {"kayn": {"ranged": 0, "melee": 3, "unlocked": "kayn"}}}
var failures: Array[String] = []
var rounds := 5
var samples := 20
var reference := ""
var legacy_snapshot: GDScript
var legacy_growth: GDScript
var legacy_roster: GDScript
var legacy_playback: GDScript

class ProbeMain extends "res://scripts/main.gd":
	func _setup_battle_presentation() -> void: pass
	func _start_local() -> void:
		super._start_local()
		_remote_deck = _deck.duplicate()
		_remote_active_skill_choices = _active_skill_choices.duplicate()
		_ai.enabled = false
		_minion_waves_enabled = false

class CountingHand extends CardHand:
	var refreshes := 0
	func _refresh(value: float) -> void:
		refreshes += 1
		super._refresh(value)

func option(key: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(key + "="): return argument.trim_prefix(key + "=")
	return fallback

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> bool:
	if not value:
		failures.append(message)
		push_error(message)
	return value

func load_reference(file_name: String) -> GDScript:
	var script := GDScript.new()
	var source := FileAccess.get_file_as_string(reference.path_join(file_name))
	if source.begins_with("class_name "): source = source.substr(source.find("\n") + 1)
	script.source_code = source
	if not check(script.reload() == OK, "reference compile: " + file_name): return null
	return script

func make_main() -> Node2D:
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	main.set_script(ProbeMain)
	main._deck = DECK.duplicate()
	root.add_child(main)
	main.set_process(false)
	seed(12345)
	await main._start_local_with_loading()
	main._audio_manager.end_battle()
	main._audio_manager = null
	main.process_mode = Node.PROCESS_MODE_DISABLED
	# 安装真正CardHand的计数子类；第一次建子控件/字体/卡面均在计时外。
	main._hand.free()
	main._hand = CountingHand.new()
	main.add_child(main._hand)
	main._hand.setup(main._elixir, DECK)
	main._hand.growth_progress_query = func(id: String): return main._card_growth.progress(main.local_team, id)
	main._hand.visual_card_query = func(id: String): return main._card_growth.resolved_id(main.local_team, id)
	main._hand.cost_query = func(id: String): return main.card_cost_for_team(main.local_team, id)
	main._hand.set_cycle_state(DECK.slice(0, 4), DECK.slice(4, 8))
	return main

func distribution(values: Array) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	if sorted.is_empty(): return {"samples": 0}
	var total := 0.0
	for value in sorted: total += float(value)
	var result := {"samples": sorted.size(), "total_ms": total, "mean_ms": total / sorted.size(), "max_ms": sorted.back()}
	for percentile in [50, 95, 99]: result["p%d_ms" % percentile] = sorted[mini(ceili(sorted.size() * percentile / 100.0) - 1, sorted.size() - 1)]
	return result

func pair(label: String, old: Callable, current: Callable, operations: int = 1) -> Dictionary:
	var times := {"old": [], "current": []}
	var orders: Array = []
	var checksums := {"old": [], "current": []}
	for round_index in rounds:
		var order := ["old", "current"] if round_index % 2 == 0 else ["current", "old"]
		orders.append(order)
		for side in order:
			for sample in samples:
				var started := Time.get_ticks_usec()
				var checksum: Variant = old.call() if side == "old" else current.call()
				times[side].append((Time.get_ticks_usec() - started) / 1000.0)
				checksums[side].append(checksum)
		check(checksums.old == checksums.current, label + " paired results differ")
		# 两边都完成才让出帧；没有把释放/主循环回调夹进单侧计时。
		await process_frame
	var old_result := distribution(times.old)
	var current_result := distribution(times.current)
	for result in [old_result, current_result]:
		result.operations_per_sample = operations
		result.operations = rounds * samples * operations
		result.mean_ms_per_operation = result.mean_ms / operations
	print("[REPEATED_WORK] %s old=%.4fms current=%.4fms per_sample" % [label, old_result.mean_ms, current_result.mean_ms])
	return {"case": label, "order": orders, "equivalent": checksums.old == checksums.current, "old": old_result, "current": current_result}

func private_growth(team: int) -> Dictionary: return {team: GROWTH[team]}

func measure_count(count: int) -> Dictionary:
	var host: Node2D = await make_main()
	host.mode = "server"
	host._snapshot_system.reset_session("repeated-work")
	host._card_growth.replace_replica(GROWTH)
	host._elixir.elixir = 3.0
	host._elixir_p1 = ElixirManager.new()
	host.add_child(host._elixir_p1)
	host._elixir_p1.elixir = 8.0
	for index in count:
		var team := index % 2
		var card := "ashe" if index % 4 == 0 else "melee_minion"
		host._spawn_unit(UnitSpawnRequest.new(team, card, Vector2(80 + index % 8 * 75, 300 + int(index / 8) * 35), {"deploy_time_override": 0.0}))
	var old_host: RefCounted = legacy_snapshot.new(host, host._projectile_system)
	old_host.lifecycle = host._snapshot_system.lifecycle
	var a: Node2D = await make_main()
	var b: Node2D = await make_main()
	for client in [a, b]:
		client.mode = "client"
		client.local_team = 0
		client._snapshot_system.reset_session("repeated-work")
	var old_parser: RefCounted = legacy_snapshot.new(a, a._projectile_system)
	old_parser.lifecycle.reset("repeated-work")
	host._sim_tick_id = 1000
	var warm: PackedByteArray = host._snapshot_system.capture(0)
	for client in [a, b]: check(client._snapshot_system.apply(warm), "initial replica warmup")
	var packets: Array[PackedByteArray] = []
	var frame: Array = host._snapshot_system.capture_public_frame()
	for index in rounds * samples:
		var packet := frame.duplicate()
		packet[SNAP.S_SERVER_TICK] = 1001 + index
		packets.append(host._snapshot_system.encode_frame(packet, 0))
	var cursor := [0, 0]
	var accepted := [0, 0]
	var decode := await pair("decode_apply_%d" % count,
		func():
			var bytes: PackedByteArray = packets[cursor[0]]
			cursor[0] += 1
			var tick: int = old_parser.packet_tick(bytes)
			if a._snapshot_system.apply(bytes): accepted[0] += 1
			return tick,
		func():
			var decoded = b._snapshot_system.decode_validated(packets[cursor[1]])
			cursor[1] += 1
			if b._snapshot_system.apply_decoded(decoded): accepted[1] += 1
			return int(decoded.packet[SNAP.S_SERVER_TICK]))
	check(accepted == [rounds * samples, rounds * samples], "all measured snapshots must apply, never stale reject")
	check(replica_state(a) == replica_state(b), "replica final states")
	decode.accepted = accepted
	decode.packet_bytes = warm.size()
	var captures: Array = []
	for receivers in [[0, 1], [0, 1, 0]]:
		var result := await pair("capture_%d_projection_%d" % [count, receivers.size()],
			func():
				var output: Array = []
				for team in receivers: output.append(old_host.capture(team))
				return output,
			func():
				var public: Array = host._snapshot_system.capture_public_frame()
				var output: Array = []
				for team in receivers: output.append(host._snapshot_system.encode_frame(public, team))
				return output)
		result.old_public_collections = rounds * samples * receivers.size()
		result.current_public_collections = rounds * samples
		result.encodes_per_side = rounds * samples * receivers.size()
		captures.append(result)
	var first: Array = bytes_to_var(host._snapshot_system.capture(0).decompress_dynamic(1024 * 1024, FileAccess.COMPRESSION_DEFLATE))
	var second: Array = bytes_to_var(host._snapshot_system.capture(1).decompress_dynamic(1024 * 1024, FileAccess.COMPRESSION_DEFLATE))
	check(first[SNAP.S_CLIENT_ELIXIR] == 3.0 and second[SNAP.S_CLIENT_ELIXIR] == 8.0 and first[SNAP.S_CARD_GROWTH] == private_growth(0) and second[SNAP.S_CARD_GROWTH] == private_growth(1), "private projections remain distinct")
	var growth := await measure_growth(a)
	var cost := await measure_cost()
	var queue_memory: Array = []
	for depth in [1, 16, 64, 256]:
		queue_memory.append(queue_probe(a._snapshot_system, warm, depth, false))
	queue_memory.append(queue_probe(a._snapshot_system, warm, NetworkPlayback.MAX_QUEUED + 1, true))
	var result := {"count": count, "deck": host._deck, "remote_deck": host._remote_deck,
		"resource_cards": host._resources.cards.keys(), "resource_paths": host._resources.resources.keys(),
		"pool_specs": pool_summary(host), "decode_apply": decode, "capture": captures,
		"growth": growth, "cost": cost, "queue_memory": queue_memory,
		"private_wallets": [3.0, 8.0], "private_growth": GROWTH, "projectile_count": 0}
	old_parser = null
	old_host = null
	for main in [a, b, host]: main.free()
	await process_frame
	await create_timer(0.25).timeout
	return result

func replica_state(main: Node2D) -> Array:
	var units: Array = []
	for id in main._client_units:
		units.append(main._snapshot_system._unit_snapshot_payload(int(id), main._client_units[id]))
	var towers: Array = []
	for tower in main._towers: towers.append(main._snapshot_system._tower_snapshot_payload(tower))
	return [units, towers, main._projectile_system.client_snapshot(), main._card_growth.snapshot(), main._elixir.elixir, main._match_rules.snapshot()]

func pool_summary(main: Node2D) -> Dictionary:
	var result := {}
	var specs := MatchModelPool.build_specs(main._resources.cards, main._resources.plan)
	for path in specs:
		result[path] = 0
		for use in specs[path]: result[path] += int(use.count)
		result[path] = mini(result[path], 64)
	return result

func measure_growth(main: Node2D) -> Dictionary:
	var old: RefCounted = legacy_growth.new()
	var payload := private_growth(0)
	old.replace_replica(payload)
	main.apply_growth_snapshot(payload)
	var counts := [0, 0]
	var hand: CountingHand = main._hand
	# 旧ref状态用于旧增长查询；UI执行真实_refresh，不替换成空计数器。
	var query: Callable = hand.growth_progress_query
	var result := await pair("unchanged_growth_100",
		func():
			hand.growth_progress_query = func(id: String): return old.progress(0, id)
			var before := hand.refreshes
			for index in 100:
				old.replace_replica(payload)
				hand._refresh(0.0)
			counts[0] += hand.refreshes - before
			return true,
		func():
			hand.growth_progress_query = query
			var before := hand.refreshes
			for index in 100: main.apply_growth_snapshot(payload)
			counts[1] += hand.refreshes - before
			return true, 100)
	hand.growth_progress_query = query
	check(counts == [rounds * samples * 100, 0], "same growth UI refresh counts")
	check(old.snapshot() == main._card_growth.snapshot(), "growth final states")
	result.refreshes = counts
	result.old_source = "reference MatchCardGrowth.replace_replica + real CardHand._refresh, equivalent archived Main.apply_growth_snapshot body"
	var changed := payload.duplicate(true)
	changed[0].kayn.ranged = 3
	var before := hand.refreshes
	main.apply_growth_snapshot(changed)
	check(hand.refreshes == before + 1, "changed growth still refreshes exactly once")
	return result

func measure_cost() -> Dictionary:
	var old: RefCounted = legacy_roster.new()
	var current := ActiveSkillRoster.new()
	var entries := {}
	var id := 0
	for card_id in CardDB.all():
		for skill in CardDB.active_skills_for(card_id):
			var max_uses := maxi(int(skill.get("max_uses", 1)), 1)
			# 包括耗尽后的读取；无限次数另覆盖超过max_uses时的封顶规则。
			for used in max_uses + (4 if bool(skill.get("unlimited_uses", false)) else 1):
				id += 1
				entries[id] = {"skill": skill, "max_uses": maxi(int(skill.get("max_uses", 1)), 1), "uses_remaining": maxi(int(skill.get("max_uses", 1)), 1) - used, "free_recast": false}
				if String(skill.get("kind", "")) == "bleeding_execute":
					id += 1
					entries[id] = {"skill": skill, "max_uses": 1, "uses_remaining": 0, "free_recast": true}
	old._entries = entries
	current._entries = entries
	var ids: Array = entries.keys()
	for key in ids: check(old.cost(key) == current.cost(key), "formal cost input equivalence")
	var result := await pair("cost_1000", func():
		var checksum := 0.0
		for index in 1000: checksum += old.cost(ids[index % ids.size()])
		return checksum,
		func():
			var checksum := 0.0
			for index in 1000: checksum += current.cost(ids[index % ids.size()])
			return checksum, 1000)
	result.formal_inputs = ids.size()
	return result

func memory() -> Dictionary:
	return {"static_bytes": OS.get_static_memory_usage(), "objects": int(Performance.get_monitor(Performance.OBJECT_COUNT))}

func owned_bytes(bytes: PackedByteArray) -> PackedByteArray:
	var owned := bytes.duplicate()
	# duplicate()本身共享COW底层；写回同一字节强制独占，字节内容保持不变。
	if not owned.is_empty(): owned[0] = owned[0]
	return owned

func queue_probe(system: NetworkSnapshotSystem, bytes: PackedByteArray, depth: int, fill_to_rejection: bool) -> Dictionary:
	var queue := NetworkPlayback.new()
	var result := {"requested": depth, "until_rejection": fill_to_rejection, "before": memory()}
	var peak := int(result.before.static_bytes)
	var accepted := 0
	var dropped := 0
	var witness: WeakRef
	for index in depth:
		var decoded := system.decode_validated(bytes)
		check(decoded != null, "queue decode")
		if queue.enqueue_snapshot(decoded):
			accepted += 1
			witness = weakref(decoded)
		else:
			dropped += 1
			var rejected: WeakRef = weakref(decoded)
			decoded = null
			check(rejected.get_ref() == null, "dropped decoded reference released")
			break
		decoded = null
		peak = maxi(peak, OS.get_static_memory_usage())
	result.accepted = accepted
	result.dropped = dropped
	result.raw_serialized_budget_bytes = queue.snapshot_bytes()
	result.filled = memory()
	result.sampled_peak_static_bytes = peak
	if fill_to_rejection: check(dropped == 1, "queue guard must reject at raw budget or count bound")
	var ready: Array[Dictionary] = queue.advance(1000000)
	result.drained_but_return_array_held = memory()
	check(queue.snapshot_count() == 0 and queue.snapshot_bytes() == 0 and ready.size() == accepted, "queue drain accounting")
	ready.clear()
	check(witness == null or witness.get_ref() == null, "drained references released with return array")
	result.drained_return_array_released = memory()
	for index in mini(depth, 16): queue.enqueue_snapshot(system.decode_validated(bytes))
	result.refilled_before_clear = memory()
	queue.clear()
	result.after_clear = memory()
	check(queue.snapshot_count() == 0 and queue.snapshot_bytes() == 0, "queue clear accounting")
	# 每次写入脱离COW，模拟独立网络接收缓冲，而非共享压缩数据的容器下界。
	var old: RefCounted = legacy_playback.new()
	result.old_before = memory()
	for index in accepted: old.enqueue(1000, &"_apply_buffered_snapshot", [owned_bytes(bytes)])
	result.old_compressed_queue_filled = memory()
	old.clear()
	result.old_after_clear = memory()
	return result

func run() -> void:
	rounds = int(option("--rounds", "5"))
	samples = int(option("--samples", "20"))
	reference = option("--reference", "")
	var output := option("--output", "")
	legacy_snapshot = load_reference("network_snapshot_system.gd")
	legacy_growth = load_reference("match_card_growth.gd")
	legacy_roster = load_reference("active_skill_roster.gd")
	legacy_playback = load_reference("network_playback.gd")
	if not failures.is_empty(): quit(1); return
	var results: Array = []
	var replay_path := option("--replay-trace", "")
	if not replay_path.is_empty(): results.append(replay_trace(replay_path))
	else:
		for value in option("--counts", "32,64,128").split(","):
			results.append(await measure_count(int(value)))
	legacy_snapshot = null
	legacy_growth = null
	legacy_roster = null
	legacy_playback = null
	await process_frame
	var result := {"schema": 1, "engine": Engine.get_version_info().string, "rendered": false, "simulation_ticks": 0,
		"rounds": rounds, "samples_per_round": samples, "results": results, "failures": failures,
		"scope": "CPU microbenchmarks; setup, encoding test packets, comparison, queue memory probes and frame drains excluded from timed samples",
		"memory_scope": "Godot static live allocations and object counts; raw serialized queue budget is not a heap bound; wrapper RSS peak includes deliberate queue stress"}
	FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("[REPEATED_WORK_RESULT] " + JSON.stringify({"passed": failures.is_empty(), "output": output}))
	quit(0 if failures.is_empty() else 1)

func replay_trace(path: String) -> Dictionary:
	var trace: Dictionary = FileAccess.open(path, FileAccess.READ).get_var()
	check(trace.get("schema") == 1 and not trace.packets.is_empty(), "valid nonempty network trace")
	var controller := Node2D.new()
	var projectiles := ProjectileSystem.new()
	var system := SNAP.new(controller, projectiles)
	# 正常对局在收包前已预热定义；离树回放也必须在双方基线前完成。
	# _valid_spawn -> CardDB.get_unit_stats -> all 会首次编译并永久持有77定义。
	var warmup := warm_trace_decoding(trace, system)
	var actual := {"current": replay_queue(trace, system, false), "old_independent_buffers": replay_queue(trace, system, true)}
	var windows: Array = []
	var largest := 0
	for index in trace.packet_meta.size():
		if int(trace.packet_meta[index].raw_bytes) > int(trace.packet_meta[largest].raw_bytes): largest = index
	var packet: Array = bytes_to_var((trace.packets[largest] as PackedByteArray).decompress_dynamic(SNAP.MAX_DECODED_BYTES, FileAccess.COMPRESSION_DEFLATE))
	for delay in [1, 2, 3, 4]:
		var probe = load("res://tools/performance/network_queue_probe.gd").new()
		probe.configure(float(delay))
		for frame_index in (32 + delay + 2) * 3:
			if frame_index % 3 == 0 and frame_index / 3 < 32:
				var projected := packet.duplicate()
				projected[SNAP.S_SERVER_TICK] = 1000 + int(frame_index / 3)
				var bytes := var_to_bytes(projected).compress(FileAccess.COMPRESSION_DEFLATE)
				probe.begin_receive(bytes)
				probe.enqueue_snapshot(system.decode_validated(bytes))
				probe.end_receive()
			probe.advance(1000.0 + float(frame_index) / 3.0)
		var fixed := {"packets": probe.packets, "events": probe.events, "fixed_delay_ticks": delay}
		windows.append({"delay_ticks": delay, "current": replay_queue(fixed, system, false), "old_independent_buffers": replay_queue(fixed, system, true)})
	var budget_checks: Array = []
	for mib in [8, 16, 64]: budget_checks.append({"mib": mib, "actual_peak_fits": int(actual.current.peak_queued_raw_bytes) <= mib * 1024 * 1024, "maximum_legal_packets_capacity": mib})
	system = null
	projectiles.free()
	controller.free()
	return {"trace_context": trace.context, "trace_summary": trace.summary, "decode_warmup": warmup, "actual_schedule": actual,
		"fixed_windows": windows, "fixed_window_scope": "32 copies of largest observed real payload; only server Tick rewritten; 20Hz arrivals, 60Hz drain, no simulation or WAN claim",
		"budget_checks": budget_checks, "production_budget_raw_bytes": NetworkPlayback.MAX_SNAPSHOT_BYTES,
		"memory_scope": "warm queue deltas only; CardDB and all trace payloads validated before both baselines; compressed archive/trace/sampling arrays excluded; delayed predecode RPC holds excluded; drain return arrays sampled before release"}

func warm_trace_decoding(trace: Dictionary, system: NetworkSnapshotSystem) -> Dictionary:
	var before := OS.get_static_memory_usage()
	var definitions_count := CardDB.all().size()
	var after_definitions := OS.get_static_memory_usage()
	for bytes: PackedByteArray in trace.packets:
		var decoded := system.decode_validated(bytes)
		check(decoded != null, "warmup trace packet validates")
		decoded = null
	var after_first_pass := OS.get_static_memory_usage()
	# 再走同一全集，独立列出预热后残留增量，避免把冷缓存误称队列常驻。
	for bytes: PackedByteArray in trace.packets:
		var decoded := system.decode_validated(bytes)
		check(decoded != null, "warmup second pass trace packet validates")
		decoded = null
	var after_second_pass := OS.get_static_memory_usage()
	return {"packets_per_pass": trace.packets.size(), "passes": 2, "definitions": definitions_count,
		"carddb_global_static_bytes": after_definitions - before,
		"first_decode_pass_static_bytes": after_first_pass - after_definitions,
		"second_decode_pass_static_bytes": after_second_pass - after_first_pass,
		"warmup_global_static_bytes": after_second_pass - before,
		"scope": "one-time global initialization before either queue baseline; all decoded warmup references released"}

func replay_queue(trace: Dictionary, system: NetworkSnapshotSystem, old: bool) -> Dictionary:
	var queue: RefCounted = legacy_playback.new() if old else NetworkPlayback.new()
	var fixed := float(trace.get("fixed_delay_ticks", 0.0))
	if fixed > 0.0: queue.delay_ticks = fixed
	var queue_counts: Array[int] = []
	var snapshot_counts: Array[int] = []
	var raw_counts: Array[int] = []
	var static_deltas: Array[int] = []
	queue_counts.resize(trace.events.size())
	snapshot_counts.resize(trace.events.size())
	raw_counts.resize(trace.events.size())
	static_deltas.resize(trace.events.size())
	# 两侧先放同样的一个WeakRef探针，避免将探针对象计入新队列增量。
	var witness: WeakRef = weakref(queue)
	var base_static := OS.get_static_memory_usage()
	var base_objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var peak_static := base_static
	var peak_objects := base_objects
	var peak_ready := 0
	var peak_ready_held_delta := 0
	var peak_after_ready_release_delta := 0
	var index := 0
	var applied := 0
	var rejected := 0
	for operation in trace.events:
		match String(operation.kind):
			"snapshot":
				var accepted: bool
				if old:
					accepted = queue.enqueue(int(operation.tick), &"_apply_buffered_snapshot", [owned_bytes(trace.packets[operation.index])])
				else:
					var decoded := system.decode_validated(trace.packets[operation.index])
					check(decoded != null, "trace packet validates")
					witness = weakref(decoded)
					accepted = queue.enqueue_snapshot(decoded)
					decoded = null
				check(accepted == bool(operation.accepted), "trace enqueue outcome")
				if not accepted: rejected += 1
			"enqueue": check(queue.enqueue(operation.tick, operation.method, operation.args) == bool(operation.accepted), "trace event enqueue")
			"observe":
				if fixed > 0.0: queue.delay_ticks = fixed
				else: queue.observe_delay(float(operation.milliseconds))
			"advance":
				var ready: Array = queue.advance(float(operation.server_time))
				check(ready.size() == operation.ready_serials.size(), "trace drain count")
				for event_index in ready.size(): check(int(ready[event_index].serial) == int(operation.ready_serials[event_index]), "trace drain order")
				applied += ready.size()
				peak_ready = maxi(peak_ready, ready.size())
				peak_static = maxi(peak_static, OS.get_static_memory_usage())
				peak_objects = maxi(peak_objects, int(Performance.get_monitor(Performance.OBJECT_COUNT)))
				peak_ready_held_delta = maxi(peak_ready_held_delta, OS.get_static_memory_usage() - base_static)
				ready.clear()
				peak_after_ready_release_delta = maxi(peak_after_ready_release_delta, OS.get_static_memory_usage() - base_static)
			"clear":
				queue.clear()
				if fixed > 0.0: queue.delay_ticks = fixed
		check(queue.size() == int(operation.queue_count), "trace queue occupancy")
		if not old: check(queue.snapshot_count() == int(operation.snapshot_count) and queue.snapshot_bytes() == int(operation.raw_bytes), "trace decoded queue byte/count accounting")
		queue_counts[index] = queue.size()
		snapshot_counts[index] = int(operation.snapshot_count)
		raw_counts[index] = int(operation.raw_bytes)
		static_deltas[index] = OS.get_static_memory_usage() - base_static
		index += 1
		peak_static = maxi(peak_static, OS.get_static_memory_usage())
		peak_objects = maxi(peak_objects, int(Performance.get_monitor(Performance.OBJECT_COUNT)))
	queue.clear()
	check(old or witness == null or witness.get_ref() == null, "trace final decoded release")
	var after_clear := OS.get_static_memory_usage() - base_static
	var after_objects := int(Performance.get_monitor(Performance.OBJECT_COUNT)) - base_objects
	witness = null
	var stats = load("res://tools/performance/network_queue_probe.gd")
	var occupied_counts: Array[int] = []
	var occupied_raw: Array[int] = []
	var occupied_static: Array[int] = []
	for sample_index in snapshot_counts.size():
		if snapshot_counts[sample_index] > 0:
			occupied_counts.append(snapshot_counts[sample_index])
			occupied_raw.append(raw_counts[sample_index])
			occupied_static.append(static_deltas[sample_index])
	return {"queue_count": stats.stats(queue_counts), "snapshot_count": stats.stats(snapshot_counts), "raw_bytes": stats.stats(raw_counts),
		"occupied_snapshot_count": stats.stats(occupied_counts), "occupied_raw_bytes": stats.stats(occupied_raw), "occupied_static_delta_bytes": stats.stats(occupied_static),
		"peak_queued_raw_bytes": raw_counts.max() if not raw_counts.is_empty() else 0,
		"static_baseline_bytes": base_static, "peak_static_delta_bytes": peak_static - base_static,
		"peak_objects_delta": peak_objects - base_objects, "after_clear_static_delta_bytes": after_clear,
		"after_clear_objects_delta": after_objects, "peak_ready_events": peak_ready, "drained_events": applied, "queue_rejected": rejected,
		"peak_ready_held_static_delta_bytes": peak_ready_held_delta, "peak_after_ready_release_static_delta_bytes": peak_after_ready_release_delta,
		"sampling": "same operation-boundary sequence on both sides; occupied means snapshot_count>0; no time-weighted percentile",
		"old_buffer_policy": "independent COW detach by same-byte write" if old else "independent decode per received packet"}
