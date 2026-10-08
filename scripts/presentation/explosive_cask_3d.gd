extends Node3D
## Gragas基础R原生网格/粒子，只读取权威飞行与抵达事件。
const PLAYER = preload("res://assets/units/pantheon/arrival/particle_player.gd")
const FLIGHT = preload("res://assets/effects/explosive_cask/mis/flight_player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
# Independent source-unit conversion, retaining the approved barrel size.
const FLIGHT_UNIT_SCALE := 0.00365
const NATIVE_END = preload("res://assets/effects/explosive_cask/native_end/player.gd")
## Original GragasR effect radius from the current spell BIN.
const SOURCE_RADIUS := 350.0
const GROUND = preload("res://scripts/presentation/corrosion_ground_3d.gd")
var _flight: Array = []
var _hit_views: Dictionary = {}
var _hits: Array = []
var _views: Dictionary = {}

func sync_effects(spells: RefCounted, camera: Camera3D) -> void:
	if _flight.is_empty():
		_flight = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/explosive_cask/mis/systems.json"))
	if _hits.is_empty(): _hits = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/explosive_cask/tar/systems.json"))
	var hit_present := {}
	for hit in spells.cask_hits:
		hit_present[hit.id] = true
		var age := 0.7 - float(hit.timer)
		if not _hit_views.has(hit.id):
			var player := PLAYER.new()
			add_child(player)
			player.position = _ground(camera, hit.pos) + Vector3.UP * 0.8
			player.setup("explosive_cask_hit", 0.008, false, "", false, false, _hits)
			_hit_views[hit.id] = {"player": player, "age": 0.0}
		var hit_view: Dictionary = _hit_views[hit.id]
		hit_view.player.advance(maxf(0.0, age - float(hit_view.age)))
		hit_view.age = age
	for id in _hit_views.keys():
		if not hit_present.has(id):
			_hit_views[id].player.free()
			_hit_views.erase(id)
	var present := {}
	for effect in spells.cask_effects:
		var id := int(effect.id)
		present[id] = true
		var center := _ground(camera, effect.pos)
		var world_radius := _ground(camera, effect.pos + Vector2(float(effect.radius), 0)).distance_to(center)
		var impacted := bool(effect.impacted)
		var age := float(effect.duration) - float(effect.timer) if impacted else float(effect.progress) * float(int(effect.impact_tick) - int(effect.start_tick)) * FixedStepClock.STEP
		if not _views.has(id):
			_views[id] = {"player": null, "impacted": not impacted, "age": 0.0, "ring": null, "tail": null}
		var view: Dictionary = _views[id]
		if view.impacted != impacted:
			if is_instance_valid(view.player):
				if impacted:
					var travel_time := float(int(effect.impact_tick) - int(effect.start_tick)) * FixedStepClock.STEP
					view.player.seek_flight(travel_time)
					view.player.finish_flight()
					view.tail = view.player
				else: view.player.free()
			var player: Node3D = NATIVE_END.new() if impacted else FLIGHT.new()
			add_child(player)
			player.position = center if impacted else PROJECTION.flight_position(camera, effect.origin, effect.pos, 0.0, 140.0, 45.0)
			if impacted:
				player.projection_basis = PROJECTION.footprint_basis(camera, effect.pos, float(effect.radius))
				player.setup_native(world_radius / SOURCE_RADIUS)
			else:
				var origin: Vector2 = effect.origin
				var target: Vector2 = effect.pos
				var travel_time := float(int(effect.impact_tick) - int(effect.start_tick)) * FixedStepClock.STEP
				player.position_at = func(time: float) -> Vector3:
					return PROJECTION.flight_position(camera, origin, target, clampf(time / travel_time, 0.0, 1.0), 140.0, 45.0)
				player.setup("explosive_cask", FLIGHT_UNIT_SCALE, false, "", false, false, _flight)
			view.player = player
			view.impacted = impacted
			view.age = 0.0
			if impacted and is_instance_valid(view.ring):
				view.ring.free()
				view.ring = null
		if not impacted:
			view.player.seek_flight(age)
			if not is_instance_valid(view.ring):
				var ring := MeshInstance3D.new()
				var mat := ShaderMaterial.new()
				mat.shader = preload("res://assets/effects/corrosion/range.gdshader")
				mat.set_shader_parameter("rim_color", Color(0.8, 0.4, 1.0))
				ring.material_override = mat
				add_child(ring)
				var helper := GROUND.new()
				helper._update_mesh(ring, Rect2(effect.pos - Vector2.ONE * float(effect.radius), Vector2.ONE * float(effect.radius) * 2.0), camera)
				helper.free()
				view.ring = ring
		if impacted:
			view.player.advance(maxf(0.0, age - float(view.age)))
			if is_instance_valid(view.tail):
				view.tail.advance(maxf(0.0, age - float(view.age)))
				if age >= FLIGHT.TAIL_LIFETIME:
					view.tail.free()
					view.tail = null
		view.age = age
	for id in _views.keys():
		if not present.has(id):
			_views[id].player.free()
			if is_instance_valid(_views[id].tail): _views[id].tail.free()
			if is_instance_valid(_views[id].ring): _views[id].ring.free()
			_views.erase(id)

func _ground(camera: Camera3D, point: Vector2) -> Vector3:
	return PROJECTION.ground(camera, point)

func _impact_basis(camera: Camera3D, point: Vector2, radius: float) -> Basis:
	var unit_scale := _ground(camera, point + Vector2(radius, 0)).distance_to(_ground(camera, point)) / SOURCE_RADIUS
	return PROJECTION.footprint_basis(camera, point, radius).scaled(Vector3.ONE * unit_scale)
