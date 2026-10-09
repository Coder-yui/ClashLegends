extends Node3D
## 原版R粒子只读取表现事件；命中与冲击波传播由权威模拟决定。
const PLAYER = preload("res://assets/effects/aurelionsol_r/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
# 按实际渲染标定主轮廓；预警与爆炸的原素材尺寸不同，不能共用缩放。
const TELL_SOURCE_RADIUS := 350.0
const IMPACT_SOURCE_RADIUS := 560.0
var _views: Dictionary = {}
var _serial := 0

func sync_effects(skills: RefCounted, camera: Camera3D, delta: float) -> void:
	var present := {}
	for effect in skills.frontal_effects:
		var shape := String(effect.shape)
		if shape not in ["target_circle", "target_circle_strong", "star_impact", "star_impact_strong", "shockwave"]: continue
		if not effect.has("aurelion_view_id"):
			_serial += 1
			effect.aurelion_view_id = _serial
		var id := int(effect.aurelion_view_id)
		present[id] = true
		var strong := shape.ends_with("strong")
		var tell := shape.begins_with("target_circle")
		var kind := ("strong_" if strong else "") + ("tell" if tell else "impact")
		if shape == "shockwave": kind = "wave"
		var center := PROJECTION.ground(camera, effect.pos)
		var radius := float(effect.length)
		var world_radius := PROJECTION.ground(camera, effect.pos + Vector2(radius, 0)).distance_to(center)
		if not _views.has(id):
			var player := PLAYER.new()
			add_child(player)
			player.load_kind(kind)
			player.position = center
			player.projection_basis = PROJECTION.footprint_basis(camera, effect.pos, radius)
			player.setup_native(world_radius / (TELL_SOURCE_RADIUS if tell else IMPACT_SOURCE_RADIUS))
			var entry := {"player": player, "kind": kind, "age": 0.0}
			if tell:
				var missile := PLAYER.new()
				add_child(missile)
				missile.load_kind("strong_missile" if strong else "missile")
				missile.position = PROJECTION.flight_position(camera, effect.pos, effect.pos, 0.0, 0.0, 420.0)
				missile.setup_native(world_radius / 420.0)
				missile.rotate_x(PI)
				entry.missile = missile
			_views[id] = entry
		var age := float(effect.duration) - float(effect.timer)
		var progress := clampf(age / float(effect.duration), 0.0, 1.0)
		var view: Dictionary = _views[id]
		var player: Node3D = view.player
		view.age = age
		if kind == "wave":
			# 原版网格半径30.5537，曲线在3秒内从14.98扩大到199。
			var source_radius := 30.553667 * (14.977777 + 61.333333 * age)
			var wave_radius := lerpf(float(effect.width), radius, progress)
			player.scale = Vector3.ONE * world_radius * wave_radius / radius / source_radius
		player.seek(progress * (2.4 if strong else 1.4) if tell else age)
		if tell:
			var missile: Node3D = view.missile
			var flight := progress
			missile.visible = true
			missile.position = PROJECTION.flight_position(camera, effect.pos, effect.pos, flight, 0.0, 420.0)
			missile.seek(age)
	for id in _views.keys():
		if not present.has(id):
			var view: Dictionary = _views[id]
			if String(view.kind).ends_with("impact"):
				view.age += delta
				view.player.seek(view.age)
				if float(view.age) < 4.0: continue
			view.player.free()
			if view.has("missile"): view.missile.free()
			_views.erase(id)
