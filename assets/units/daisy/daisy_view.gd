extends Node3D
## 小菊出生表现：由通用部署状态启动，不生成单位、不延长部署、不结算伤害。
const SPAWN_PLAYER = preload("res://assets/effects/ivern/player.gd")
const EFFECT_DURATION := 1.8
# 原版40帧出生动作在第29帧触发GroundSlam。
const LANDING_RATIO := 29.0 / 40.0
var _deploy_complete := false
var _source: Unit
var _effect: Node3D
var _age := 0.0
var _started := false
var _finished := false

func configure_unit_visual(source: Unit) -> void:
	reset_pool_visual()
	_source = source

func advance_deployment_visual(elapsed: float, duration: float, active: bool) -> void:
	if _finished: return
	if not active or duration <= 0.0:
		_finish()
		return
	if _started:
		_deploy_complete = elapsed >= duration
		if not _deploy_complete:
			_age = maxf(elapsed - duration * LANDING_RATIO, 0.0)
			_effect.seek(_age)
		return
	# 重连已完成部署的士兵不补播出生；冻结取消后也不重新开始。
	if elapsed >= duration:
		_finish()
		return
	if elapsed < duration * LANDING_RATIO: return
	_started = true
	_age = maxf(elapsed - duration * LANDING_RATIO, 0.0)
	_effect = SPAWN_PLAYER.new()
	add_child(_effect)
	_effect.top_level = true
	# 原版出生土尘留在出生地；部署后的走动/推挤不能拖走地面旋风。
	_effect.global_transform = Transform3D(global_basis.orthonormalized(), Vector3(global_position.x, 0.0, global_position.z))
	_effect.load_kind("spawn")
	_effect.setup_native(0.012)
	_effect.seek(_age)

func _process(delta: float) -> void:
	if not is_instance_valid(_effect): return
	if not is_instance_valid(_source) or _source.hp <= 0.0 or _source.cancelled_deployment:
		_finish()
		return
	if not _deploy_complete: return
	_age += delta
	if _age >= EFFECT_DURATION:
		_finish()
	else:
		_effect.seek(_age)

func _finish() -> void:
	if is_instance_valid(_effect): _effect.free()
	_effect = null
	_finished = true

func reset_pool_visual() -> void:
	_finish()
	_source = null
	_age = 0.0
	_started = false
	_deploy_complete = false
	_finished = false
