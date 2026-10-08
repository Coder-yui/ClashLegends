extends Node3D
## 钢铁烈阳之匣原版施放粒子；仅消费本地/网络共用的护盾表现事件。
const PLAYER = preload("res://assets/effects/locket/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const SOURCE_RADIUS := 800.0
var _views: Dictionary = {}
var _serial := 0

func sync_effects(skills: RefCounted, camera: Camera3D) -> void:
	var present := {}
	for effect in skills.shield_effects:
		if not effect.has("locket_view_id"):
			_serial += 1
			effect.locket_view_id = _serial
		var id := int(effect.locket_view_id)
		present[id] = true
		if not _views.has(id):
			var player := PLAYER.new()
			add_child(player)
			player.position = PROJECTION.ground(camera, effect.pos)
			var radius := float(effect.radius)
			var world_radius := PROJECTION.ground(camera, effect.pos + Vector2(radius, 0)).distance_to(player.position)
			player.projection_basis = PROJECTION.footprint_basis(camera, effect.pos, radius)
			player.setup_native(world_radius / SOURCE_RADIUS)
			_views[id] = player
		_views[id].seek(float(effect.duration) - float(effect.timer))
	for id in _views.keys():
		if not present.has(id):
			_views[id].free()
			_views.erase(id)

static func resource_manifest(variant: String) -> Dictionary:
	if variant != "default": return {}
	return {"emitter_provider": "res://assets/effects/locket/player.gd", "json": ["res://assets/effects/locket/sampled.json"], "view": {"script": "res://scripts/presentation/locket_effect_3d.gd", "collection": "shield_effects", "kind": "sun_disc", "duration": 2.8, "flight": false}}
