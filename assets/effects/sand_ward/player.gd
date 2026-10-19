extends ActiveBuffVisual3D
## 只读黄沙庇护层：沙粒聚拢、淡金盾轮廓，层消失时立即收起。
const ROOT := "res://assets/effects/sand_ward/"
const SHELL = preload("res://assets/effects/sand_ward/shell.gdshader")
const SAND = preload("res://assets/effects/sand_ward/sand.gdshader")
# Complete fixed topology at first visible age. Source/render-mode audit is a build gate;
# runtime checks actual geometry/materials before drawing. No live pool is transferred.
static func warmup_coverage() -> Dictionary:
	return {"version": 1, "strategy": "static-untextured-primitives-v1",
		"samples": [{"age": 0.08, "states": ["shell", "grain"]}],
		"states": [
			{"id": "shell", "mesh": "SphereMesh", "geometry": [0.7, 2.5, 64, 32], "shader": ROOT + "shell.gdshader", "count": 1, "uniforms": ["elapsed"],
				"render_modes": ["unshaded", "blend_add", "cull_back", "depth_draw_never", "shadows_disabled"]},
			{"id": "grain", "mesh": "QuadMesh", "geometry": [0.06, 0.09], "shader": ROOT + "sand.gdshader", "count": 24, "uniforms": ["opacity"],
				"render_modes": ["unshaded", "blend_add", "cull_disabled", "depth_draw_never", "shadows_disabled"]}]}
var _shell: MeshInstance3D
var _grains: Array[MeshInstance3D] = []
var _skeleton: Skeleton3D
var _body_bone := -1
var _model: Node3D
var _pools: Array = []
var _data := {"duration": 2.0, "emitters": [], "frames": [], "fps": 120.0}

func configure(_visual_radius: float, _team: int = 0) -> void:
	_shell = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.7
	sphere.height = 2.5
	_shell.mesh = sphere
	var material := ShaderMaterial.new()
	material.shader = SHELL
	_shell.material_override = material
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shell)
	for index in 24:
		var grain := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.06, 0.09)
		grain.mesh = mesh
		var sand := ShaderMaterial.new()
		sand.shader = SAND
		grain.material_override = sand
		grain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(grain)
		_grains.append(grain)
	_pools = [[_shell], _grains]
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
	visible = shown and status_active
	if is_instance_valid(_skeleton) and _body_bone >= 0:
		global_position = (_skeleton.global_transform * _skeleton.get_bone_global_pose(_body_bone)).origin
	elif is_instance_valid(_model):
		var native := _model.get_node_or_null("Model") as Node3D
		global_position = native.to_global(Vector3(0, 120, 0)) if native != null else _model.global_position
	_update_effects(maxf(0.0, status_state.y - status_state.x))

func _update_effects(age: float) -> void:
	(_shell.material_override as ShaderMaterial).set_shader_parameter("elapsed", age)
	var gather := 1.0 - smoothstep(0.0, 0.38, age)
	_shell.scale = Vector3.ONE * (1.0 + 0.15 * gather)
	for index in _grains.size():
		var angle := float(index) * 2.39996 + age * 0.7
		var height := -0.95 + fmod(float(index) * 0.173 + age * 0.24, 1.9)
		var radius := 0.66 * sqrt(maxf(0.1, 1.0 - pow(height / 1.3, 2.0))) + gather * 0.65
		_grains[index].position = Vector3(cos(angle) * radius, height, sin(angle) * radius)
		(_grains[index].material_override as ShaderMaterial).set_shader_parameter("opacity", 0.5 + gather * 0.4)

func load_kind(_kind: String) -> void: pass
func setup_native(_unit_scale: float) -> void:
	configure(18.0)
func seek(age: float) -> void:
	visible = age >= 0.0 and age < 2.0
	_update_effects(maxf(age, 0.0))
static func resource_manifest(variant: String) -> Dictionary:
	if variant != "ward": return {}
	return {"paths": [ROOT + "shell.gdshader", ROOT + "sand.gdshader"], "sample": {"player": ROOT + "player.gd", "kind": "ward", "setup": "native", "coverage": warmup_coverage()}}
func prepare_resource_sample(_skills: Array, draw: Callable) -> PackedStringArray:
	return preload("res://scripts/presentation/effect_warmup_coverage.gd").prepare_attached(self, warmup_coverage(), draw)
