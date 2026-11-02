extends Node3D
## 自制黄色彗星：渐变亮芯与沿历史位置收窄的拖尾。权威路径/命中仍由ProjectileSystem驱动，只读取飞行进度。
const COMET_SHADER = preload("res://assets/effects/evolution_turret/comet/comet.gdshader")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const ANCHOR = preload("res://scripts/presentation/projectile_model_anchor.gd")
const BULLET_SCALE := 0.022
var _projectiles: Node2D
var _camera: Camera3D
var _missiles: Dictionary = {}

func _ready() -> void:
	process_priority = 10

func set_sources(projectiles: Node2D, camera: Camera3D) -> void:
	_projectiles = projectiles
	_camera = camera

func _process(_delta: float) -> void:
	if is_instance_valid(_camera): sync_effects(_projectiles, _camera)

func _create_comet() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var head := MeshInstance3D.new()
	head.name = "Head"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 22.0 * BULLET_SCALE
	head.mesh = quad
	var glow := ShaderMaterial.new()
	glow.shader = COMET_SHADER
	glow.set_shader_parameter("head", true)
	head.material_override = glow
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(head)
	var tail := MeshInstance3D.new()
	tail.name = "Tail"
	tail.mesh = ImmediateMesh.new()
	var material := ShaderMaterial.new()
	material.shader = COMET_SHADER
	tail.material_override = material
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tail)
	return root

func _draw_comet(view: Dictionary, position: Vector3, camera: Camera3D) -> void:
	var head: MeshInstance3D = view.player.get_node("Head")
	head.position = position
	head.basis = camera.global_basis
	var points: Array = view.points
	if points.is_empty() or (points[-1] as Vector3).distance_to(position) > 0.015:
		points.append(position)
	# 留下真实经过的位置，尾巴不随弹头转向整体摆动，也不会伸到炮口后方。
	var length := 0.0
	for i in range(points.size()-1, 0, -1):
		var segment: float = (points[i] as Vector3).distance_to(points[i-1])
		if length + segment > 85.0 * BULLET_SCALE:
			points[i-1] = (points[i] as Vector3).lerp(points[i-1], (85.0 * BULLET_SCALE-length)/maxf(segment,0.0001))
			for unused in i-1: points.pop_front()
			break
		length += segment
	while points.size() > 32: points.pop_front()
	var mesh: ImmediateMesh = view.player.get_node("Tail").mesh
	mesh.clear_surfaces()
	if points.size() < 2: return
	var distances := [0.0]
	for i in range(1, points.size()): distances.append(distances[-1] + (points[i] as Vector3).distance_to(points[i-1]))
	var total: float = maxf(distances[-1], 0.001)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()-1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i+1]
		var side := (b-a).cross(camera.global_position-(a+b)*0.5).normalized()
		var u: float = distances[i]/total
		var v: float = distances[i+1]/total
		var wa := 7.0 * BULLET_SCALE * pow(u,0.65)
		var wb := 7.0 * BULLET_SCALE * pow(v,0.65)
		var vertices := [a-side*wa,a+side*wa,b+side*wb,a-side*wa,b+side*wb,b-side*wb]
		var uv := [Vector2(0,u),Vector2(1,u),Vector2(1,v),Vector2(0,u),Vector2(1,v),Vector2(0,v)]
		for j in 6:
			mesh.surface_set_uv(uv[j])
			mesh.surface_add_vertex(vertices[j])
	mesh.surface_end()

func sync_effects(projectiles: Node2D, camera: Camera3D) -> void:
	var present := {}
	if projectiles != null:
		for id in projectiles.visible_view():
			var projectile: Dictionary = projectiles.visible_view()[id]
			if StringName(projectile.get("visual", "")) != &"evolution_turret_bullet": continue
			present[id] = true
			var path: Dictionary = projectile.get("visual_path", {})
			if not _missiles.has(id):
				var player := _create_comet()
				var origin: Vector3 = projectiles.visual_model_anchor_position(path.get("source", {}))
				if not origin.is_finite():
					origin = PROJECTION.ground(camera, path.get("start", projectile.pos)) + Vector3.UP * 45.0 * BULLET_SCALE
				_missiles[id] = {"player": player, "origin": origin, "points": [origin]}
			var view: Dictionary = _missiles[id]
			var target_body: Node2D = projectiles._visual_body(path.get("target", {}))
			var target_point: Variant = ANCHOR.body_position(target_body) if is_instance_valid(target_body) else null
			var target: Vector3 = target_point if target_point is Vector3 else PROJECTION.ground(camera, path.get("end", projectile.pos)) + Vector3.UP * 45.0 * BULLET_SCALE
			var progress := clampf(float(path.get("progress", 0.0)), 0.0, 1.0)
			_draw_comet(view, (view.origin as Vector3).lerp(target, progress), camera)
	for id in _missiles.keys():
		if not present.has(id):
			_missiles[id].player.free()
			_missiles.erase(id)
