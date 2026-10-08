extends Node2D
## 原版粒子采样与轨迹投影；权威弹体独立推进。
const PLAYER = preload("res://assets/effects/kayle/native/player.gd")
var _system: ProjectileSystem
var _views: Dictionary = {}

static func dependency_paths() -> Array: return PLAYER.dependency_paths()

func setup(system: ProjectileSystem) -> void:
	_system = system
	system.visuals_cleared.connect(clear)

func advance(delta: float) -> void:
	var seen := {}
	var visible := _system.visible_snapshot()
	for id in visible:
		var p: Dictionary = visible[id]
		var visual := String(p.get("visual", ""))
		if visual not in ["kayle_sword", "kayle_wave"]: continue
		seen[id] = true
		if not _views.has(id):
			var player := PLAYER.new()
			add_child(player)
			player.setup("wave" if visual == "kayle_wave" else "sword")
			_views[id] = {"node":player,"age":0.0,"fade":0.0,"wave":visual == "kayle_wave","phase":0.0}
		var view: Dictionary = _views[id]
		view.node.position = _path_position(p,view)
		if not view.has("facing"):
			var direction := _system._direction(p)
			if view.has("start_offset"):
				direction = ((p.visual_path.end as Vector2) + view.end_offset) - ((p.visual_path.start as Vector2) + view.start_offset)
			view.facing = direction
		view.node.rotation = (view.facing as Vector2).angle()+PI*0.5
		var progress := float(p.get("visual_path",{}).get("progress",0.0))
		view.phase = minf(0.22, progress*0.22+0.025)
		if bool(view.wave): view.node.wave_radius = float(p.radius)
	for id in _views.keys():
		var view: Dictionary = _views[id]
		view.age += delta
		if not seen.has(id): view.fade += delta
		if view.fade >= 0.12 or (not bool(view.wave) and not seen.has(id)):
			view.node.free()
			_views.erase(id)
			continue
		view.node.sample(float(view.phase)+float(view.fade),1.0-float(view.fade)/0.12)

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
