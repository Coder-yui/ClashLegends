extends Node3D
## 落雷与防御塔失效只消费可靠表现事件；护盾/减速沿用通用提示。
const PLAYER = preload("res://assets/effects/medium_lightning/player.gd")
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const SOURCE_RADIUS := 325.0
var _serial := 0
var _views: Dictionary = {}
var _towers: Array[Dictionary] = []

func track(tower: Tower, view: TowerModel3D) -> void:
	_towers = _towers.filter(func(entry): return entry.tower.get_ref() != null and entry.view.get_ref() != null)
	_towers.append({"tower": weakref(tower), "view": weakref(view)})

func sync_effects(spells: RefCounted, camera: Camera3D) -> void:
	var present := {}
	for effect in spells.lightning_effects:
		if String(effect.kind) not in ["medium_lightning", "medium_lightning_disabled", "medium_lightning_warning", "medium_lightning_warning_enemy"]: continue
		if bool(effect.get("cancelled", false)): continue
		var disabled := String(effect.kind) == "medium_lightning_disabled"
		if not effect.has("medium_view_id"):
			_serial += 1
			effect.medium_view_id = _serial
		var id := int(effect.medium_view_id)
		if not _views.has(id):
			var player := PLAYER.new()
			add_child(player)
			var kind := "disabled" if disabled else "strike"
			if String(effect.kind) == "medium_lightning_warning": kind = "warning"
			if String(effect.kind) == "medium_lightning_warning_enemy": kind = "warning_enemy"
			player.load_kind(kind)
			player.position = PROJECTION.ground(camera, effect.pos)
			var radius := float(effect.radius)
			var unit_scale := PROJECTION.ground(camera, effect.pos + Vector2(radius, 0)).distance_to(player.position) / SOURCE_RADIUS
			player.setup_native(unit_scale)
			var entry := {"player": player, "surfaces": [], "tower": null, "extra": []}
			if disabled:
				for extra_kind in ["tower_hit", "tower_crack"]:
					var extra := PLAYER.new()
					player.add_child(extra)
					extra.load_kind(extra_kind)
					extra.setup_native(1.0)
					entry.extra.append(extra)
				for tracked in _towers:
					var tower = tracked.tower.get_ref()
					var view = tracked.view.get_ref()
					if not is_instance_valid(tower) or not is_instance_valid(view) or tower.is_king: continue
					if tower.global_position.distance_to(effect.pos) > 1.0: continue
					entry.tower = tracked.tower
					# Refresh replaces the old overlay for this tower without stacking tint.
					for old_id in _views.keys():
						if _views[old_id].tower != null and _views[old_id].tower.get_ref() == tower: _remove(old_id)
					for surface in view.presentation_surface_materials():
						var original: Material = surface.next_pass
						var overlay: Material = player.make_overlay(original, surface)
						for extra in entry.extra: overlay = extra.make_overlay(overlay, surface)
						surface.next_pass = overlay
						entry.surfaces.append({"material": surface, "original": original, "overlay": overlay})
					break
			_views[id] = entry
		var entry: Dictionary = _views[id]
		if entry.tower != null:
			var tower = entry.tower.get_ref()
			if not is_instance_valid(tower) or tower.hp <= 0:
				effect["cancelled"] = true
				continue
		present[id] = true
		entry.player.seek(maxf(float(effect.duration) - float(effect.timer), 1.0 / 120.0))
		entry.player.update_attached(true)
		for extra in entry.extra:
			extra.seek(maxf(float(effect.duration) - float(effect.timer), 1.0 / 120.0))
			extra.update_attached(true)
	for id in _views.keys():
		if not present.has(id): _remove(id)

func _remove(id: int) -> void:
	var entry: Dictionary = _views[id]
	for surface in entry.surfaces:
		if surface.material.next_pass == surface.overlay: surface.material.next_pass = surface.original
	entry.player.free()
	_views.erase(id)

func _exit_tree() -> void:
	for id in _views.keys(): _remove(id)

static func resource_manifest(variant: String) -> Dictionary:
	if variant != "default": return {}
	return {"emitter_provider": "res://assets/effects/medium_lightning/player.gd",
		"json": ["res://assets/effects/medium_lightning/strike/sampled.json", "res://assets/effects/medium_lightning/disabled/sampled.json", "res://assets/effects/medium_lightning/warning/sampled.json", "res://assets/effects/medium_lightning/warning_enemy/sampled.json", "res://assets/effects/medium_lightning/tower_hit/sampled.json", "res://assets/effects/medium_lightning/tower_crack/sampled.json"],
		"view": {"script": "res://scripts/presentation/medium_lightning_3d.gd", "collection": "lightning_effects", "kind": "medium_lightning", "duration": 2.1, "flight": false}}
