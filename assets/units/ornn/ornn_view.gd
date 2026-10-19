extends "res://scripts/presentation/model_template_view.gd"
## 确定性网格加工在开发模板完成。

# The imported mesh AABB includes hidden cosmetic vertices; focus on the body.
func get_preview_focus(_fallback: Vector3) -> Vector3:
	return global_transform * Vector3(0.0, 1.202, 0.156)
