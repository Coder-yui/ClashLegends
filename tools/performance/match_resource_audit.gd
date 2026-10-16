extends RefCounted
## Diagnostic provenance for known paths; cache membership is observed, not inferred from text.
const MANIFEST = preload("res://scripts/presentation/effect_resource_manifest.gd")
var candidates := {}
var origins := {}
var preload_sites := {}
var _scripts_seen := {}

func _init() -> void:
	for id in CardDB.all(): _paths(CardDB.get_card(id), candidates, "definition:" + String(id))
	_script("res://scripts/main.gd")

func _paths(value: Variant, target: Dictionary, label: String) -> void:
	if value is Dictionary:
		for key in value: _paths(value[key], target, label + "/" + String(key))
	elif value is Array or value is PackedStringArray:
		for index in value.size(): _paths(value[index], target, label + "/" + str(index))
	elif value is String and value.begins_with("res://"):
		if not target.has(value): target[value] = []
		if label not in target[value]: target[value].append(label)

func _script(path: String) -> void:
	if _scripts_seen.has(path) or not FileAccess.file_exists(path): return
	_scripts_seen[path] = true
	var regex := RegEx.new()
	regex.compile("(preload|load)\\(\\s*[\"'](res://[^\"']+)[\"']")
	var text := FileAccess.get_file_as_string(path)
	for found in regex.search_all(text):
		var child := found.get_string(2)
		if not candidates.has(child): candidates[child] = []
		if not preload_sites.has(child): preload_sites[child] = []
		preload_sites[child].append({"caller": path, "call": found.get_string(1)})
		if child.ends_with(".gd"): _script(child)

func describe_plan(plan: RefCounted) -> void:
	origins.clear()
	for id in plan.cards:
		for team in plan.cards[id]:
			_paths(plan.definition(id, team), origins, "card:" + id + "/team:" + str(team) + "/selected:" + str(plan.skills[id][team]))
	_paths(CardDB.PRINCESS_TOWER_VISUAL_CONFIG, origins, "shared:both_towers")
	_paths(CardDB.NEXUS_VISUAL_CONFIG, origins, "shared:both_nexus")
	_paths(preload("res://scripts/data/world_audio.gd").DEFINITIONS, origins, "shared:world_audio")
	_paths(preload("res://scripts/data/match_audio.gd").EVENTS, origins, "shared:match_audio")
	origins["res://assets/arena/rift_arena/rift_arena.tscn"] = ["shared:arena"]
	var failures := PackedStringArray()
	for request in plan.effects:
		var files := MANIFEST.files(request, failures)
		for path in files.resources + files.raw:
			if not origins.has(path): origins[path] = []
			origins[path].append("effect:" + request.card + "/" + request.provider + ":" + request.variant)
	for path in origins:
		if not candidates.has(path): candidates[path] = []
		if not path.ends_with(".json") and not path.ends_with(".clps"): _dependencies(path, path, {})

func _dependencies(path: String, root: String, visited: Dictionary) -> void:
	if visited.has(path) or not ResourceLoader.exists(path): return
	visited[path] = true
	for dependency in ResourceLoader.get_dependencies(path):
		var child: String = String(dependency).split("::")[-1]
		if not child.begins_with("res://"): continue
		if not candidates.has(child): candidates[child] = []
		if not origins.has(child): origins[child] = []
		var label := "engine_dependency:" + root
		if label not in origins[child]: origins[child].append(label)
		_dependencies(child, root, visited)

func snapshot(stage: String, resources: MatchResources = null) -> Dictionary:
	var loaded := {}
	var outside := {}
	var types := {}
	for path in candidates:
		if path.ends_with(".gd") or not ResourceLoader.has_cached(path): continue
		var resource := ResourceLoader.get_cached_ref(path)
		if resource == null: continue
		var kind := resource.get_class()
		types[kind] = int(types.get(kind, 0)) + 1
		loaded[path] = {"type": kind, "origins": origins.get(path, []), "literal_sites": preload_sites.get(path, [])}
		if resources != null and not resources.resources.has(path): outside[path] = loaded[path]
	return {"stage": stage, "known_loaded_count": loaded.size(), "types": types, "known_loaded": loaded, "outside_direct_plan": outside, "card_art_cache_ids": CardArt._textures.keys(), "scope": "known definition/literal/transitive paths only; has_cached observed; raw FileAccess datasets are not ResourceLoader resources; static call sites do not prove execution"}
