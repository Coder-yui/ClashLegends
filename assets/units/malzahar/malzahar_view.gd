extends Node3D
var _prepared := false
func _ready() -> void: prepare_visual_animations()
func prepare_visual_animations() -> void:
	if _prepared: return
	var player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if player == null or skeleton == null: return
	_prepared = true
	var snap := preload("res://assets/units/malzahar/w_weapon_snap.gd").new()
	snap.player = player
	skeleton.add_child(snap)

func reset_pool_visual() -> void:
	pass # 只持有本模型播放器，骨骼姿态由模型池恢复。

## 原版两套普攻的 mStartBoneName；仅改变投影起点。
func create_projectile_anchor() -> Node3D:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null: return null
	var bone := skeleton.find_bone("C_BUFFBONE_GLB_CHEST_LOC")
	if bone < 0: return null
	var anchor := BoneAttachment3D.new()
	anchor.name = "ProjectileModelAnchor"
	anchor.bone_name = "C_BUFFBONE_GLB_CHEST_LOC"
	skeleton.add_child(anchor)
	anchor.bone_idx = bone
	return anchor

## R独立使用眼部锚点。
func configure_unit_visual(source: Unit) -> void:
	var eye := find_child("NetherGraspEye", true, false) as Node3D
	if eye == null:
		var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
		if skeleton == null: return
		var head := skeleton.find_bone("head")
		if head < 0: return
		var attachment := BoneAttachment3D.new()
		attachment.name = "NetherGraspHead"
		attachment.bone_idx = head
		skeleton.add_child(attachment)
		eye = Marker3D.new()
		eye.name = "NetherGraspEye"
		eye.position = Vector3(0.0, 5.0, 10.0)
		attachment.add_child(eye)
	source.set_meta("skill_beam_anchor", weakref(eye))
