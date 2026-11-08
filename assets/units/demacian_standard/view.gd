extends Node3D
## 旗面原生CameraTrail只负责表现；暂停/冰冻随本体，死亡随骨骼下沉并在动作结束清理。
var flag: Node3D
var age := 1.0
var _source: Unit
const PLAYER = preload("res://assets/effects/demacian_standard/player.gd")
const MODEL_SCALE := 0.01
const LAND_TIME := 0.5
var _fall: Node3D
var _landing: Node3D
var _landing_age := 0.0
var _deploy_finished := false
var _grounded := true
var _aura: MeshInstance3D
var _preview_deployed := true
var _skeleton: Skeleton3D
var _root_bone := -1
var _dying := false
var _death_finished := false
var _death_flag_visible := false
func configure_unit_visual(source: Unit) -> void:
	reset_pool_visual()
	_source = source
	age = 1.0
	var radius := float(source._base_form_stats.get("haste_aura_radius", 160.0)) / 40.0
	_aura.scale = Vector3(radius, 1.0, radius)
	set_preview_team(source.team)
func reset_pool_visual() -> void:
	_clear_deploy()
	_deploy_finished = false
	_grounded = true
	_preview_deployed = true
	$Model.visible = true
	_source = null
	age = 1.0
	_dying = false
	_death_finished = false
	_death_flag_visible = false
func _clear_deploy() -> void:
	if is_instance_valid(_fall): _fall.free()
	if is_instance_valid(_landing): _landing.free()
	_fall = null
	_landing = null
func _seek_landing(value: float) -> void:
	_landing_age = value
	if not is_instance_valid(_landing): return
	if value >= 1.12:
		_landing.free()
		_landing = null
	else:
		_landing.seek(value)
func advance_deployment_visual(elapsed: float, duration: float, active: bool) -> void:
	_preview_deployed = active and elapsed >= duration
	if _deploy_finished:
		if not active: _clear_deploy()
		elif not is_instance_valid(_source): _seek_landing(elapsed - LAND_TIME)
		return
	if not active or elapsed >= duration:
		if not active:
			_clear_deploy()
		else:
			if is_instance_valid(_fall): _fall.free()
			_fall = null
			_seek_landing(elapsed - LAND_TIME)
		_deploy_finished = true
		_grounded = true
		$Model.visible = true
		return
	_grounded = elapsed >= LAND_TIME
	$Model.visible = _grounded
	flag.visible = _grounded
	if not _grounded:
		if not is_instance_valid(_fall):
			_fall = PLAYER.new()
			add_child(_fall)
			_fall.load_kind("fall_red" if is_instance_valid(_source) and _source.team == 1 else "fall")
			_fall.setup_native(MODEL_SCALE)
		_fall.seek(maxf(elapsed, 0.0))
	else:
		if is_instance_valid(_fall):
			_fall.free()
			_fall = null
		if not is_instance_valid(_landing):
			_landing = PLAYER.new()
			add_child(_landing)
			_landing.load_kind("landing")
			_landing.setup_native(MODEL_SCALE)
		_seek_landing(elapsed - LAND_TIME)
func _ready() -> void:
	_aura = MeshInstance3D.new()
	_aura.add_to_group("presentation_fx")
	_aura.name = "HasteRange"
	_aura.mesh = PlaneMesh.new()
	(_aura.mesh as PlaneMesh).size = Vector2(2.04, 2.04)
	_aura.scale = Vector3(4.0, 1.0, 4.0)
	_aura.position.y = 0.025
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/effects/demacian_standard/aura.gdshader")
	_aura.material_override = material
	add_child(_aura)
	flag = preload("res://assets/effects/demacian_standard/player.gd").new()
	add_child(flag)
	flag.load_kind("flag")
	flag.setup_native(MODEL_SCALE)
	flag.pin_trail_root = true
	var skeletons := $Model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0]
		_root_bone = _skeleton.find_bone("root")
		_skeleton.skeleton_updated.connect(_sync_flag_attachment)
	_sync_flag_attachment()

func set_preview_team(team: int) -> void:
	_aura.material_override.set_shader_parameter("edge_tint", Color(0.25, 0.65, 1.0) if team == 0 else Color(1.0, 0.28, 0.25))

func _sync_flag_attachment() -> void:
	if is_instance_valid(_skeleton) and _root_bone >= 0 and is_instance_valid(flag):
		flag.global_transform = _skeleton.global_transform * _skeleton.get_bone_global_pose(_root_bone)

func begin_visual_death(_duration: float) -> void:
	_dying = true
	_death_flag_visible = _grounded and not (is_instance_valid(_source) and _source.cancelled_deployment)
	_clear_deploy()
	_aura.hide()
	flag.visible = _death_flag_visible

func finish_visual_death() -> void:
	_death_finished = true
	flag.hide()
	_aura.hide()

func _process(delta: float) -> void:
	_aura.visible = _preview_deployed
	flag.visible = _grounded and not _death_finished
	_sync_flag_attachment()
	if _dying:
		flag.visible = _death_flag_visible and not _death_finished
		_aura.hide()
		age += delta
		flag.seek(1.0 + fmod(age, 8.0))
		return
	if is_instance_valid(_source):
		_aura.visible = _source.hp > 0.0 and _source._deploy_timer <= 0.0 and not CombatInteraction.in_stasis(_source) and not _source.cancelled_deployment
		if _source.hp <= 0.0 or _source.cancelled_deployment: _clear_deploy()
		flag.visible = _source.hp > 0.0 and _grounded
		if not flag.visible: return
		if _source.is_frozen() or CombatInteraction.in_stasis(_source): delta = 0.0
		if _deploy_finished: _seek_landing(_landing_age + delta)
	age += delta
	flag.seek(1.0 + fmod(age, 8.0))

func seek_preview_visual(elapsed: float) -> void:
	age = elapsed
	_process(0.0)
