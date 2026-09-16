extends Node3D
## 只读动画播放位置复刻 Skin0 的部件事件；不参与形态或伤害结算。
@export var ultimate_form := false
## 120个等间隔样本，低侧Foot_end均值：Ult 0.979366，Idle -0.019225（包装缩放0.013）。
const NATIVE_AIR_LIFT := 0.998591
var _initial_ultimate_form := false
var _mesh: MeshInstance3D
var _player: AnimationPlayer
var _normal_mesh: ArrayMesh
var _wing_mesh: ArrayMesh
var _full_mesh: ArrayMesh

func _ready() -> void:
	_initial_ultimate_form = ultimate_form
	prepare_visual_animations()

func prepare_visual_animations() -> void:
	if _full_mesh != null:
		return
	_mesh = find_child("Meshes", true, false) as MeshInstance3D
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _mesh == null or _player == null:
		return
	_full_mesh = _mesh.mesh as ArrayMesh
	_normal_mesh = _filter_surfaces(["Wings"])
	_wing_mesh = _filter_surfaces(["Shoulder"])
	_mesh.mesh = _full_mesh if ultimate_form else _normal_mesh
	var skeleton := _mesh.get_parent() as Skeleton3D
	var snap := preload("res://assets/units/aatrox/weapon_snap.gd").new()
	snap.player = _player
	skeleton.add_child(snap)
	_prepare_air_attack_height()

func _filter_surfaces(hidden: Array) -> ArrayMesh:
	var result := ArrayMesh.new()
	for i in _full_mesh.get_surface_count():
		var material := _full_mesh.surface_get_material(i)
		if material != null and String(material.resource_name) in hidden:
			continue
		result.add_surface_from_arrays(_full_mesh.surface_get_primitive_type(i), _full_mesh.surface_get_arrays(i))
		var index := result.get_surface_count() - 1
		result.surface_set_material(index, material)
		result.surface_set_name(index, _full_mesh.surface_get_name(i))
	return result

func set_visual_clip(animation_name: StringName) -> void:
	prepare_visual_animations()
	_update_surfaces(animation_name, 0.0)

func _process(_delta: float) -> void:
	if _player != null:
		_update_surfaces(_player.assigned_animation, _player.current_animation_position)

func _update_surfaces(clip: StringName, source_time: float) -> void:
	if _mesh == null:
		return
	# 原表 ULT_out: 0..11 帧显示 Wings、隐藏 Shoulder，tick 为 1/32 秒。
	if clip == &"ULT_out":
		_mesh.mesh = _wing_mesh if source_time < 11.0 / 32.0 else _normal_mesh
	else:
		_mesh.mesh = _full_mesh if ultimate_form else _normal_mesh

func _prepare_air_attack_height() -> void:
	# 地面版被动增加原生浮空量，与大灭动作姿态衔接；每条片段都有同一轨道，交给AnimationPlayer混合。
	var target := _player.get_node(_player.root_node).get_path_to(get_node("Model"))
	for library_name in _player.get_animation_library_list():
		var library := _player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
		_player.remove_animation_library(library_name)
		_player.add_animation_library(library_name, library)
		for clip in library.get_animation_list():
			var animation := library.get_animation(clip)
			var track := animation.add_track(Animation.TYPE_POSITION_3D)
			animation.track_set_path(track, target)
			var lift := 0.0
			animation.position_track_insert_key(track, 0.0, Vector3(0, lift, 0))

		if library.has_animation("Passive_Attack"):
			var passive := library.get_animation("Passive_Attack").duplicate(true) as Animation
			var track := passive.find_track(target, Animation.TYPE_POSITION_3D)
			passive.track_set_key_value(track, 0, Vector3(0, NATIVE_AIR_LIFT, 0))
			library.add_animation("Passive_Attack_Ult", passive)

func set_visual_form(form_index: int) -> void:
	ultimate_form = form_index == 1
	# 动作通知会立即应用该形态；收翼前段仍遵循原表翅膀事件。

func can_reuse_visual(scene_path: String) -> bool:
	return scene_path in ["res://assets/units/aatrox/normal_view.tscn", "res://assets/units/aatrox/ultimate_view.tscn"]

func reset_pool_visual() -> void:
	ultimate_form = _initial_ultimate_form
	if _mesh != null: _mesh.mesh = _full_mesh if ultimate_form else _normal_mesh
