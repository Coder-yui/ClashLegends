extends Node3D
## 只读可靠法术时钟；原版E/W的XYZ同比例，不改变权威接触范围。
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const PLAYER_PATH := "res://assets/effects/event_horizon/player.gd"
var _views: Dictionary = {}
func sync_effects(spells: RefCounted, camera: Camera3D, viewer_team: int = 0) -> void:
	var present := {}
	for effect in spells.horizon_effects:
		present[effect.id] = true
		if not _views.has(effect.id):
			var container := Node3D.new()
			add_child(container)
			container.position = PROJECTION.ground(camera, effect.pos)
			var radius := PROJECTION.ground(camera, effect.pos + Vector2(float(effect.radius),0)).distance_to(container.position)
			var kinds: Array = ["warning", "cage"] if effect.kind == "event_horizon" else ["meteor", "impact"]
			if int(effect.get("team", 0)) != viewer_team:
				kinds = ["warning_red", "cage_red"] if effect.kind == "event_horizon" else ["meteor_red", "impact_red"]
			var players := []
			for kind in kinds:
				var player: Node3D = load(PLAYER_PATH).new()
				container.add_child(player)
				player.load_kind(kind)
				player.setup_native(radius / (390.0 if effect.kind == "event_horizon" else 225.0))
				players.append(player)
			_views[effect.id] = {"container": container, "players": players}
		var players: Array = _views[effect.id].players
		var age := float(effect.age)
		if effect.kind == "event_horizon":
			var windup := float(CardDB.get_card("event_horizon").spell_windup)
			players[0].seek(age)
			players[1].visible = age >= windup
			players[1].seek(maxf(0.0,age-windup))
		else:
			var delay := float(int(effect.end_tick)-int(effect.start_tick))*FixedStepClock.STEP
			players[0].seek(age)
			players[1].visible = age >= delay
			players[1].seek(maxf(0.0,age-delay))
	for id in _views.keys():
		if not present.has(id):
			_views[id].container.free()
			_views.erase(id)

static func resource_manifest(variant: String) -> Dictionary:
	var kinds := ["warning", "warning_red", "cage", "cage_red"] if variant == "cage" else (["meteor", "meteor_red", "impact", "impact_red"] if variant == "meteor" else [])
	if kinds.is_empty(): return {}
	var json_paths: Array[String] = []
	for kind in kinds: json_paths.append("res://assets/effects/event_horizon/" + kind + "/sampled.json")
	return {"emitter_provider": PLAYER_PATH, "json": json_paths}
