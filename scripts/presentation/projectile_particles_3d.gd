class_name ProjectileParticles3D
extends Node3D
## 读取 ProjectileSystem 的位置/类型及已结算的纯表现事件；不能产生命中。
const FLIGHTS := {&"baron_siege": "sru_junglebuff_baron_siegemin_mis"}
const BURSTS := {&"baron_siege_cast": "sru_junglebuff_baron_siegemin_cas", &"baron_siege_hit": "sru_junglebuff_baron_siegemin_tar"}
var _system: ProjectileSystem
var _camera: Camera3D
var _flights: Dictionary = {}
var _bursts: Array[LolParticleEffect3D] = []

func setup(system: ProjectileSystem, camera: Camera3D) -> void:
	_system = system
	_camera = camera
	process_priority = 20
	system.impact_added.connect(_impact)
	system.visuals_cleared.connect(clear)

func _process(delta: float) -> void:
	if not is_instance_valid(_system):
		queue_free()
		return
	var visible_projectiles := _system.client_projectiles if _system._context.is_net_client() else _system.projectiles
	var seen := {}
	for id in visible_projectiles:
		var p: Dictionary = visible_projectiles[id]
		var visual := StringName(p.get("visual", ""))
		if not FLIGHTS.has(visual): continue
		seen[id] = true
		if not _flights.has(id):
			var effect := LolParticleEffect3D.new()
			add_child(effect)
			effect.setup(FLIGHTS[visual], 0.0072, true)
			_flights[id] = effect
		var instance: LolParticleEffect3D = _flights[id]
		var screen := _system._visual_position(p)
		instance.position = _ground(screen)
		var facing := _ground(screen + _system._direction(p) * 20.0) - instance.position
		instance.rotation.y = atan2(facing.x, facing.z)
		instance.advance(delta)
	for id in _flights.keys():
		if not seen.has(id):
			_flights[id].free()
			_flights.erase(id)
	for i in range(_bursts.size() - 1, -1, -1):
		_bursts[i].advance(delta)
		if _bursts[i].finished():
			_bursts[i].free()
			_bursts.remove_at(i)

func _impact(position_2d: Vector2, _radius: float, _color: Color, visual: StringName) -> void:
	if not BURSTS.has(visual): return
	var effect := LolParticleEffect3D.new()
	add_child(effect)
	effect.position = _ground(position_2d)
	effect.setup(BURSTS[visual], 0.0072)
	_bursts.append(effect)

func _ground(screen: Vector2) -> Vector3:
	var origin := _camera.project_ray_origin(screen)
	var direction := _camera.project_ray_normal(screen)
	return origin + direction * (-origin.y / direction.y)

func clear() -> void:
	for instance in _flights.values(): instance.free()
	for instance in _bursts: instance.free()
	_flights.clear()
	_bursts.clear()
