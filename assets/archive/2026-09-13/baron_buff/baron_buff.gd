extends ActiveBuffVisual3D
## SRX_Buf_Baron/Child 的 Godot 适配：原贴图、旋转/寿命/三路拖尾参数。
## CameraTrail 用相机朝向条带近似；LoL 复杂概率加速度改为有界螺旋。

const DECAL := preload("res://assets/effects/baron_buff/decal.gdshader")
const RUNE := preload("res://assets/effects/baron_buff/jungle_buff_baron.png")
const RING := preload("res://assets/effects/baron_buff/ring_soft_02.png")
const MASK := preload("res://assets/effects/baron_buff/base_shield_mult.png")
const TRAIL := preload("res://assets/effects/baron_buff/srx_infernal_smoke_trail.png")
const AVATAR := preload("res://assets/effects/baron_buff/sru_junglebuff_baron_meleemin_avataroverlay.png")
const TRAIL_LIFETIME := 0.8
const TRAIL_RATE := 50.0
var elapsed := 0.0
var _fade := 0.0
var _radius := 0.6
var _rune: MeshInstance3D
var _proc: MeshInstance3D
var _ring: MeshInstance3D
var _rune_material: ShaderMaterial
var _proc_material: ShaderMaterial
var _ring_material: ShaderMaterial
var _trail_shadow_material: ShaderMaterial
var _trail_material: ShaderMaterial
var _trail_mesh: ImmediateMesh

func configure(visual_radius: float, _team: int = 0) -> void:
	_radius = maxf(visual_radius / 40.0, 0.38) * 1.4
	overlay_material = ShaderMaterial.new()
	overlay_material.shader = preload("res://assets/effects/baron_buff/overlay.gdshader")
	overlay_material.set_shader_parameter("overlay_texture", AVATAR)
	_rune = _quad("Decal_Persist", RUNE, 2.5 * _radius, 0.04)
	_rune_material = _rune.material_override
	_rune_material.set_shader_parameter("use_mask", true)
	_proc = _quad("Decal_Proc", RUNE, 2.5 * _radius, 0.05)
	_proc_material = _proc.material_override
	_proc_material.set_shader_parameter("tint", Color(1.0, 0.80784, 1.0))
	_ring = _quad("card-ground", RING, 3.0 * _radius, 0.03)
	_ring_material = _ring.material_override
	_ring_material.set_shader_parameter("tint", Color(0.41569, 0.03137, 0.51373, 0.5))
	_trail_material = ShaderMaterial.new()
	_trail_material.shader = preload("res://assets/effects/baron_buff/trail.gdshader")
	_trail_material.set_shader_parameter("trail_texture", TRAIL)
	_trail_mesh = ImmediateMesh.new()
	var trails := MeshInstance3D.new()
	trails.name = "Wispies_Parent"
	trails.mesh = _trail_mesh
	trails.material_override = _trail_material
	trails.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trails.add_to_group("presentation_fx")
	add_child(trails)
	var shadow := MeshInstance3D.new()
	shadow.name = "Wispies_Blend"
	shadow.mesh = _trail_mesh
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.add_to_group("presentation_fx")
	_trail_shadow_material = ShaderMaterial.new()
	_trail_shadow_material.shader = preload("res://assets/effects/baron_buff/trail_shadow.gdshader")
	_trail_shadow_material.set_shader_parameter("trail_texture", TRAIL)
	_trail_shadow_material.render_priority = -1
	shadow.material_override = _trail_shadow_material
	add_child(shadow)
	visible = false

func _quad(label: String, texture: Texture2D, diameter: float, height: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * diameter
	node.mesh = plane
	node.position.y = height
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_to_group("presentation_fx")
	var material := ShaderMaterial.new()
	material.shader = DECAL
	material.set_shader_parameter("source_texture", texture)
	material.set_shader_parameter("mask_texture", MASK)
	node.material_override = material
	add_child(node)
	return node

func advance(enabled: bool, delta: float) -> void:
	if enabled and not active:
		elapsed = 0.0
	active = enabled
	_fade = move_toward(_fade, 1.0 if active else 0.0, delta * 5.0)
	visible = active or _fade > 0.001
	if not visible:
		return
	elapsed += delta
	# 抵消单位朝向，符文和拖尾不会在角色转身时一起甩动。
	global_rotation = Vector3.ZERO
	_rune.rotation.y = deg_to_rad(-40.0) * elapsed
	_rune_material.set_shader_parameter("opacity", _fade * clampf((elapsed - 0.5) * 5.0, 0.0, 1.0))
	_rune_material.set_shader_parameter("phase", deg_to_rad(-45.0) * elapsed)
	var proc_t := clampf(elapsed / 0.5, 0.0, 1.0)
	_proc.visible = proc_t < 1.0
	_proc.rotation.y = deg_to_rad(45.0 - 300.0 * elapsed)
	var proc_scale := lerpf(1.6, 2.25, proc_t / 0.2) if proc_t < 0.2 else lerpf(2.25, 1.0, (proc_t - 0.2) / 0.8)
	_proc.scale = Vector3.ONE * proc_scale
	_proc_material.set_shader_parameter("opacity", sin(proc_t * PI) * _fade)
	var ring_t := fmod(elapsed * 0.7, 1.0)
	_ring.scale = Vector3.ONE * lerpf(1.0, 0.5, ring_t)
	_ring_material.set_shader_parameter("opacity", sin(ring_t * PI) * _fade)
	for material in overlay_instances:
		material.set_shader_parameter("elapsed", elapsed)
		material.set_shader_parameter("strength", _fade)
	_trail_shadow_material.set_shader_parameter("elapsed", elapsed)
	_trail_material.set_shader_parameter("elapsed", elapsed)
	_draw_trails()

func _draw_trails() -> void:
	_trail_mesh.clear_surfaces()
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var view := camera.global_basis.z.normalized()
	var count := int(TRAIL_LIFETIME * TRAIL_RATE)
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for lane in range(3):
		for i in range(count):
			var t0 := float(i) / count
			var t1 := float(i + 1) / count
			var a := _trail_point(lane, t0)
			var b := _trail_point(lane, t1)
			var side := (b - a).cross(view).normalized()
			var w0 := 0.32 * _radius * sin(t0 * PI)
			var w1 := 0.32 * _radius * sin(t1 * PI)
			_vertex(a - side * w0, Vector2(t0 * 2.0, 0), t0)
			_vertex(a + side * w0, Vector2(t0 * 2.0, 1), t0)
			_vertex(b + side * w1, Vector2(t1 * 2.0, 1), t1)
			_vertex(a - side * w0, Vector2(t0 * 2.0, 0), t0)
			_vertex(b + side * w1, Vector2(t1 * 2.0, 1), t1)
			_vertex(b - side * w1, Vector2(t1 * 2.0, 0), t1)
	_trail_mesh.surface_end()

func _trail_point(lane: int, age: float) -> Vector3:
	var theta := lane * TAU / 3.0 - elapsed * deg_to_rad(40.0) + age * TRAIL_LIFETIME * 2.0
	var radius := _radius * (0.88 + age * 0.30)
	return Vector3(cos(theta) * radius, 0.08 + age * age * _radius * 1.5, sin(theta) * radius)

func _vertex(point: Vector3, uv: Vector2, age: float) -> void:
	var life_alpha := sin(age * PI) * _fade * minf(elapsed / TRAIL_LIFETIME, 1.0)
	_trail_mesh.surface_set_color(Color(0.83, 0.13, 1.0, life_alpha))
	_trail_mesh.surface_set_uv(uv)
	_trail_mesh.surface_add_vertex(point)
