extends ActiveBuffVisual3D
## 原版Q流动光环与双层贴筒流光挂接真实武器骨骼，随武器转动；不改变模型材质。
const PLAYER = preload("res://assets/effects/gwen_tristana/player.gd")
var _attachment: BoneAttachment3D
var _player: Node3D
var _age := 0.0

func configure(_radius: float, _team: int = 0) -> void:
	visible = false

func _create_effect() -> void:
	for skeleton: Skeleton3D in get_parent().find_children("*", "Skeleton3D", true, false):
		var index := skeleton.find_bone("Buffbone_Glb_Weapon_1")
		if index < 0: continue
		_attachment = BoneAttachment3D.new()
		_attachment.bone_idx = index
		skeleton.add_child(_attachment)
		_player = PLAYER.new()
		_attachment.add_child(_player)
		_player.load_kind("rapid")
		_player.setup_native(0.01)
		return

func advance(enabled: bool, delta: float) -> void:
	advance_status(enabled, enabled, delta)

func advance_status(status_active: bool, shown: bool, delta: float) -> void:
	if status_active and not active: _age = 0.0
	active = status_active
	visible = shown
	if status_active and not is_instance_valid(_player): _create_effect()
	if not is_instance_valid(_player): return
	_player.visible = shown
	if not status_active: return
	_age += delta
	_player.seek(minf(_age, 5.0))

func _exit_tree() -> void:
	if is_instance_valid(_attachment): _attachment.queue_free()
