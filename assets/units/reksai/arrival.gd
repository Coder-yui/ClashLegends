extends PreDeploymentVisual3D
## 地下阶段没有战斗实体；只采样权威预部署队列的进度。
const PLAYER = preload("res://assets/effects/reksai/player.gd")
const PATH = preload("res://scripts/battle/burrow_deployment_path.gd")
var _route: Curve2D
var _effect: Node3D
var _layers: Array[Dictionary] = []
var _phase_start := 0.0
var _age := 0.0
var _ending := false
var _tail_age := 0.0
func setup(view_camera: Camera3D, point: Vector2, source_team: int) -> void:
	super.setup(view_camera, point, source_team)
	_route = PATH.curve(route if not route.is_empty() else PackedVector2Array([destination]))
	if duration <= 0.0:
		duration = maxf(0.05, _route.get_baked_length() / float(CardDB.get_card("reksai").pre_deploy_burrow_speed))
	_start_layer(0.0)
	advance_visual(0.0)

func _start_layer(start: float) -> void:
	_phase_start = start
	_effect = PLAYER.new()
	add_child(_effect)
	_effect.load_kind("travel")
	_effect.setup_native(0.008)
	_layers.append({"effect":_effect,"start":start})
func advance_visual(progress: float) -> void:
	if _effect == null: return
	_age = clampf(progress, 0.0, 1.0) * duration
	var distance := minf(_age * float(CardDB.get_card("reksai").pre_deploy_burrow_speed), _route.get_baked_length())
	audio_position = _route.sample_baked(distance)
	var point := ground(audio_position)
	var direction := ground(_route.sample_baked(minf(distance+2.0, _route.get_baked_length()))) - ground(_route.sample_baked(maxf(distance-2.0, 0.0)))
	var facing := Basis(Vector3.UP, atan2(direction.x, direction.z)) if direction.length_squared() > 0.001 else Basis.IDENTITY
	if _age-_phase_start>=4.0:
		_effect.stop_emission(4.0)
		_start_layer(floorf(_age/4.0)*4.0)
	for layer in _layers.duplicate():
		var age := _age-float(layer.start)
		if age>=5.8 and layer.effect!=_effect:
			layer.effect.queue_free()
			_layers.erase(layer)
		else: layer.effect.seek_motion(age,point,facing)

func finish_visual() -> void:
	_ending = true
	_tail_age = 0.0
	for layer in _layers: layer.effect.stop_emission(minf(_age-float(layer.start),4.0))

func _process(delta: float) -> void:
	if not _ending: return
	_tail_age += maxf(delta, 0.0)
	for layer in _layers:
		layer.effect.seek_motion(_age + _tail_age - float(layer.start), layer.effect.global_position, layer.effect.global_basis.orthonormalized())
	if _tail_age >= 1.8: queue_free()
