extends ActiveBuffVisual3D
## 自制程序紫色覆层：仅消费表现状态，不加载外部粒子/纹理。
var _elapsed := 0.0

func configure(_visual_radius: float, _team: int = 0) -> void:
	overlay_material = ShaderMaterial.new()
	overlay_material.shader = preload("res://assets/effects/baron_minion/overlay.gdshader")
	visible = false

func advance(enabled: bool, delta: float) -> void:
	if enabled and not active: _elapsed = 0.0
	active = enabled
	visible = enabled
	_elapsed += delta
	for material in overlay_instances:
		material.set_shader_parameter("elapsed", _elapsed)
		material.set_shader_parameter("strength", 1.0 if enabled else 0.0)
