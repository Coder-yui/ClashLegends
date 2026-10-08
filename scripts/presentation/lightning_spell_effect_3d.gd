extends Node3D
## 两个法术只消费已派发的落雷位置、年龄；不选择目标，不结算伤害。
const PLAYER = preload("res://assets/effects/lightning_spells/player.gd")
const SKY_HEIGHT_PIXELS := 320.0
var _views: Dictionary = {}
var _serial := 0

func sync_effects(spells: RefCounted, camera: Camera3D) -> void:
	var present := {}
	for effect in spells.lightning_effects:
		if not effect.has("lightning_view_id"):
			_serial += 1
			effect.lightning_view_id = _serial
		var id := int(effect.lightning_view_id)
		present[id] = true
		if not _views.has(id):
			var area := String(effect.kind) == "zap"
			var player := PLAYER.new()
			add_child(player)
			player.position = _ground(camera, effect.pos)
			# 风暴狂涌OutsideRing为1050尺度；电刑Flash为550。
			# 大型电击的120是选敌范围，定点表现不随选敌范围膨胀。
			var radius := float(effect.radius) if area else 90.0
			var world_radius := _ground(camera, effect.pos + Vector2(radius, 0)).distance_to(player.position)
			if area:
				# 地面仍在XZ平面；反投影圆形权威范围，补偿俯视压缩。
				var across := (_ground(camera, effect.pos + Vector2(radius, 0)) - player.position) / world_radius
				var along := (_ground(camera, effect.pos + Vector2(0, radius)) - player.position) / world_radius
				player.ground_basis = Basis(across, Vector3.UP, along)
			player.setup_native("stormsurge" if area else "electrocute", world_radius / (1050.0 if area else 550.0))
			var screen_ground := camera.unproject_position(player.position)
			var screen_up := camera.unproject_position(player.position + Vector3.UP)
			var pixels_per_world_y := maxf(absf(screen_up.y - screen_ground.y), 0.001)
			# 固定适中屏幕高度，避免靠近下方的落雷贯穿整屏。
			player.configure_sky(SKY_HEIGHT_PIXELS / pixels_per_world_y, "stormsurge" if area else "electrocute")
			_views[id] = player
		_views[id].seek(float(effect.duration) - float(effect.timer))
	for id in _views.keys():
		if not present.has(id):
			_views[id].free()
			_views.erase(id)

func _ground(camera: Camera3D, point: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	return origin + direction * ((0.06 - origin.y) / direction.y)

static func resource_manifest(variant: String) -> Dictionary:
	if variant not in ["lightning", "zap"]: return {}
	return {"emitter_provider": "res://assets/effects/lightning_spells/player.gd", "json": ["res://assets/effects/lightning_spells/" + ("electrocute" if variant == "lightning" else "stormsurge") + "/sampled.json"], "view": {"script": "res://scripts/presentation/lightning_spell_effect_3d.gd", "collection": "lightning_effects", "kind": variant, "duration": 2.15, "flight": false}}
