extends Node3D
## 纯表现睡眠符号；生命周期由通用模型代理控制。
var _letters: Array[Label3D] = []
var _age := 0.0
var _dead := false
var _unit: WeakRef
func _ready() -> void:
	for index in 3:
		var label := Label3D.new()
		label.text = "Z"
		label.font_size = 48
		label.pixel_size = 0.009
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.8, 0.65, 1.0)
		label.outline_modulate = Color(0.15, 0.05, 0.25)
		add_child(label)
		_letters.append(label)
	_sync()
func advance_ambient_visual(delta: float) -> void:
	_age += maxf(delta, 0.0)
	_sync()
func _sync() -> void:
	var unit = _unit.get_ref() if _unit != null else null
	var sleeping: bool = not _dead and (not is_instance_valid(unit) or unit.get_form_index() == 0 and unit.get_visual_state_code() == 1)
	for index in _letters.size():
		# 三个Z错峰出生，每个独立经历长大、上飘、淡出的完整周期。
		var phase := fposmod(_age / 2.5 + float(index) / 3.0, 1.0)
		_letters[index].position = Vector3(0.15 + phase * 0.8, 1.45 + phase * 1.25, 0.0)
		_letters[index].scale = Vector3.ONE * lerpf(0.25, 1.15, phase)
		_letters[index].modulate.a = smoothstep(0.0, 0.1, phase) * (1.0 - smoothstep(0.65, 1.0, phase))
		_letters[index].visible = sleeping
func _process(delta: float) -> void:
	# 无权威绑定的摄影实例也播放睡眠动画；实战由模型代理推进。
	if _unit == null: advance_ambient_visual(delta)
func configure_unit_visual(unit: Unit) -> void:
	_unit = weakref(unit)
	_dead = false
	_age = 0.0
func begin_visual_death(_duration: float) -> void:
	_dead = true
	_sync()
func reset_pool_visual() -> void:
	_unit = null
	_dead = true
	_sync()
