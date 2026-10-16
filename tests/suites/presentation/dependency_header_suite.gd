extends RefCounted
const MANIFEST = preload("res://scripts/presentation/effect_resource_manifest.gd")

func run(harness: Object) -> void:
	var path := "/tmp/clash-effect-dependencies-%d.json" % OS.get_process_id()
	var header_path := path.get_basename() + ".dependencies.json"
	var original := {"fps": 30, "emitters": [{"name": "test", "enabled": false, "texture_path": "res://assets/arena/arena_rift_v4.png", "nested": {"mesh": "res://assets/units/gnar/gnar_mega_view.tscn", "blendMode": 4}}], "frames": [[[[1, 2, 3]]]]}
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(original))
	var header := {"schema": 1, "source": path, "source_sha256": FileAccess.get_sha256(path), "data": {"fps": 30, "emitters": original.emitters}}
	FileAccess.open(header_path, FileAccess.WRITE).store_string(JSON.stringify(header))
	header = JSON.parse_string(FileAccess.get_file_as_string(header_path))
	var raw: Array = []
	var data: Variant = MANIFEST.dependency_data(path, raw)
	harness._expect(data == header.data and not data.has("frames") and raw == [header_path], "匹配完整源SHA的依赖头保留元数据且登记原始依赖")
	data = MANIFEST.dependency_data(path, raw)
	harness._expect(data == header.data and raw == [header_path], "重复收集只登记一次依赖头且保留禁用层及嵌套资源/Shader字段")
	original.frames[0][0][0][0] = 9
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(original))
	original = JSON.parse_string(FileAccess.get_file_as_string(path))
	raw.clear()
	data = MANIFEST.dependency_data(path, raw)
	harness._expect(data == original and raw.is_empty(), "源文件变化后旧依赖头不会漏加载，回退完整JSON")
	for field in ["schema", "source", "source_sha256", "data"]:
		var invalid := header.duplicate(true)
		invalid.source_sha256 = FileAccess.get_sha256(path)
		invalid[field] = -1
		FileAccess.open(header_path, FileAccess.WRITE).store_string(JSON.stringify(invalid))
		raw.clear()
		harness._expect(MANIFEST.dependency_data(path, raw) == original and raw.is_empty(), "无效依赖头合同回退：" + field)
	for invalid_data in [{}, {"emitters": "wrong type"}]:
		var invalid := header.duplicate(true)
		invalid.source_sha256 = FileAccess.get_sha256(path)
		invalid.data = invalid_data
		FileAccess.open(header_path, FileAccess.WRITE).store_string(JSON.stringify(invalid))
		raw.assign(["/tmp/already-collected.json"])
		harness._expect(MANIFEST.dependency_data(path, raw) == original and raw == ["/tmp/already-collected.json"], "依赖头缺失/错误发射器结构回退且不污染已有原始依赖")
	FileAccess.open(header_path, FileAccess.WRITE).store_string("not json")
	raw.clear()
	harness._expect(MANIFEST.dependency_data(path, raw) == original and raw.is_empty(), "损坏依赖头安全回退完整数据")
	DirAccess.remove_absolute(header_path)
	harness._expect(MANIFEST.dependency_data(path, raw) == original, "缺少依赖头仍支持原始JSON")
	DirAccess.remove_absolute(path)
	if "--full-dependency-headers" in OS.get_cmdline_user_args():
		print("[DEPENDENCY_HEADER_SCOPE] explicit-full-source-projection")
		var count := _check_formal(harness, "res://assets/effects", 0)
		harness._expect(count > 0, "显式全量模式：正式依赖头均纳入源数据等价检查")
	else:
		print("[DEPENDENCY_HEADER_SCOPE] small-fixture/header-contract-only; formal source/header equivalence belongs to tools/maintenance/effect_dependencies.py --check")

func _check_formal(harness: Object, folder: String, count: int) -> int:
	for file in DirAccess.get_files_at(folder):
		if not file.ends_with(".dependencies.json"): continue
		var header: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(file)))
		var full: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(header.source))
		full.erase("frames")
		var raw: Array = []
		var projected: Variant = MANIFEST.dependency_data(header.source, raw)
		harness._expect(projected == full and raw == [folder.path_join(file)], "正式依赖头完整保留所有发射器/资源/Shader判别字段：" + header.source)
		count += 1
	for child in DirAccess.get_directories_at(folder): count = _check_formal(harness, folder.path_join(child), count)
	return count
