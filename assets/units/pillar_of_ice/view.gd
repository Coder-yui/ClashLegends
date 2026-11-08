extends Node3D
## 原版E柱体为粒子网格；只读单位状态，主体保持稳定姿态，死亡播放原生下沉段。
const PLAYER = preload("res://assets/effects/pillar_of_ice/player.gd")
const MODEL_SCALE := 0.009
const RISE_END := 0.36
const DEATH_START := 5.625
const FIELD_SOURCE_RADIUS := 450.0
const RING_SHADER = preload("res://assets/effects/freeze/range_ring.gdshader")
## 预览动画的真实采样轨道；实战由部署/死亡适配器使用同一原生时间段。
var body_source_time := RISE_END:
	set(value):
		body_source_time = value
		if is_instance_valid(_pillar) and not is_instance_valid(_source):
			_pillar.set_emitter_sample_time(&"ice_pillar", value)
var _source: Unit
var _pillar: Node3D
var _ring: MeshInstance3D
var _age := 1.0
var _dying := false
var _death_age := 0.0
var _finished := false
func _ready() -> void:
	_pillar = PLAYER.new()
	add_child(_pillar)
	_pillar.load_kind("pillar")
	_pillar.setup_native(MODEL_SCALE)
	_pillar.set_emitter_sample_time(&"ice_pillar", RISE_END)
	_pillar.seek(1.0)
	_set_ring(0)
func _set_ring(team: int) -> void:
	if is_instance_valid(_ring): _ring.free()
	_ring = MeshInstance3D.new()
	_ring.add_to_group("presentation_fx")
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	_ring.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = RING_SHADER
	material.set_shader_parameter("rim_color", Color(0.15, 0.55, 1.0) if team == 0 else Color(1.0, 0.25, 0.20))
	_ring.material_override = material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_ring.position.y = 0.025
	_set_field_radius(110.0)
func _set_field_radius(radius: float) -> void:
	_ring.scale = Vector3.ONE * radius / 40.0
	# Each field layer calibrates its own visible source radius in the player.
	# Body, splash, rays and base glow retain model scale.
	_pillar.field_scale = radius / 40.0 / FIELD_SOURCE_RADIUS / MODEL_SCALE
func _seek_effects(age: float) -> void:
	# Long-lived ground particles keep their original fade-in, then hold the stable phase.
	for emitter in [&"ice_cracks", &"base_glow", &"black_circle"]:
		_pillar.set_emitter_sample_time(emitter, minf(age, 4.0))
	# Native particle cohorts crossing the 20s period are carried into the next cycle.
	_pillar.seek(age if age < 24.0 else 27.0 + fmod(age - 24.0, 20.0))
func configure_unit_visual(source: Unit) -> void:
	reset_pool_visual()
	_source = source
	_set_ring(source.team)
func reset_pool_visual() -> void:
	_source = null
	_age = 1.0
	_dying = false
	_death_age = 0.0
	_finished = false
	if is_instance_valid(_pillar):
		_pillar.show()
		_pillar.set_emitter_sample_time(&"ice_pillar", RISE_END)
		_pillar.set_effect_fade(1.0)
func set_preview_team(team: int) -> void:
	if is_instance_valid(_ring): _set_ring(team)
func advance_deployment_visual(elapsed: float, duration: float, active: bool) -> void:
	if _dying: return
	if active and elapsed < duration:
		_age = maxf(elapsed, 0.0)
		_pillar.set_emitter_sample_time(&"ice_pillar", minf(_age, RISE_END))
		_seek_effects(_age)
		_ring.hide()
func begin_visual_death(_duration: float) -> void:
	_dying = true
	_death_age = 0.0
	_pillar.set_emitter_sample_time(&"ice_pillar", DEATH_START)
	_ring.hide()
func finish_visual_death() -> void:
	_finished = true
	_pillar.hide()
	_ring.hide()
func _process(delta: float) -> void:
	if _finished: return
	if _dying:
		_death_age += delta
		_pillar.set_emitter_sample_time(&"ice_pillar", DEATH_START + _death_age)
		_seek_effects(_age + _death_age)
		_pillar.set_effect_fade(1.0 - clampf(_death_age / 0.8, 0.0, 1.0))
		return
	_pillar.set_effect_fade(1.0)
	var radius := 110.0
	_ring.visible = String($AnimationPlayer.current_animation) not in ["Rise", "Death"]
	if is_instance_valid(_source):
		if _source.hp <= 0.0 or _source.cancelled_deployment:
			_ring.hide()
			return
		if _source._deploy_timer > 0.0:
			_ring.hide()
			return
		if _source.is_frozen() or CombatInteraction.in_stasis(_source): delta = 0.0
		_ring.visible = not CombatInteraction.in_stasis(_source)
		radius = float(_source._base_form_stats.debuff_aura_active_radius if _source.get_active_buff_active_visual() else _source._base_form_stats.debuff_aura_radius)
	_age += delta
	if is_instance_valid(_source): _pillar.set_emitter_sample_time(&"ice_pillar", RISE_END)
	_set_field_radius(radius)
	_seek_effects(_age)
func seek_preview_visual(elapsed: float) -> void:
	_age = elapsed
	var animation := String($AnimationPlayer.current_animation)
	if animation == "Rise": body_source_time = minf(elapsed, RISE_END)
	elif animation == "Death": body_source_time = DEATH_START + elapsed
	else: body_source_time = RISE_END
	_seek_effects(elapsed if animation == "Rise" else elapsed + 1.0)
	_ring.visible = animation == "Idle"
