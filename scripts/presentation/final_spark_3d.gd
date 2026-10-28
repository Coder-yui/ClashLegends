extends Node3D
## R_cas / R_mis_beam share the cast clock; no target-hit particles.
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const PLAYER_PATH := "res://assets/effects/final_spark/player.gd"
# LuxR TargeterDefinitionLine.overrideBaseRange; not the minimap/display range.
const NATIVE_LENGTH := 3410.0
const NATIVE_HAND_HEIGHT := 160.0
var _views: Dictionary = {}

func sync_effects(spells: RefCounted, camera: Camera3D) -> void:
	var present := {}
	for effect in spells.spark_effects:
		present[effect.id] = true
		if not _views.has(effect.id):
			var container := Node3D.new()
			add_child(container)
			var start := PROJECTION.ground(camera, effect.origin)
			var finish := PROJECTION.ground(camera, effect.pos)
			var native_scale := start.distance_to(finish) / NATIVE_LENGTH
			container.basis = Basis.looking_at((finish - start).normalized(), Vector3.UP, true)
			container.position = start + Vector3.UP * NATIVE_HAND_HEIGHT * native_scale
			var players := []
			for kind in ["cast", "beam"]:
				var player: Node3D = load(PLAYER_PATH).new()
				container.add_child(player)
				player.load_kind(kind)
				player.beam_length = NATIVE_LENGTH
				player.setup_native(native_scale)
				players.append(player)
			_views[effect.id] = {"container": container, "players": players}
		for player in _views[effect.id].players: player.seek(float(effect.age))
	for id in _views.keys():
		if not present.has(id):
			_views[id].container.free()
			_views.erase(id)
