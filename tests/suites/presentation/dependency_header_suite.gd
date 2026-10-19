extends RefCounted
## Small generated-artifact contract, no real source parsing or player prewarm.
const MANIFEST = preload("res://scripts/presentation/effect_resource_manifest.gd")

func run(harness: Object) -> void:
	var path := "/tmp/clash-effect-artifact-%d.json" % OS.get_process_id()
	var request := {"provider": ("res" + "://fixture.gd"), "variant": "filtered"}
	var valid := {"schema": 1, "generator": "effect-artifacts-v1", "policy": "effect-files-v1", "provider": request.provider, "variant": request.variant, "policy_sha256": "a".repeat(64), "source_identity": {("res" + "://absent-source.json"): "b".repeat(64)}, "selection": {"sample": {"kind": "filtered"}}, "resources": [("res" + "://fixture.png")], "raw": [("res" + "://runtime.json")]}
	_write(path, JSON.stringify(valid))
	var errors := PackedStringArray()
	var result := MANIFEST.read_artifact(path, request, errors)
	harness._expect(errors.is_empty() and result.resources == valid.resources and result.raw == [("res" + "://runtime.json"), path], "生成依赖直接消费；源文件不必存在；资源与原始数据分开登记")
	for field in ["schema", "generator", "policy", "provider", "variant", "source_identity", "selection", "policy_sha256", "resources", "raw"]:
		var invalid := valid.duplicate(true)
		invalid[field] = -1
		_write(path, JSON.stringify(invalid))
		errors.clear()
		result = MANIFEST.read_artifact(path, request, errors)
		harness._expect(not errors.is_empty() and result.resources.is_empty() and result.raw.is_empty(), "错误产物显式拒绝，无源解析回退：" + field)
	for text in ["not json", " ".repeat(MANIFEST.MAX_BYTES + 1), JSON.stringify({"schema": 1})]:
		_write(path, text)
		errors.clear()
		MANIFEST.read_artifact(path, request, errors)
		harness._expect(not errors.is_empty(), "损坏/超大/缺字段产物拒绝")
	var invalid := valid.duplicate(true)
	invalid.resources = [("res" + "://../escape.png")]
	_write(path, JSON.stringify(invalid))
	errors.clear()
	MANIFEST.read_artifact(path, request, errors)
	harness._expect(not errors.is_empty(), "越界路径拒绝")
	DirAccess.remove_absolute(path)
	errors.clear()
	MANIFEST.read_artifact(path, request, errors)
	harness._expect(not errors.is_empty(), "缺产物显式拒绝")
	errors.clear()
	MANIFEST.files({"provider": ("res" + "://unknown.gd"), "variant": "unknown"}, errors)
	harness._expect(not errors.is_empty(), "未知provider/variant显式拒绝")

func _write(path: String, text: String) -> void:
	FileAccess.open(path, FileAccess.WRITE).store_string(text)
