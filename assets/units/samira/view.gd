extends Node3D
## 模型挂点仅控制弹体绘制，不改变权威出生坐标。
var unit_ref: WeakRef
func configure_unit_visual(unit: Unit) -> void:
	unit_ref = weakref(unit)
func create_projectile_anchor() -> Node3D:
	for skeleton in find_children("*", "Skeleton3D", true, false):
		var index: int = skeleton.find_bone("Pistol_Muzzle")
		if index >= 0:
			var anchor := BoneAttachment3D.new()
			anchor.name = "ProjectileModelAnchor"
			anchor.bone_idx = index
			skeleton.add_child(anchor)
			return anchor
	push_error("沙漠玫瑰缺少原生 Pistol_Muzzle 挂点")
	return null


func prepare_visual_animations() -> void:
	var player := find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("").duplicate() as AnimationLibrary
	var locomotion := preload("res://assets/units/samira/locomotion.res") as AnimationLibrary
	for clip in locomotion.get_animation_list():
		if library.has_animation(clip): library.remove_animation(clip)
		library.add_animation(clip, locomotion.get_animation(clip))
	player.remove_animation_library("")
	player.add_animation_library("", library)
