extends Node3D
## 原生R预警/冲击与P日光；仅读取权威表现窗口及单位快照。
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const PLAYER_PATH := "res://assets/effects/solar_flare/player.gd"
var _views: Dictionary = {}
var _marks: Dictionary = {}

func _player(parent: Node3D, kind: String, scale_value: float) -> Node3D:
	var player: Node3D = load(PLAYER_PATH).new()
	parent.add_child(player)
	player.load_kind(kind)
	player.setup_native(scale_value)
	return player

func sync_effects(spells: RefCounted, camera: Camera3D, viewer_team: int = 0) -> void:
	var present := {}
	for effect in spells.solar_effects:
		present[effect.id] = true
		if not _views.has(effect.id):
			var container := Node3D.new()
			add_child(container)
			container.position = PROJECTION.ground(camera, effect.pos)
			var radius := PROJECTION.ground(camera, effect.pos + Vector2(float(effect.radius), 0)).distance_to(container.position)
			var players := []
			for kind in (["consume"] if effect.kind == "sunlight_consume" else ["warning" if int(effect.team) == viewer_team else "warning_red", "impact"]):
				players.append(_player(container, kind, radius / (60.0 if kind == "consume" else 250.0)))
			_views[effect.id] = {"container": container, "players": players}
		var players: Array = _views[effect.id].players
		var age := float(effect.age)
		if effect.kind == "sunlight_consume":
			players[0].seek(age)
			continue
		var impact := float(int(effect.end_tick) - int(effect.start_tick)) * FixedStepClock.STEP
		# 0.25秒施法，再展示原生0.625秒预警；20Hz上取整至0.9秒。
		players[0].visible = age >= 0.25 and age < impact
		players[0].seek(maxf(0.0, age - 0.25))
		players[1].visible = age >= impact
		players[1].seek(maxf(0.0, age - impact))
	for id in _views.keys():
		if not present.has(id):
			_views[id].container.free()
			_views.erase(id)
	var marked := {}
	for unit in get_tree().get_nodes_in_group("combatants"):
		if not (unit is Unit or unit is Tower) or unit.hp <= 0 or unit.sunlight_visual() <= 0: continue
		var id: int = unit.get_instance_id()
		marked[id] = true
		if not _marks.has(id):
			var native_scale := PROJECTION.ground(camera, unit.global_position + Vector2(100.0, 0)).distance_to(PROJECTION.ground(camera, unit.global_position)) / 250.0
			_marks[id] = _player(self, "mark", native_scale)
		var player: Node3D = _marks[id]
		player.position = PROJECTION.ground(camera, unit.global_position) + Vector3.UP * (1.2 + (CardDB.AIR_VISUAL_ELEVATION if unit is Unit and unit.is_air else 0.0))
		player.seek(maxf(0.0, 2.5 - unit.sunlight_visual()))
	for id in _marks.keys():
		if not marked.has(id):
			_marks[id].free()
			_marks.erase(id)
