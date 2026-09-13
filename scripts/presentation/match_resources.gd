class_name MatchResources
extends RefCounted
## 本局强引用资源集合。加载不消除实例化成本；这里只避免首次使用时读取整套资源。
var resources: Dictionary = {}
var cards: Dictionary = {}
var preparation_usec := 0
const REFERENCES := ["spawn_id", "death_spawn_id", "death_replacement_id", "timed_revival_id"]

func prepare(card_ids: Array) -> void:
	var started := Time.get_ticks_usec()
	for id in card_ids:
		_prepare_card(String(id))
	_collect(CardDB.PRINCESS_TOWER_VISUAL_CONFIG)
	_collect(CardDB.NEXUS_VISUAL_CONFIG)
	preparation_usec += Time.get_ticks_usec() - started

func _prepare_card(id: String) -> void:
	if cards.has(id) or not CardDB.has_card(id):
		return
	cards[id] = true
	_collect(CardDB.get_card(id))
	var art := CardArt.texture_for(id)
	if art != null:
		resources[art.resource_path] = art

func _collect(value: Variant) -> void:
	if value is Dictionary:
		for key in value:
			if key in REFERENCES:
				_prepare_card(String(value[key]))
			_collect(value[key])
	elif value is Array:
		for child in value:
			_collect(child)
	elif value is String and value.begins_with("res://") and not resources.has(value) and ResourceLoader.exists(value):
		resources[value] = load(value)
