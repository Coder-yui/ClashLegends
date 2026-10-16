extends Node3D
## 只读主客端共用弹体快照；不推进战斗、不结算命中。
const PLAYER = preload("res://assets/effects/voidfish_ranged/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const NATIVE_SCALE := 0.014
const FIRST_SAMPLE := 1.0 / 120.0
var _missiles: Dictionary = {}

func sync_effects(_skills: RefCounted, projectiles: Node2D, camera: Camera3D) -> void:
	var present := {}
	if projectiles == null: return
	var visible: Dictionary = projectiles.visible_view()
	for id in visible:
		var projectile: Dictionary = visible[id]
		if String(projectile.get("visual", "")) != "voidfish_missile": continue
		present[id] = true
		var point: Vector2 = projectiles._visual_position(projectile)
		var path: Dictionary = projectile.get("visual_path", {})
		var target_anchor: Vector3 = projectiles.visual_model_anchor_position(path.get("target", {}))
		if not _missiles.has(id):
			var source_anchor: Vector3 = projectiles.visual_model_anchor_position(path.get("source", {}))
			var source_height := source_anchor.y if source_anchor.is_finite() else 1.6
			var player := PLAYER.new()
			add_child(player)
			player.load_kind("missile")
			# 首次收到快照可能已飞行；用真实飞行距离恢复年龄，不能预跳0.1秒。
			var start: Vector2 = path.get("start", projectile.get("visual_launch_pos", projectile.pos))
			var age: float = (projectile.pos as Vector2).distance_to(start) / maxf(float(projectile.speed), 1.0)
			_missiles[id] = {"player": player, "age": age, "last": projectile.pos, "height": source_height, "ready": false}
		var view: Dictionary = _missiles[id]
		view.age += (projectile.pos as Vector2).distance_to(view.last) / maxf(float(projectile.speed), 1.0)
		view.last = projectile.pos
		var player: Node3D = view.player
		var target_height: float = target_anchor.y if target_anchor.is_finite() else float(view.height)
		var height: float = lerpf(float(view.height), target_height, clampf(float(path.get("progress", 0.0)), 0.0, 1.0))
		player.position = _at_height(camera, point, height)
		var forward: Vector3
		if target_anchor.is_finite():
			forward = (target_anchor - player.position).normalized()
		else:
			var direction: Vector2 = projectiles._direction(projectile)
			forward = (PROJECTION.ground(camera, point + direction) - PROJECTION.ground(camera, point)).normalized()
		if forward.is_zero_approx(): forward = Vector3.FORWARD
		var right := Vector3.UP.cross(forward).normalized()
		if right.is_zero_approx(): right = Vector3.RIGHT
		# 原版+Z沿速度，包含源定义VerticalFacingMatchVelocity的俯仰。
		player.basis = Basis(right, forward.cross(right).normalized(), forward) * NATIVE_SCALE
		if not view.ready:
			player.setup_native(NATIVE_SCALE)
			view.ready = true
		# 0帧尚无采样粒子，只取第一个120Hz采样；长飞行不在1.8秒无依据地重播。
		player.seek(clampf(float(view.age), FIRST_SAMPLE, float(player._data.duration)))
	for id in _missiles.keys():
		if not present.has(id):
			_missiles[id].player.free()
			_missiles.erase(id)

func _at_height(camera: Camera3D, point: Vector2, height: float) -> Vector3:
	var origin := camera.project_ray_origin(point)
	var ray := camera.project_ray_normal(point)
	return origin + ray * ((height - origin.y) / ray.y) if absf(ray.y) > 0.00001 else PROJECTION.ground(camera, point)
