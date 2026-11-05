extends Node3D
## 原版霰弹从枪口出发，沿释放时固定方向读取权威路径。
const PLAYER = preload("res://assets/effects/graves/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const ANCHOR = preload("res://scripts/presentation/projectile_model_anchor.gd")
const NATIVE_SCALE := PLAYER.NATIVE_SCALE
var _projectiles: Node2D
var _camera: Camera3D
var _missiles: Dictionary = {}
func _ready() -> void:
	process_priority = 10
func set_sources(projectiles: Node2D, camera: Camera3D) -> void:
	if _projectiles != projectiles:
		if is_instance_valid(_projectiles):
			_projectiles.visuals_cleared.disconnect(_clear)
		_projectiles = projectiles
		if is_instance_valid(_projectiles):
			_projectiles.visuals_cleared.connect(_clear)
	_camera = camera
func _process(_delta: float) -> void:
	if is_instance_valid(_camera): sync_effects()
func _create(kind: String) -> Node3D:
	var player := PLAYER.new()
	add_child(player)
	player.load_kind(kind)
	player.setup_native(NATIVE_SCALE)
	return player
func sync_effects() -> void:
	var present := {}
	if is_instance_valid(_projectiles):
		for id in _projectiles.visible_view():
			var projectile: Dictionary = _projectiles.visible_view()[id]
			if StringName(projectile.get("visual", "")) != &"graves_bullet": continue
			present[id] = true
			var path: Dictionary = projectile.get("visual_path", {})
			if not _missiles.has(id):
				# 使用模型的 buffbone_cstm_weapona 枪口挂点。
				var origin := PROJECTION.ground(_camera, path.get("start", projectile.pos)) + Vector3.UP * 100.0 * NATIVE_SCALE
				var source_body: Node2D = _projectiles._visual_body(path.get("source", {}))
				if is_instance_valid(source_body) and source_body.has_meta("projectile_launch_anchor"):
					var anchor = source_body.get_meta("projectile_launch_anchor").get_ref()
					if is_instance_valid(anchor): origin = anchor.global_position
				# 只在创建时读取目标高度；空军抬升也不使弹丸随后追踪目标。
				var aim_correction := Vector3.ZERO
				var target_body: Node2D = _projectiles._visual_body(path.get("target", {}))
				var attached: Variant = ANCHOR.body_position(target_body) if is_instance_valid(target_body) else null
				if attached is Vector3:
					var ground_start := PROJECTION.ground(_camera, path.get("start", projectile.pos))
					var ground_target := PROJECTION.ground(_camera, target_body.global_position)
					# 枪口偏移在瞄准距离处收敛，避免整条弹道平移后穿过目标身侧。
					var contact := ground_start
					contact.y = attached.y
					aim_correction = (contact - origin) / maxf(ground_start.distance_to(ground_target), 0.01)
				_missiles[id] = {"player": _create("missile"), "origin": origin, "aim_correction": aim_correction, "last": path.get("start", projectile.pos), "age": 0.0, "started": false}
			var view: Dictionary = _missiles[id]
			view.age += (projectile.pos as Vector2).distance_to(view.last) / maxf(float(projectile.speed), 1.0)
			view.last = projectile.pos
			var start: Vector3 = PROJECTION.ground(_camera, path.get("start", projectile.pos))
			var end: Vector3 = PROJECTION.ground(_camera, path.get("end", projectile.pos))
			var direction := (end - start).normalized()
			direction = (direction + Vector3(view.aim_correction)).normalized()
			var side := direction.cross(Vector3.UP).normalized()
			if side.is_zero_approx(): side = Vector3.RIGHT
			var orientation := Basis(side, direction, side.cross(direction).normalized())
			var travelled := PROJECTION.ground(_camera, projectile.pos) - start
			var current: Vector3 = view.origin + travelled + Vector3(view.aim_correction) * travelled.length()
			if not view.started:
				view.player.seek_motion(0.0, view.origin, orientation)
				view.started = true
			view.player.seek_motion(maxf(minf(view.age, 2.0), 1.0 / 120.0), current, orientation)
	for id in _missiles.keys():
		if not present.has(id):
			_missiles[id].player.free()
			_missiles.erase(id)
func _clear() -> void:
	for view in _missiles.values(): view.player.free()
	_missiles.clear()
