extends Node3D
## 原版植物尖刺；仅原版尖刺网格，读取权威弹体，不生成附属粒子或命中特效。
const PLAYER = preload("res://assets/effects/thorn_spitter/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const ANCHOR = preload("res://scripts/presentation/projectile_model_anchor.gd")
const NATIVE_SCALE := 0.016 / 1.2
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
			if StringName(projectile.get("visual", "")) != &"thorn_spitter_bullet": continue
			present[id] = true
			var path: Dictionary = projectile.get("visual_path", {})
			if not _missiles.has(id):
				# 原定义没有起始骨骼覆盖；使用植物模型武器挂点，不把目标高度100误当出生高度。
				var origin := PROJECTION.ground(_camera, path.get("start", projectile.pos)) + Vector3.UP * 100.0 * NATIVE_SCALE
				var source_body: Node2D = _projectiles._visual_body(path.get("source", {}))
				if is_instance_valid(source_body) and source_body.has_meta("projectile_model_anchor"):
					var anchor = source_body.get_meta("projectile_model_anchor").get_ref()
					if is_instance_valid(anchor): origin = anchor.global_position
				_missiles[id] = {"player": _create("missile"), "origin": origin, "last": path.get("start", projectile.pos), "age": 0.0}
			var view: Dictionary = _missiles[id]
			view.age += (projectile.pos as Vector2).distance_to(view.last) / maxf(float(projectile.speed), 1.0)
			view.last = projectile.pos
			var target_body: Node2D = _projectiles._visual_body(path.get("target", {}))
			var attached: Variant = ANCHOR.body_position(target_body) if is_instance_valid(target_body) else null
			var target: Vector3 = attached if attached is Vector3 else PROJECTION.ground(_camera, path.get("end", projectile.pos)) + Vector3.UP * 100.0 * NATIVE_SCALE
			var direction := (target - (view.origin as Vector3)).normalized()
			var side := direction.cross(Vector3.UP).normalized()
			if side.is_zero_approx(): side = Vector3.RIGHT
			var orientation := Basis(side, direction, side.cross(direction).normalized())
			view.player.seek_motion(maxf(minf(view.age, 2.0), 1.0 / 120.0), (view.origin as Vector3).lerp(target, clampf(float(path.get("progress", 0.0)), 0.0, 1.0)), orientation)
	for id in _missiles.keys():
		if not present.has(id):
			_missiles[id].player.free()
			_missiles.erase(id)
func _clear() -> void:
	for view in _missiles.values(): view.player.free()
	_missiles.clear()
