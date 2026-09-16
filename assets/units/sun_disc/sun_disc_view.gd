extends Node3D
## 太阳圆盘的组合包装：动态圆盘 + 已烘焙为单一 Rubble 表面的静态公主塔废墟。
## 本脚本只处理纯表现：固定废墟朝向和死亡末帧显隐。

var _built_on_tower_ruin := false
var _ruin_world_yaw := INF


func configure_unit_visual(source: Unit) -> void:
	_built_on_tower_ruin = source.built_on_tower_ruin
	var ruin_root := get_node_or_null("RuinBase") as Node3D
	if ruin_root != null:
		# 真实塔墟由 TowerModel3D 保留；此处隐藏自带基座，避免双层废墟叠模。
		ruin_root.visible = not _built_on_tower_ruin


## UnitModel3D 随权威朝向旋转；自带废墟反向抵消，保持部署首帧的世界朝向。
func sync_visual_facing(parent_yaw: float) -> void:
	var ruin_root := get_node_or_null("RuinBase") as Node3D
	if ruin_root == null:
		return
	if is_inf(_ruin_world_yaw):
		_ruin_world_yaw = parent_yaw + ruin_root.rotation.y
	ruin_root.rotation.y = _ruin_world_yaw - parent_yaw


func finish_visual_death() -> void:
	var ruin_root := get_node_or_null("RuinBase") as Node3D
	if ruin_root != null and not _built_on_tower_ruin:
		# 废墟没有死亡片段，在圆盘 Death 的最后一帧直接移除。
		ruin_root.hide()


## 原 AzirSunDisc Disk 遮罩只启用第 11/12 号骨骼。
## 复制实例动画后裁掉静态基座轨道，两个攻击片段只驱动圆盘上部。
func prepare_visual_animations() -> void:
	var players := get_node("DiscModel").find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var player := players[0] as AnimationPlayer
	for library_name in player.get_animation_library_list():
		var library := player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
		for clip_name in ["Attack1_BASE", "Attack2_BASE"]:
			if not library.has_animation(clip_name):
				continue
			var clip := library.get_animation(clip_name)
			for track in range(clip.get_track_count() - 1, -1, -1):
				var bone := String(clip.track_get_path(track).get_concatenated_subnames())
				if bone not in ["C_Buffbone_Glb_Chest_Loc", "Buffbone_Cstm_Obelisk_Tip"]:
					clip.remove_track(track)
		player.remove_animation_library(library_name)
		player.add_animation_library(library_name, library)

func reset_pool_visual() -> void:
	_built_on_tower_ruin = false
	_ruin_world_yaw = INF
