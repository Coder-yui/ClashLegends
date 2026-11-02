extends ActiveBuffVisual3D
const PLAYER = preload("res://assets/effects/thorn_spitter/player.gd")
var _player: Node3D
var _anchor: Node3D
func configure(_radius: float, _team: int = 0) -> void:
	status_source = "active_buff_clock"
	_player = PLAYER.new()
	_player.add_to_group("presentation_fx")
	add_child(_player)
	_player.load_kind("buff")
	_player.setup_native(0.016 / 1.2)
	visible = false
func bind_model(model: Node3D) -> void:
	if is_instance_valid(_anchor): _anchor.queue_free()
	if model.has_method("create_buff_anchor"): _anchor = model.create_buff_anchor()
	if is_instance_valid(_anchor):
		# 直接属于放大后的骨架：继承其位置和尺寸，同帧响应体型变化。
		_player.reparent(_anchor, false)
		_player.position = Vector3.ZERO
		_player.visible = false
		_sync_attachment_basis()
func advance(enabled: bool, delta: float) -> void:
	advance_status(enabled, enabled, delta)
func advance_status(status_active: bool, shown: bool, _delta: float) -> void:
	active = status_active and status_state.x < 6.0
	visible = shown and active
	_player.visible = visible
	_sync_attachment_basis()
	if status_active: _player.seek(minf(status_state.x, 6.0))
func _sync_attachment_basis() -> void:
	if not is_instance_valid(_anchor): return
	# 只抵消挂点旋转/镜像；保留骨架的全部尺寸，源皮肤比例仅除一次。
	_player.basis = _anchor.global_basis.orthonormalized().inverse().scaled(Vector3.ONE / 1.2)
func _exit_tree() -> void:
	if is_instance_valid(_anchor): _anchor.queue_free()
