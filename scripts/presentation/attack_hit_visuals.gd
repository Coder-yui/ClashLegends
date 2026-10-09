extends Node2D
## 真实命中后的短时光束；只读表现事件，不参与飞行、碰撞或伤害。
const HIT_PLAYER = preload("res://assets/effects/azir/player.gd")
const PLAYER = preload("res://assets/effects/azir/beam_player.gd")
var _context: BattleContext
var _views: Array[Dictionary] = []
var _hits: Array[Dictionary] = []

func _ready() -> void:
	# Main 先推进表现时间；本节点在模型和 AnimationPlayer 更新后重采挂点。
	process_priority = 100

func _process(_delta: float) -> void:
	for view in _views: _update_view(view, true)
	for hit in _hits:
		if not is_instance_valid(hit.camera): continue
		_update_endpoints(hit.view, true)
		_place_hit(hit.player, hit.camera, hit.view.end)
		hit.player.seek(hit.age)

func setup(system: ProjectileSystem) -> void:
	_context = system._context
	system.visuals_cleared.connect(clear)

func play_hit(source: Dictionary, position: Vector2, world: Node3D = null, camera: Camera3D = null) -> void:
	var stats := PresentationConfig.for_form(CardDB.get_card(String(source.get("card_id", ""))), int(source.get("form", 0)))
	if String(stats.get("attack_hit_visual", "")) != "azir_beam": return
	var player := PLAYER.new()
	add_child(player)
	player.setup("basic_attack", int(source.get("serial", 0)))
	var view := {"player": player, "age": 0.0, "source": source.duplicate(true),
		"camera": camera, "start": source.get("hit_origin", position) + Vector2(0,-60), "end": position + source.get("hit_target_offset", Vector2(0,-30))}
	_views.append(view)
	_update_view(view)
	if is_instance_valid(world) and is_instance_valid(camera):
		var hit := HIT_PLAYER.new()
		world.add_child(hit)
		hit.load_kind("hit")
		hit.setup_native(0.011)
		_place_hit(hit, camera, view.end)
		_hits.append({"player": hit, "camera": camera, "age": 0.0, "view": view})

func advance(delta: float) -> void:
	for index in range(_views.size()-1,-1,-1):
		var view := _views[index]
		view.age += delta
		if view.age >= 0.25:
			view.player.free()
			_views.remove_at(index)
		else: _update_view(view)
	for index in range(_hits.size() - 1, -1, -1):
		var hit := _hits[index]
		hit.age += delta
		if hit.age >= 0.7 or not is_instance_valid(hit.camera):
			if is_instance_valid(hit.player): hit.player.free()
			_hits.remove_at(index)
		else:
			_update_endpoints(hit.view)
			_place_hit(hit.player, hit.camera, hit.view.end)
			hit.player.seek(hit.age)

func _place_hit(player: Node3D, camera: Camera3D, point: Vector2) -> void:
	# 光束终点和受击层共用屏幕挂点；保留真实高度以接受正常遮挡。
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	player.global_position = origin + direction * ((1.0 - origin.y) / direction.y)

func _update_view(view: Dictionary, current_pose: bool = false) -> void:
	_update_endpoints(view, current_pose)
	view.player.set_segment(view.start, view.end)
	view.player.sample(view.age, 1.0)

func _update_endpoints(view: Dictionary, current_pose: bool = false) -> void:
	var source := _body(int(view.source.get("unit_id", -1)), not _context.is_net_client())
	var descriptor: Dictionary = view.source.get("hit_target", {})
	var target := _body(int(descriptor.get("id", -1)), false)
	# 本地ID只在权威端匹配，不能跨进程解引用；客户端找不到目标时保留事件落点。
	if target == null and not _context.is_net_client():
		for body in get_tree().get_nodes_in_group("combatants"):
			if body.get_instance_id() == int(descriptor.get("local_id", 0)): target = body; break
	if target == null and descriptor.has("tower_position"):
		for body in get_tree().get_nodes_in_group("combatants"):
			if body is Tower and body.global_position.is_equal_approx(descriptor.tower_position): target = body; break
	if is_instance_valid(source): view.start = source.global_position + source.get_meta("projectile_model_offset", Vector2(0,-60))
	if is_instance_valid(target): view.end = target.global_position + target.get_meta("projectile_model_offset", view.source.get("hit_target_offset", Vector2(0,-30)))

	if current_pose and is_instance_valid(view.camera):
		if is_instance_valid(source): view.start = _anchor_position(source, view.camera, view.start)
		if is_instance_valid(target): view.end = _anchor_position(target, view.camera, view.end)

func _anchor_position(body: Node2D, camera: Camera3D, fallback: Vector2) -> Vector2:
	var reference = body.get_meta("projectile_model_anchor", null)
	if not reference is WeakRef: return fallback
	var anchor = reference.get_ref()
	if not is_instance_valid(anchor): return fallback
	if anchor is BoneAttachment3D:
		var skeleton := anchor.get_parent() as Skeleton3D
		if skeleton != null and anchor.bone_idx >= 0:
			# 直接读本帧骨骼姿势，避免 BoneAttachment 延迟通知造成一帧拖尾。
			return camera.unproject_position(skeleton.to_global(skeleton.get_bone_global_pose(anchor.bone_idx).origin))
	return camera.unproject_position(anchor.global_position)

func _body(id: int, allow_local: bool) -> Node2D:
	if id < 0: return null
	for body in get_tree().get_nodes_in_group("combatants"):
		if body is Unit and (body.net_id == id or (allow_local and body.get_instance_id() == id)): return body
	return null

func clear() -> void:
	for view in _views: view.player.free()
	_views.clear()
	for hit in _hits:
		if is_instance_valid(hit.player): hit.player.free()
	_hits.clear()
