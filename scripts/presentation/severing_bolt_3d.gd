extends Node3D
## QW预警与落雷只读取权威时钟，原生XYZ同比例。
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const PLAYER_PATH := "res://assets/effects/severing_bolt/player.gd"
var _views: Dictionary = {}

func sync_effects(spells: RefCounted, camera: Camera3D, viewer_team: int = 0) -> void:
	var present := {}
	for effect in spells.bolt_effects:
		present[effect.id] = true
		if not _views.has(effect.id):
			var container := Node3D.new()
			add_child(container)
			container.position = PROJECTION.ground(camera, effect.pos)
			var radius := PROJECTION.ground(camera, effect.pos + Vector2(float(effect.radius), 0)).distance_to(container.position)
			var players := []
			var kinds := variants_for(String(effect.kind), int(effect.team), viewer_team)
			for kind in kinds:
				var player: Node3D = load(PLAYER_PATH).new()
				container.add_child(player)
				player.load_kind(kind)
				player.setup_native(radius / 225.0)
				players.append(player)
			_views[effect.id] = {"container": container, "players": players}
		var players: Array = _views[effect.id].players
		var age := float(effect.age)
		if effect.kind == "severing_bolt_hit":
			players[0].seek(age)
			continue
		var windup := float(CardDB.get_card("severing_bolt").spell_windup)
		var impact := float(int(effect.end_tick) - int(effect.start_tick)) * FixedStepClock.STEP
		players[0].visible = age >= windup
		players[0].seek(maxf(0.0, age - windup))
		players[1].visible = age >= impact
		players[1].seek(maxf(0.0, age - impact))
		if players.size() > 2:
			players[2].visible = age >= windup
			players[2].seek(maxf(0.0, age - windup))
	for id in _views.keys():
		if not present.has(id):
			_views[id].container.free()
			_views.erase(id)

## 原版red是附加的敌方红圈；共用预警主体、爆炸与受击仍然保留。
static func variants_for(kind: String, source_team: int, viewer_team: int) -> Array:
	if kind == "severing_bolt_hit": return ["hit"]
	return ["warning", "impact"] if source_team == viewer_team else ["warning", "impact", "warning_red"]
