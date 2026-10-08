extends Node3D
## 只读技能区域和主客端共用弹体快照；不推进战斗、不结算命中。
const PLAYER = preload("res://assets/effects/anivia/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const SOURCE_RADIUS := 395.5019 # 原版边环纹理亮线峰值V=66.5/128映射网格半径，再乘6.5。
var _storms: Dictionary = {}
var _missiles: Dictionary = {}
var _serial := 0

func sync_effects(skills: RefCounted, projectiles: Node2D, camera: Camera3D) -> void:
	var present := {}
	for effect in skills.frontal_effects:
		if String(effect.shape) != "frost_storm": continue
		if not effect.has("anivia_view_id"):
			_serial += 1
			effect.anivia_view_id = _serial
		var id := int(effect.anivia_view_id)
		present[id] = true
		if not _storms.has(id):
			var player := PLAYER.new()
			add_child(player)
			player.load_kind("storm")
			player.position = PROJECTION.ground(camera, effect.pos)
			var radius := float(effect.length)
			var world_radius := PROJECTION.ground(camera, effect.pos + Vector2(radius, 0)).distance_to(player.position)
			player.projection_basis = PROJECTION.footprint_basis(camera, effect.pos, radius)
			player.setup_native(world_radius / SOURCE_RADIUS)
			_storms[id] = player
		var elapsed := float(effect.duration) - float(effect.timer)
		var player: Node3D = _storms[id]
		player.opacity = smoothstep(0.0, 0.12, float(effect.timer))
		# 采样已从原版3秒的满尺寸阶段开始，直接按区域年龄播放。
		player.seek(elapsed)
	for id in _storms.keys():
		if not present.has(id):
			_storms[id].free()
			_storms.erase(id)
	present.clear()
	if projectiles == null: return
	var visible: Dictionary = projectiles.visible_snapshot()
	for id in visible:
		var projectile: Dictionary = visible[id]
		if String(projectile.get("visual", "")) != "ice_cone": continue
		present[id] = true
		var point: Vector2 = projectiles._visual_position(projectile)
		if not _missiles.has(id):
			var player := PLAYER.new()
			add_child(player)
			player.load_kind("missile")
			player.position = PROJECTION.ground(camera, point)
			player.setup_native(0.011)
			player._birth_positions.clear()
			_missiles[id] = {"player":player, "age":0.05, "last":projectile.pos}
		var view: Dictionary = _missiles[id]
		view.age += (projectile.pos as Vector2).distance_to(view.last) / maxf(float(projectile.speed), 1.0)
		view.last = projectile.pos
		var player: Node3D = view.player
		# 同一可见锚点投射到空中平面，保留深度；朝向取可见飞行方向。
		var origin := camera.project_ray_origin(point)
		var ray := camera.project_ray_normal(point)
		player.position = origin + ray * ((1.6 - origin.y) / ray.y)
		var direction: Vector2 = projectiles._direction(projectile)
		var ahead := PROJECTION.ground(camera, point + direction) - PROJECTION.ground(camera, point)
		# 源IcicleSpear出生旋转将网格+Z转为系统+Y；+Y才是弹头轴。
		var forward := ahead.normalized()
		player.basis = Basis(forward.cross(Vector3.UP), forward, Vector3.UP) * 0.011
		player.seek(0.05 + fmod(float(view.age), 1.8))
	for id in _missiles.keys():
		if not present.has(id):
			_missiles[id].player.free()
			_missiles.erase(id)
