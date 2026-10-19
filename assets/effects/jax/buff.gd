extends ActiveBuffVisual3D
const PLAYER = preload("res://assets/effects/jax/player.gd")
var _player: Node3D
func configure(_radius: float, _team: int = 0) -> void:
	status_source = "active_buff_clock"
	_player = PLAYER.new()
	add_child(_player)
	_player.load_kind("buf")
	_player.setup_native(PLAYER.NATIVE_SCALE)
func advance_status(status_active: bool, shown: bool, _delta: float) -> void:
	active = status_active and status_state.y > 0.0 and status_state.x <= status_state.y + 1.1
	visible = shown and active
	if active: _player.seek(status_state.x)
