extends ActiveBuffVisual3D
const PLAYER = preload("res://assets/effects/graves/player.gd")
var _unit: WeakRef
var _dash: Node3D
var _flash: Node3D
var _flash_age := 10.0
func configure(_radius: float, _team: int = 0) -> void:
	status_source = "active_action"
	_flash = PLAYER.new()
	add_child(_flash)
	_flash.load_kind("cast")
	_flash.setup_native(PLAYER.NATIVE_SCALE)
func bind_model(model: Node3D) -> void:
	_unit = model.unit_ref
func on_cue(cue: StringName) -> void:
	if cue == &"attack_launch": _flash_age = 0.0
func advance_status(_status_active: bool, shown: bool, delta: float) -> void:
	var unit = _unit.get_ref() if _unit != null else null
	if not is_instance_valid(unit) or unit.hp <= 0.0:
		visible = false
		return
	var casting: bool = shown and unit.get_visual_action_name() == &"active"
	if casting and _dash == null:
		_dash = PLAYER.new()
		add_child(_dash)
		_dash.load_kind("dash")
		_dash.setup_native(PLAYER.NATIVE_SCALE)
	if _dash != null: _dash.visible = casting
	if casting:
		_dash.seek(unit.get_visual_action_duration() - unit.get_visual_action_time_left())
	_flash_age += delta
	_flash.visible = _flash_age < 0.3 and PresentationConfig.status_indicators_visible(unit)
	if _flash.visible:
		var anchor = unit.get_meta("projectile_model_anchor").get_ref() if unit.has_meta("projectile_model_anchor") else null
		if is_instance_valid(anchor): _flash.global_position = anchor.global_position
		_flash.seek(_flash_age)
	visible = casting or _flash.visible
