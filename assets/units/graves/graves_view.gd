extends Node3D
var unit_ref: WeakRef
func configure_unit_visual(unit: Unit) -> void:
	unit_ref = weakref(unit)
## 原版子弹挂点；只改变可见枪口，权威弹道来自Unit中心。
func get_attack_launch_bones() -> Array[String]:
	return ["buffbone_cstm_weapona"]

func uses_configured_attack_launch() -> bool:
	return false

func prepare_visual_animations() -> void:
	var player := find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("").duplicate() as AnimationLibrary
	var locomotion := preload("res://assets/units/graves/reload_move.res") as AnimationLibrary
	library.add_animation("ReloadMove", locomotion.get_animation("ReloadMove"))
	player.remove_animation_library("")
	player.add_animation_library("", library)
