extends "res://scripts/presentation/model_template_view.gd"
## 原版 Passive_Death 第23帧隐藏斧头；只消费动画位置，不参与权威复生。
var _mesh: MeshInstance3D
var _player: AnimationPlayer
var _full: ArrayMesh
var _unarmed: ArrayMesh
var _clip: StringName
var _berserk := false

func _initialize_template_geometry() -> bool:
	_mesh = find_child("Meshes", true, false) as MeshInstance3D
	_player = _template_player
	_unarmed = visual_template.meshes.get("unarmed") as ArrayMesh
	if _mesh == null or _unarmed == null:
		preparation_errors.append("Sion requires generated unarmed mesh")
		return false
	_full = _mesh.mesh as ArrayMesh # 原网格只引用，不重复保存。
	return _full != null

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
	var source_time := _player.current_animation_position if not _player.current_animation.is_empty() else 0.0
	var hide_weapon := _berserk or _clip == &"Death" or (_clip == &"Passive_Death" and source_time >= 23.0 / 30.0)
	_mesh.mesh = _unarmed if hide_weapon else _full
