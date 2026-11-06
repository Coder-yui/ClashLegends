extends ActiveBuffVisual3D
## 自身W光环和施法者R_Cas挂在模型根部；导弹由独立代理拥有。
const PLAYER = preload("res://assets/effects/sona/player.gd")
const W_SCALE := 160.0 / 40.0 / 400.0
var _model: Node3D
var _player: Node3D
var _cast: Node3D
var _cast_serial := -1

func configure(_radius: float, _team: int = 0) -> void:
	_player = PLAYER.new()
	add_child(_player)
	_player.load_kind("heal_self")
	_player.setup_native(W_SCALE)
	visible = false

func bind_model(model: Node3D) -> void:
	_model = model

func _pose() -> Transform3D:
	return Transform3D(_model.global_basis.orthonormalized(), _model.global_position) if is_instance_valid(_model) else global_transform

func _ensure_cast() -> void:
	if _cast != null: return
	_cast = PLAYER.new()
	add_child(_cast)
	_cast.load_kind("cast")
	_cast.setup_native(PLAYER.NATIVE_SCALE)

func advance_status(status_active: bool, shown: bool, _delta: float) -> void:
	active = status_active
	var pose := _pose()
	_player.visible = shown
	if shown:
		var age := status_state.x
		_player.seek_motion(age if age < 4.0 else 2.0 + fmod(age - 4.0, 2.0), pose.origin, pose.basis)
	var casting := presentation_enabled and action_name == &"crescendo" and action_state.y > 0.0
	if casting:
		if _cast_serial != action_serial:
			if _cast != null: _cast.free()
			_cast = null
			_cast_serial = action_serial
		_ensure_cast()
		# R_Cas自身含100/125/250等源高度，不再叠加WEAPON高度。
		_cast.seek_motion(action_state.x, pose.origin, pose.basis)
	if _cast != null: _cast.visible = casting
	visible = shown or casting

func prepare_resource_sample(skills: Array, draw: Callable) -> void:
	for age in [0.1, 0.5, 1.0, 2.0]:
		status_state = Vector2(age, 3.0)
		advance_status(true, true, 0.0)
		draw.call()
	if skills.any(func(skill): return String(skill.get("visual_action", "")) == "crescendo"):
		action_name = &"crescendo"
		for age in [0.0, 0.1, 0.3, 0.6, 0.9]:
			action_state = Vector2(age, 1.0)
			advance_status(false, false, 0.0)
			draw.call()
	action_state = Vector2.ZERO
	advance_status(false, false, 0.0)
