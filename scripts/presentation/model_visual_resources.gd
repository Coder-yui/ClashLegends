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
var _flash: StandardMaterial3D

func bind_model(root: Node) -> AnimationPlayer:
	clear()
	_collect_meshes(root)
	_flash = StandardMaterial3D.new()
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.albedo_color = Color(1.0, 1.0, 1.0, 0.22)
	var player := _find_player(root)
	if player != null:
		for name in player.get_animation_library_list():
			var library := player.get_animation_library(name).duplicate(true) as AnimationLibrary
			player.remove_animation_library(name)
			player.add_animation_library(name, library)
	_player = player
	if player != null:
		for name in player.get_animation_list(): _loops[name] = player.get_animation(name).loop_mode
	_prepare_overlays()
	return player

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

func _overlay_variants(base: Material) -> Array:
	var variants := [base]
	for color in [Color(1.0, 1.0, 1.0, 0.22), Color(0.3, 0.7, 1.0, 0.28)]:
		var overlay := _flash.duplicate() as StandardMaterial3D
		overlay.albedo_color = color
		overlay.next_pass = base
		variants.append(overlay)
	return variants

func _prepare_overlays() -> void:
	_last_state = -1
	for index in _meshes.size():
		var variants: Array = _overlays[index].slice(0, 3) if index < _overlays.size() else _overlay_variants(_originals[index])
		variants.append_array(_overlay_variants(_buffs[index]) if index < _buffs.size() else variants.duplicate())
		if index < _overlays.size(): _overlays[index] = variants
		else: _overlays.append(variants)

func apply_overlays(hit: bool, frozen: bool, buff_visible: bool) -> void:
	var state := (3 if buff_visible else 0) + (1 if hit else (2 if frozen else 0))
	if state == _last_state: return
	_last_state = state
	for index in _meshes.size():
		if is_instance_valid(_meshes[index]): _meshes[index].material_overlay = _overlays[index][state]

func reset_overlays() -> void:
	if is_instance_valid(_player):
		for name in _loops: _player.get_animation(name).loop_mode = _loops[name]
	configure_buff()
	apply_overlays(false, false, false)

func clear() -> void:
	for index in _meshes.size():
		if is_instance_valid(_meshes[index]): _meshes[index].material_overlay = _originals[index]
	_meshes.clear()
	_originals.clear()
	_buffs.clear()
	_player = null
	_loops.clear()
	_flash = null
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
