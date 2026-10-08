extends Node3D
## 巴德R原定义采样：飞行/预警/落地；只读取权威表现时钟。
const PLAYER = preload("res://assets/effects/stasis/native/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
var _views: Dictionary = {}
var _serial := 0

func sync_effects(spells: RefCounted, camera: Camera3D) -> void:
	var present := {}
	for effect in spells.stasis_effects:
		if not effect.has("stasis_view_id"):
			_serial += 1
			effect.stasis_view_id = _serial
		var id := int(effect.stasis_view_id)
		present[id] = true
		var center := _ground(camera, effect.pos)
		var radius := _ground(camera, effect.pos + Vector2(effect.radius, 0)).distance_to(center)
		if not _views.has(id):
			var view := {}
			for source in ["flight", "warning", "impact"]:
				var player := PLAYER.new()
				add_child(player)
				player.projection_basis = Basis.IDENTITY if source == "flight" else _projection_basis(camera, effect.pos, float(effect.radius))
				player.setup_native(source, (_ground(camera, effect.pos + Vector2(1, 0)).distance_to(center) * (110.0 / 350.0)) if source == "flight" else radius / (200.0 if source == "warning" else 350.0))
				view[source] = player
			_views[id] = view
		var view: Dictionary = _views[id]
		view.warning.visible = not effect.impacted
		view.flight.visible = not effect.impacted
		view.impact.visible = effect.impacted
		view.warning.position = center
		view.impact.position = center
		if effect.impacted:
			view.impact.seek(float(effect.duration) - float(effect.timer))
		else:
			var t := float(effect.progress)
			var age := t * float(int(effect.impact_tick) - int(effect.start_tick)) * FixedStepClock.STEP
			# 预警在短飞行窗口内完整出现；不延长真实抵达时间。
			view.warning.seek(0.6 + t * 0.8)
			view.flight.position = PROJECTION.flight_position(camera, effect.origin, effect.pos, t, 160.0, 60.0)
			var duration := float(int(effect.impact_tick) - int(effect.start_tick)) * FixedStepClock.STEP
			view.flight.flight_position_at = func(time: float) -> Vector3: return PROJECTION.flight_position(camera, effect.origin, effect.pos, clampf(time / duration, 0.0, 1.0), 160.0, 60.0)
			view.flight.seek(age)
	for id in _views.keys():
		if not present.has(id):
			for player in _views[id].values(): player.free()
			_views.erase(id)

func _ground(camera: Camera3D, point: Vector2) -> Vector3:
	return PROJECTION.ground(camera, point)

func _projection_basis(camera: Camera3D, point: Vector2, pixel_radius: float) -> Basis:
	return PROJECTION.footprint_basis(camera, point, pixel_radius)

static func resource_manifest(variant: String) -> Dictionary:
	if variant != "default": return {}
	return {"emitter_provider": "res://assets/effects/stasis/native/player.gd", "json": ["res://assets/effects/stasis/native/flight/sampled.json", "res://assets/effects/stasis/native/warning/sampled.json", "res://assets/effects/stasis/native/impact/sampled.json"], "view": {"script": "res://scripts/presentation/stasis_spell_effect_3d.gd", "collection": "stasis_effects", "kind": "stasis", "duration": 2.15, "flight": true}, "target_states": ["stasis"], "paths": ["res://assets/effects/stasis/attached_mesh.gdshader", "res://assets/effects/stasis/attached_gold.gdshader", "res://assets/effects/stasis/native/trail.gdshader", "res://assets/effects/stasis/bard_swirl.png", "res://assets/effects/stasis/zhonya_swirl.png"]}
