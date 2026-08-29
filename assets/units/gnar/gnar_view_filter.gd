extends Node3D
## 纳尔专用表现修正：过滤动画中的临时道具，并把导出的加法缩放层合成为正常展开姿势。

@export var filtered_clips := PackedStringArray()
@export var hidden_surface_indices := PackedInt32Array()
@export var hidden_bone_name: StringName
@export var additive_output_clip: StringName
@export var additive_scale_clip: StringName
@export var additive_base_clip: StringName
@export var additive_pose_clip: StringName
@export var additive_secondary_output_clip: StringName
@export var additive_secondary_pose_clip: StringName
@export var additive_scale_start_overrides: Dictionary = {}

@onready var _mesh_instance := get_node("Model/Skeleton/Skeleton3D/Meshes") as MeshInstance3D
var _original_mesh: ArrayMesh
var _filtered_mesh: ArrayMesh

func _ready() -> void:
	_build_filtered_mesh()
	_build_additive_animation()

## UnitModel3D 在扫描动画名之前调用，保证同一帧换形也能立刻使用运行时合成片段。
func prepare_visual_animations() -> void:
	_build_additive_animation()

func set_visual_clip(animation_name: StringName) -> void:
	if _mesh_instance == null:
		return
	if _filtered_mesh == null:
		_build_filtered_mesh()
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

func _build_filtered_mesh() -> void:
	if _mesh_instance == null or not _mesh_instance.mesh is ArrayMesh:
		return
	_original_mesh = _mesh_instance.mesh as ArrayMesh
	var hidden_bind_index := -1
	if hidden_bone_name != &"" and _mesh_instance.skin != null:
		for bind_index in _mesh_instance.skin.get_bind_count():
			if _mesh_instance.skin.get_bind_name(bind_index) == hidden_bone_name:
				hidden_bind_index = bind_index
				break
	_filtered_mesh = ArrayMesh.new()
	for blend_shape_index in _original_mesh.get_blend_shape_count():
		_filtered_mesh.add_blend_shape(_original_mesh.get_blend_shape_name(blend_shape_index))
	_filtered_mesh.blend_shape_mode = _original_mesh.blend_shape_mode
	for surface_index in _original_mesh.get_surface_count():
		if hidden_surface_indices.has(surface_index):
			continue
		var arrays := _original_mesh.surface_get_arrays(surface_index)
		if hidden_bind_index >= 0:
			arrays = _filter_bone_triangles(arrays, hidden_bind_index)
		if arrays.is_empty():
			continue
		var new_surface_index := _filtered_mesh.get_surface_count()
		_filtered_mesh.add_surface_from_arrays(
			_original_mesh.surface_get_primitive_type(surface_index),
			arrays,
			_original_mesh.surface_get_blend_shape_arrays(surface_index)
		)
		_filtered_mesh.surface_set_name(new_surface_index, _original_mesh.surface_get_name(surface_index))
		_filtered_mesh.surface_set_material(new_surface_index, _original_mesh.surface_get_material(surface_index))

## LoL 源资源中的 Rage/Revert Scale 是相对单帧 Base 姿势的加法层，不是完整骨骼动作。
## 直接播放会让所有旋转回到绑定姿势，角色挤成一团；这里把差值逐帧烘到主体动作的完整展开姿势上。
func _build_additive_animation() -> void:
	if additive_output_clip == &"" or additive_scale_clip == &"" or additive_base_clip == &"" or additive_pose_clip == &"":
		return
	var player := _find_animation_player(self)
	if player == null:
		return
	if player.has_animation_library(&"gnar_runtime"):
		return
	var scale_animation := player.get_animation(additive_scale_clip)
	var base_animation := player.get_animation(additive_base_clip)
	var pose_animation := player.get_animation(additive_pose_clip)
	if scale_animation == null or base_animation == null or pose_animation == null:
		push_warning("纳尔加法缩放动画缺少 Scale、Base 或主体动作")
		return
	var runtime_library := AnimationLibrary.new()
	runtime_library.add_animation(additive_output_clip, _compose_animation(scale_animation, base_animation, pose_animation))
	if additive_secondary_output_clip != &"" and additive_secondary_pose_clip != &"":
		var secondary_pose_animation := player.get_animation(additive_secondary_pose_clip)
		if secondary_pose_animation != null:
			runtime_library.add_animation(
				additive_secondary_output_clip,
				_compose_animation(scale_animation, base_animation, secondary_pose_animation)
			)
	player.add_animation_library(&"gnar_runtime", runtime_library)

func _compose_animation(scale_animation: Animation, base_animation: Animation, pose_animation: Animation) -> Animation:
	var composed := Animation.new()
	composed.length = maxf(scale_animation.length, pose_animation.length)
	composed.loop_mode = Animation.LOOP_NONE
	for scale_track_index in scale_animation.get_track_count():
		var track_type := scale_animation.track_get_type(scale_track_index)
		if track_type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var track_path := scale_animation.track_get_path(scale_track_index)
		var base_track_index := _find_track(base_animation, track_type, track_path)
		var pose_track_index := _find_track(pose_animation, track_type, track_path)
		if base_track_index < 0 or pose_track_index < 0:
			continue
		var output_track_index := composed.add_track(track_type)
		composed.track_set_path(output_track_index, track_path)
		composed.track_set_interpolation_type(output_track_index, scale_animation.track_get_interpolation_type(scale_track_index))
		var key_times := PackedFloat32Array([0.0, composed.length])
		for key_index in scale_animation.track_get_key_count(scale_track_index):
			key_times.append(scale_animation.track_get_key_time(scale_track_index, key_index))
		for key_index in pose_animation.track_get_key_count(pose_track_index):
			key_times.append(pose_animation.track_get_key_time(pose_track_index, key_index))
		key_times.sort()
		var previous_key_time := -1.0
		for key_time in key_times:
			if is_equal_approx(key_time, previous_key_time):
				continue
			previous_key_time = key_time
			var scale_value = _interpolate_track(scale_animation, scale_track_index, minf(key_time, scale_animation.length))
			if track_type == Animation.TYPE_SCALE_3D and additive_scale_start_overrides.has(String(track_path)):
				scale_value = _remap_scale_start(
					scale_value,
					scale_animation.track_get_key_value(scale_track_index, 0),
					scale_animation.track_get_key_value(scale_track_index, scale_animation.track_get_key_count(scale_track_index) - 1),
					float(additive_scale_start_overrides[String(track_path)])
				)
			var base_value = base_animation.track_get_key_value(base_track_index, 0)
			var pose_value = _interpolate_track(pose_animation, pose_track_index, minf(key_time, pose_animation.length))
			var composed_value = _compose_additive_value(track_type, pose_value, base_value, scale_value)
			composed.track_insert_key(output_track_index, key_time, composed_value)
	return composed

func _remap_scale_start(value: Vector3, original_start: Vector3, original_end: Vector3, desired_uniform_start: float) -> Vector3:
	var desired_start := Vector3.ONE * desired_uniform_start
	return Vector3(
		_remap_scale_component(value.x, original_start.x, original_end.x, desired_start.x),
		_remap_scale_component(value.y, original_start.y, original_end.y, desired_start.y),
		_remap_scale_component(value.z, original_start.z, original_end.z, desired_start.z)
	)

func _remap_scale_component(value: float, original_start: float, original_end: float, desired_start: float) -> float:
	if is_equal_approx(original_start, original_end):
		return value
	var progress := (value - original_start) / (original_end - original_start)
	return lerpf(desired_start, original_end, progress)

func _interpolate_track(animation: Animation, track_index: int, time: float) -> Variant:
	match animation.track_get_type(track_index):
		Animation.TYPE_POSITION_3D:
			return animation.position_track_interpolate(track_index, time)
		Animation.TYPE_ROTATION_3D:
			return animation.rotation_track_interpolate(track_index, time)
		Animation.TYPE_SCALE_3D:
			return animation.scale_track_interpolate(track_index, time)
	return animation.track_get_key_value(track_index, 0)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _find_track(animation: Animation, track_type: Animation.TrackType, track_path: NodePath) -> int:
	for track_index in animation.get_track_count():
		if animation.track_get_type(track_index) == track_type and animation.track_get_path(track_index) == track_path:
			return track_index
	return -1

func _compose_additive_value(track_type: Animation.TrackType, pose_value: Variant, base_value: Variant, scale_value: Variant) -> Variant:
	match track_type:
		Animation.TYPE_POSITION_3D:
			return pose_value + scale_value - base_value
		Animation.TYPE_ROTATION_3D:
			return (pose_value * base_value.inverse() * scale_value).normalized()
		Animation.TYPE_SCALE_3D:
			return pose_value * _safe_scale_ratio(scale_value, base_value)
	return scale_value

func _safe_scale_ratio(value: Vector3, base: Vector3) -> Vector3:
	return Vector3(
		value.x / base.x if absf(base.x) > 0.0001 else 1.0,
		value.y / base.y if absf(base.y) > 0.0001 else 1.0,
		value.z / base.z if absf(base.z) > 0.0001 else 1.0
	)

func _filter_bone_triangles(arrays: Array, hidden_bind_index: int) -> Array:
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if indices.is_empty() or bones.is_empty() or weights.is_empty():
		return arrays
	var kept_indices := PackedInt32Array()
	for triangle_start in range(0, indices.size(), 3):
		if triangle_start + 2 >= indices.size():
			break
		var hidden_vertices := 0
		for corner in 3:
			var vertex_index := indices[triangle_start + corner]
			var hidden_weight := 0.0
			for influence in 4:
				var influence_index := vertex_index * 4 + influence
				if influence_index < bones.size() and bones[influence_index] == hidden_bind_index:
					hidden_weight += weights[influence_index]
			if hidden_weight >= 0.5:
				hidden_vertices += 1
		if hidden_vertices < 3:
			kept_indices.append(indices[triangle_start])
			kept_indices.append(indices[triangle_start + 1])
			kept_indices.append(indices[triangle_start + 2])
	arrays[Mesh.ARRAY_INDEX] = kept_indices
	return arrays
