extends Node3D
## 原版弹头/发光层只读取可见弹体。真实路径、命中及声音仍由ProjectileSystem管理。
const PLAYER = preload("res://assets/effects/samira/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
## 源骨骼→用户GLB已内含0.0085缩放（Root/Pistol_Muzzle实测）×模型包装1.2；保持原弹头与枪械比例。
const BULLET_SCALE := 0.0085 * 1.2
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
			if StringName(projectile.get("visual", "")) != &"samira_bullet": continue
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
			player.seek(minf(float(view.age), 0.65))
	for id in _missiles.keys():
		if not present.has(id):
			_missiles[id].player.free()
			_missiles.erase(id)
