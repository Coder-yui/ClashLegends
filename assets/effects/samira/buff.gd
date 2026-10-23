extends ActiveBuffVisual3D
## 只读同步动作时钟；取消、死亡和暂停沿同一表现状态处理。
const PLAYER = preload("res://assets/effects/samira/player.gd")
var _unit: WeakRef
var _particles: Node3D
var _ready_particles: Node3D
var _ready_age := 0.0
var _ready_surfaces: Array[Dictionary] = []
func configure(_radius: float, _team: int = 0) -> void:
	status_source = "full_resource_or_action"
	_particles = PLAYER.new()
	add_child(_particles)
	_particles.load_kind("cas")
	_particles.setup_native(PLAYER.NATIVE_SCALE)
	_ready_particles = PLAYER.new()
	add_child(_ready_particles)
	_ready_particles.load_kind("ready")
	_ready_particles.setup_native(0.0102)
func bind_model(model: Node3D) -> void:
	_unit = model.unit_ref
	for source in model.find_children("*", "MeshInstance3D", true, false):
		for index in source.mesh.get_surface_count():
			var material: Material = source.mesh.surface_get_material(index)
			var surface_name: String = material.resource_name if material != null else ""
			var overlay: Material = _ready_particles.make_overlay(null, surface_name)
			if overlay == null: continue
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(source.mesh.surface_get_primitive_type(index), source.mesh.surface_get_arrays(index))
			var effect := MeshInstance3D.new()
			effect.mesh = mesh
			effect.skin = source.skin
			effect.material_override = overlay
			effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(effect)
			effect.skeleton = effect.get_path_to(source.get_node(source.skeleton))
			_ready_surfaces.append({"source": weakref(source), "effect": effect})
func advance_status(_status_active: bool, shown: bool, _delta: float) -> void:
	var unit = _unit.get_ref() if _unit != null else null
	var alive: bool = shown and is_instance_valid(unit) and unit.hp > 0.0
	var casting: bool = alive and unit.get_visual_action_name() == &"inferno" and unit.get_visual_action_time_left() > 0.0 and unit.get_visual_action_serial() > unit.cancelled_visual_serial
	var full: bool = alive and unit.is_skill_resource_visible() and unit.get_skill_resource_ratio() >= 1.0
	visible = casting or full
	_particles.visible = casting
	if casting: _particles.seek(unit.get_visual_action_duration() - unit.get_visual_action_time_left())
	_particles.update_attached(casting)
	_ready_age = _ready_age + _delta if full else 0.0
	_ready_particles.visible = full
	if full: _ready_particles.seek(_ready_age if _ready_age < 8.0 else 4.0 + fmod(_ready_age - 4.0, 4.0))
	_ready_particles.update_attached(full)
	for entry in _ready_surfaces:
		var source = entry.source.get_ref()
		entry.effect.visible = full and is_instance_valid(source)
		if is_instance_valid(source): entry.effect.global_transform = source.global_transform

func make_overlay(original: Material) -> Material:
	return _particles.make_overlay(original)
