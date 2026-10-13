extends SkeletonModifier3D
## 原版 Skin0/Spell2 JointSnapEventData：只修饰W动作中的渲染骨骼。
var player: AnimationPlayer
func _process_modification() -> void:
	if not is_instance_valid(player) or player.assigned_animation != &"Spell2": return
	var skeleton := get_skeleton()
	if skeleton == null: return
	var weapon := skeleton.find_bone("weapon")
	var anchor := skeleton.find_bone("weapon_b")
	if weapon >= 0 and anchor >= 0:
		skeleton.set_bone_global_pose(weapon, skeleton.get_bone_global_pose(anchor))

func reset_pool_visual() -> void:
	pass # 只持有本模型播放器，骨骼姿态由模型池恢复。
