extends ActiveBuffVisual3D
func configure(_radius: float, _team: int = 0) -> void:
	overlay_material = ShaderMaterial.new()
	overlay_material.shader = preload("res://assets/effects/baron_minion/overlay.gdshader")
	visible = false
func advance_status(status_active: bool, shown: bool, _delta: float) -> void:
	active = status_active
	visible = shown
	for material in overlay_instances: material.set_shader_parameter("strength", 1.0 if shown else 0.0)
