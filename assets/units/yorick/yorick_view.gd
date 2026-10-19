extends "res://scripts/presentation/model_template_view.gd"
## 两层原版 AttachedMesh 共用导入披风蒙皮；材质与历史路径修饰均只影响表现。
const CAPE_SHADER = preload("res://assets/units/yorick/cape.gdshader")
const FLOW = preload("res://assets/units/yorick/cape_flow.png")
const TINT = preload("res://assets/units/yorick/cape_color.png")
var _cape_materials: Array[ShaderMaterial] = []
var _age := 0.0
# 独立表现随机源，不消耗权威/战斗全局随机序列。
var _cape_rng := RandomNumberGenerator.new()
var _cape_path: SkeletonModifier3D
var _weapon_blend: SkeletonModifier3D

func _initialize_template_geometry() -> bool:
	if not _prepare_cape_geometry(): return false
	var skeleton := find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_cape_path = preload("res://assets/units/yorick/cape_path.gd").new()
	_cape_path.player = find_children("*", "AnimationPlayer", true, false)[0]
	skeleton.add_child(_cape_path)
	_weapon_blend = preload("res://assets/units/yorick/deploy_weapon_blend.gd").new()
	_weapon_blend.player = _cape_path.player
	skeleton.add_child(_weapon_blend)
	return true

func reset_pool_visual() -> void:
	_age = 0.0
	_initialize_template()
	if not _template_initialized: return
	_cape_path.reset_pool_visual()
	_weapon_blend.reset_pool_visual()
	_reset_cape_materials()

func set_visual_blend(clip: StringName, duration: float) -> void:
	_initialize_template()
	if not _template_initialized: return
	_cape_path.begin_blend(clip, duration)
	_weapon_blend.begin_blend(clip, duration)

func _prepare_cape_geometry() -> bool:
	var body := find_child("Meshes", true, false) as MeshInstance3D
	if body == null or not visual_template.meshes.has_all(["body", "cape"]):
		preparation_errors.append("Yorick requires body/cape template meshes")
		return false
	var cape := MeshInstance3D.new()
	cape.name = "YorickCape"
	cape.mesh = visual_template.meshes.cape
	body.mesh = visual_template.meshes.body
	cape.skin = body.skin
	cape.skeleton = body.skeleton
	cape.transform = body.transform
	# Skin0 initialSubmeshShadowsToHide=Yorick_Cape；AttachedMesh未启用投影。
	cape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cape.set_meta("exclude_hit_flash", true)
	body.get_parent().add_child(cape)
	var first: ShaderMaterial
	for speed in [-0.15, -0.35]:
		var material := ShaderMaterial.new()
		material.shader = CAPE_SHADER
		material.set_shader_parameter("flow_texture", FLOW)
		material.set_shader_parameter("color_texture", TINT)
		material.set_shader_parameter("scroll_speed", speed)
		if first == null: first = material
		else: first.next_pass = material
		_cape_materials.append(material)
	cape.set_surface_override_material(0, first)
	_cape_rng.randomize()
	_reset_cape_materials()
	return true

func _reset_cape_materials() -> void:
	# birthUVOffset 的 V 概率表为 (0,0)→(1,1)，每层出生一次采样。
	for material in _cape_materials:
		material.set_shader_parameter("age", 0.0)
		material.set_shader_parameter("uv_phase", _cape_rng.randf())

func advance_ambient_visual(delta: float) -> void:
	_age += maxf(delta, 0.0)
	for material in _cape_materials: material.set_shader_parameter("age", _age)
