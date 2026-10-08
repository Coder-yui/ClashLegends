extends Node3D
## 只读区域表现，复用原生粒子采样器与莫甘娜W的11层源定义。
const PLAYER = preload("res://assets/units/pantheon/arrival/particle_player.gd")
# 原版边环网格半径499.37537 × 出生缩放0.57 = 284.64396。
# 用边环而非底光四边形350校准，让特效本体填满判定圈。
const SOURCE_EDGE_RADIUS := 284.64396
const DATA := "res://assets/effects/corrosion/systems.json"
static var _definitions: Array = []
var _prepared := false
var _warm_samples: Array[Node3D] = []
var _views: Dictionary = {}
var _serial := 0

static func dependency_paths() -> Array[String]:
	if _definitions.is_empty(): _definitions = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var paths: Array[String] = []
	for definition in _definitions:
		for key in ["texture", "mult", "erosion", "distortion_texture"]:
			var path := String(definition.get(key, ""))
			if not path.is_empty() and path not in paths: paths.append(path)
	return paths

func sync_effects(spells: RefCounted, camera: Camera3D) -> void:
	_sync_effects(spells.corrosion_effects, camera)

func _sync_effects(effects: Array, camera: Camera3D) -> void:
	if effects.is_empty() and _views.is_empty(): return
	if _definitions.is_empty(): dependency_paths()
	var present := {}
	for effect in effects:
		if not effect.has("view_id"):
			_serial += 1
			effect.view_id = _serial
		var id := int(effect.view_id)
		present[id] = true
		var elapsed := float(effect.duration) - float(effect.timer)
		if not _views.has(id):
			var player := PLAYER.new()
			add_child(player)
			player.position = _ground(camera, effect.pos)
			var world_radius := _ground(camera, effect.pos + Vector2(float(effect.radius), 0)).distance_to(player.position)
			player.setup("corrosion", world_radius / SOURCE_EDGE_RADIUS, false, "", false, false, _definitions)
			var ring := MeshInstance3D.new()
			var material := ShaderMaterial.new()
			material.shader = preload("res://assets/effects/corrosion/range.gdshader")
			material.set_shader_parameter("rim_color", Color(0.15, 0.55, 1.0) if int(effect.team) == 0 else Color(1.0, 0.25, 0.20))
			ring.material_override = material
			add_child(ring)
			_update_mesh(ring, Rect2(effect.pos - Vector2.ONE * float(effect.radius), Vector2.ONE * float(effect.radius) * 2.0), camera)
			var vertical := _ground(camera, effect.pos + Vector2(0, float(effect.radius))) - player.position
			var horizontal := _ground(camera, effect.pos + Vector2(float(effect.radius), 0)) - player.position
			var warp := Basis(horizontal / world_radius, Vector3.UP, vertical / world_radius)
			_views[id] = {"player": player, "ring": ring, "warp": warp, "age": 0.0}
		var view: Dictionary = _views[id]
		# 原版5秒曲线映射到卡牌持续时间；表现时钟暂停时不推进。
		var age := elapsed * 5.0 / float(effect.duration)
		view.player.advance(maxf(0.0, age - float(view.age)))
		view.age = age
		for particle in view.player._particles:
			var node: MeshInstance3D = particle.node
			node.global_position = view.player.position + view.warp * (node.global_position - view.player.position)
			node.global_basis = view.warp * node.global_basis
			# Compress the source linger erosion into the final 0.4 seconds of
			# the authoritative zone; no damaging-looking residue after expiry.
			var fade := smoothstep(4.6, 5.0, age)
			node.material_override.set_shader_parameter("opacity", 1.0 - fade)
			if not String(particle.c.erosion).is_empty() and age >= 4.6:
				node.material_override.set_shader_parameter("erosion", PLAYER.sample(particle.c.linger_erosion, (age - 4.6) / 0.4))
	for id in _views.keys():
		if not present.has(id):
			_views[id].player.free()
			_views[id].ring.free()
			_views.erase(id)

func _ground(camera: Camera3D, point: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	return origin + direction * ((0.06 - origin.y) / direction.y)

func _update_mesh(view: MeshInstance3D, bounds: Rect2, camera: Camera3D) -> void:
	view.set_meta("bounds", bounds)
	var center := bounds.get_center()
	var radius := bounds.size.x * 0.5
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var vertices := PackedVector3Array()
	for corner in corners:
		var screen: Vector2 = center + corner * radius
		var origin := camera.project_ray_origin(screen)
		var direction := camera.project_ray_normal(screen)
		# 正交相机逆投影四角：画面上始终匹配110px权威圆形范围。
		vertices.append(origin + direction * ((0.04 - origin.y) / direction.y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	view.mesh = mesh

## 独立表现样本覆盖延迟出生层；只改局部字典，不创建法术或派发音频。
## 保留隐藏样本的材质/网格，避免首个正式区域才创建渲染组合。
func prepare_visual(camera: Camera3D, radius: float, stop: Callable = Callable()) -> void:
	if _prepared or (stop.is_valid() and bool(stop.call())): return
	var effect := {"pos": Vector2(360, 640), "radius": radius, "team": 0, "duration": 5.0, "timer": 5.0}
	for step in range(20):
		if stop.is_valid() and bool(stop.call()): break
		effect.timer = 5.0 - float(step) * 0.25
		_sync_effects([effect], camera)
		if DisplayServer.get_name() != "headless": RenderingServer.force_draw(false)
		await get_tree().process_frame
	var view: Dictionary = _views[int(effect.view_id)]
	# 粒子为 top_level，但可见性仍继承父级。
	view.player.hide()
	view.ring.hide()
	_warm_samples.assign([view.player, view.ring])
	_views.erase(int(effect.view_id))
	_prepared = not stop.is_valid() or not bool(stop.call())
