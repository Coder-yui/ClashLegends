class_name ActiveBuffVisual3D
extends Node3D
## 可复用的持续 Buff 表现接口；由模型代理喂入权威/快照状态与表现时钟。
## 不持有 Unit，不参与玩法或网络。

@export_enum("active_buff", "blood_rage") var status_source: String = "active_buff"
var active := false
var overlay_material: ShaderMaterial
var overlay_instances: Array[ShaderMaterial] = []

func configure(_visual_radius: float, _team: int = 0) -> void:
	pass

func advance(enabled: bool, _delta: float) -> void:
	active = enabled
	visible = enabled

func make_overlay(original: Material) -> Material:
	if overlay_material == null:
		return original
	var material := overlay_material.duplicate() as ShaderMaterial
	material.next_pass = original
	overlay_instances.append(material)
	return material

func on_hit() -> void:
	pass
