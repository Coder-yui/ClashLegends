extends Node3D
var unit_ref: WeakRef
func configure_unit_visual(unit: Unit) -> void:
	unit_ref = weakref(unit)
## 原版子弹挂点；只改变可见枪口，权威弹道来自Unit中心。
func create_projectile_anchor() -> Node3D:
	for skeleton in find_children("*", "Skeleton3D", true, false):
		for index in skeleton.get_bone_count():
			if String(skeleton.get_bone_name(index)).to_lower() == "buffbone_cstm_weapona":
				var anchor := BoneAttachment3D.new()
				anchor.name = "ProjectileModelAnchor"
				anchor.bone_idx = index
				skeleton.add_child(anchor)
				return anchor
	return null

func prepare_visual_animations() -> void:
	var player := find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("").duplicate() as AnimationLibrary
	var locomotion := preload("res://assets/units/graves/reload_move.res") as AnimationLibrary
	library.add_animation("ReloadMove", locomotion.get_animation("ReloadMove"))
	player.remove_animation_library("")
	player.add_animation_library("", library)
