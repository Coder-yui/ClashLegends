extends ActiveBuffVisual3D
const PLAYER = preload("res://assets/effects/graves/player.gd")
var _unit: WeakRef
var _dash: Node3D
func configure(_radius: float, _team: int = 0) -> void:
	status_source = "active_action"

func bind_model(model: Node3D) -> void:
	_unit = model.unit_ref

func advance_status(_status_active: bool, shown: bool, _delta: float) -> void:
	var unit = _unit.get_ref() if _unit != null else null
	visible = shown and is_instance_valid(unit) and unit.get_visual_action_name() == &"active"
	if not visible: return
	if _dash == null:
		_dash = PLAYER.new()
		add_child(_dash)
		_dash.load_kind("dash")
		_dash.setup_native(PLAYER.NATIVE_SCALE)
	var elapsed: float = unit.get_visual_action_duration() - unit.get_visual_action_time_left()
	_dash.seek_motion(elapsed, global_position, global_basis.orthonormalized())
