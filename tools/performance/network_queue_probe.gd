extends NetworkPlayback
## 仅network测试flag启用。保留生产队列逻辑，只存压缩输入和数值调度轨迹。
var packets: Array[PackedByteArray] = []
var packet_meta: Array[Dictionary] = []
var events: Array[Dictionary] = []
var _incoming := PackedByteArray()
var _receiving := false
var _enqueued := false
var _fixed_delay := 0.0
var rejected := 0
var transport_dropped := 0

func configure(fixed_delay: float = 0.0) -> void:
	_fixed_delay = clampf(fixed_delay, 1.0, 4.0) if fixed_delay > 0.0 else 0.0
	if _fixed_delay > 0.0: delay_ticks = _fixed_delay

func begin_receive(bytes: PackedByteArray) -> void:
	_incoming = bytes
	_receiving = true
	_enqueued = false

func end_receive() -> void:
	if _receiving and not _enqueued: _record({"kind": "ignored_receive", "compressed_bytes": _incoming.size()})
	_incoming = PackedByteArray()
	_receiving = false

func record_transport_drop(size: int) -> void:
	transport_dropped += 1
	_record({"kind": "transport_drop", "compressed_bytes": size})

func enqueue_snapshot(snapshot: NetworkSnapshotSystem.DecodedSnapshot) -> bool:
	var accepted := super.enqueue_snapshot(snapshot)
	if not accepted: rejected += 1
	var index := packets.size()
	packets.append(_incoming)
	packet_meta.append({"tick": int(snapshot.packet[NetworkSnapshotSystem.S_SERVER_TICK]), "compressed_bytes": _incoming.size(), "raw_bytes": snapshot.raw_bytes_size, "units": snapshot.packet[NetworkSnapshotSystem.S_UNITS].size(), "projectiles": snapshot.packet[NetworkSnapshotSystem.S_PROJECTILES].size()})
	_enqueued = true
	_record({"kind": "snapshot", "index": index, "tick": int(snapshot.packet[NetworkSnapshotSystem.S_SERVER_TICK]), "accepted": accepted})
	return accepted

func enqueue(at_tick: int, method: StringName, args: Array) -> bool:
	var accepted := super.enqueue(at_tick, method, args)
	_record({"kind": "enqueue", "tick": at_tick, "method": method, "args": args.duplicate(true), "accepted": accepted})
	return accepted

func observe_delay(milliseconds: float) -> void:
	if _fixed_delay > 0.0: delay_ticks = _fixed_delay
	else: super.observe_delay(milliseconds)
	_record({"kind": "observe", "milliseconds": milliseconds})

func advance(server_tick: float) -> Array[Dictionary]:
	var ready := super.advance(server_tick)
	var serials: Array[int] = []
	for event in ready: serials.append(int(event.serial))
	_record({"kind": "advance", "server_time": server_tick, "ready_serials": serials})
	return ready

func clear() -> void:
	super.clear()
	if _fixed_delay > 0.0: delay_ticks = _fixed_delay
	_record({"kind": "clear"})

func _record(event: Dictionary) -> void:
	event.time_usec = Time.get_ticks_usec()
	event.queue_count = size()
	event.snapshot_count = snapshot_count()
	event.raw_bytes = snapshot_bytes()
	event.delay_ticks = delay_ticks
	events.append(event)

static func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {"samples": 0}
	var ordered := values.duplicate()
	ordered.sort()
	return {"samples": ordered.size(), "p50": ordered[ceili(ordered.size() * 0.5) - 1], "p95": ordered[ceili(ordered.size() * 0.95) - 1], "peak": ordered.back()}

func save(path: String, context: Dictionary) -> void:
	var occupied := events.filter(func(e): return int(e.snapshot_count) > 0)
	var summary := {"queue_count": stats(events.map(func(e): return e.queue_count)), "snapshot_count": stats(events.map(func(e): return e.snapshot_count)), "queued_raw_bytes": stats(events.map(func(e): return e.raw_bytes)), "delay_ticks": stats(events.map(func(e): return e.delay_ticks)), "compressed_packet_bytes": stats(packet_meta.map(func(e): return e.compressed_bytes)), "raw_packet_bytes": stats(packet_meta.map(func(e): return e.raw_bytes)), "units": stats(packet_meta.map(func(e): return e.units)), "projectiles": stats(packet_meta.map(func(e): return e.projectiles)), "queue_rejected": rejected, "transport_dropped": transport_dropped, "packet_count": packets.size()}
	summary.occupied_snapshot_count = stats(occupied.map(func(e): return e.snapshot_count))
	summary.occupied_raw_bytes = stats(occupied.map(func(e): return e.raw_bytes))
	summary.sampling = "operation-boundary weighted, not time-weighted; occupied excludes empty/load samples; peak includes enqueue-before-advance"
	var data := {"schema": 1, "context": context, "packets": packets, "packet_meta": packet_meta, "events": events, "summary": summary, "fixed_delay_ticks": _fixed_delay, "budget_raw_bytes": MAX_SNAPSHOT_BYTES}
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path, FileAccess.WRITE).store_var(data)
	FileAccess.open(path + ".json", FileAccess.WRITE).store_string(JSON.stringify({"context": context, "summary": summary, "budget_raw_bytes": MAX_SNAPSHOT_BYTES}, "\t"))
	print("[QUEUE_TRACE_RESULT] " + JSON.stringify({"path": path, "summary": summary}))
