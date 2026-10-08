extends RefCounted
## 本局法术运行依赖与绘制预热。独立样本不进入权威SpellSystem或事件/音频通路。
const DATA := {
	"lightning": ["res://assets/effects/lightning_spells/electrocute/sampled.json"],
	"zap": ["res://assets/effects/lightning_spells/stormsurge/sampled.json"],
	"stasis": ["res://assets/effects/stasis/native/flight/sampled.json", "res://assets/effects/stasis/native/warning/sampled.json", "res://assets/effects/stasis/native/impact/sampled.json"],
	"explosive_cask": ["res://assets/effects/explosive_cask/mis/systems.json", "res://assets/effects/explosive_cask/tar/systems.json", "res://assets/effects/explosive_cask/native_end/sampled.json"],
}
const VIEWS := {
	"lightning": preload("res://scripts/presentation/lightning_spell_effect_3d.gd"),
	"zap": preload("res://scripts/presentation/lightning_spell_effect_3d.gd"),
	"stasis": preload("res://scripts/presentation/stasis_spell_effect_3d.gd"),
	"explosive_cask": preload("res://scripts/presentation/explosive_cask_3d.gd"),
}
var retained: Array[Resource] = []
var prepared: Array[String] = []
var draws := 0

static func dependency_paths(cards: Dictionary) -> Array[String]:
	var paths: Array[String] = []
	for card in DATA:
		if not cards.has(card): continue
		for path in DATA[card]:
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			_collect_paths(data.get("emitters", []) if data is Dictionary else data, paths)
	return paths

static func _collect_paths(value: Variant, paths: Array[String]) -> void:
	if value is Dictionary:
		for child in value.values(): _collect_paths(child, paths)
	elif value is Array:
		for child in value: _collect_paths(child, paths)
	elif value is String and value.begins_with("res://") and not value.ends_with(".json") and value not in paths:
		paths.append(value)

class Samples extends RefCounted:
	var lightning_effects: Array[Dictionary] = []
	var stasis_effects: Array[Dictionary] = []
	var cask_effects: Array[Dictionary] = []
	var cask_hits: Array[Dictionary] = []

func prepare(cards: Dictionary, world: Node3D, camera: Camera3D, stop: Callable = Callable()) -> void:
	for card in VIEWS:
		if not cards.has(card) or card in prepared: continue
		if stop.is_valid() and bool(stop.call()): return
		var view: Node3D = VIEWS[card].new()
		world.add_child(view)
		var samples := Samples.new()
		var effect := {"id": 1, "kind": card, "origin": Vector2(360, 1000), "pos": Vector2(360, 640), "radius": 110.0,
			"start_tick": 0, "impact_tick": 20, "progress": 0.0, "impacted": false, "duration": 2.15, "timer": 2.15}
		if card in ["lightning", "zap"]: samples.lightning_effects.append(effect)
		elif card == "stasis": samples.stasis_effects.append(effect)
		else: samples.cask_effects.append(effect)
		# 飞行/拖尾、预警、抵达和延迟出生层均经过真实播放器与绘制。
		for step in 32:
			if stop.is_valid() and bool(stop.call()): break
			var age := float(step) * 0.1
			effect.progress = minf(age, 1.0)
			effect.impacted = age >= 1.0
			effect.timer = 2.15 - (age if card in ["lightning", "zap"] else maxf(age - 1.0, 0.0))
			if card == "explosive_cask" and step == 10: samples.cask_hits.append({"id": 1, "pos": effect.pos, "timer": 0.7})
			if not samples.cask_hits.is_empty(): samples.cask_hits[0].timer = maxf(0.0, 0.7 - maxf(age - 1.0, 0.0))
			view.sync_effects(samples, camera)
			_retain(view)
			if DisplayServer.get_name() != "headless":
				RenderingServer.force_draw(false)
				draws += 1
			await world.get_tree().process_frame
		view.free()
		if stop.is_valid() and bool(stop.call()): return
		prepared.append(card)

func _retain(node: Node) -> void:
	if node is MeshInstance3D:
		for resource in [node.mesh, node.material_override]:
			if resource != null and resource not in retained: retained.append(resource)
	for child in node.get_children(): _retain(child)
