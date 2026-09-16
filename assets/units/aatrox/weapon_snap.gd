extends SkeletonModifier3D
## Skin0 JointSnapEventData：这些片段把剑挂到 Weapon_World。
var player: AnimationPlayer
const SNAP_CLIPS := [&"Aatrox_unsheath_anm", &"Run_Base", &"Run_Ult", &"Passive_Attack", &"Passive_Attack_Ult", &"Passive_Idle", &"Passive_Run", &"Passive_Attack_out", &"Spell4", &"Aatrox_ULT_into_anm", &"ULT_out"]
func _process_modification() -> void:
	if player == null or not player.assigned_animation in SNAP_CLIPS:
		return
	var skeleton := get_skeleton()
	var weapon := skeleton.find_bone("Weapon")
	var anchor := skeleton.find_bone("Weapon_World")
	if weapon >= 0 and anchor >= 0:
		skeleton.set_bone_global_pose(weapon, skeleton.get_bone_global_pose(anchor))

func reset_pool_visual() -> void:
	pass # player 始终属于本模型；这里只读片段名，不持有来源、形态或时钟。
