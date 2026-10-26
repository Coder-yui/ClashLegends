class_name CardDB
extends "res://scripts/data/card_schema.gd"
## 共享定义递归只读；单位运行状态归 Unit，技能实例使用独立副本。
const DEFINITION_COMPILER = preload("res://scripts/data/card_definition_compiler.gd")
const VALIDATOR = preload("res://scripts/data/card_validator.gd")
const DEFINITIONS = [
	preload("res://scripts/data/cards/severing_bolt.gd"),
	preload("res://scripts/data/cards/pool_of_reflection.gd"),
	preload("res://scripts/data/cards/solar_flare.gd"),
	preload("res://scripts/data/cards/mega_inferno_bomb.gd"),
	preload("res://scripts/data/cards/event_horizon.gd"),
	preload("res://scripts/data/cards/powder_keg.gd"),
	preload("res://scripts/data/cards/tidal_wave.gd"),
	preload("res://scripts/data/cards/medium_lightning.gd"),
	preload("res://scripts/data/cards/jayce.gd"),
	preload("res://scripts/data/cards/blitzcrank.gd"),
	preload("res://scripts/data/cards/ekko.gd"),
	preload("res://scripts/data/cards/samira.gd"),
	preload("res://scripts/data/cards/hecarim.gd"),
	preload("res://scripts/data/cards/malphite.gd"),
	preload("res://scripts/data/cards/jax.gd"),
	preload("res://scripts/data/cards/void_summoning.gd"),
	preload("res://scripts/data/cards/scuttle_crab.gd"),
	preload("res://scripts/data/cards/void_scuttle_crab.gd"),
	preload("res://scripts/data/cards/malzahar.gd"),
	preload("res://scripts/data/cards/voidling.gd"),
	preload("res://scripts/data/cards/void_gate.gd"),
	preload("res://scripts/data/cards/void_spawn.gd"),
	preload("res://scripts/data/cards/void_spawn_single.gd"),
	preload("res://scripts/data/cards/azir.gd"),
	preload("res://scripts/data/cards/sand_soldier.gd"),
	preload("res://scripts/data/cards/explosive_cask.gd"),
	preload("res://scripts/data/cards/nocturne.gd"),
	preload("res://scripts/data/cards/jinx.gd"),
	preload("res://scripts/data/cards/corki.gd"),
	preload("res://scripts/data/cards/target_dummy.gd"),
	preload("res://scripts/data/cards/corrosion.gd"),
	preload("res://scripts/data/cards/tryndamere.gd"),
	preload("res://scripts/data/cards/tristana.gd"),
	preload("res://scripts/data/cards/belveth.gd"),
	preload("res://scripts/data/cards/voidfish.gd"),
	preload("res://scripts/data/cards/voidfish_ranged.gd"),
	preload("res://scripts/data/cards/voidfish_ranged_army.gd"),
	preload("res://scripts/data/cards/voidfish_ranged_single.gd"),
	preload("res://scripts/data/cards/twitch.gd"),
	preload("res://scripts/data/cards/lulu.gd"),
	preload("res://scripts/data/cards/pantheon.gd"),
	preload("res://scripts/data/cards/kayn.gd"),
	preload("res://scripts/data/cards/kayn_assassin.gd"),
	preload("res://scripts/data/cards/kayn_slayer.gd"),
	preload("res://scripts/data/cards/shurima_guard.gd"),
	preload("res://scripts/data/cards/garen.gd"),
	preload("res://scripts/data/cards/xin.gd"),
	preload("res://scripts/data/cards/ashe.gd"),
	preload("res://scripts/data/cards/teemo.gd"),
	preload("res://scripts/data/cards/gnar.gd"),
	preload("res://scripts/data/cards/melee_minion.gd"),
	preload("res://scripts/data/cards/ranged_minion.gd"),
	preload("res://scripts/data/cards/minion_squad.gd"),
	preload("res://scripts/data/cards/melee_minion_squad.gd"),
	preload("res://scripts/data/cards/ranged_minion_squad.gd"),
	preload("res://scripts/data/cards/heavy_minion_squad.gd"),
	preload("res://scripts/data/cards/super_minion_squad.gd"),
	preload("res://scripts/data/cards/siege_minion_squad.gd"),
	preload("res://scripts/data/cards/siege_minion.gd"),
	preload("res://scripts/data/cards/super_minion.gd"),
	preload("res://scripts/data/cards/pix.gd"),
	preload("res://scripts/data/cards/pix_single.gd"),
	preload("res://scripts/data/cards/freeze.gd"),
	preload("res://scripts/data/cards/stasis.gd"),
	preload("res://scripts/data/cards/heal.gd"),
	preload("res://scripts/data/cards/zap.gd"),
	preload("res://scripts/data/cards/lightning.gd"),
	preload("res://scripts/data/cards/mirror.gd"),
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
	preload("res://scripts/data/cards/kayle.gd"),
	preload("res://scripts/data/cards/kayle_ranged.gd"),
	preload("res://scripts/data/cards/sion.gd"),
	preload("res://scripts/data/cards/darius.gd"),
	preload("res://scripts/data/cards/ornn.gd"),
	preload("res://scripts/data/cards/olaf.gd"),
	preload("res://scripts/data/cards/olaf_single.gd"),
	preload("res://scripts/data/cards/kassadin.gd"),
	preload("res://scripts/data/cards/yorick.gd"),
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

static func validate_all(inspect_resources: bool = true) -> PackedStringArray:
	var errors: PackedStringArray = VALIDATOR.validate_all(all(), inspect_resources)
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
	if stats.has("spawn_plan") or StringName(stats.get("type", "")) not in [&"unit", &"building"]:
		return {}
	return stats

## 纯部署卡直接持有唯一计划；旧同质单位卡仅由其自身数量/间距单向投影。
## members 顺序即生成顺序，重复引用表达数量，不再维护第二份 count。
static func deployment_plan(card_id: String) -> Dictionary:
	var card := get_card(card_id)
	if card.has("spawn_plan"):
		return card.spawn_plan
	if get_unit_stats(card_id).is_empty(): return {}
	var members: Array[String] = []
	for index in maxi(int(card.get("deployment_count", 1)), 1): members.append(card_id)
	var plan := {"members": members, "spacing": maxf(float(card.get("deployment_spacing", 0.0)), 0.0), "formation": String(card.get("deployment_formation", "ring"))}
	_freeze(plan)
	return plan

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
	return DEFINITION_COMPILER.compile(definition)

## 金币足够时选择配置的高费部署单位；只在提交前调用，排程保存结果。
static func deployment_card_id(card_id: String, available: float) -> String:
	var upgraded := String(get_card(card_id).get("deployment_upgrade_id", ""))
	if not upgraded.is_empty() and available >= float(get_card(upgraded).get("cost", INF)):
		return upgraded
	return card_id

static func deployment_cost(card_id: String, available: float) -> int:
	return int(get_card(deployment_card_id(card_id, available)).get("cost", 0))
