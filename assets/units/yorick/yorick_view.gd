extends Node3D
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
var _cape_geometry_prepared := false

func prepare_visual_animations() -> void:
	_prepare_cape_geometry()
	if is_instance_valid(_cape_path): return
	var skeleton := find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_cape_path = preload("res://assets/units/yorick/cape_path.gd").new()
	_cape_path.player = find_children("*", "AnimationPlayer", true, false)[0]
	skeleton.add_child(_cape_path)
	_weapon_blend = preload("res://assets/units/yorick/deploy_weapon_blend.gd").new()
	_weapon_blend.player = _cape_path.player
	skeleton.add_child(_weapon_blend)
	# 包装内裁剪副本；保留源GLB六秒IdleIn，部署绝不会采样1秒之后的动作。
	var player: AnimationPlayer = _cape_path.player
	var library := player.get_animation_library(&"").duplicate() as AnimationLibrary
	var deploy := library.get_animation(&"IdleIn").duplicate() as Animation
	deploy.length = 1.0
	deploy.loop_mode = Animation.LOOP_NONE
	library.remove_animation(&"IdleIn")
	library.add_animation(&"IdleIn", deploy)
	player.remove_animation_library(&"")
	player.add_animation_library(&"", library)

func reset_pool_visual() -> void:
	_age = 0.0
	prepare_visual_animations()
	_cape_path.reset_pool_visual()
	_weapon_blend.reset_pool_visual()
	_reset_cape_materials()

func set_visual_blend(clip: StringName, duration: float) -> void:
	prepare_visual_animations()
	_cape_path.begin_blend(clip, duration)
	_weapon_blend.begin_blend(clip, duration)

func _ready() -> void:
	prepare_visual_animations()

func _prepare_cape_geometry() -> void:
	if _cape_geometry_prepared: return
	_cape_geometry_prepared = true
	# 原GLB的Body/Cape是同一MeshInstance的两个表面。复制表面容器、共用原Skin，
	# 不重建顶点/UV/权重、不改局部变换；让受击覆盖层可以只选择身体。
	for node in find_children("*", "MeshInstance3D", true, false):
		var body := node as MeshInstance3D
		for index in body.mesh.get_surface_count():
			var original := body.mesh.surface_get_material(index)
			if original == null or original.resource_name != "Yorick_Cape": continue
			var cape := MeshInstance3D.new()
			cape.name = "YorickCape"
			cape.mesh = body.mesh.duplicate() as ArrayMesh
			for surface in range(cape.mesh.get_surface_count() - 1, -1, -1):
				if surface != index: (cape.mesh as ArrayMesh).surface_remove(surface)
			body.mesh = body.mesh.duplicate() as ArrayMesh
			(body.mesh as ArrayMesh).surface_remove(index)
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
			break
	_cape_rng.randomize()
	_reset_cape_materials()

func _reset_cape_materials() -> void:
	# birthUVOffset 的 V 概率表为 (0,0)→(1,1)，每层出生一次采样。
	for material in _cape_materials:
		material.set_shader_parameter("age", 0.0)
		material.set_shader_parameter("uv_phase", _cape_rng.randf())

func advance_ambient_visual(delta: float) -> void:
	_age += maxf(delta, 0.0)
	for material in _cape_materials: material.set_shader_parameter("age", _age)
