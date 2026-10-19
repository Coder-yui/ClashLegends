extends ActiveBuffVisual3D
## 项目自制：轮廓光与绑定头角的渐变光球，没有上升光丝。
const OUTLINE = preload("res://assets/effects/void_spawn/empowered_outline.gdshader")
const ORB = preload("res://assets/effects/void_spawn/empowered_mote.gdshader")
var _elapsed := 0.0
var _orb: MeshInstance3D
var _skeleton: Skeleton3D
var _horn := -1
var _attachment: BoneAttachment3D

func configure(_visual_radius: float, _team: int = 0) -> void:
	if _orb != null: return
	overlay_material = ShaderMaterial.new()
	overlay_material.shader = OUTLINE
	_orb = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.90, 0.90)
	_orb.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = ORB
	_orb.material_override = material
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_orb)
	advance(false, 0.0)

func bind_model(model: Node3D) -> void:
	if not is_instance_valid(model): return
	for node in model.find_children("*", "Skeleton3D", true, false):
		_skeleton = node
		_horn = _skeleton.find_bone("Horn")
		if _horn < 0: continue
		_attachment = BoneAttachment3D.new()
		_attachment.name = "EmpoweredHornAttachment"
		_attachment.bone_idx = _horn
		_skeleton.add_child(_attachment)
		_orb.reparent(_attachment, false)
		# Horn局部坐标；光球贴合角体，完整继承骨骼与模型变换。
		_orb.position = Vector3(0.48, 0.14, 0.0)
		break

func advance(enabled: bool, delta: float) -> void:
	active = enabled
	visible = enabled
	if enabled: _elapsed += maxf(delta, 0.0)
	for material in overlay_instances:
		material.set_shader_parameter("strength", 1.0 if enabled else 0.0)
		material.set_shader_parameter("elapsed", _elapsed)
	if not is_instance_valid(_orb): return
	_orb.visible = enabled
	_orb.material_override.set_shader_parameter("opacity", 0.85 if enabled else 0.0)
	_orb.material_override.set_shader_parameter("elapsed", _elapsed)

func _exit_tree() -> void:
	if is_instance_valid(_attachment):
		_attachment.hide()
		_attachment.queue_free()
