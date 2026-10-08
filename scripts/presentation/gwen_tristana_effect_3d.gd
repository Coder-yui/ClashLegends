extends Node3D
## 原版圣霭和炮弹只读取权威状态/可见弹体；不驱动战斗。
const PLAYER = preload("res://assets/effects/gwen_tristana/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const MIST_RADIUS := 425.593 # 原TeamRing纹理亮线V=46.5/128，网格UV插值后乘4.45。
var _mists: Dictionary = {}
var _missiles: Dictionary = {}

func sync_effects(projectiles: Node2D, camera: Camera3D) -> void:
	var present := {}
	for actor in get_tree().get_nodes_in_group("combatants"):
		if not actor is Unit or actor.hp <= 0.0 or not actor.target_protection.active(): continue
		var state: TargetProtectionState = actor.target_protection
		var id := str(actor.get_instance_id()) + ":" + str(state.serial)
		present[id] = true
		if not _mists.has(id):
			var player := PLAYER.new()
			add_child(player)
			player.load_kind("mist")
			player.position = PROJECTION.ground(camera, state.center)
			var world_radius := PROJECTION.ground(camera, state.center + Vector2(state.radius, 0)).distance_to(player.position)
			player.projection_basis = PROJECTION.footprint_basis(camera, state.center, state.radius)
			player.setup_native(world_radius / MIST_RADIUS)
			_mists[id] = player
		var player: Node3D = _mists[id]
		player.opacity = smoothstep(0.0, 0.12, state.remaining())
		player.seek(maxf(0.0, 4.0 - state.remaining()))
	for id in _mists.keys():
		if not present.has(id):
			_mists[id].free()
			_mists.erase(id)
	present.clear()
	if projectiles == null: return
	var snapshot: Dictionary = projectiles.visible_snapshot()
	for id in snapshot:
		var projectile: Dictionary = snapshot[id]
		if String(projectile.get("visual", "")) != "tristana_bullet": continue
		present[id] = true
		var point: Vector2 = projectiles._visual_position(projectile)
		if not _missiles.has(id):
			var player := PLAYER.new()
			add_child(player)
			player.load_kind("missile")
			player.position = PROJECTION.ground(camera, point)
			player.setup_native(0.01)
			player._birth_positions.clear()
			_missiles[id] = {"player":player, "age":0.0, "last":projectile.pos}
		var view: Dictionary = _missiles[id]
		view.age += (projectile.pos as Vector2).distance_to(view.last) / maxf(float(projectile.speed), 1.0)
		view.last = projectile.pos
		var player: Node3D = view.player
		var origin := camera.project_ray_origin(point)
		var ray := camera.project_ray_normal(point)
		player.position = origin + ray * ((1.6 - origin.y) / ray.y)
		var direction: Vector2 = projectiles._direction(projectile)
		var forward := (PROJECTION.ground(camera, point + direction) - PROJECTION.ground(camera, point)).normalized()
		player.basis = Basis(forward.cross(Vector3.UP), forward, Vector3.UP) * 0.01
		player.seek(0.025 + fmod(float(view.age), 2.9))
	for id in _missiles.keys():
		if not present.has(id):
			_missiles[id].player.free()
			_missiles.erase(id)
