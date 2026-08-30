class_name SuiteUtils
extends RefCounted
## 跨领域 suite 共用的测试工具。

static func find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := SuiteUtils.find_anim_player(child)
		if found != null:
			return found
	return null

## 静止木桩属性：不索敌、不移动、不还手，但保留质量与体型，专测横扫本身。
static func sweep_dummy_stats(base: Dictionary) -> Dictionary:
	var stats: Dictionary = base.duplicate()
	stats["deploy_time"] = 0.0
	stats["hp"] = 99999.0
	stats["damage"] = 0.0
	stats["speed"] = 0.0
	stats["sight"] = 0.0
	return stats
