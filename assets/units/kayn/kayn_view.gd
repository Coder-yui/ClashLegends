extends Node3D
## 源库三形态显隐；只显示当前形态的皮肤和武器，不创建三套骨骼。
@export_enum("普通", "蓝凯", "红凯") var form := 0
var _weapon_blend: SkeletonModifier3D
func prepare_visual_animations() -> void:
	if _weapon_blend == null:
		var skeleton := find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		_weapon_blend = preload("res://assets/units/kayn/weapon_blend.gd").new()
		_weapon_blend.player = find_children("*", "AnimationPlayer", true, false)[0]
		skeleton.add_child(_weapon_blend)
	var names := [["Kayn_Base_Mat"], ["Kayn_Base_Assassin_Mat", "Kayn_Assassin_Hair_Mat"], ["Kayn_Base_Slayer_Mat"]]
	for mesh in find_children("*", "MeshInstance3D", true, false):
		mesh.visible = String(mesh.name) in names[form]
func _ready() -> void:
	prepare_visual_animations()
func reset_pool_visual() -> void:
	prepare_visual_animations()
	_weapon_blend.reset_pool_visual()

func set_visual_blend(clip: StringName, duration: float) -> void:
	_weapon_blend.begin_blend(clip, duration)

## 展台围绕人物脚下原点取景，避免静态镰刀包围盒把主体挤向一侧。
func get_preview_focus(bounds_center: Vector3) -> Vector3:
	return Vector3(global_position.x, bounds_center.y, global_position.z)
