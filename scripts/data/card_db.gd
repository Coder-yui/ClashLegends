class_name CardDB
extends "res://scripts/data/card_schema.gd"
## 共享定义递归只读；单位运行状态归 Unit，技能实例使用独立副本。
const DEFINITION_COMPILER = preload("res://scripts/data/card_definition_compiler.gd")
const VALIDATOR = preload("res://scripts/data/card_validator.gd")
const DEFINITIONS = [
	preload("res://scripts/data/cards/shurima_guard.gd"),
	preload("res://scripts/data/cards/garen.gd"),
	preload("res://scripts/data/cards/xin.gd"),
	preload("res://scripts/data/cards/ashe.gd"),
	preload("res://scripts/data/cards/teemo.gd"),
	preload("res://scripts/data/cards/gnar.gd"),
	preload("res://scripts/data/cards/melee_minion.gd"),
	preload("res://scripts/data/cards/ranged_minion.gd"),
	preload("res://scripts/data/cards/siege_minion.gd"),
	preload("res://scripts/data/cards/super_minion.gd"),
	preload("res://scripts/data/cards/pix.gd"),
	preload("res://scripts/data/cards/freeze.gd"),
	preload("res://scripts/data/cards/heal.gd"),
	preload("res://scripts/data/cards/masteryi.gd"),
	preload("res://scripts/data/cards/twisted_fate.gd"),
	preload("res://scripts/data/cards/gwen.gd"),
	preload("res://scripts/data/cards/sett.gd"),
	preload("res://scripts/data/cards/tombstone.gd"),
	preload("res://scripts/data/cards/apex_turret.gd"),
	preload("res://scripts/data/cards/sun_disc.gd"),
	preload("res://scripts/data/cards/aurelionsol.gd"),
	preload("res://scripts/data/cards/anivia.gd"),
	preload("res://scripts/data/cards/anivia_egg.gd"),
	preload("res://scripts/data/cards/missfortune.gd"),
	preload("res://scripts/data/cards/imp.gd"),
	preload("res://scripts/data/cards/aatrox.gd"),
	preload("res://scripts/data/cards/rift_herald.gd"),
	preload("res://scripts/data/cards/voidmite.gd"),
]
static var _cards: Dictionary = {}
static var _definition_errors := PackedStringArray()

static func all() -> Dictionary:
	if _cards.is_empty():
		for definition_script in DEFINITIONS:
			var id := String(definition_script.resource_path).get_file().get_basename()
			var definition: Dictionary = definition_script.definition()
			_definition_errors.append_array(DEFINITION_COMPILER.validate(id, definition))
			_cards[id] = compile_definition(definition)
		_freeze(_cards)
	return _cards

static func _freeze(value: Variant) -> void:
	if value is Dictionary or value is Array:
		for child in value.values() if value is Dictionary else value:
			_freeze(child)
		value.make_read_only()

static func validate_all() -> PackedStringArray:
	var errors: PackedStringArray = VALIDATOR.validate_all(all())
	errors.append_array(_definition_errors)
	return errors

## 玩家卡池。保留 selectable 开关供未来纯系统单位使用；当前四类兵线单位也可选。
static func selectable_ids() -> Array:
	var ids: Array = []
	var cards := all()
	for card_id in cards:
		if bool(cards[card_id].get("selectable", true)):
			ids.append(card_id)
	return ids

## 统一读取入口。调用方在确认 has_card() 后可以安全读取；未知 id 返回空字典。
static func get_card(card_id: String) -> Dictionary:
	return all().get(card_id, {})

static func has_card(card_id: String) -> bool:
	return all().has(card_id)

## 只读取可生成的单位/建筑数据；系统召唤物同样是 selectable=false 的正式条目。
static func get_unit_stats(card_id: String) -> Dictionary:
	var stats := get_card(card_id)
	if StringName(stats.get("type", "")) not in [&"unit", &"building"]:
		return {}
	return stats

## 返回一张卡可供主动槽选择的技能集合；一次出战仍只从候选集合中携带一个。
static func active_skills_for(card_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cards := all()
	if not cards.has(card_id):
		return result
	var stats: Dictionary = cards[card_id]
	for configured_skill in stats.get("active_skills", []):
		if configured_skill is Dictionary:
			result.append((configured_skill as Dictionary).duplicate(true))
	return result

static func training_dummy_stats() -> Dictionary:
	return {
		"name": "训练木桩", "hp": 1000000.0, "damage": 0.0, "range": 0.0,
		"speed": 0.0, "interval": 1.0, "first_hit": 0.2,
		"radius": 18.0, "visual_radius": 20.0, "mass": 1000.0, "sight": 0.0,
		"color": Color(0.48, 0.30, 0.16), "is_air": false,
		"building_only": false, "can_attack_air": false, "is_building": true,
	}

static func speed_tier_name(speed: float) -> String:
	if speed >= (SPEED_EXTREMELY_FAST + SPEED_FAST) * 0.5:
		return "极快"
	if speed >= (SPEED_FAST + SPEED_SLIGHTLY_FAST) * 0.5:
		return "快"
	if speed >= (SPEED_SLIGHTLY_FAST + SPEED_MEDIUM) * 0.5:
		return "稍快"
	if speed >= (SPEED_MEDIUM + SPEED_SLIGHTLY_SLOW) * 0.5:
		return "中"
	if speed >= (SPEED_SLIGHTLY_SLOW + SPEED_SLOW) * 0.5:
		return "稍慢"
	if speed >= (SPEED_SLOW + SPEED_EXTREMELY_SLOW) * 0.5:
		return "慢"
	return "极慢"

static func size_tier_name(size_tier: StringName) -> String:
	match size_tier:
		SIZE_EXTREMELY_SMALL:
			return "极小"
		SIZE_SMALL:
			return "小"
		SIZE_SLIGHTLY_SMALL:
			return "稍小"
		SIZE_MEDIUM:
			return "中"
		SIZE_SLIGHTLY_LARGE:
			return "稍大"
		SIZE_LARGE:
			return "大"
		SIZE_EXTREMELY_LARGE:
			return "极大"
	return "未分档"

## 新卡/测试夹具共用编译入口；仅内容构建时合并一次，运行查询零复制。
static func compile_definition(definition: Dictionary) -> Dictionary:
	var stats: Dictionary = DEFINITION_COMPILER.compile(definition)
	if not stats.is_empty() and not stats.has("card_art"):
		stats.card_art = {}
	return stats
