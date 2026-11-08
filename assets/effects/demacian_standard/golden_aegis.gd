extends ActiveBuffVisual3D
## 可靠shield:cast启动；护盾只读表现，不驱动加盾与减速。
const PLAYER = preload("res://assets/effects/demacian_standard/player.gd")
const SOURCE_NOVA_RADIUS := 153.06227423519815 * 3.0
var _nova: Node3D
var _shield: Node3D
var _age := INF
var _shield_duration := 3.0
func configure(_radius: float, _team: int = 0) -> void:
	_nova = PLAYER.new()
	add_child(_nova)
	_nova.load_kind("nova")
	var stats := CardDB.get_card("demacian_standard")
	var radius := float(stats.radius) + float(stats.active_skills[0].radius)
	_shield_duration = float(stats.active_skills[0].shield_duration)
	# 以可见主环的3倍扩张对齐边缘；源尾段额外2%扩张裁在同一范围内。
	_nova.range_radius = SOURCE_NOVA_RADIUS
	_nova.setup_native(radius / 40.0 / SOURCE_NOVA_RADIUS)
	_nova.position.y = 0.025 - 10.0 * _nova.scale.x
	_shield = PLAYER.new()
	add_child(_shield)
	_shield.load_kind("shield")
	_shield.setup_native(0.01)
	visible = false
func on_cue(cue: StringName) -> void:
	if cue == &"shield:cast": _age = 0.0
func advance_status(_active: bool, _shown: bool, delta: float) -> void:
	if not is_finite(_age): return
	_age += delta
	_nova.visible = presentation_enabled and _age < 0.6
	_shield.visible = presentation_enabled and shield_active and _age < _shield_duration
	if _nova.visible: _nova.seek(_age)
	# 保留新版源粒子速度，项目3秒盾期末尾仅淡出，不加速旋转及颜色查表。
	if _shield.visible:
		_shield.seek(_age)
		_shield.set_effect_fade(clampf((_shield_duration - _age) / 0.35, 0.0, 1.0))
	visible = _nova.visible or _shield.visible
func prepare_resource_sample(_skills: Array, draw: Callable) -> void:
	shield_active = true
	for age in [0.05, 0.2, 0.4, 1.0, 2.5]:
		_age = age
		advance_status(true, true, 0.0)
		draw.call()
	_age = INF
	visible = false
