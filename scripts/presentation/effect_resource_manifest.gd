extends RefCounted
## 效果提供者声明文件和采样方法。这里不认识卡牌或技能名称。
const COVERAGE = preload("res://scripts/presentation/effect_warmup_coverage.gd")

static func requests(cards: Dictionary, plan: RefCounted, definitions: Dictionary) -> Array[Dictionary]:
	if plan != null: return plan.effects
	var result: Array[Dictionary] = []
	for id in cards:
		collect_requests(definitions[id], String(id), result)
	return result

static func collect_requests(stats: Dictionary, id: String, result: Array[Dictionary]) -> void:
	for effect in stats.get("resource_dependencies", {}).get("effects", []):
		var request: Dictionary = effect.duplicate()
		request.card = id
		request.radius = float(stats.get("radius", 110.0))
		if request not in result: result.append(request)
	for skill in stats.get("active_skills", []): collect_requests(skill, id, result)
	if stats.has("transformed_stats"): collect_requests(stats.transformed_stats, id, result)

static func resolve(request: Dictionary, errors: PackedStringArray) -> Dictionary:
	var path := String(request.provider)
	var provider := load(path) as Script
	if provider == null or not provider.has_method("resource_manifest"):
		errors.append("效果缺少 resource_manifest: " + path)
		return {}
	var manifest: Dictionary = provider.resource_manifest(String(request.variant))
	if manifest.is_empty(): errors.append("未知效果变体: %s / %s" % [path, request.variant])
	for state in manifest.get("target_states", []):
		if state not in ["stasis", "freeze"]: errors.append("未知目标表现状态: %s / %s" % [path, state])
	if manifest.has("sample") and COVERAGE.plan(manifest.sample, errors).is_empty(): return {}
	return manifest

## Generated per provider/variant. No source parsing, fingerprints or process-wide cache.
const DIRECTORY := "res://assets/generated/effect_dependencies/"
const SCHEMA := 1
const POLICY := "effect-files-v1"
const GENERATOR := "effect-artifacts-v1"
const MAX_BYTES := 262144

static func artifact_path(request: Dictionary) -> String:
	return DIRECTORY + (String(request.provider) + "\n" + String(request.variant)).sha256_text() + ".json"

static func files(request: Dictionary, errors: PackedStringArray) -> Dictionary:
	return read_artifact(artifact_path(request), request, errors)

static func read_artifact(path: String, request: Dictionary, errors: PackedStringArray) -> Dictionary:
	var empty := {"resources": [], "raw": []}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 2 or file.get_length() > MAX_BYTES:
		errors.append("效果依赖产物缺失/长度错误，运行 python3 tools/dev.py resources --write: " + path)
		return empty
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		errors.append("效果依赖产物JSON损坏: " + path)
		return empty
	var value: Variant = parser.data
	if not value is Dictionary or typeof(value.get("schema")) not in [TYPE_INT, TYPE_FLOAT] or value.schema != SCHEMA or not value.get("generator") is String or value.generator != GENERATOR or not value.get("policy") is String or value.policy != POLICY or not value.get("provider") is String or value.provider != request.provider or not value.get("variant") is String or value.variant != request.variant:
		errors.append("效果依赖产物schema/策略/身份错误: " + path)
		return empty
	if not value.get("source_identity") is Dictionary or not value.get("selection") is Dictionary or not value.get("policy_sha256") is String or value.policy_sha256.length() != 64 or not value.policy_sha256.is_valid_hex_number(false):
		errors.append("效果依赖产物生成身份错误: " + path)
		return empty
	for key in ["resources", "raw"]:
		if not value.get(key) is Array or value[key].size() > 4096:
			errors.append("效果依赖产物数组错误: " + path)
			return empty
		for item in value[key]:
			if not item is String or not item.begins_with("res://") or ".." in item or item.length() > 1024:
				errors.append("效果依赖产物路径错误: " + path)
				return empty
	var raw: Array = value.raw.duplicate()
	if path not in raw: raw.append(path)
	return {"resources": value.resources, "raw": raw, "selection": value.selection}
