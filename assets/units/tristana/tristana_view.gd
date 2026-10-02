extends Node3D
## 炮口只决定弹体绘制起点，不参与权威弹体生成。
func create_projectile_anchor() -> Node3D:
	for skeleton: Skeleton3D in find_children("*", "Skeleton3D", true, false):
		var index := skeleton.find_bone("Buffbone_Glb_Weapon_1")
		if index < 0: continue
		var anchor := BoneAttachment3D.new()
		anchor.name = "ProjectileModelAnchor"
		anchor.bone_idx = index
		skeleton.add_child(anchor)
		return anchor
	return null
