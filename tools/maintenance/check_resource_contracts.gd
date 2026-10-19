extends SceneTree
const PULSE = preload("res://tools/performance/safe_probe_heartbeat.gd")
const COMPACT = preload("res://scripts/presentation/compact_particle_samples.gd")
var pulse: RefCounted
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	pulse = PULSE.new(self)
	call_deferred("run")

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)

func run() -> void:
	if not pulse.enabled: quit(2); return
	preload("res://tests/suites/presentation/dependency_header_suite.gd").new().run(self)
	var path := "/tmp/clash-compact-contract-%d.clps" % OS.get_process_id()
	var payload := PackedInt64Array([0, 1]).to_byte_array()
	payload.append_array(PackedInt64Array([7]).to_byte_array())
	payload.append_array(PackedFloat64Array([1.0, 2.0, 3.0]).to_byte_array())
	var header := {"schema": 2, "generator": "compact-f64-v2", "source": ("res" + "://absent-editable-source.json"), "source_sha256": "a".repeat(64), "payload_sha256": _sha(payload), "frames": 1, "layers": 1, "rows": 1, "width": 4, "payload_bytes": 48, "data": {"fps": 30, "duration": 1, "emitters": [{}]}}
	_save(path, header, payload)
	var samples := COMPACT.new()
	_expect(samples.read(path, header.source) and samples.count(0, 0) == 1 and samples.row(0) == [7, 1.0, 2.0, 3.0], "微型CLPS无源件运行且行数据完整")
	for field in ["schema", "generator", "source", "frames", "layers", "rows", "width", "payload_bytes", "source_sha256", "payload_sha256", "data"]:
		var invalid := header.duplicate(true)
		invalid[field] = -1
		_save(path, invalid, payload)
		samples = COMPACT.new()
		_expect(not samples.read(path, header.source) and not samples.errors.is_empty() and samples.values.is_empty(), "CLPS坏头拒绝：" + field)
	for offsets in [[1, 1], [0, 2], [0, -1]]:
		var bad := PackedInt64Array(offsets).to_byte_array()
		bad.append_array(payload.slice(16))
		var changed := header.duplicate(true)
		changed.payload_sha256 = _sha(bad)
		_save(path, changed, bad)
		samples = COMPACT.new()
		_expect(not samples.read(path, header.source), "载荷SHA正确但offset错误仍拒绝")
	var nonmonotonic := PackedInt64Array([0, 1, 0, 1]).to_byte_array()
	nonmonotonic.append_array(payload.slice(16))
	var interior := header.duplicate(true)
	interior.frames = 3
	interior.payload_bytes = nonmonotonic.size()
	interior.payload_sha256 = _sha(nonmonotonic)
	_save(path, interior, nonmonotonic)
	samples = COMPACT.new()
	_expect(not samples.read(path, header.source), "offset端点正确但内部倒退仍拒绝")
	_save(path, header, payload)
	samples = COMPACT.new()
	_expect(samples.read(path, header.source), "有效数据恢复")
	_expect(samples.count(-1, 0) == 0 and samples.begin(0, 1) == 0 and samples.row(1).is_empty() and samples.errors.size() == 3, "帧/层/行数组边界显式记录错误")
	var longer := header.duplicate(true)
	longer.frames = 2
	longer.payload_bytes = 56
	_save(path, longer, payload)
	samples = COMPACT.new()
	_expect(not samples.read(path, header.source), "错误解压长度拒绝")
	var wrong_hash := header.duplicate(true)
	wrong_hash.payload_sha256 = "b".repeat(64)
	_save(path, wrong_hash, payload)
	samples = COMPACT.new()
	_expect(not samples.read(path, header.source), "载荷SHA继续校验")
	DirAccess.remove_absolute(path)
	print("[RESOURCE_CONTRACTS] ", JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	pulse.set_phase("done", true)
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _sha(payload: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(payload)
	return hash.finish().hex_encode()

func _save(path: String, header: Dictionary, payload: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	var text := JSON.stringify(header).to_utf8_buffer()
	file.store_buffer(COMPACT.MAGIC.to_ascii_buffer())
	file.store_32(text.size())
	file.store_buffer(text)
	file.store_buffer(payload.compress(FileAccess.COMPRESSION_ZSTD))
