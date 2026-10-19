extends Node3D
## 只读动画播放位置复刻 Skin0 的部件事件；不参与形态或伤害结算。
@export var ultimate_form := false
@export var visual_template: Resource
var _initial_ultimate_form := false
var _mesh: MeshInstance3D
var _player: AnimationPlayer
var _normal_mesh: ArrayMesh
var _wing_mesh: ArrayMesh
var _full_mesh: ArrayMesh
var _libraries := {}

func _ready() -> void:
	_initial_ultimate_form = ultimate_form
	prepare_visual_animations()

func prepare_visual_animations() -> void:
	_initialize_template()
	if not bool(get_meta("defer_animation_ownership", false)):
		ModelVisualResources.prepare_instance_animations(self)

func visual_animation_contract() -> Dictionary:
	_initialize_template()
	return {"version": 1, "player": _player, "libraries": _libraries}

func _initialize_template() -> void:
	if _full_mesh != null:
		return
	_mesh = find_child("Meshes", true, false) as MeshInstance3D
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _mesh == null or _player == null or visual_template == null or visual_template.get_script() != preload("res://scripts/presentation/model_visual_template.gd") or visual_template.schema != 1:
		push_error("Aatrox requires generated model template v1")
		return
	if visual_template.meshes.size() != 2 or visual_template.meshes.has("full"):
		push_error("Aatrox requires normal/wing-only generated template")
		return
	_full_mesh = _mesh.mesh as ArrayMesh # 原导入只读资源；不在模板中重复序列化。
	_normal_mesh = visual_template.meshes.get("normal") as ArrayMesh
	_wing_mesh = visual_template.meshes.get("wing") as ArrayMesh
	_libraries = visual_template.libraries
	if _full_mesh == null or _normal_mesh == null or _wing_mesh == null or _libraries.is_empty():
		push_error("Incomplete generated Aatrox model template")
		_full_mesh = null
		return
	_mesh.mesh = _full_mesh if ultimate_form else _normal_mesh
	var skeleton := _mesh.get_parent() as Skeleton3D
	var snap := preload("res://assets/units/aatrox/weapon_snap.gd").new()
	snap.player = _player
	skeleton.add_child(snap)

func set_visual_clip(animation_name: StringName) -> void:
	_initialize_template()
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

func set_visual_form(form_index: int) -> void:
	ultimate_form = form_index == 1
	# 动作通知会立即应用该形态；收翼前段仍遵循原表翅膀事件。

func can_reuse_visual(scene_path: String) -> bool:
	return scene_path in ["res://assets/units/aatrox/normal_view.tscn", "res://assets/units/aatrox/ultimate_view.tscn"]

func reset_pool_visual() -> void:
	ultimate_form = _initial_ultimate_form
	if _mesh != null: _mesh.mesh = _full_mesh if ultimate_form else _normal_mesh
