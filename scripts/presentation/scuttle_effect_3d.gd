extends Node3D
## 河蟹治疗区与兰顿施放；只读取可靠表现事件。
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
# 兰顿源范围标尺500；河蟹边界网格半径250.15558。
const SOURCE_RADIUS := 500.0
var _views: Dictionary = {}
var _serial := 0
func sync_effects(skills: RefCounted, camera: Camera3D, viewer_team: int = 0) -> void:
	var present := {}
	for effect in skills.frontal_effects:
		if String(effect.get("shape", "")) not in ["scuttle_shrine", "scuttle_void_shrine", "randuin"]: continue
		if not effect.has("scuttle_view_id"):
			_serial += 1
			effect.scuttle_view_id = _serial
		var id := int(effect.scuttle_view_id)
		present[id] = true
		if not _views.has(id):
			var kind := "randuin" if String(effect.shape) == "randuin" else ("shrine_green" if int(effect.team) == viewer_team else "shrine_red")
			if String(effect.shape) == "scuttle_void_shrine": kind = "void_z_visionring_green" if int(effect.team) == viewer_team else "void_z_visionring_red"
			var player: Node3D = load("res://assets/effects/scuttle_crab/" + kind + "/player.gd").new()
			add_child(player)
			player.setup_native(1.0)
			_views[id] = player
			if String(effect.shape) != "randuin":
				var voidborn := String(effect.shape) == "scuttle_void_shrine"
				for suffix in ["ward_antenna_wake"]:
					var layer: Node3D = load("res://assets/effects/scuttle_crab/" + ("void_" if voidborn else "normal_") + suffix + "/player.gd").new()
					layer.name = suffix
					player.add_child(layer)
					layer.setup_native(1.0)
		var view: Node3D = _views[id]
		var point: Vector2 = effect.pos
		var radius := float(effect.length)
		view.position = PROJECTION.ground(camera, point)
		view.projection_basis = PROJECTION.footprint_basis(camera, point, radius)
		view.scale = Vector3.ONE * PROJECTION.ground(camera, point + Vector2(radius, 0)).distance_to(view.position) / (SOURCE_RADIUS if String(effect.shape) == "randuin" else 250.15558)
		view.seek(maxf(float(effect.duration) - float(effect.timer), 1.0 / 120.0))
		if String(effect.shape) != "randuin":
			var age := maxf(float(effect.duration) - float(effect.timer), 0.0)
			for suffix in ["ward_antenna_wake"]:
				var layer := view.get_node(suffix)
				layer.projection_basis = view.projection_basis
				layer.seek(age)
	for id in _views.keys():
		if not present.has(id):
			_views[id].free()
			_views.erase(id)
