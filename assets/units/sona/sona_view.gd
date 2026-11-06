extends Node3D

func _ready() -> void:
	# 源绑定姿势的WEAPON朝后约180°，运行片段均朝前。混合以rest为
	# 四元数参考会绕远路；改用Idle1的旋转参考，保留Skin逆绑定和源动画。
	var players := find_children("*", "AnimationPlayer", true, false)
	if players.is_empty(): return
	var player := players[0] as AnimationPlayer
	var idle := player.get_animation("Idle1")
	var animation_root := player.get_node(player.root_node)
	for track in idle.get_track_count():
		if idle.track_get_type(track) != Animation.TYPE_ROTATION_3D: continue
		var path := idle.track_get_path(track)
		if path.get_subname_count() != 1: continue
		var skeleton := animation_root.get_node_or_null(NodePath(path.get_concatenated_names())) as Skeleton3D
		if skeleton == null: continue
		var bone := skeleton.find_bone(path.get_subname(0))
		if bone < 0: continue
		var rest := skeleton.get_bone_rest(bone)
		rest.basis = Basis(idle.rotation_track_interpolate(track, 0.0)).scaled(rest.basis.get_scale())
		skeleton.set_bone_rest(bone, rest)
	player.clear_caches()

## 普攻源没有专用起始骨骼，显式使用琴身 WEAPON 作为项目视觉挂点。
func create_projectile_anchor() -> Node3D:
	for skeleton in find_children("*", "Skeleton3D", true, false):
		var index: int = skeleton.find_bone("WEAPON")
		if index < 0: continue
		var anchor := BoneAttachment3D.new()
		anchor.name = "ProjectileModelAnchor"
		anchor.bone_idx = index
		skeleton.add_child(anchor)
		return anchor
	return null
