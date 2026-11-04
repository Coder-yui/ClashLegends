extends Node3D
## 原版炸弹/引信/爆炸，只消费固定落点弹体快照和落地事件。
const PLAYER = preload("res://assets/effects/ziggs/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
var _projectiles: Node2D
var _camera: Camera3D
var _missiles: Dictionary = {}
var _impacts: Array[Dictionary] = []
var _tails: Array[Dictionary] = []
func set_sources(projectiles: Node2D, camera: Camera3D) -> void:
	if _projectiles != projectiles:
		if is_instance_valid(_projectiles):
			_projectiles.impact_added.disconnect(_impact)
			_projectiles.visuals_cleared.disconnect(_clear)
		_projectiles = projectiles
		if is_instance_valid(_projectiles):
			_projectiles.impact_added.connect(_impact)
			_projectiles.visuals_cleared.connect(_clear)
	_camera = camera
func _create(kind: String, unit_scale: float) -> Node3D:
	var player := PLAYER.new()
	add_child(player)
	player.load_kind(kind)
	player.setup_native(unit_scale)
	return player
func _process(delta: float) -> void:
	if not is_instance_valid(_camera): return
	var present := {}
	if is_instance_valid(_projectiles):
		for id in _projectiles.visible_view():
			var p: Dictionary = _projectiles.visible_view()[id]
			var visual := String(p.get("visual", ""))
			if visual != "ziggs_bomb" and not visual.begins_with("ziggs_bounce"): continue
			present[id] = true
			var ground := PROJECTION.ground(_camera, p.pos)
			var pixels_per_y := maxf(absf(BattleGroundProjection.unproject(_camera, ground + Vector3.UP).y - BattleGroundProjection.unproject(_camera, ground).y), 0.001)
			var point := ground + Vector3.UP * float(p.visual_height) / pixels_per_y
			if _missiles.has(id) and _missiles[id].visual != visual:
				_retire(_missiles[id])
				_missiles.erase(id)
			if not _missiles.has(id):
				var kind := "basic"
				if visual == "ziggs_bounce": kind = "missile"
				elif visual == "ziggs_bounce_2": kind = "missile2"
				elif visual == "ziggs_bounce_3": kind = "missile3"
				_missiles[id] = {"player": _create(kind, PLAYER.NATIVE_SCALE), "visual": visual, "last": p.pos, "age": 0.0}
			var view: Dictionary = _missiles[id]
			view.age += (p.pos as Vector2).distance_to(view.last) / maxf(float(p.speed), 1.0)
			view.last = p.pos
			view.player.seek_motion(minf(maxf(view.age, 1.0/120.0), 4.9), point, Basis.IDENTITY)
	for id in _missiles.keys():
		if not present.has(id):
			_retire(_missiles[id])
			_missiles.erase(id)
	var paused := is_instance_valid(_projectiles) and _projectiles.get_tree().paused
	for i in range(_impacts.size()-1, -1, -1):
		if not paused: _impacts[i].age += delta
		_impacts[i].player.seek(_impacts[i].age)
		if _impacts[i].age >= _impacts[i].player.sample_duration():
			_impacts[i].player.free()
			_impacts.remove_at(i)
	for i in range(_tails.size()-1, -1, -1):
		var tail: Dictionary = _tails[i]
		if not paused: tail.age += delta
		tail.player.seek_motion(tail.age, tail.player.global_position, Basis.IDENTITY)
		if tail.age >= tail.player.sample_duration():
			tail.player.free()
			_tails.remove_at(i)

func _retire(view: Dictionary) -> void:
	view.player.stop_emission()
	_tails.append({"player": view.player, "age": view.age})
func _impact(point: Vector2, radius: float, _color: Color, visual: StringName) -> void:
	if visual != &"ziggs_explosion" or not is_instance_valid(_camera): return
	# 原生爆炸半径约200；按权威半径等比缩放，不压平地面。
	var player := _create("hit", radius / 40.0 / 200.0)
	player.position = PROJECTION.ground(_camera, point)
	_impacts.append({"player": player, "age": 0.0})
func _clear() -> void:
	for view in _missiles.values(): view.player.free()
	for view in _impacts: view.player.free()
	for view in _tails: view.player.free()
	_missiles.clear()
	_impacts.clear()
	_tails.clear()
