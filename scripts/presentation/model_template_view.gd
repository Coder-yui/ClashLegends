extends Node3D
## 整表面过滤包装共用入口。网格/模板只读，活体动画仍由根所有权记录持有。
@export var visual_template: Resource
var _template_initialized := false
var _template_player: AnimationPlayer
var preparation_errors := PackedStringArray()

func _ready() -> void:
	prepare_visual_animations()

func prepare_visual_animations() -> PackedStringArray:
	_initialize_template()
	if _template_initialized and not bool(get_meta("defer_animation_ownership", false)):
		var owner: RefCounted = preload("res://scripts/presentation/model_animation_instance.gd").begin(self)
		while not owner.step(): pass
		preparation_errors.append_array(owner.errors)
	return preparation_errors

func _initialize_template() -> void:
	if _template_initialized or not preparation_errors.is_empty(): return
	_template_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _template_player == null or visual_template == null or visual_template.get_script() != preload("res://scripts/presentation/model_visual_template.gd") or visual_template.schema != 1 or visual_template.libraries.is_empty():
		preparation_errors.append("Model wrapper requires generated template v1")
		return
	_template_initialized = _initialize_template_geometry()
	if not _template_initialized and preparation_errors.is_empty(): preparation_errors.append("Model template geometry initialization failed")

func _initialize_template_geometry() -> bool:
	if visual_template.meshes.is_empty(): return true # 来源已是最终网格，不再复制保存。
	var meshes := find_children("*", "MeshInstance3D", true, false)
	var mesh := meshes[0] as MeshInstance3D if meshes.size() == 1 else null
	var body: ArrayMesh = visual_template.meshes.get("body")
	if mesh == null or body == null:
		preparation_errors.append("Model template requires body mesh")
		return false
	mesh.mesh = body
	return true

func visual_animation_contract() -> Dictionary:
	_initialize_template()
	return {"version": 1, "player": _template_player, "libraries": visual_template.libraries if _template_initialized else {}, "errors": preparation_errors}
