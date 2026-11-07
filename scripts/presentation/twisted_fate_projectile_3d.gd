extends Node3D
## 卡牌大师原版卡片本体与万能牌（无附加特效），仅读取权威路径。
const PLAYER = preload("res://scripts/presentation/twisted_fate_card_model.gd")
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
			if StringName(projectile.get("visual", "")) not in [&"twisted_fate_card", &"twisted_fate_wild"]: continue
			var wild := StringName(projectile.visual) == &"twisted_fate_wild"
			present[id] = true
			var path: Dictionary = projectile.get("visual_path", {})
			if not _missiles.has(id):
				# 普攻按动作选手；万能牌固定从原版 r_hand 发出。
				var origin := PROJECTION.ground(_camera, path.get("start", projectile.pos)) + Vector3.UP * 100.0 * NATIVE_SCALE
				var source_body: Node2D = _projectiles._visual_body(path.get("source", {}))
				if is_instance_valid(source_body) and source_body.has_meta("projectile_launch_anchor"):
					var anchor = source_body.get_meta("projectile_launch_anchor").get_ref()
					if is_instance_valid(anchor):
						origin = anchor.global_position
						if wild and anchor.get_parent() is Skeleton3D:
							var skeleton := anchor.get_parent() as Skeleton3D
							var bone := skeleton.find_bone("R_Hand")
							if bone >= 0: origin = skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
				_missiles[id] = {"player": _create(_wild_kind(projectile.get("color", Color.WHITE)) if wild else "basic"), "origin": origin, "last": path.get("start", projectile.pos), "age": 0.0, "started": false}
			var view: Dictionary = _missiles[id]
			view.age += (projectile.pos as Vector2).distance_to(view.last) / maxf(float(projectile.speed), 1.0)
			view.last = projectile.pos
			var target_body: Node2D = _projectiles._visual_body(path.get("target", {}))
			var attached: Variant = ANCHOR.body_position(target_body) if is_instance_valid(target_body) else null
			var target: Vector3 = attached if attached is Vector3 else PROJECTION.ground(_camera, path.get("end", projectile.pos)) + Vector3.UP * 100.0 * NATIVE_SCALE
			if wild:
				target = view.origin + PROJECTION.ground(_camera, path.get("end", projectile.pos)) - PROJECTION.ground(_camera, path.get("start", projectile.pos))
			var direction := (target - (view.origin as Vector3)).normalized()
			var side := direction.cross(Vector3.UP).normalized()
			if side.is_zero_approx(): side = Vector3.RIGHT
			var orientation := Basis(side, direction, side.cross(direction).normalized())
			if not view.started:
				view.player.seek_motion(0.0, view.origin, orientation)
				view.started = true
			view.player.seek_motion(maxf(minf(view.age, 2.0), 1.0 / 120.0), (view.origin as Vector3).lerp(target, clampf(float(path.get("progress", 0.0)) if not wild else (projectile.pos as Vector2).distance_to(path.get("start", projectile.pos)) / maxf((path.get("start", projectile.pos) as Vector2).distance_to(path.get("end", projectile.pos)), 1.0), 0.0, 1.0)), orientation)
	for id in _missiles.keys():
		if not present.has(id):
			var view: Dictionary = _missiles[id]
			view.player.free()
			_missiles.erase(id)
func _clear() -> void:
	for view in _missiles.values(): view.player.free()
	for view in _tails: view.player.free()
	_missiles.clear()
	_tails.clear()

static func _wild_kind(color: Color) -> String:
	if color.b > color.r: return "wild_blue"
	return "wild_red" if color.g < 0.5 else "wild_yellow"
