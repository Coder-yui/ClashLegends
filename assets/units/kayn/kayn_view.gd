extends Node3D
## 源库三形态显隐；只显示当前形态的皮肤和武器，不创建三套骨骼。
@export_enum("普通", "蓝凯", "红凯") var form := 0
func prepare_visual_animations() -> void:
	var names := [["Kayn_Base_Mat"], ["Kayn_Base_Assassin_Mat", "Kayn_Assassin_Hair_Mat"], ["Kayn_Base_Slayer_Mat"]]
	for mesh in find_children("*", "MeshInstance3D", true, false):
		mesh.visible = String(mesh.name) in names[form]
func _ready() -> void:
	prepare_visual_animations()
func reset_pool_visual() -> void:
	prepare_visual_animations()
