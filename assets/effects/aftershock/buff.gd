extends ActiveBuffVisual3D
## 原版六层 Buff；RimLighting 附着模型，其余五层保持源网格/贴图/曲线。
const PLAYER = preload("res://assets/effects/aftershock/native/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
var _age := 0.0
var _player: Node3D

func configure(radius: float, _team: int = 0) -> void:
	overlay_material = ShaderMaterial.new()
	overlay_material.shader = preload("res://assets/effects/aftershock/body.gdshader")
	overlay_material.set_shader_parameter("source_texture", preload("res://assets/effects/aftershock/native/Buff/assets/perks/styles/resolve/aftershock/particles/perks_aftershock_avatar_mult.png"))
	overlay_material.set_shader_parameter("reflection_texture", preload("res://assets/effects/aftershock/native/Buff/assets/shared/particles/generic_white_cubemap.png"))
	_player = PLAYER.new()
	add_child(_player)
	_player.load_kind("Buff")
	# 原版 Buff150 / circleOut311.40326 共用尺度，随模型视觉半径整体缩放。
	_player.setup_native((radius / 34.5) * 110.0 / 40.0 / 311.40326)
	visible = false

func advance(enabled: bool, delta: float) -> void:
	advance_status(enabled, enabled, delta)

func advance_status(status_active: bool, shown: bool, delta: float) -> void:
	active = status_active
	visible = shown
	_age = _age + delta if status_active else 0.0
	if _player == null: return
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		_player.projection_basis = PROJECTION.footprint_basis(camera, camera.unproject_position(global_position), 110.0)
	_player.seek(maxf(_age, 1.0 / 120.0))
	var sample: Array = _player.attached_sample()
	for surface in overlay_instances:
		surface.set_shader_parameter("strength", 1.0 if shown and not sample.is_empty() else 0.0)
		if not sample.is_empty():
			surface.set_shader_parameter("source_tint", Vector4(sample[7], sample[8], sample[9], sample[10]))
			surface.set_shader_parameter("source_uv", Vector4(sample[22], sample[23], sample[24], sample[25]))
