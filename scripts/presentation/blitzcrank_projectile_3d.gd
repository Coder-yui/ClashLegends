extends Node3D
## 原版Q_cas / Q_mis / Q_mis_return分层；只读取权威弹体，不能影响命中。
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const DEFAULT_SCALE := 0.0085 * 1.25
const CABLE_ROOT := "res://assets/effects/blitzcrank/qmis/assets/characters/blitzcrank/skins/base/particles/"
var _views: Dictionary = {}
var _cable_data: Dictionary = {}
var _system: Node2D
var _camera: Camera3D

func _ready() -> void:
	process_priority = 12 # 在模型发布当前帧手部位置和缩放之后读取。

func sync_effects(system: Node2D, camera: Camera3D) -> void:
	_system = system
	_camera = camera

func _effect(kind: String, unit_scale: float) -> Node3D:
	var effect: Node3D = load("res://assets/effects/blitzcrank/player.gd").new()
	add_child(effect)
	effect.load_kind(kind)
	effect.setup_native(unit_scale)
	return effect

func _create_view(p: Dictionary) -> Dictionary:
	var source: Node2D = _system._visual_body(p.visual_path.source)
	var unit_scale := float(source.get_meta("blitzcrank_vfx_scale", DEFAULT_SCALE)) if is_instance_valid(source) else DEFAULT_SCALE
	var start: Vector3 = source.get_meta("blitzcrank_hand_world", PROJECTION.ground(_camera, p.visual_path.start) + Vector3.UP * 60.0 * unit_scale) if is_instance_valid(source) else PROJECTION.ground(_camera, p.visual_path.start) + Vector3.UP * 60.0 * unit_scale
	var forward := PROJECTION.ground(_camera, p.visual_path.end) - PROJECTION.ground(_camera, p.visual_path.start)
	var orientation := Basis.looking_at(forward.normalized(), Vector3.UP)
	var cable := MeshInstance3D.new()
	add_child(cable)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = load(CABLE_ROOT + "blitzcrank_base_z_cable.png")
	cable.material_override = material
	cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _cable_data.is_empty(): _cable_data = JSON.parse_string(FileAccess.get_file_as_string(CABLE_ROOT + "blitzcrank_base_z_fist_cable.mesh.json"))
	return {"cast": _effect("qcas", unit_scale), "out": _effect("qmis", unit_scale), "back": _effect("qreturn", unit_scale), "cable": cable,
		"start": start, "end": start, "scale": unit_scale, "basis": orientation, "age": 0.0, "phase_age": 0.0, "returning": false, "tail": 0.0}

func _process(delta: float) -> void:
	if not is_instance_valid(_system) or not is_instance_valid(_camera): return
	var seen := {}
	var visible_projectiles: Dictionary = _system.visible_view()
	for id in visible_projectiles:
		var p: Dictionary = visible_projectiles[id]
		if StringName(p.get("visual", "")) != &"blitzcrank_hook": continue
		seen[id] = true
		if not _views.has(id): _views[id] = _create_view(p)
		var view: Dictionary = _views[id]
		if bool(p.visual_path.wave) and not bool(view.returning):
			view.returning = true
			view.phase_age = 0.0
		# 权威坐标是地面中心；仅给拳头匹配原手部高度，不叠加原始粒子的60单位偏移。
		var end := PROJECTION.ground(_camera, p.pos)
		end.y = (view.start as Vector3).y
		if not bool(view.returning):
			var progress := float(p.visual_path.progress)
			var ground_start := PROJECTION.ground(_camera, p.visual_path.start)
			end += ((view.start as Vector3)-Vector3(ground_start.x,end.y,ground_start.z)) * (1.0-progress)
		view.end = end
	for id in _views.keys():
		var view: Dictionary = _views[id]
		view.age += delta
		view.phase_age += delta
		if not seen.has(id):
			view.tail += delta
			view.end = (view.end as Vector3).lerp(view.start, minf(delta / maxf(0.12-float(view.tail)+delta, delta), 1.0))
		_sample(view)
		if float(view.tail) >= 0.16:
			for key in ["cast", "out", "back", "cable"]: view[key].free()
			_views.erase(id)

func _sample(view: Dictionary) -> void:
	var start: Vector3 = view.start
	var end: Vector3 = view.end
	var orientation: Basis = view.basis
	var unit_scale := float(view.scale)
	view.cast.seek_motion(view.age, start, orientation)
	view.out.visible = not bool(view.returning)
	view.back.visible = bool(view.returning)
	var fist: Node3D = view.back if bool(view.returning) else view.out
	# Q_mis原张手粒子的出生偏移为(-10,60,-60)，导入X镜像后为(10,60,-60)。
	var native_offset := Vector3.ZERO if bool(view.returning) else Vector3(10,60,-60)
	fist.seek_motion(view.phase_age, end-orientation*native_offset*unit_scale, orientation)
	_draw_cable(view.cable, start, end, unit_scale)

func _draw_cable(cable: MeshInstance3D, start: Vector3, end: Vector3, unit_scale: float) -> void:
	var length := start.distance_to(end)
	cable.visible = length > 0.01
	if not cable.visible: return
	# 原始Beam带圆柱网格：XY约0.7，乘源birthScale50；Z约20，仅沿轴伸缩。
	# 保留源UV与环形截面，不再把50误读为平面带宽。
	var axis := (end-start)/length
	var right := axis.cross(Vector3.UP).normalized()
	if right.is_zero_approx(): right = Vector3.RIGHT
	var up := right.cross(axis).normalized()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in _cable_data.vertices.size()/3:
		var x := -float(_cable_data.vertices[i*3]) * 50.0 * unit_scale
		var y := float(_cable_data.vertices[i*3+1]) * 50.0 * unit_scale
		var z := (float(_cable_data.vertices[i*3+2])+10.031800270080566)/20.06369972229004
		mesh.surface_set_uv(Vector2(_cable_data.uv[i*2],_cable_data.uv[i*2+1]))
		mesh.surface_add_vertex(start+right*x+up*y+axis*z*length)
	mesh.surface_end()
	cable.mesh = mesh
