extends Node3D
## 原始普攻按动作顺序声明发射骨骼；空字符串表示来源未确定。
@export var attack_launch_bones := PackedStringArray()
@export var attack_launch_use_configured_offset := false

func get_attack_launch_bones() -> PackedStringArray:
	return attack_launch_bones

func uses_configured_attack_launch() -> bool:
	return attack_launch_use_configured_offset
