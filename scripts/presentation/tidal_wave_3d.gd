extends Node3D
## Source Nami R sampled geometry; authority owns all positions and hits.
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
var _views: Dictionary = {}

func sync_effects(spells: RefCounted, camera: Camera3D) -> void:
	var present := {}
	for effect in spells.tidal_effects:
		present[effect.id] = true
		var start := PROJECTION.ground(camera, effect.origin)
		var end := PROJECTION.ground(camera, effect.pos)
		var width := PROJECTION.ground(camera, effect.origin + Vector2(float(effect.radius) * 2.0, 0.0)).distance_to(start)
		if not _views.has(effect.id):
			var player: Node3D = load("res://assets/effects/tidal_wave/player.gd").new()
			add_child(player)
			player.load_kind("wave")
			player.setup_native(width / 600.0)
			_views[effect.id] = player
		var player: Node3D = _views[effect.id]
		var progress := float(effect.progress)
		var duration := float(int(effect.end_tick) - int(effect.start_tick)) * FixedStepClock.STEP
		var age := progress * duration + float(effect.get("tail", 0.0))
		# 原浪潮沿局部+Y推进、+Z为浪峰高度；刚性转轴，不改变XYZ比例。
		player.seek_motion(age, start.lerp(end, progress), Basis.looking_at((end-start).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5), (end-start) / duration, minf(age, duration))
	for id in _views.keys():
		if not present.has(id):
			_views[id].free()
			_views.erase(id)

static func resource_manifest(variant: String) -> Dictionary:
	if variant != "default": return {}
	return {"emitter_provider": "res://assets/effects/tidal_wave/player.gd", "json": ["res://assets/effects/tidal_wave/wave/sampled.json"]}
