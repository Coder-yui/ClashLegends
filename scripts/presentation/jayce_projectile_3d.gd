extends Node3D
## 原版弹头/发光层只读取可见弹体。真实路径、命中及声音仍由ProjectileSystem管理。
const PLAYER = preload("res://assets/effects/jayce/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
## 杰斯原生模型坐标与粒子统一按包装缩放0.0095，保留弹头和武器比例。
const BULLET_SCALE := 0.0095
var _projectiles: Node2D
var _camera: Camera3D

func _ready() -> void:
	# 枪口骨骼与投影元数据在UnitModel3D本帧更新后再读取。
	process_priority = 10

func set_sources(projectiles: Node2D, camera: Camera3D) -> void:
	_projectiles = projectiles
	_camera = camera

func _process(_delta: float) -> void:
	if is_instance_valid(_camera): sync_effects(_projectiles, _camera)
var _missiles: Dictionary = {}
func sync_effects(projectiles: Node2D, camera: Camera3D) -> void:
	var present := {}
	if projectiles != null:
		var visible_projectiles: Dictionary = projectiles.visible_view()
		for id in visible_projectiles:
			var projectile: Dictionary = visible_projectiles[id]
			if StringName(projectile.get("visual", "")) != &"jayce_bullet": continue
			present[id] = true
			if not _missiles.has(id):
				var player := PLAYER.new()
				add_child(player)
				player.load_kind("bullet")
				player.setup_native(BULLET_SCALE)
				var origin: Vector2 = projectile.get("visual_path", {}).get("start", projectile.pos)
				var initial_age := (projectile.pos as Vector2).distance_to(origin) / maxf(float(projectile.speed), 1.0)
				_missiles[id] = {"player": player, "age": initial_age, "last": projectile.pos}
			var view: Dictionary = _missiles[id]
			view.age += (projectile.pos as Vector2).distance_to(view.last) / maxf(float(projectile.speed), 1.0)
			view.last = projectile.pos
			var point: Vector2 = projectiles._visual_position(projectile)
			var origin := BattleGroundProjection.ray_origin(camera, point)
			var ray := BattleGroundProjection.ray_normal(camera, point)
			var player: Node3D = view.player
			player.position = origin + ray * ((1.2 - origin.y) / ray.y)
			var direction: Vector2 = projectiles._direction(projectile)
			var forward := (PROJECTION.ground(camera, point + direction) - PROJECTION.ground(camera, point)).normalized()
			# 源弹头沿+Y，变换到可见枪口至目标路径，保留三轴比例。
			player.basis = Basis(forward.cross(Vector3.UP), forward, Vector3.UP) * BULLET_SCALE
			player.seek_motion(fmod(float(view.age), 5.0), player.global_position, player.basis.orthonormalized())
	for id in _missiles.keys():
		if not present.has(id):
			_missiles[id].player.free()
			_missiles.erase(id)

var _field_hits: Dictionary = {}
var _field_serial := 0
func sync_field_hits(skills: SkillEffectPresentation, camera: Camera3D) -> void:
	var present := {}
	for effect in skills.frontal_effects:
		if String(effect.get("shape", "")) != "jayce_field_hit": continue
		if not effect.has("jayce_view_id"):
			_field_serial += 1
			effect.jayce_view_id = _field_serial
		var id := int(effect.jayce_view_id)
		present[id] = true
		if not _field_hits.has(id):
			var player := PLAYER.new()
			add_child(player)
			player.load_kind("field_hit")
			player.setup_native(BULLET_SCALE)
			_field_hits[id] = player
		var target: Node2D = skills._controller.world.find_replica_unit(int(effect.get("target_net_id", -1))) if skills._controller.is_net_client() else instance_from_id(int(effect.get("target_instance_id", 0))) as Node2D
		if not is_instance_valid(target) and effect.has("target_tower_position"):
			for tower in skills._controller.world.towers_snapshot():
				if tower.position == effect.target_tower_position:
					target = tower
					break
		var point: Vector3 = PROJECTION.ground(camera, effect.pos) + Vector3.UP
		if is_instance_valid(target):
			var attached: Variant = preload("res://scripts/presentation/projectile_model_anchor.gd").body_position(target)
			point = attached if attached != null else PROJECTION.ground(camera, target.global_position) + Vector3.UP
		var player: Node3D = _field_hits[id]
		player.seek_motion(maxf(float(effect.duration) - float(effect.timer), 0.0), point, Basis.IDENTITY)
	for id in _field_hits.keys():
		if not present.has(id):
			_field_hits[id].free()
			_field_hits.erase(id)
