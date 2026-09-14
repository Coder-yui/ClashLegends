class_name ModelVisualResources
extends RefCounted
## 单模型的可变资源。只管理动画库副本和叠加材质，不选择动作或读取战斗状态。
var _meshes: Array[MeshInstance3D] = []
var _originals: Array[Material] = []
var _buffs: Array[Material] = []
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
	return player

func meshes() -> Array[MeshInstance3D]:
	return _meshes.duplicate()

func original_overlay(index: int) -> Material:
	return _originals[index]

func configure_buff(factory: Callable = Callable()) -> void:
	_buffs.clear()
	if factory.is_valid():
		for original in _originals: _buffs.append(factory.call(original))

func apply_overlays(hit: bool, frozen: bool, buff_visible: bool) -> void:
	for index in _meshes.size():
		var mesh := _meshes[index]
		if not is_instance_valid(mesh): continue
		var base := _buffs[index] if buff_visible and index < _buffs.size() else _originals[index]
		if hit or frozen:
			var overlay := _flash.duplicate() as StandardMaterial3D
			overlay.albedo_color = Color(1.0, 1.0, 1.0, 0.22) if hit else Color(0.3, 0.7, 1.0, 0.28)
			overlay.next_pass = base
			mesh.material_overlay = overlay
		else:
			mesh.material_overlay = base

func clear() -> void:
	for index in _meshes.size():
		if is_instance_valid(_meshes[index]): _meshes[index].material_overlay = _originals[index]
	_meshes.clear()
	_originals.clear()
	_buffs.clear()
	_flash = null

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
