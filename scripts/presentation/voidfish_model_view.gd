extends Node3D
## 两种虚空鱼共用原版Transform出生；零部署时间的女皇散出物不播放。
var prepared := false
func _ready() -> void:
	prepare_visual_animations()

func prepare_visual_animations() -> void:
	if prepared: return
	prepared = true
	for instance in find_children("*", "MeshInstance3D", true, false):
		var original: ArrayMesh = instance.mesh
		var filtered := ArrayMesh.new()
		for surface in original.get_surface_count():
			var material := original.surface_get_material(surface)
			if material != null and material.resource_name == _hidden_surface(): continue
			filtered.add_surface_from_arrays(original.surface_get_primitive_type(surface), original.surface_get_arrays(surface))
			filtered.surface_set_material(filtered.get_surface_count() - 1, material)
		instance.mesh = filtered

const PARTICLES = preload("res://assets/effects/voidfish_ranged/player.gd")
const BODY_REVEAL_TIME := 0.72 # 0.2起发+0.5寿命，含采样边界，确保剪影已清除。
const SPAWN_DURATION := 0.78 # 原始最后一层0.2起发+0.55寿命，含采样边界。

func _hidden_surface() -> String: return "Ranged"
var _skeleton: Skeleton3D
var _source: Unit
var _spawn: Node3D
var _spawn_age := 0.0
var _spawn_started := false
var _spawn_finished := false
var _dying := false

func configure_unit_visual(source: Unit) -> void:
	reset_pool_visual()
	_source = source

func _find_bones() -> void:
	if _skeleton != null: return
	_skeleton = find_children("*", "Skeleton3D", true, false)[0]

func advance_deployment_visual(elapsed: float, duration: float, active: bool) -> void:
	if not active or duration <= 0.0:
		_finish_spawn()
		return
	if _spawn_finished: return
	# 重连到已经完成部署的对象，不补播出生。
	if elapsed >= duration:
		_finish_spawn()
		return
	if not _spawn_started:
		_spawn_started = true
		_spawn = PARTICLES.new()
		add_child(_spawn)
		# 原定义的EmitterPosition/SpawnShape已经包含(0,50,0)，不额外挂胸骨偏移。
		# 继承模型根的平移、朝向、尺寸：随宿主变换，不能锁在首次世界坐标。
		_spawn.transform = $Model.transform
		_spawn.load_kind("spawn")
		_spawn.setup_native(absf($Model.scale.x))
	# 只读部署时钟；暂停、重连不再按帧时间额外推进或反复重启。
	var interpolation := 0.0
	if is_instance_valid(_source) and _source.battle_context != null:
		interpolation = _source.battle_context.simulation_interpolation_alpha() * FixedStepClock.STEP
	_spawn_age = minf(duration, maxf(elapsed, 0.0) + interpolation)
	_spawn.seek(_spawn_age)
	$Model.visible = _spawn_age >= BODY_REVEAL_TIME
	if _spawn_age >= SPAWN_DURATION: _finish_spawn()

func _process(_delta: float) -> void:
	if is_instance_valid(_spawn) and (_dying or (is_instance_valid(_source) and (_source.hp <= 0.0 or _source.cancelled_deployment))):
		_finish_spawn()

func _finish_spawn() -> void:
	if is_instance_valid(_spawn): _spawn.free()
	_spawn = null
	_spawn_finished = true
	$Model.visible = true

func begin_visual_death(_duration: float) -> void:
	_dying = true
	_finish_spawn()

func reset_pool_visual() -> void:
	_finish_spawn()
	_spawn_started = false
	_spawn_finished = false
	_dying = false
	_spawn_age = 0.0
	_source = null
