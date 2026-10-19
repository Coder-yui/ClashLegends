extends Node3D
## 原版八层爆炸；只读取可靠表现事件的落点、半径和年龄。
const PLAYER = preload("res://assets/effects/aftershock/native/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
# 原版 circleOut SCB 外沿163.89645 × 出生缩放1.9。
const SOURCE_RADIUS := 311.40326
var _views: Dictionary = {}
var _serial := 0
func sync_effects(skills: RefCounted, camera: Camera3D) -> void:
	var present := {}
	for effect in skills.frontal_effects:
		var hit := String(effect.get("shape", "")) == "counter_strike_hit"
		var counter := hit or String(effect.get("shape", "")) == "counter_strike"
		if not counter and String(effect.get("shape", "")) != "aftershock": continue
		if not effect.has("aftershock_view_id"):
			_serial += 1
			effect.aftershock_view_id = _serial
		var id := int(effect.aftershock_view_id)
		present[id] = true
		if not _views.has(id):
			var player: Node3D = load("res://assets/effects/jax/player.gd").new() if counter else PLAYER.new()
			add_child(player)
			player.load_kind("tar" if hit else ("cas" if counter else "AOE"))
			player.setup_native(1.0)
			_views[id] = player
		var view: Node3D = _views[id]
		var point: Vector2 = effect.pos
		var radius := float(effect.length)
		view.position = PROJECTION.ground(camera, point)
		if counter:
			# 只定位落点，Jax粒子不再接受相机足印变形；高度不计入横向缩放。
			# 与单位模型采用同一地面根点；不额外抬高粒子系统。
			var ray_origin := camera.project_ray_origin(point)
			var ray_direction := camera.project_ray_normal(point)
			view.position = ray_origin + ray_direction * (-ray_origin.y / ray_direction.y)
			view.projection_basis = Basis.IDENTITY
			var native_player = load("res://assets/effects/jax/player.gd")
			view.scale = Vector3.ONE * native_player.NATIVE_SCALE
		else:
			view.projection_basis = PROJECTION.footprint_basis(camera, point, radius)
			view.scale = Vector3.ONE * PROJECTION.ground(camera, point + Vector2(radius, 0)).distance_to(view.position) / SOURCE_RADIUS
		view.seek(maxf(float(effect.duration) - float(effect.timer), 1.0 / 120.0))
	for id in _views.keys():
		if not present.has(id):
			_views[id].free()
			_views.erase(id)
