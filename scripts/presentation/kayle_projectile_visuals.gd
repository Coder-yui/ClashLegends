extends Node2D
## 原生贴图分层适配；只读可见弹体，所有动画计时只影响绘制。
const ROOT := "res://assets/effects/kayle/"
const SHADER := preload("res://assets/effects/kayle/native_projectile.gdshader")
const PALETTE := preload("res://assets/effects/kayle/kayle_base_wing_fire_gradient.png")
const SWORD_PALETTE := preload("res://assets/effects/kayle/flame_trail_gradient.png")
const GLOW := preload("res://assets/effects/kayle/kayle_base_e_bigglow02.png")
const SWORD := preload("res://assets/effects/kayle/caitlyn_skin11_ba_bullet.png")
const SWORD_TRAIL := preload("res://assets/effects/kayle/kayle_base_ba_trail.png")
const EDGE := preload("res://assets/effects/kayle/kayle_base_ba_enraged_head.png")
const ARC := preload("res://assets/effects/kayle/ezreal_base_q_mis2_glow.png")
const FIRE := preload("res://assets/effects/kayle/kayle_base_q_tar_wisps_4x1.png")
const WAKE := preload("res://assets/effects/kayle/kayle_base_e_wake_texture.png")
var _system: ProjectileSystem
var _views: Dictionary = {}

static func dependency_paths() -> Array:
	return [SWORD_PALETTE.resource_path, GLOW.resource_path, SHADER.resource_path, PALETTE.resource_path, SWORD.resource_path, SWORD_TRAIL.resource_path, EDGE.resource_path, ARC.resource_path, FIRE.resource_path, WAKE.resource_path]

func setup(system: ProjectileSystem) -> void:
	_system = system
	system.visuals_cleared.connect(clear)

func _layer(parent: Node2D, texture: Texture2D, size: Vector2, layer: int, offset := Vector2.ZERO, opacity := 1.0) -> void:
	var sprite := Sprite2D.new()
	sprite.set_meta("opacity", opacity)
	sprite.texture = texture
	sprite.scale = size / Vector2(texture.get_size())
	sprite.position = offset
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("fire_palette", PALETTE)
	material.set_shader_parameter("sword_palette", SWORD_PALETTE)
	material.set_shader_parameter("layer", layer)
	sprite.material = material
	parent.add_child(sprite)

func advance(delta: float) -> void:
	var seen := {}
	var visible := _system.visible_snapshot()
	for id in visible:
		var p: Dictionary = visible[id]
		var visual := String(p.get("visual", ""))
		if visual not in ["kayle_sword", "kayle_wave"]: continue
		seen[id] = true
		if not _views.has(id):
			var root := Node2D.new()
			add_child(root)
			if visual == "kayle_sword":
				_layer(root, SWORD, Vector2(16, 65), 1, Vector2(0, 30))
				_layer(root, GLOW, Vector2(22, 54), 4, Vector2(0, 36), 0.28)
			else:
				var width := float(p.radius) * 2.0
				_layer(root, WAKE, Vector2(width, width * 0.95), 3, Vector2(0, 12), 0.65)
				_layer(root, FIRE, Vector2(width, width * 0.80), 2, Vector2(0, 6), 0.85)
				_layer(root, ARC, Vector2(width, width * 0.66), 0, Vector2.ZERO, 0.28)
				_layer(root, EDGE, Vector2(width, width * 0.66), 0, Vector2(0, -2), 0.8)
			_views[id] = {"node": root, "age": 0.0, "fade": 0.0, "width": float(p.radius) * 2.0, "wave": visual == "kayle_wave", "history": []}
		var view: Dictionary = _views[id]
		if bool(view.wave):
			view.node.scale = Vector2(float(p.radius) * 2.0 / float(view.width), 1.0)
		view.node.position = _path_position(p, view)
		# 创建时按模型投影起终点固定朝向；后续追踪位移不旋转光剑。
		if not view.has("facing"):
			var facing := _system._direction(p)
			if view.has("start_offset"):
				facing = ((p.visual_path.end as Vector2) + view.end_offset) - ((p.visual_path.start as Vector2) + view.start_offset)
			view.facing = facing
		view.node.rotation = (view.facing as Vector2).angle() + PI * 0.5
		if not bool(view.wave): _update_sword_trail(view, delta)
	for id in _views.keys():
		var view: Dictionary = _views[id]
		view.age += delta
		if not seen.has(id): view.fade += delta
		if view.fade >= 0.12 or (not bool(view.wave) and not seen.has(id)):
			view.node.free()
			_views.erase(id)
			continue
		var strength := minf(float(view.age) / 0.05, 1.0) * (1.0 - float(view.fade) / 0.12)
		for sprite in view.node.get_children():
			sprite.material.set_shader_parameter("age", view.age)
			sprite.material.set_shader_parameter("strength", strength * float(sprite.get_meta("opacity")))

func clear() -> void:
	for view in _views.values(): view.node.free()
	_views.clear()

func _find_entity(descriptor: Dictionary) -> Node2D:
	if bool(descriptor.unit) and int(descriptor.get("id", -1)) < 0:
		return instance_from_id(int(descriptor.get("local_id", 0))) as Node2D
	var nearest: Node2D
	var nearest_distance := INF
	for body in get_tree().get_nodes_in_group("combatants"):
		if body.team != int(descriptor.team) or (body is Unit) != bool(descriptor.unit): continue
		if body is Unit and int(descriptor.get("id", -1)) >= 0:
			if body.net_id == int(descriptor.id): return body
			continue
		if body is Tower and body.is_king != bool(descriptor.king): continue
		var distance: float = body.global_position.distance_squared_to(descriptor.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = body
	return nearest

func _model_offset(descriptor: Dictionary, fallback: Vector2) -> Vector2:
	var body := _find_entity(descriptor)
	return body.get_meta("projectile_model_offset", fallback) if is_instance_valid(body) else fallback

func _path_position(p: Dictionary, view: Dictionary) -> Vector2:
	var path: Dictionary = p.get("visual_path", {})
	if path.is_empty(): return _system._visual_position(p)
	if not view.has("start_offset"):
		view.start_offset = (path.origin_offset as Vector2) + _model_offset(path.source, Vector2(0, -80))
		view.end_offset = _model_offset(path.target, Vector2(0, -30))
	if not bool(path.wave): view.end_offset = _model_offset(path.target, view.end_offset)
	var position := (p.pos as Vector2) + (view.start_offset as Vector2).lerp(view.end_offset, float(path.progress))
	if not bool(path.wave): position += _system._direction(p) * float(path.contact_radius) * float(path.progress)
	return position

## 原Trail使用0.12秒相机朝向拖尾；记录实际画面轨迹，转弯时尾迹不硬转。
func _update_sword_trail(view: Dictionary, delta: float) -> void:
	var history: Array = view.history
	for entry in history: entry.life -= delta
	while not history.is_empty() and float(history[0].life) <= 0.0: history.pop_front()
	var point: Vector2 = view.node.to_global(Vector2(0, 50))
	if history.is_empty() or (history.back().pos as Vector2).distance_squared_to(point) > 0.01:
		history.append({"pos": point, "life": 0.12})
	if not view.has("trail"):
		var trail := Polygon2D.new()
		trail.texture = SWORD_TRAIL
		trail.set_meta("opacity", 0.65)
		var material := ShaderMaterial.new()
		material.shader = SHADER
		trail.material = material
		view.node.add_child(trail)
		view.node.move_child(trail, 0)
		view.trail = trail
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	if history.size() >= 2:
		for side in [-1.0, 1.0]:
			for step in history.size():
				var i: int = step if side < 0 else history.size() - 1 - step
				var previous: Vector2 = history[maxi(i - 1, 0)].pos
				var next: Vector2 = history[mini(i + 1, history.size() - 1)].pos
				var normal := (next - previous).normalized().orthogonal()
				var ratio := float(history[i].life) / 0.12
				vertices.append(view.node.to_local(history[i].pos + normal * side * ratio * 2.0))
				uv.append(Vector2(0 if side < 0 else SWORD_TRAIL.get_width(), (1.0 - ratio) * SWORD_TRAIL.get_height()))
				colors.append(Color(1.0, 0.85, 0.24, ratio * 0.75))
	view.trail.polygon = vertices
	view.trail.uv = uv
	view.trail.vertex_colors = colors
