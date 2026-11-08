extends Node3D
const PLAYER = preload("res://assets/effects/reksai/player.gd")
const BUFF = preload("res://assets/units/reksai/empowered.gd")
var _unit: WeakRef
var _swipes: Array[Node3D] = []
var _buff: Node3D
var _serial := -1
var _dead := false
func configure_unit_visual(unit: Unit) -> void:
	_unit = weakref(unit)
	_dead = false
	_serial = -1
	if _swipes.is_empty():
		for kind in ["swipe", "swipe_second"]:
			var effect := PLAYER.new()
			add_child(effect)
			effect.load_kind(kind)
			effect.setup_native(0.008)
			effect.hide()
			_swipes.append(effect)
		_buff = BUFF.new()
		add_child(_buff)
		_buff.configure(unit.body_radius, unit.team)
		_buff.bind_model(self)
func advance_ambient_visual(delta: float) -> void:
	var unit = _unit.get_ref() if _unit != null else null
	var shown: bool = not _dead and is_instance_valid(unit) and unit.hp > 0.0 and unit.visible_to_local_player()
	if _buff != null: _buff.advance_status(shown, shown, delta)
	for effect in _swipes: effect.hide()
	if not shown or unit.get_visual_state_code() != 3: return
	var serial: int = unit.get_attack_visual_serial()
	if serial <= 0: return
	var effect: Node3D = _swipes[posmod(serial - 1, 2)]
	if serial != _serial:
		effect.seek_motion(0.0, global_position, global_basis.orthonormalized())
		_serial = serial
	effect.show()
	effect.seek_motion(unit.get_attack_elapsed_visual() * 2.0 / maxf(unit.attack_interval, 0.01), global_position, global_basis.orthonormalized())
func begin_visual_death(_duration: float) -> void:
	_dead = true
	for effect in _swipes: effect.hide()
	if _buff != null: _buff.hide()
func reset_pool_visual() -> void:
	begin_visual_death(0.0)
	_unit = null
