extends RefCounted
## 开局固定的表现资源可达集合；不参与技能资格或战斗结算。
## cards/skills 按观察者的蓝红阵营保存；镜像只扩展本方牌组。
const INHERIT := ["growth_ranged_id", "growth_melee_id", "deployment_upgrade_id", "death_replacement_id", "timed_revival_id"]
const EFFECTS = preload("res://scripts/presentation/effect_resource_manifest.gd")
var effects: Array[Dictionary] = []
var target_states: Dictionary = {}
var errors := PackedStringArray()
var cards: Dictionary = {}
var skills: Dictionary = {}
var _pending: Array[Dictionary] = []

static func for_match(decks: Array, choices: Array) -> RefCounted:
	var plan: RefCounted = load("res://scripts/presentation/match_resource_plan.gd").new()
	for team in decks.size():
		var deck: Array = decks[team]
		var active_copy := deck.slice(0, 2).any(func(id): return bool(CardDB.get_card(String(id)).get("resource_dependencies", {}).get("copy_deck_skills", false)))
		for slot in deck.size():
			var id := String(deck[slot])
			var count := CardDB.active_skills_for(id).size()
			var selected: Array = []
			if count > 0 and (slot < 2 or active_copy):
				selected.append(clampi(int(choices[team].get(id, 0)), 0, count - 1))
			plan._enqueue(id, team, selected)
		for id in MatchResources.SYSTEM_UNIT_BUDGET: plan._enqueue(id, team, [])
	while not plan._pending.is_empty():
		var entry: Dictionary = plan._pending.pop_front()
		plan._references(plan.definition(entry.id, entry.team), entry.team, plan.skills[entry.id][entry.team])
	for id in plan.cards:
		EFFECTS.collect_requests(plan.definition(id), id, plan.effects)
	for request in plan.effects:
		for state in EFFECTS.resolve(request, plan.errors).get("target_states", []): plan.target_states[state] = true
	return plan

func _enqueue(id: String, team: int, selected: Array) -> void:
	if not CardDB.has_card(id):
		errors.append("资源依赖引用未知卡牌: " + id)
		return
	if not cards.has(id):
		cards[id] = []
		skills[id] = {}
	var changed: bool = team not in cards[id]
	if changed:
		cards[id].append(team)
		skills[id][team] = []
	var count := CardDB.active_skills_for(id).size()
	for index in selected:
		if count > 0:
			var clamped := clampi(int(index), 0, count - 1)
			if clamped not in skills[id][team]:
				skills[id][team].append(clamped)
				changed = true
	if changed: _pending.append({"id": id, "team": team})

func _references(value: Variant, team: int, selected: Array) -> void:
	if value is Dictionary:
		for key in value:
			if key in MatchResources.REFERENCES:
				_enqueue(String(value[key]), team, selected if key in INHERIT else [])
			elif key == "deployment_member_ids":
				for id in value[key]: _enqueue(String(id), team, selected)
			_references(value[key], team, selected)
	elif value is Array:
		for child in value: _references(child, team, selected)

func allows(id: String, index: int = -1, team: int = -1) -> bool:
	for side in skills.get(id, {}):
		if team >= 0 and side != team: continue
		if index in skills[id][side] or (index < 0 and not skills[id][side].is_empty()): return true
	return false

func definition(id: String, team: int = -1) -> Dictionary:
	return _filter(CardDB.get_card(id), id, team)

func _filter(base: Dictionary, id: String, team: int) -> Dictionary:
	var result := base.duplicate()
	if base.has("active_skills"):
		var selected: Array = []
		for index in base.active_skills.size():
			if allows(id, index, team): selected.append(base.active_skills[index])
		result.active_skills = selected
	# 技能明确拥有的字段，仅在该技能可达时加入；其他字段默认属于基础能力。
	var claimed := {}
	var available := {}
	var original_skills: Array = CardDB.active_skills_for(id)
	for index in original_skills.size():
		for field in original_skills[index].get("resource_dependencies", {}).get("fields", []):
			claimed[field] = true
			if allows(id, index, team): available[field] = true
	for field in claimed:
		if not available.has(field): result.erase(field)
	if result.has("transformed_stats"):
		result.transformed_stats = _filter(result.transformed_stats, id, team)
	if base.has("visual_scene_paths"):
		var paths: Array = base.visual_scene_paths.duplicate()
		for side in paths.size():
			if side not in cards.get(id, []) or (team >= 0 and side != team): paths[side] = ""
		result.visual_scene_paths = paths
	var capabilities := CardDB.get_card(id).duplicate()
	capabilities.merge(result, true)
	capabilities.active_skills = []
	var original: Array = CardDB.get_card(id).get("active_skills", [])
	for index in original.size():
		if allows(id, index, team): capabilities.active_skills.append(original[index])
	if not capabilities.get("active_skills", []).any(func(skill): return bool(skill.get("uses_skill_resource", false))):
		capabilities.skill_resource_max = 0.0
	if base.has("audio"):
		result.audio = _audio(base.audio, capabilities)
		if result.audio.has("team_overrides"):
			for side in result.audio.team_overrides.size():
				if side not in cards.get(id, []) or (team >= 0 and side != team): result.audio.team_overrides[side] = {}
	return result

func _audio(base: Dictionary, capabilities: Dictionary) -> Dictionary:
	var result := base.duplicate()
	if base.has("events"):
		var events: Dictionary = base.events.duplicate()
		for cue in events.keys():
			if not PresentationEvents.supports(capabilities, String(cue)): events.erase(cue)
		result.events = events
	if base.has("empowered_hit") and not PresentationEvents.supports(capabilities, "empowered_swing"): result.erase("empowered_hit")
	if base.has("team_overrides"):
		result.team_overrides = []
		for entry in base.team_overrides: result.team_overrides.append(_audio(entry, capabilities))
	return result
