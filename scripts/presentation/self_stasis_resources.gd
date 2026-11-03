extends RefCounted
## 自身金身只准备目标状态，不加载巴德法术弹体及落点粒子。
static func resource_manifest(_variant: String) -> Dictionary:
	return {"target_states": ["stasis"], "paths": [
		"res://assets/effects/stasis/attached_mesh.gdshader",
		"res://assets/effects/stasis/attached_gold.gdshader",
		"res://assets/effects/stasis/bard_swirl.png", "res://assets/effects/stasis/zhonya_swirl.png"]}
