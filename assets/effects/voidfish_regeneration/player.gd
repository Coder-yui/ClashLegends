extends ActiveBuffVisual3D
## 再生窗口只读表现：开启紫色上升光流，持续复用男爵之力模型覆层。
const ROOT := "res://assets/effects/voidfish_regeneration/"
const OVERLAY = preload("res://assets/effects/baron_minion/overlay.gdshader")
const RISE = preload("res://assets/effects/voidfish_regeneration/rise.gdshader")
var _age := 0.0
var _wisps: Array[MeshInstance3D] = []
var _model: Node3D
var _skeleton: Skeleton3D
var _body_bone := -1
var _pools: Array = []
var _data := {"duration": 3.0, "emitters": [], "frames": [], "fps": 120.0}

func configure(_visual_radius: float, _team: int = 0) -> void:
	overlay_material = ShaderMaterial.new()
	overlay_material.shader = OVERLAY
	for index in 9:
		var item := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.24, 0.75)
		item.mesh = mesh
		var material := ShaderMaterial.new()
		material.shader = RISE
		item.material_override = material
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(item)
		_wisps.append(item)
	_pools = [_wisps]
	visible = false

func bind_model(model: Node3D) -> void:
	_model = model
	for node: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		var index := node.find_bone("Root")
		if index >= 0:
			_skeleton = node
			_body_bone = index
			break

func advance_status(status_active: bool, shown: bool, _delta: float) -> void:
	active = status_active
	visible = shown
	_age = maxf(0.0, status_state.y - status_state.x) if status_active else 0.0
	if is_instance_valid(_model):
		# 包装根含飞行高度；Model中的原生中心(0,50,0)换算为世界挂点。
		var native := _model.get_node_or_null("Model") as Node3D
		global_position = native.to_global(Vector3(0, 50, 0)) if native != null else _model.global_position
	if is_instance_valid(_skeleton) and _body_bone >= 0:
		global_position = (_skeleton.global_transform * _skeleton.get_bone_global_pose(_body_bone)).origin
	_update_effects(shown)

func _update_effects(shown: bool) -> void:
	for material in overlay_instances:
		material.set_shader_parameter("elapsed", _age)
		material.set_shader_parameter("strength", 1.0 if shown else 0.0)
	for index in _wisps.size():
		var wisp := _wisps[index]
		var pair := (index - 1) / 2 if index > 0 else 0
		var elapsed := _age - float(pair % 3) * 0.075
		var progress := elapsed / 0.65
		wisp.visible = shown and progress >= 0.0 and progress < 1.0
		if not wisp.visible: continue
		var side := 0.0 if index == 0 else (1.0 if index % 2 == 1 else -1.0)
		var angle := PI * float(pair) / float((_wisps.size() - 1) / 2)
		wisp.position = Vector3(side * cos(angle) * 0.38, -0.6 + 1.65 * progress, side * sin(angle) * 0.38)
		var material := wisp.material_override as ShaderMaterial
		material.set_shader_parameter("opacity", sin(PI * progress) * 0.9)
		material.set_shader_parameter("phase", progress + float(pair) * 0.7)
		material.set_shader_parameter("mirror_sign", side)

# 通用资源预热：实际绘制上升光流和一个带同材质的曲面。
func load_kind(_kind: String) -> void: pass
func setup_native(_unit_scale: float) -> void:
	configure(12.0)
	var sample := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 40.0
	sphere.height = 80.0
	sample.mesh = sphere
	sample.scale = Vector3.ONE * 0.014
	sample.material_overlay = make_overlay(null)
	add_child(sample)
	_pools.append([sample])
func seek(age: float) -> void:
	_age = maxf(age, 0.0)
	visible = true
	_update_effects(true)
static func resource_manifest(variant: String) -> Dictionary:
	if variant != "regeneration": return {}
	return {"paths": ["res://assets/effects/baron_minion/overlay.gdshader", ROOT + "rise.gdshader"], "sample": {"player": ROOT + "player.gd", "kind": "regeneration", "setup": "native"}}

func prepare_resource_sample(_skills: Array, draw: Callable) -> void:
	for age in [0.15, 0.4, 1.5]:
		seek(age)
		draw.call()
