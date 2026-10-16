extends Node3D
## 原版223069范围层，读取法术表现时钟；不驱动召唤。
const PLAYER = preload("res://assets/effects/void_summoning/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
# Voiddiscglow1/2: cylinder radius 15 × sampled scale 28 = 420.
# 525 is the surrounding textured quad's extent, not the visible range rim.
const VISIBLE_SOURCE_RADIUS := 420.0
var _views: Dictionary = {}
var _serial := 0

func sync_effects(spells: RefCounted, camera: Camera3D) -> void:
	var present := {}
	for effect in spells.summon_effects:
		if not effect.has("view_id"):
			_serial += 1
			effect.view_id = _serial
		var id := int(effect.view_id)
		present[id] = true
		if not _views.has(id):
			var player := PLAYER.new()
			add_child(player)
			player.position = PROJECTION.ground(camera, effect.pos)
			var radius := PROJECTION.ground(camera, effect.pos + Vector2(effect.radius, 0)).distance_to(player.position)
			player.projection_basis = PROJECTION.footprint_basis(camera, effect.pos, effect.radius)
			player.setup_native(radius / VISIBLE_SOURCE_RADIUS)
			_views[id] = player
		var elapsed := float(effect.duration) - float(effect.timer)
		_views[id].seek(elapsed)
	for id in _views.keys():
		if not present.has(id):
			_views[id].free()
			_views.erase(id)
