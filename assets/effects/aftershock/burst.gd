extends RefCounted
## 卡牌声明入口：原版爆炸资源与真实绘制预热。
static func resource_manifest(variant: String) -> Dictionary:
	if variant != "default": return {}
	return {"json": ["res://assets/effects/aftershock/native/AOE/sampled.json"],
		"sample": {"player": "res://assets/effects/aftershock/native/player.gd", "kind": "AOE", "setup": "native"}}
