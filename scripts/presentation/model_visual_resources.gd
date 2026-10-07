class_name ModelVisualResources
extends RefCounted
## 单模型的可变资源。只管理动画库副本和叠加材质，不选择动作或读取战斗状态。
var _meshes: Array[MeshInstance3D] = []
var _originals: Array[Material] = []
var _buffs: Array[Material] = []
var _overlays: Array = []
var _last_state := -1
var _loops := {}
var _player: AnimationPlayer
var _stealth_active := false
var _surface_originals: Array = []
var _surface_ghosts: Array = []
var _override_originals: Array = []
var _shadow_originals: Array = []
var _gold_overlays: Array[Material] = []
var _gold: ShaderMaterial
var _flash: StandardMaterial3D
var _building_frost := false

var _copy_jobs: Array = []
var _copy_cache := {}

func bind_model(root: Node, allowed: Dictionary = {}) -> AnimationPlayer:
	begin_bind(root, allowed)
	while not step_bind(): pass
	return _player

## 场景树/材质仍在主线程；动画按单片段分步复制，未完成者不交给表现代理。
func begin_bind(root: Node, allowed: Dictionary = {}) -> void:
	clear()
	_collect_meshes(root)
	_prepare_stealth_materials()
	_gold = ShaderMaterial.new()
	_gold.shader = preload("res://assets/effects/stasis/attached_mesh.gdshader")
	_gold.set_shader_parameter("swirl", preload("res://assets/effects/stasis/bard_swirl.png"))
	var gold_layer := ShaderMaterial.new()
	gold_layer.shader = preload("res://assets/effects/stasis/attached_gold.gdshader")
	gold_layer.set_shader_parameter("swirl", preload("res://assets/effects/stasis/zhonya_swirl.png"))
	_gold.next_pass = gold_layer
	_gold_overlays.clear()
	for mesh in _meshes:
		var overlay := _gold
		# 烘焙废墟包含内凹面；绕原点扩张会让覆盖面埋回原网格。
		# 保持顶点完全贴合，仅向相机偏移深度，不改变轮廓或遮挡关系。
		if String(root.get_path_to(mesh)).begins_with("RuinBase/"):
			overlay = _gold.duplicate() as ShaderMaterial
			overlay.set_shader_parameter("mesh_scale", 1.0)
			overlay.set_shader_parameter("depth_bias", 0.00001)
			var attached_gold := gold_layer.duplicate() as ShaderMaterial
			attached_gold.set_shader_parameter("mesh_scale", 1.0)
			attached_gold.set_shader_parameter("depth_bias", 0.00002)
			overlay.next_pass = attached_gold
		_gold_overlays.append(overlay)
	_flash = StandardMaterial3D.new()
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.albedo_color = Color(1.0, 1.0, 1.0, 0.22)
	_player = _find_player(root)
	_copy_jobs.clear()
	_copy_cache.clear()
	if _player != null:
		for name in _player.get_animation_library_list():
			var source := _player.get_animation_library(name)
			if source.get_script() != null or not source.get_meta_list().is_empty():
				_copy_jobs.append({"name": name, "source": source})
				continue
			var library := source.duplicate(false) as AnimationLibrary
			for clip in library.get_animation_list(): library.remove_animation(clip)
			_player.remove_animation_library(name)
			_player.add_animation_library(name, library)
			for clip in source.get_animation_list():
				var full_name := String(clip) if String(name).is_empty() else String(name) + "/" + String(clip)
				if allowed.is_empty() or allowed.has(full_name) or clip == &"RESET":
					_copy_jobs.append({"library": library, "clip": clip, "animation": source.get_animation(clip)})
	_prepare_overlays()

func step_bind() -> bool:
	if not _copy_jobs.is_empty():
		var job: Dictionary = _copy_jobs.pop_back()
		if job.has("source"):
			_player.remove_animation_library(job.name)
			_player.add_animation_library(job.name, copy_library(job.source))
		else:
			if not _copy_cache.has(job.library): _copy_cache[job.library] = {}
			var copies: Dictionary = _copy_cache[job.library]
			if not copies.has(job.animation): copies[job.animation] = copy_animation(job.animation)
			job.library.add_animation(job.clip, copies[job.animation])
	if not _copy_jobs.is_empty(): return false
	if _player != null:
		for name in _player.get_animation_list(): _loops[name] = _player.get_animation(name).loop_mode
	_copy_cache.clear()
	return true

func animation_player() -> AnimationPlayer:
	return _player

## 脚本包装可能构造/选择未声明动作，保守保留其完整动画库。
static func supports_clip_filter(node: Node) -> bool:
	if node.get_script() != null: return false
	for child in node.get_children():
		if not supports_clip_filter(child): return false
	return true

static func collect_clip_names(value: Variant, result: Dictionary) -> void:
	if value is String or value is StringName: result[String(value)] = true
	elif value is Dictionary:
		for key in value:
			collect_clip_names(key, result)
			collect_clip_names(value[key], result)
	elif value is Array or value is PackedStringArray:
		for child in value: collect_clip_names(child, result)

func has_meshes() -> bool:
	return not _meshes.is_empty()

func meshes() -> Array[MeshInstance3D]:
	return _meshes.duplicate()

func original_overlay(index: int) -> Material:
	return _originals[index]

func configure_buff(factory: Callable = Callable()) -> void:
	if not factory.is_valid() and _buffs.is_empty(): return
	_buffs.clear()
	if factory.is_valid():
		for original in _originals: _buffs.append(factory.call(original))
	_prepare_overlays()

func configure_frost(building: bool) -> void:
	if _building_frost == building: return
	_building_frost = building
	_overlays.clear()
	_prepare_overlays()

func _overlay_variants(base: Material) -> Array:
	var variants := [base]
	for color in [Color(1.0, 1.0, 1.0, 0.22), Color(0.3, 0.7, 1.0, 0.28)]:
		var overlay := _flash.duplicate() as StandardMaterial3D
		overlay.albedo_color = color
		overlay.next_pass = base
		if _building_frost and color.b == 1.0 and color.r < 1.0:
			var frost := ShaderMaterial.new()
			frost.shader = preload("res://assets/effects/freeze/attached_frost.gdshader")
			frost.next_pass = base
			variants.append(frost)
		else:
			variants.append(overlay)
	return variants

func _prepare_overlays() -> void:
	_last_state = -1
	for index in _meshes.size():
		var variants: Array = _overlays[index].slice(0, 3) if index < _overlays.size() else _overlay_variants(_originals[index])
		variants.append_array(_overlay_variants(_buffs[index]) if index < _buffs.size() else variants.duplicate())
		if index < _overlays.size(): _overlays[index] = variants
		else: _overlays.append(variants)

## _prepare_overlays 在没有强化材质时，后三态直接复用前三态的引用。
## apply_overlays 只切换引用，不修改资源参数；任何强化材质均保守保留六次绘制。
func overlay_state_repeats_base(state: int) -> bool:
	return state >= 3 and state < 6 and _buffs.is_empty()

func apply_overlays(hit: bool, frozen: bool, buff_visible: bool, stasis: bool = false, stealth: bool = false) -> void:
	apply_stealth(stealth and not stasis)
	var state := 6 if stasis else (3 if buff_visible else 0) + (1 if hit else (2 if frozen else 0))
	if state == _last_state: return
	_last_state = state
	for index in _meshes.size():
		if is_instance_valid(_meshes[index]): _meshes[index].material_overlay = _gold_overlays[index] if stasis else _overlays[index][state]

func reset_overlays() -> void:
	if is_instance_valid(_player):
		for name in _loops: _player.get_animation(name).loop_mode = _loops[name]
	configure_buff()
	apply_overlays(false, false, false)

func _prepare_stealth_materials() -> void:
	for mesh in _meshes:
		var originals: Array = []
		var ghosts: Array = []
		_override_originals.append(mesh.material_override)
		_shadow_originals.append(mesh.cast_shadow)
		for surface in mesh.get_surface_override_material_count():
			originals.append(mesh.get_surface_override_material(surface))
			var material := mesh.get_active_material(surface)
			var ghost := material.duplicate() as BaseMaterial3D if material is BaseMaterial3D else StandardMaterial3D.new()
			ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ghost.albedo_color = Color(0.75, 0.95, 0.90, 0.42)
			ghost.emission_enabled = true
			ghost.emission = Color(0.035, 0.10, 0.08)
			ghost.next_pass = null
			ghosts.append(ghost)
		_surface_originals.append(originals)
		_surface_ghosts.append(ghosts)

func apply_stealth(enabled: bool) -> void:
	if enabled == _stealth_active: return
	_stealth_active = enabled
	for index in _meshes.size():
		var mesh := _meshes[index]
		if not is_instance_valid(mesh): continue
		mesh.material_override = null if enabled else _override_originals[index]
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if enabled else _shadow_originals[index]
		for surface in mesh.get_surface_override_material_count():
			mesh.set_surface_override_material(surface, _surface_ghosts[index][surface] if enabled else _surface_originals[index][surface])

func clear() -> void:
	_copy_jobs.clear()
	_copy_cache.clear()
	apply_stealth(false)
	_surface_originals.clear()
	_surface_ghosts.clear()
	_override_originals.clear()
	_shadow_originals.clear()
	for index in _meshes.size():
		if is_instance_valid(_meshes[index]): _meshes[index].material_overlay = _originals[index]
	_meshes.clear()
	_originals.clear()
	_buffs.clear()
	_player = null
	_loops.clear()
	_flash = null
	_building_frost = false
	_overlays.clear()
	_last_state = -1

func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D and not node.is_in_group("presentation_fx"):
		_meshes.append(node)
		_originals.append(node.material_overlay)
	for child in node.get_children(): _collect_meshes(child)

func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var player := _find_player(child)
		if player != null: return player
	return null

## 数值骨骼轨道直接由引擎复制，避免 duplicate 的逐属性序列化往返。
## 仍是实例独立 Animation；含资源/事件、压缩轨道或扩展数据时保留完整深复制。
static func copy_animation(source: Animation) -> Animation:
	if source.get_script() != null or not source.get_meta_list().is_empty():
		return source.duplicate(true) as Animation
	for track in source.get_track_count():
		if source.track_is_compressed(track) or source.track_get_type(track) not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D, Animation.TYPE_BLEND_SHAPE]:
			return source.duplicate(true) as Animation
	var result := Animation.new()
	result.resource_name = source.resource_name
	result.resource_local_to_scene = source.resource_local_to_scene
	result.length = source.length
	result.step = source.step
	result.loop_mode = source.loop_mode
	for marker in source.get_marker_names():
		result.add_marker(marker, source.get_marker_time(marker))
		result.set_marker_color(marker, source.get_marker_color(marker))
	for track in source.get_track_count(): source.copy_track(track, result)
	return result

static func copy_library(source: AnimationLibrary) -> AnimationLibrary:
	if source.get_script() != null or not source.get_meta_list().is_empty():
		return source.duplicate(true) as AnimationLibrary
	var result := source.duplicate(false) as AnimationLibrary
	var copies := {}
	for clip in source.get_animation_list():
		result.remove_animation(clip)
		var animation := source.get_animation(clip)
		if not copies.has(animation): copies[animation] = copy_animation(animation)
		result.add_animation(clip, copies[animation])
	return result
