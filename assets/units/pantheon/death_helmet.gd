extends SkeletonModifier3D
## 原版 Death 的 JointSnapEventData；只修饰渲染骨骼，Skeleton 每帧会恢复动画姿态。
func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null: return
	var helmet := skeleton.find_bone("C_Helmet")
	var anchor := skeleton.find_bone("C_Helmet_Snap")
	if helmet >= 0 and anchor >= 0:
		skeleton.set_bone_global_pose(helmet, skeleton.get_bone_global_pose(anchor))
