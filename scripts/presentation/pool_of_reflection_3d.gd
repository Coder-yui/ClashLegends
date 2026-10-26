extends Node3D
## WW区域与受盾粒子：只读权威状态，XYZ同比例缩放。
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const PLAYER_PATH := "res://assets/effects/pool_of_reflection/player.gd"
var _last_time := -1.0
var _areas: Dictionary = {}
var _shields: Dictionary = {}
var _tails: Array[Dictionary] = []

func _player(kind: String, size: float) -> Node3D:
	var player: Node3D = load(PLAYER_PATH).new()
	add_child(player)
	player.load_kind(kind)
	player.setup_native(size)
	return player

func sync_effects(spells: RefCounted, camera: Camera3D, viewer_team: int) -> void:
	var delta := maxf(0.0, float(spells.pool_visual_time) - _last_time) if _last_time >= 0.0 else 0.0
	_last_time = float(spells.pool_visual_time)
	var present := {}
	for effect in spells.pool_effects:
		present[effect.id] = true
		if not _areas.has(effect.id):
			var point := PROJECTION.ground(camera, effect.pos)
			var radius := PROJECTION.ground(camera, effect.pos + Vector2(float(effect.radius), 0)).distance_to(point)
			var players := [_player("area", radius / 350.0)]
			if int(effect.team) != viewer_team: players.append(_player("area_red", radius / 350.0))
			for player in players: player.position = point
			_areas[effect.id] = players
		for player in _areas[effect.id]: player.seek(float(effect.age))
	for id in _areas.keys():
		if not present.has(id):
			for player in _areas[id]: player.free()
			_areas.erase(id)
	present.clear()
	for unit in get_tree().get_nodes_in_group("combatants"):
		if not unit is Unit or unit.hp <= 0 or not unit.pool_shield_visual() or not unit.visible_to_local_player(): continue
		var id: int = unit.get_instance_id()
		present[id] = true
		if not _shields.has(id): _shields[id] = {"player": _player("shield", 0.0125), "age": 0.0}
		var view: Dictionary = _shields[id]
		view.age += delta
		view.player.position = PROJECTION.ground(camera, unit.global_position) + Vector3.UP * (CardDB.AIR_VISUAL_ELEVATION if unit.is_air else 0.0)
		view.player.seek(float(view.age) if float(view.age) < 5.0 else 1.0 + fmod(float(view.age) - 1.0, 4.0))
	for id in _shields.keys():
		if present.has(id): continue
		var view: Dictionary = _shields[id]
		var tail := _player("break", 0.0125)
		tail.position = view.player.position
		_tails.append({"player": tail, "age": 0.0})
		view.player.free()
		_shields.erase(id)
	for tail in _tails:
		tail.age += delta
		tail.player.seek(float(tail.age))
		if float(tail.age) >= 2.0: tail.player.free()
	_tails.assign(_tails.filter(func(tail): return float(tail.age) < 2.0))
