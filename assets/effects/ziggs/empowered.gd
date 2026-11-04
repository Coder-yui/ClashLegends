extends ActiveBuffVisual3D
## 原版 P_buf 待发光效；只读取强化状态，跟随模型 Bomb 骨骼。
const PLAYER = preload("res://assets/effects/ziggs/player.gd")
var _player: Node3D
var _attachment: BoneAttachment3D
var _age := 0.0

func configure(_radius: float, _team: int = 0) -> void:
	status_source = "empowered_attack"
	_player = PLAYER.new()
	add_child(_player)
	_player.load_kind("passive")
	_player.setup_native(PLAYER.NATIVE_SCALE)
	_player.hide()

func bind_model(model: Node3D) -> void:
	for skeleton in model.find_children("*", "Skeleton3D", true, false):
		var bone: int = skeleton.find_bone("Bomb")
		if bone < 0: continue
		_attachment = BoneAttachment3D.new()
		skeleton.add_child(_attachment)
		_attachment.bone_name = "Bomb"
		_attachment.bone_idx = bone
		return

func advance_status(status_active: bool, shown: bool, delta: float) -> void:
	if not status_active:
		_age = 0.0
	elif shown:
		_age += maxf(delta, 0.0)
	active = status_active
	visible = shown
	_player.visible = shown and is_instance_valid(_attachment)
	if _player.visible:
		# 激活闪光仅播一次；此后循环稳定段，不重播 CastFlash。
		var sample_age := _age if _age < 1.0 else 1.0 + fmod(_age - 1.0, 4.0)
		_player.seek_motion(sample_age, _attachment.global_position, _attachment.global_basis.orthonormalized())

func _exit_tree() -> void:
	if is_instance_valid(_attachment):
		_attachment.hide()
		_attachment.queue_free()
