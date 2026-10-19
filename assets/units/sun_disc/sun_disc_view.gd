extends Node3D
## 太阳圆盘的组合包装：动态圆盘 + 已烘焙为单一 Rubble 表面的静态公主塔废墟。
## 本脚本只处理纯表现：固定废墟朝向和死亡末帧显隐。

var _shares_tower_base := false
var _ruin_world_yaw := INF
@export var visual_template: Resource

func _ready() -> void:
	prepare_visual_animations()

func visual_animation_contract() -> Dictionary:
	if visual_template == null or visual_template.get_script() != preload("res://scripts/presentation/model_visual_template.gd") or visual_template.schema != 1 or visual_template.libraries.is_empty():
		push_error("Sun disc requires generated model template v1")
		return {}
	return {"version": 1, "player": get_node("DiscModel").find_child("AnimationPlayer", true, false), "libraries": visual_template.libraries}


## 原版 AzirSunDiscBasicAttack 的 FixedSpeedMovement.mStartBoneName 为 joint2。
## 只提供画面发射点，随圆盘姿态运动；权威出生点与命中仍由 ProjectileSystem 决定。
func create_projectile_anchor() -> Node3D:
	var skeleton := get_node("DiscModel").find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null or skeleton.find_bone("joint2") < 0:
		return null
	var anchor := BoneAttachment3D.new()
	anchor.name = "ProjectileModelAnchor"
	anchor.bone_name = "joint2"
	skeleton.add_child(anchor)
	return anchor


func configure_unit_visual(source: Unit) -> void:
	# 外观取决于实际塔位，不能用“免寿命衰减”资格决定是否另放废墟。
	_shares_tower_base = false
	for body in source.get_tree().get_nodes_in_group("combatants") if source.is_inside_tree() else []:
		if body is Tower and not body.is_king and body.global_position.is_equal_approx(source.global_position):
			# 客户端可靠生成可能先于塔死亡快照；真实塔的基座已存在。
			_shares_tower_base = true
			break
	var ruin_root := get_node_or_null("RuinBase") as Node3D
	if ruin_root != null:
		# 真实塔墟由 TowerModel3D 保留；此处隐藏自带基座，避免双层废墟叠模。
		ruin_root.visible = not _shares_tower_base


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
	if ruin_root != null and not _shares_tower_base:
		# 废墟没有死亡片段，在圆盘 Death 的最后一帧直接移除。
		ruin_root.hide()


## 磁盘模板已在开发生成时裁掉静态基座轨道。直接摄影和bind共用一次副本。
func prepare_visual_animations() -> void:
	if not bool(get_meta("defer_animation_ownership", false)):
		ModelVisualResources.prepare_instance_animations(self)

func reset_pool_visual() -> void:
	_shares_tower_base = false
	_ruin_world_yaw = INF
