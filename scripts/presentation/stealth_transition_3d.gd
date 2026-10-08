class_name StealthTransition3D
extends Node3D
## 只消费隐身切换表现事件；收束／迸散不参与感知、伤害或计时。
const SMOKE_SHADER := "res://assets/effects/stealth/smoke.gdshader"
const STREAK_SHADER := "res://assets/effects/stealth/streak.gdshader"
const WAVE_SHADER := "res://assets/effects/stealth/wave.gdshader"
static var _visual_prepared := false

const PUFF_COUNT := 12
const STREAK_COUNT := 9
var elapsed := 0.0
var entering := true
var puffs: Array[MeshInstance3D] = []
var streaks: Array[MeshInstance3D] = []
var material: ShaderMaterial
var streak_material: ShaderMaterial
var wave: MeshInstance3D
var wave_material: ShaderMaterial

func setup(is_entering: bool) -> void:
	entering = is_entering
	material = _shader_material(load(SMOKE_SHADER))
	material.set_shader_parameter("tint", Vector3(0.20, 0.72, 0.40) if entering else Vector3(0.56, 0.82, 0.16))
	streak_material = _shader_material(load(STREAK_SHADER))
	streak_material.set_shader_parameter("inward", entering)
	wave_material = _shader_material(load(WAVE_SHADER))
	for i in PUFF_COUNT:
		puffs.append(_quad(Vector2.ONE, material))
	for i in STREAK_COUNT:
		var streak := _quad(Vector2(0.11, 0.55), streak_material)
		# Quad 的纵轴对齐径向，纹理 y 从近端指向远端。
		var angle := TAU * float(i) / STREAK_COUNT
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		streak.basis = Basis(Vector3(-sin(angle), 0.0, cos(angle)), -radial, Vector3.UP)
		streaks.append(streak)
	wave = _quad(Vector2.ONE * 2.0, wave_material)
	wave.rotation.x = -PI * 0.5
	wave.position.y = 0.08
	_update_puffs(0.0)

func _shader_material(shader: Shader) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = shader
	return result

## 不显示的独立视口只编译共享着色器，样本不进入战场或派发事件。
static func prepare_visual(parent: Node) -> void:
	if _visual_prepared or DisplayServer.get_name() == "headless" or not parent.is_inside_tree(): return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(32, 32)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	viewport.add_child(camera)
	camera.position = Vector3(3.0, 2.6, 5.5)
	camera.look_at(Vector3.UP * 0.6)
	camera.current = true
	var sample := StealthTransition3D.new()
	sample.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.add_child(sample)
	sample.setup(false)
	sample._update_puffs(0.3)
	# 同步创建后立即绘制，先提交变换；等待常规帧更新会让预热相机仍看向空处。
	camera.force_update_transform()
	for mesh in sample.find_children("*", "MeshInstance3D", true, false): mesh.force_update_transform()
	RenderingServer.force_draw(false)
	viewport.free()
	_visual_prepared = true

func _quad(size: Vector2, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mesh.mesh = quad
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh

func _process(delta: float) -> void:
	elapsed += delta
	var t := elapsed / (0.65 if entering else 0.45)
	if t >= 1.0:
		queue_free()
		return
	_update_puffs(t)

func _update_puffs(t: float) -> void:
	# 入隐加速吸向躯干；破隐快速向外喷发并减速消散。
	var travel := t * t if entering else 1.0 - pow(1.0 - t, 2.0)
	var fade := smoothstep(0.0, 0.10, t) * (1.0 - smoothstep(0.58, 1.0, t))
	material.set_shader_parameter("fade", fade)
	material.set_shader_parameter("progress", t)
	streak_material.set_shader_parameter("fade", fade)
	wave_material.set_shader_parameter("fade", fade)
	for i in puffs.size():
		var angle := TAU * float(i) / puffs.size() + (0.20 * travel if entering else 0.06 * travel)
		var spread := 1.0 + 0.14 * sin(float(i) * 2.4)
		var radius := lerpf(1.05 * spread, 0.10, travel) if entering else lerpf(0.16, 1.20 * spread, travel)
		var height := lerpf(0.25 + (i % 4) * 0.27, 0.65, travel) if entering else 0.35 + (i % 4) * 0.22 + travel * 0.25
		puffs[i].position = Vector3(cos(angle) * radius, height, sin(angle) * radius)
		puffs[i].scale = Vector3.ONE * (lerpf(0.65, 0.30, travel) if entering else lerpf(0.40, 0.75, travel))
	for i in streaks.size():
		var angle := TAU * float(i) / streaks.size()
		var radius := lerpf(1.05, 0.12, travel) if entering else lerpf(0.25, 1.25, travel)
		streaks[i].position = Vector3(cos(angle) * radius, 0.3 + (i % 3) * 0.25, sin(angle) * radius)
		streaks[i].scale = Vector3(1.0, lerpf(1.2, 0.25, travel) if entering else lerpf(0.45, 1.25, travel), 1.0)
	var wave_radius := lerpf(1.35, 0.12, travel) if entering else lerpf(0.22, 1.45, travel)
	wave.scale = Vector3.ONE * wave_radius

static func resource_manifest(variant: String) -> Dictionary:
	if variant != "default": return {}
	return {"paths": [SMOKE_SHADER, STREAK_SHADER, WAVE_SHADER]}
