extends Node3D
## W/R 原始发射器采样；所有时间/端点仅读取权威表现数据。
const PLAYER = preload("res://assets/effects/malzahar/player.gd")
const NETHER_GRASP = preload("res://assets/effects/malzahar/nether_grasp/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
# W native geometry shares one conversion across opening, closing, cast and births.
# 70 source units occupy 28 screen pixels; source mesh/height proportions stay intact.
const W_REFERENCE_UNITS := 70.0
const W_REFERENCE_PIXELS := 28.0
const W_CLOSE_TIME := 1.5
const W_CAST_RELEASE := 0.25
const W_BIRTH_RELEASE := 0.25
var views: Dictionary = {}
var serial := 0
func sync_effects(skills: RefCounted, camera: Camera3D) -> void:
	var present := {}
	for effect in skills.frontal_effects:
		if String(effect.shape) not in ["nether_zone", "voidling_birth", "voidling_portal"]: continue
		if not effect.has("malzahar_id"):
			serial += 1
			effect.malzahar_id = serial
		var id: String = "area_" + str(effect.malzahar_id)
		present[id] = true
		var kind := "zone" if String(effect.shape) == "nether_zone" else ("portal_start" if String(effect.shape) == "voidling_portal" else "spawn")
		if not views.has(id):
			var player = NETHER_GRASP.new() if kind == "zone" else PLAYER.new()
			add_child(player)
			player.load_kind(kind)
			player.position = PROJECTION.ground(camera, effect.pos)
			var radius: float = effect.length
			var world_radius := PROJECTION.ground(camera, effect.pos + Vector2(radius, 0)).distance_to(player.position)
			if kind == "zone":
				player.basis = PROJECTION.footprint_basis(camera, effect.pos, radius).scaled(Vector3.ONE * world_radius)
			else:
				# The portal is a volume, not an authoritative range decal.
				# Do not stretch its meshes along the camera's ground projection.
				player.setup_native(_w_scale(camera, effect.pos))
			views[id] = player
		if kind == "zone":
			views[id].seek(float(effect.duration) - float(effect.timer), float(effect.timer))
		else:
			views[id].seek(float(effect.duration) - float(effect.timer) + (W_BIRTH_RELEASE if kind == "spawn" else 0.0))
		if kind == "portal_start":
			var cast_id := id + "_cast"
			present[cast_id] = true
			if not views.has(cast_id):
				var cast := PLAYER.new()
				add_child(cast)
				cast.load_kind("cast")
				cast.position = PROJECTION.ground(camera, effect.pos)
				cast.setup_native(views[id].scale.x)
				views[cast_id] = cast
			# W_cas already contains a 0.25 s emission delay. This event arrives
			# at release, so resume the source clock there instead of delaying twice.
			views[cast_id].seek(float(effect.duration) - float(effect.timer) + W_CAST_RELEASE)

			var end_id := id + "_end"
			var age := float(effect.duration) - float(effect.timer)
			if age >= W_CLOSE_TIME:
				present[end_id] = true
				if not views.has(end_id):
					var closing := PLAYER.new()
					add_child(closing)
					closing.load_kind("portal_end")
					closing.position = views[id].position
					closing.setup_native(views[id].scale.x)
					views[end_id] = closing
				views[end_id].seek(age - W_CLOSE_TIME)

	for actor in get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(actor) or not actor is Unit or actor.card_id != "malzahar" or actor.hp <= 0.0: continue
		if actor.get_visual_action_name() != &"channel" or actor.get_visual_action_time_left() <= 0.0 or not actor.has_continuous_visual_target(): continue
		var eye_ref: WeakRef = actor.get_meta("skill_beam_anchor", null)
		var eye: Node3D = eye_ref.get_ref() as Node3D if eye_ref != null and is_instance_valid(eye_ref.get_ref()) else null
		if eye == null: continue
		var id := "beam_" + str(actor.get_instance_id())
		present[id] = true
		if not views.has(id):
			var player := NETHER_GRASP.new()
			add_child(player)
			player.load_kind("beam")
			views[id] = player
		var start := eye.global_position
		var end := _at_height(camera, actor.get_continuous_visual_target_position(), 1.0)
		views[id].set_endpoints(start, end, camera)
		views[id].seek(actor.get_visual_action_duration() - actor.get_visual_action_time_left(), actor.get_visual_action_time_left())
	for id in views.keys():
		if not present.has(id):
			views[id].free()
			views.erase(id)

func _at_height(camera: Camera3D, screen: Vector2, height: float) -> Vector3:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	return origin + direction * ((height - origin.y) / direction.y)

func _w_scale(camera: Camera3D, point: Vector2) -> float:
	return PROJECTION.ground(camera, point + Vector2(W_REFERENCE_PIXELS, 0)).distance_to(PROJECTION.ground(camera, point)) / W_REFERENCE_UNITS
