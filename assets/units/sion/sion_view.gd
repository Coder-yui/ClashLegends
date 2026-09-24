extends Node3D
## 原版 Passive_Death 第23帧隐藏斧头；只消费动画位置，不参与权威复生。
var _mesh: MeshInstance3D
var _player: AnimationPlayer
var _full: ArrayMesh
var _unarmed: ArrayMesh
var _clip: StringName
var _berserk := false

func _ready() -> void:
	var meshes := find_children("*", "MeshInstance3D", true, false)
	var players := find_children("*", "AnimationPlayer", true, false)
	if meshes.is_empty() or players.is_empty(): return
	_mesh = meshes[0]
	_player = players[0]
	_full = _mesh.mesh as ArrayMesh
	if _full == null: return
	_unarmed = ArrayMesh.new()
	for surface in _full.get_surface_count():
		var material := _full.surface_get_material(surface)
		if material != null and material.resource_name.to_lower() == "weapon": continue
		_unarmed.add_surface_from_arrays(_full.surface_get_primitive_type(surface), _full.surface_get_arrays(surface))
		_unarmed.surface_set_material(_unarmed.get_surface_count() - 1, material)

func can_reuse_visual(scene_path: String) -> bool:
	return scene_path in ["res://assets/units/sion/sion_view.tscn", "res://assets/units/sion/sion_passive_view.tscn"]

func set_visual_form(form_index: int) -> void:
	_berserk = form_index == 1
	_update_weapon()

func reset_pool_visual() -> void:
	_berserk = false
	_clip = &""
	if _mesh != null: _mesh.mesh = _full

func set_visual_clip(clip: StringName) -> void:
	_clip = clip
	_update_weapon()

func _process(_delta: float) -> void:
	_update_weapon()

func _update_weapon() -> void:
	if _mesh == null or _unarmed == null or _player == null: return
	var hide_weapon := _berserk or _clip == &"Death" or (_clip == &"Passive_Death" and _player.current_animation_position >= 23.0 / 30.0)
	_mesh.mesh = _unarmed if hide_weapon else _full
