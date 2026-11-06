extends Node3D
## 琴女原版音符与狂舞终乐章，仅读取权威路径。
const PLAYER = preload("res://assets/effects/sona/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const ANCHOR = preload("res://scripts/presentation/projectile_model_anchor.gd")
const NATIVE_SCALE := PLAYER.NATIVE_SCALE
var _projectiles: Node2D
var _camera: Camera3D
var _missiles: Dictionary = {}
var _tails: Array[Dictionary] = []
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
func _process(delta: float) -> void:
	if is_instance_valid(_camera): sync_effects()
	_tick_tails(delta)
func _create(kind: String) -> Node3D:
	var player := PLAYER.new()
	add_child(player)
	player.load_kind(kind)
	player.setup_native(0.0125 if kind == "wave" else NATIVE_SCALE)
	return player
func sync_effects() -> void:
	var present := {}
	if is_instance_valid(_projectiles):
		for id in _projectiles.visible_view():
			var projectile: Dictionary = _projectiles.visible_view()[id]
			if StringName(projectile.get("visual", "")) == &"sona_wave":
				present[id] = true
				_sync_wave(id, projectile)
				continue
			if StringName(projectile.get("visual", "")) != &"sona_bolt": continue
			present[id] = true
			var path: Dictionary = projectile.get("visual_path", {})
			if not _missiles.has(id):
				# 普攻源未声明起始骨骼；项目显式绑定 WEAPON。
				var origin := PROJECTION.ground(_camera, path.get("start", projectile.pos)) + Vector3.UP * 100.0 * NATIVE_SCALE
				var source_body: Node2D = _projectiles._visual_body(path.get("source", {}))
				if is_instance_valid(source_body) and source_body.has_meta("projectile_model_anchor"):
					var anchor = source_body.get_meta("projectile_model_anchor").get_ref()
					if is_instance_valid(anchor): origin = anchor.global_position
				_missiles[id] = {"player": _create("basic"), "origin": origin, "last": path.get("start", projectile.pos), "age": 0.0, "started": false}
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
			if not view.started:
				view.player.seek_motion(0.0, view.origin, orientation)
				view.started = true
			view.player.seek_motion(maxf(minf(view.age, 2.0), 1.0 / 120.0), (view.origin as Vector3).lerp(target, clampf(float(path.get("progress", 0.0)), 0.0, 1.0)), orientation)
	for id in _missiles.keys():
		if not present.has(id):
			var view: Dictionary = _missiles[id]
			if view.get("wave", false):
				view.player.stop_emission(view.age)
				view["stop_age"] = view.age
				_tails.append(view)
			else: view.player.free()
			_missiles.erase(id)
func _clear() -> void:
	for view in _missiles.values(): view.player.free()
	for view in _tails: view.player.free()
	_missiles.clear()
	_tails.clear()

## 原版missile对象约定：局部Y沿水平航线、Z向上，不是单位的Y-up/Z-forward。
static func missile_basis(direction: Vector3) -> Basis:
	var forward := Vector3(direction.x, 0.0, direction.z).normalized()
	if forward.is_zero_approx(): forward = Vector3.FORWARD
	var side := forward.cross(Vector3.UP).normalized()
	return Basis(side, forward, Vector3.UP)

func _sync_wave(id: int, projectile: Dictionary) -> void:
	var pos: Vector2 = projectile.pos
	var direction: Vector2 = projectile.direction
	var path: Dictionary = projectile.get("visual_path", {})
	var start: Vector2 = path.get("start", pos)
	var end: Vector2 = path.get("end", pos + direction)
	if not _missiles.has(id):
		var launch := PROJECTION.ground(_camera, start) + Vector3.UP * 2.5
		var body: Node2D = _projectiles._visual_body(path.get("source", {}))
		if is_instance_valid(body) and body.has_meta("projectile_model_anchor"):
			var anchor = body.get_meta("projectile_model_anchor").get_ref()
			if is_instance_valid(anchor): launch = anchor.global_position
		# 原始两个-50字段都是目标高度设置，不能当作WEAPON到终点的50落差。
		# 项目为空军平面扫掠：保留WEAPON高度，以水平Y-forward/Z-up导弹基底飞行。
		var target := launch + PROJECTION.ground(_camera, end) - PROJECTION.ground(_camera, start)
		var orientation := missile_basis(target - launch)
		var player := _create("wave")
		player.use_battle_range()
		player.seek_motion(0.0, launch, orientation)
		_missiles[id] = {"player": player, "wave": true, "last": start, "age": 0.0, "launch": launch, "target": target, "origin": launch, "basis": orientation}
	var view: Dictionary = _missiles[id]
	view.age += pos.distance_to(view.last) / maxf(float(projectile.speed), 1.0)
	view.last = pos
	var progress := clampf(pos.distance_to(start) / maxf(end.distance_to(start), 1.0), 0.0, 1.0)
	view.origin = (view.launch as Vector3).lerp(view.target, progress)
	view.player.seek_motion(maxf(view.age, 1.0 / 120.0), view.origin, view.basis)

func _tick_tails(delta: float) -> void:
	for index in range(_tails.size() - 1, -1, -1):
		var view: Dictionary = _tails[index]
		view.age += delta
		if view.age - view.stop_age >= 1.5:
			view.player.free()
			_tails.remove_at(index)
		else:
			view.player.seek_motion(view.age, view.origin, view.basis)
