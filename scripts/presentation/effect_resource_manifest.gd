extends RefCounted
## 效果提供者声明文件和采样方法。这里不认识卡牌或技能名称。

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
	return manifest

## JSON 保留在独立的原始文件清单中；纹理/场景/Shader 才交给 ResourceLoader。
static func files(request: Dictionary, errors: PackedStringArray) -> Dictionary:
	var manifest := resolve(request, errors)
	var paths: Array = manifest.get("paths", []).duplicate()
	var raw: Array = []
	var sample: Dictionary = manifest.get("sample", {})
	var player_path := String(sample.get("player", manifest.get("emitter_provider", "")))
	var player: Script = load(player_path) if not player_path.is_empty() else null
	for path in manifest.get("raw", []):
		if path not in raw: raw.append(path)
	if manifest.has("emitter_source"):
		var emitters: Array = load(manifest.emitter_source).resource_emitters()
		_collect_files(emitters, paths, raw)
		_collect_shaders(emitters, load(manifest.emitter_source), paths)
	for path in manifest.get("json", []):
		if not FileAccess.file_exists(path):
			errors.append("效果数据不存在: " + path)
			continue
		raw.append(path)
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data == null:
			errors.append("效果数据无法解析: " + path)
			continue
		if manifest.has("systems"):
			var systems := {}
			for key in manifest.systems:
				if not data is Dictionary or not data.has(key): errors.append("效果数据缺少系统: %s / %s" % [path, key])
				else: systems[key] = data[key]
			data = systems
		var emitters: Variant = data.get("emitters", data) if data is Dictionary else data
		if player != null and sample.has("kind") and player.has_method("layer_enabled"):
			emitters = emitters.filter(func(emitter): return player.layer_enabled(String(sample.kind), String(emitter.name)))
		_collect_files(emitters, paths, raw)
		if player != null and player.has_method("resource_shader_path"): _collect_shaders(emitters, player, paths)
		for shader_provider in manifest.get("shader_providers", []): _collect_shaders(emitters, load(shader_provider), paths)
	return {"resources": paths, "raw": raw}

static func _collect_files(value: Variant, paths: Array, raw: Array) -> void:
	if value is Dictionary:
		for child in value.values(): _collect_files(child, paths, raw)
	elif value is Array:
		for child in value: _collect_files(child, paths, raw)
	elif value is String and value.begins_with("res://"):
		var target: Array = raw if value.ends_with(".json") else paths
		if value not in target: target.append(value)

static func _collect_shaders(value: Variant, player: Script, paths: Array) -> void:
	if value is Dictionary:
		if (player.resource_shader_matches(value) if player.has_method("resource_shader_matches") else value.has("blendMode")):
			var path: String = player.resource_shader_path(value)
			if path not in paths: paths.append(path)
		else:
			for child in value.values(): _collect_shaders(child, player, paths)
	elif value is Array:
		for child in value: _collect_shaders(child, player, paths)
