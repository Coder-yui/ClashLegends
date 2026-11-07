extends Node3D
## 原版 W 击飞出土及 Q 三击；粒子独立结束，不把部署终点帧当作常驻状态。
const PLAYER = preload("res://assets/effects/reksai/player.gd")
var _unit: WeakRef
var _emerge: Node3D
var _emerge_cast: Node3D
var _swipes: Array[Node3D] = []
var _emerge_age := 0.0
var _deploy_finished := false
var _dead := false
var _attack_serial := -1
func configure_unit_visual(unit: Unit) -> void:
	_unit = weakref(unit)
	_emerge_age = 0.0
	_deploy_finished = false
	_dead = false
	_attack_serial = -1
	if _emerge == null:
		_emerge = _new_effect("emerge")
		_emerge_cast = _new_effect("emerge_cast")
	if _swipes.is_empty():
		_swipes.assign([_new_effect("swipe"), _new_effect("swipe_second")])
	_hide_effects()
func _new_effect(kind: String) -> Node3D:
	var effect := PLAYER.new()
	add_child(effect)
	effect.load_kind(kind)
	effect.setup_native(0.008)
	return effect
func advance_deployment_visual(elapsed: float, duration: float, shown: bool) -> void:
	if _emerge == null: return
	_emerge_age = maxf(_emerge_age, elapsed)
	_deploy_finished = elapsed >= duration
	_emerge.visible = shown and not _dead and _emerge_age < 3.0
	_emerge_cast.visible = _emerge.visible
	if _emerge.visible:
		_emerge.seek_motion(_emerge_age, global_position, global_basis.orthonormalized())
		_emerge_cast.seek_motion(_emerge_age, global_position, global_basis.orthonormalized())
func advance_ambient_visual(delta: float) -> void:
	if _deploy_finished: _emerge_age += maxf(delta, 0.0)
	var unit = _unit.get_ref() if _unit != null else null
	var shown: bool = not _dead and is_instance_valid(unit) and unit.hp > 0.0 and unit.visible_to_local_player() and unit.get_visual_state_code() == 3 and unit.get_attack_visual_serial() > 0 and unit.get_attack_visual_serial() == unit.get_empowered_attack_visual_serial()
	for effect in _swipes: effect.hide()
	if shown:
		var serial: int = unit.get_attack_visual_serial()
		var effect: Node3D = _swipes[1 if posmod(serial - 1, 3) == 1 else 0]
		# 即使连续两击共用素材，也要重新建立世界空间粒子出生挂点。
		if serial != _attack_serial:
			effect.seek_motion(0.0, global_position, global_basis.orthonormalized())
			_attack_serial = serial
		effect.show()
		effect.seek_motion(unit.get_attack_elapsed_visual() * 2.0 / maxf(unit.attack_interval, 0.01), global_position, global_basis.orthonormalized())
func _hide_effects() -> void:
	if _emerge != null: _emerge.hide()
	if _emerge_cast != null: _emerge_cast.hide()
	for effect in _swipes: effect.hide()
func begin_visual_death(_duration: float) -> void:
	_dead = true
	_hide_effects()
func reset_pool_visual() -> void:
	_unit = null
	_dead = true
	_hide_effects()
