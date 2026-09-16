class_name MatchResources
extends RefCounted
## 本局强引用资源集合；覆盖双方卡组、衍生形态/召唤物及世界音频。模型实例由 MatchModelPool 预建。
var resources: Dictionary = {}
var cards: Dictionary = {}
var preparation_usec := 0
var particle_systems: Array = []
var _world_prepared := false
var errors := PackedStringArray()
# 系统兵线每种单位可占两路；准备两波重叠窗口，根集合与预算使用同一声明。
const SYSTEM_UNIT_BUDGET := {"melee_minion": 4, "ranged_minion": 4, "siege_minion": 4, "super_minion": 4}
const REFERENCES := ["spawn_id", "death_spawn_id", "death_replacement_id", "timed_revival_id", "rush_spawn_id"]

func prepare(card_ids: Array) -> void:
	var started := Time.get_ticks_usec()
	for id in card_ids:
		_prepare_card(String(id))
	if not _world_prepared:
		_collect(CardDB.PRINCESS_TOWER_VISUAL_CONFIG)
		_collect(CardDB.NEXUS_VISUAL_CONFIG)
		_collect(preload("res://scripts/data/world_audio.gd").DEFINITIONS)
		_collect(preload("res://scripts/data/match_audio.gd").EVENTS, &"AudioStream")
		_collect("res://assets/arena/rift_arena/rift_arena.tscn")
		_world_prepared = true
	particle_systems = LolParticleEffect3D.dependencies_for(cards)
	_collect(LolParticleEffect3D.dependency_paths(particle_systems))
	preparation_usec += Time.get_ticks_usec() - started

func _prepare_card(id: String) -> void:
	if cards.has(id) or not CardDB.has_card(id):
		return
	cards[id] = true
	_collect(CardDB.get_card(id))
	var art := CardArt.texture_for(id)
	if art != null:
		resources[art.resource_path] = art

func _collect(value: Variant, expected: StringName = &"") -> void:
	if value is Dictionary:
		for key in value:
			if key in REFERENCES:
				_prepare_card(String(value[key]))
			var child_type := expected
			if key == "audio": child_type = &"AudioStream"
			elif key == "card_art": child_type = &"Texture2D"
			elif key in ["visual_scene_path", "visual_scene_paths", "visual_active_buff_scene", "death_followup_scene_path"]: child_type = &"PackedScene"
			_collect(value[key], child_type)
	elif value is Array or value is PackedStringArray:
		for child in value:
			_collect(child, expected)
	elif value is String and value.begins_with("res://"):
		var resource: Resource = resources.get(value)
		if resource == null:
			if not ResourceLoader.exists(value):
				errors.append("本局资源不存在: " + value)
				return
			resource = load(value)
		if resource == null: errors.append("本局资源加载失败: " + value)
		elif expected != &"" and not resource.is_class(expected): errors.append("本局资源类型错误（期望%s）: %s" % [expected, value])
		else: resources[value] = resource
