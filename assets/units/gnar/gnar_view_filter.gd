extends "res://scripts/presentation/model_template_view.gd"
## 纯加工已由配方离线完成；本实例只持有片段选择和播放状态。
@export var filtered_clips := PackedStringArray()
var _mesh_instance: MeshInstance3D
var _original_mesh: ArrayMesh
var _filtered_mesh: ArrayMesh

func _initialize_template_geometry() -> bool:
	_mesh_instance = get_node_or_null("Model/Skeleton/Skeleton3D/Meshes") as MeshInstance3D
	_filtered_mesh = visual_template.meshes.get("filtered")
	if _mesh_instance == null or _filtered_mesh == null:
		preparation_errors.append("Gnar requires filtered template mesh")
		return false
	_original_mesh = _mesh_instance.mesh as ArrayMesh
	return true

func set_visual_clip(animation_name: StringName) -> void:
	if _mesh_instance == null:
		return
	if _filtered_mesh == null:
		_initialize_template()
	var should_filter := filtered_clips.has(String(animation_name))
	_mesh_instance.mesh = _filtered_mesh if should_filter and _filtered_mesh != null else _original_mesh

func is_filtered_clip_active() -> bool:
	return _mesh_instance != null and _filtered_mesh != null and _mesh_instance.mesh == _filtered_mesh

func get_original_triangle_count() -> int:
	return _triangle_count(_original_mesh)

func get_filtered_triangle_count() -> int:
	return _triangle_count(_filtered_mesh)

func _triangle_count(mesh: ArrayMesh) -> int:
	if mesh == null:
		return 0
	var count := 0
	for surface_index in mesh.get_surface_count():
		var indices: PackedInt32Array = mesh.surface_get_arrays(surface_index)[Mesh.ARRAY_INDEX]
		count += indices.size() / 3
	return count

func reset_pool_visual() -> void:
	if _mesh_instance != null: _mesh_instance.mesh = _original_mesh
