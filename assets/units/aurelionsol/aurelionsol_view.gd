extends Node3D
## 包装层将素材骨骼映射到稳定的发射挂点接口；通用动画控制器不认识骨骼名。
var _skeleton: Skeleton3D
var _mouth := -1
var _breath: Node3D
var _breath_end: Node3D
var _breath_age := 0.0

func _ready() -> void:
	_skeleton = _find_skeleton(self)
	if _skeleton != null:
		_mouth = _skeleton.find_bone("Jaw")

func get_beam_origin_world() -> Vector3:
	if _skeleton == null or _mouth < 0:
		return global_position
	return _skeleton.to_global(_skeleton.get_bone_global_pose(_mouth).origin)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func reset_pool_visual() -> void:
	stop_continuous_attack_visual()

func stop_continuous_attack_visual() -> void:
	_breath_age = 0.0
	if is_instance_valid(_breath):
		_breath.visible = false
	if is_instance_valid(_breath_end):
		_breath_end.visible = false

func advance_continuous_attack_visual(active: bool, endpoint: Vector2, camera: Camera3D, delta: float) -> void:
	if not active or camera == null:
		stop_continuous_attack_visual()
		return
	if not is_instance_valid(_breath):
		_breath = preload("res://assets/effects/aurelionsol_q/player.gd").new()
		add_child(_breath)
		_breath.top_level = true
		_breath.setup_native(0.006)
		_breath_end = preload("res://assets/effects/aurelionsol_q/player.gd").new()
		add_child(_breath_end)
		_breath_end.top_level = true
		_breath_end.setup_native(0.006, "end")
	var mouth := get_beam_origin_world()
	# Preserve the existing screen-space ground/air target contract at mouth depth.
	var depth := -camera.to_local(mouth).z
	var end := camera.project_position(endpoint, depth)
	var along := end - mouth
	if along.length_squared() < 0.0001:
		stop_continuous_attack_visual()
		return
	var forward := along.normalized()
	var across := forward.cross(camera.global_basis.z).normalized()
	if across.length_squared() < 0.001:
		across = camera.global_basis.x
	var up := forward.cross(across).normalized()
	_breath.global_transform = Transform3D(Basis(across, up, forward).scaled(Vector3.ONE * 0.006), mouth)
	_breath.beam_length = along.length() / 0.006
	_breath.visible = true
	_breath_age += delta
	_breath.seek(_breath_age)
	_breath_end.global_transform = Transform3D(_breath.global_basis, end)
	_breath_end.visible = true
	_breath_end.seek(_breath_age)
