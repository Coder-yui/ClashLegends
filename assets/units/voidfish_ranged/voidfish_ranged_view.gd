extends "res://scripts/presentation/voidfish_model_view.gd"

func _hidden_surface() -> String: return "Melee"

## 原版 BelvethVoidlingRangedAttack.FixedSpeedMovement.mStartBoneName。
func create_projectile_anchor() -> Node3D:
	_find_bones()
	if _skeleton == null or _skeleton.find_bone("BackSpine_end") < 0: return null
	var anchor := BoneAttachment3D.new()
	anchor.name = "ProjectileModelAnchor"
	anchor.bone_name = "BackSpine_end"
	_skeleton.add_child(anchor)
	return anchor
