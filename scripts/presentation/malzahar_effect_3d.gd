extends Node3D
## W/R 原始发射器采样；所有时间/端点仅读取权威表现数据。
const PLAYER = preload("res://assets/effects/malzahar/player.gd")
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
			var player := PLAYER.new()
			add_child(player)
			player.load_kind(kind)
			player.position = PROJECTION.ground(camera, effect.pos)
			var radius: float = effect.length
			var world_radius := PROJECTION.ground(camera, effect.pos + Vector2(radius, 0)).distance_to(player.position)
			if kind == "zone":
				player.projection_basis = PROJECTION.footprint_basis(camera, effect.pos, radius)
				player.setup_native(world_radius / 400.0)
			else:
				# The portal is a volume, not an authoritative range decal.
				# Do not stretch its meshes along the camera's ground projection.
				player.setup_native(_w_scale(camera, effect.pos))
			if kind == "zone":
				var outline := MeshInstance3D.new()
				var ring := TorusMesh.new()
				ring.inner_radius = 392.0
				ring.outer_radius = 400.0
				ring.rings = 64
				ring.ring_segments = 8
				outline.mesh = ring
				var material := StandardMaterial3D.new()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.albedo_color = Color(0.55, 0.08, 0.8, 0.55)
				outline.material_override = material
				outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				player.add_child(outline)
				outline.basis = player.projection_basis
			views[id] = player
		views[id].opacity = smoothstep(0.0, 0.15, float(effect.timer)) if kind == "zone" else 1.0
		# Birth arrives 0.25 s after opening. Its source pre-emission phase
		# has elapsed; resume at that age without imposing a second delay.
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
		var id := "beam_" + str(actor.get_instance_id())
		present[id] = true
		if not views.has(id):
			var player := PLAYER.new()
			add_child(player)
			player.load_kind("beam")
			player.setup_native(0.01)
			views[id] = player
		var player: Node3D = views[id]
		var start := _at_height(camera, actor.get_visual_screen_position() + actor.get_meta("projectile_model_offset", Vector2.ZERO), 3.5)
		var end := _at_height(camera, actor.get_continuous_visual_target_position(), 1.0)
		player.position = start
		var forward := (end - start).normalized()
		var right := forward.cross(Vector3.UP).normalized()
		player.basis = Basis(right, forward.cross(right).normalized(), forward) * 0.01
		player.beam_length = start.distance_to(end) / 0.01
		player._frame = -1
		player.seek(actor.get_visual_action_duration() - actor.get_visual_action_time_left())
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
