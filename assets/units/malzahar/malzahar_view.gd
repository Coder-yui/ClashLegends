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
