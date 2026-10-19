extends RefCounted
## 一个模型根的一次活体动画准备。包装器直用与通用绑定移交同一个记录。
const COPY = preload("res://scripts/presentation/model_animation_copy.gd")
const SLOT := &"model_animation_instance_v1"
var errors := PackedStringArray()
var player: AnimationPlayer
var complete := false
var copied_animations := 0
var policy := "scene-clips-v1"
var _root: WeakRef
var _jobs: Array = []
var _copies := {}
var _libraries := {}
var _animations := {}
var _source_catalog := {}
var _selected := {}
var _template_sources := {}

static func begin(root: Node, allowed: Dictionary = {}) -> RefCounted:
	if root.has_meta(SLOT):
		var existing: Variant = root.get_meta(SLOT)
		if existing is RefCounted and existing.get_script() == load("res://scripts/presentation/model_animation_instance.gd"):
			existing.validate(root)
			if existing.errors.is_empty():
				var request_errors: PackedStringArray = existing.requirement_errors(allowed)
				if not request_errors.is_empty():
					var rejected := new()
					rejected.errors = request_errors
					return rejected # 拒绝本次需求，不污染仍有效的原记录。
			return existing
		var invalid := new()
		invalid.errors.append("Unknown model animation ownership record")
		return invalid
	var owner := new()
	owner._root = weakref(root)
	owner._begin(root, allowed)
	root.set_meta(SLOT, owner)
	return owner

func _begin(root: Node, allowed: Dictionary) -> void:
	var sources := {}
	if root.has_method("visual_animation_contract"):
		var contract: Variant = root.call("visual_animation_contract")
		if contract is Dictionary and contract.get("errors") is PackedStringArray and not contract.errors.is_empty():
			errors.append_array(contract.errors)
			return
		if not contract is Dictionary or not contract.get("version") is int or contract.get("version") != 1 or not contract.get("player") is AnimationPlayer or not contract.get("libraries") is Dictionary or contract.libraries.is_empty():
			errors.append("Invalid visual_animation_contract v1")
			return
		player = contract.player
		if not root.is_ancestor_of(player):
			errors.append("Animation contract player is outside model")
			return
		sources = contract.libraries
		policy = "generated-template-v1"
		_template_sources = sources.duplicate()
		# 模板已经按开发声明选择完整片段闭包，含后续形态/摄影动作。
		# 不用当前形态 allowed 再裁一次，也不靠脚本存在与否猜测。
	else:
		player = find_player(root)
		if player == null:
			complete = true
			return
		if not supports_clip_filter(root):
			policy = "legacy-script-unfiltered-v1"
			allowed = {}
		for name in player.get_animation_library_list(): sources[name] = player.get_animation_library(name)
	# 完整验证后才替换库；坏声明不留下半套活体资源。
	for name in sources:
		if not (name is String or name is StringName) or not sources[name] is AnimationLibrary:
			errors.append("Animation template must contain named AnimationLibrary")
			return
	# allowed来自配置递归收集，只有来源目录中的真实clip名构成需求；
	# idle/attack等字段键不当作clip。原导入目录也保留，能识别模板漏掉的真实需求。
	for clip in player.get_animation_list(): _source_catalog[String(clip)] = true
	for name in sources:
		for clip in sources[name].get_animation_list():
			var full := _full_name(name, clip)
			_source_catalog[full] = true
			if policy != "scene-clips-v1" or sources[name].get_script() != null or not sources[name].get_meta_list().is_empty() or allowed.is_empty() or allowed.has(full) or clip == &"RESET": _selected[full] = true
	errors.append_array(requirement_errors(allowed))
	if not errors.is_empty(): return
	for name in player.get_animation_library_list(): player.remove_animation_library(name)
	for name in sources:
		var source: Variant = sources[name]
		# 扩展库走既有保真复制；生成模板只允许内建无元数据库。
		if source.get_script() != null or not source.get_meta_list().is_empty():
			_jobs.append({"name": name, "source": source})
			continue
		var library := source.duplicate(false) as AnimationLibrary
		for clip in library.get_animation_list(): library.remove_animation(clip)
		_install(name, library)
		for clip in source.get_animation_list():
			var full_name := _full_name(name, clip)
			if _selected.has(full_name):
				_jobs.append({"library": library, "clip": clip, "full_name": full_name, "animation": source.get_animation(clip)})

static func _full_name(library: Variant, clip: Variant) -> String:
	return String(clip) if String(library).is_empty() else String(library) + "/" + String(clip)

func requirement_errors(allowed: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	# 固定模板空需求=完整声明闭包；普通空需求=完整原来源目录。
	var requested: Dictionary = _selected if policy == "generated-template-v1" and allowed.is_empty() else (_source_catalog if allowed.is_empty() else allowed)
	for clip in requested:
		if _source_catalog.has(String(clip)) and not _selected.has(String(clip)):
			result.append("Animation request exceeds prepared clip closure: " + String(clip))
	return result

func _install(name: StringName, library: AnimationLibrary) -> void:
	if player.has_animation_library(name): player.remove_animation_library(name)
	player.add_animation_library(name, library)
	_libraries[name] = library

func step() -> bool:
	if complete or not errors.is_empty(): return true
	validate(_root.get_ref() if _root != null else null, false)
	if not errors.is_empty(): return true
	if not _jobs.is_empty():
		var job: Dictionary = _jobs.pop_back()
		if job.has("source"):
			_install(job.name, COPY.copy_library(job.source))
			for clip in player.get_animation_library(job.name).get_animation_list():
				var full := _full_name(job.name, clip)
				_animations[full] = player.get_animation(full)
		else:
			if not _copies.has(job.animation):
				_copies[job.animation] = COPY.copy_animation(job.animation)
				copied_animations += 1
			job.library.add_animation(job.clip, _copies[job.animation])
			_animations[job.full_name] = _copies[job.animation]
	if not _jobs.is_empty(): return false
	_copies.clear()
	validate(_root.get_ref())
	if not errors.is_empty(): return true
	complete = true
	return true

func validate(root: Node, verify_animations: bool = true) -> void:
	if _root == null or _root.get_ref() == null or _root.get_ref() != root:
		errors.append("Animation ownership transferred to a different model")
		return
	if player == null: return
	if not is_instance_valid(player):
		errors.append("Animation ownership player was freed")
		return
	if policy == "generated-template-v1":
		var contract: Variant = root.call("visual_animation_contract") if root.has_method("visual_animation_contract") else null
		if not contract is Dictionary or contract.get("version") != 1 or contract.get("player") != player or not contract.get("libraries") is Dictionary or contract.libraries.size() != _template_sources.size():
			errors.append("Fixed animation template contract changed")
			return
		for name in _template_sources:
			if contract.libraries.get(name) != _template_sources[name]: errors.append("Fixed animation template library replaced: " + String(name))
	if player.get_animation_library_list().size() != _libraries.size():
		errors.append("Owned animation set changed during/after preparation")
		return
	for name in _libraries:
		if player.get_animation_library(name) != _libraries[name]: errors.append("Owned animation library replaced: " + String(name))
	if not verify_animations: return # 每clip step只核对库身份，避免重复扫描全部已完成clip。
	if player.get_animation_list().size() != _animations.size():
		errors.append("Owned animation clips changed during/after preparation")
		return
	for name in _animations:
		if player.get_animation(name) != _animations[name]: errors.append("Owned animation replaced: " + String(name))

static func supports_clip_filter(node: Node) -> bool:
	if node.has_method("visual_animation_contract"): return true
	return scene_has_no_scripts(node)

## 仅用于旧动画clip裁剪策略；不再被解释为运行时构造能力。
static func scene_has_no_scripts(node: Node) -> bool:
	if node.get_script() != null: return false
	for child in node.get_children():
		if not scene_has_no_scripts(child): return false
	return true

static func find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found := find_player(child)
		if found != null: return found
	return null
