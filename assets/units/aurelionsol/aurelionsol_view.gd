extends Node3D
## 包装层将素材骨骼映射到稳定的发射挂点接口；通用动画控制器不认识骨骼名。
var _skeleton: Skeleton3D
var _mouth := -1

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
