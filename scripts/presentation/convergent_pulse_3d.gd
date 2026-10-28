extends Node3D
## 原生R范围、向内波纹与中心球层整体播放；不以表现反推权威命中。
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const PLAYER_PATH := "res://assets/effects/convergent_pulse/player.gd"
# Indicator_OuterRing_Core: Donut03_Thin's alpha=255 ridge × uniform birthScale 16.
const NATIVE_BOUNDARY_RADIUS := 378.684694082086
# Authored ground plane shared by the core ring/decal; translate the whole system,
# retaining all XYZ proportions and relative layer heights.
const NATIVE_GROUND_Y := -30.0
var _views: Dictionary = {}

func sync_effects(spells: RefCounted, camera: Camera3D, _viewer_team: int = 0) -> void:
	var present := {}
	for effect in spells.pulse_effects:
		present[effect.id] = true
		if not _views.has(effect.id):
			var container := Node3D.new()
			add_child(container)
			container.position = PROJECTION.ground(camera, effect.pos)
			var radius := PROJECTION.ground(camera, effect.pos + Vector2(float(effect.radius), 0)).distance_to(container.position)
			var native_scale := radius / NATIVE_BOUNDARY_RADIUS
			container.position.y -= NATIVE_GROUND_Y * native_scale
			var players := []
			for kind in ["pulse", "ball"]:
				var player: Node3D = load(PLAYER_PATH).new()
				container.add_child(player)
				player.load_kind(kind)
				player.setup_native(native_scale)
				players.append(player)
			_views[effect.id] = {"container": container, "players": players}
		for player in _views[effect.id].players: player.seek(float(effect.age))
	for id in _views.keys():
		if not present.has(id):
			_views[id].container.free()
			_views.erase(id)
