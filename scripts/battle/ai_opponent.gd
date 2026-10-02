class_name AIOpponent
extends Node
## 单机策略只读取战况，所有操作仍走正式出牌/主动命令与付款入口。
const THINK_INTERVAL := 1.0
var enabled := true
var _main: Node
var _elixir: ElixirManager
var _think_timer := 0.0
var _planned_card := ""

## 每局独立组牌：保留单位主体，并带一张建筑、一张伤害/控制法术。
static func build_deck() -> Array:
	var units: Array = []
	var buildings: Array = []
	var spells: Array = []
	for card_id in CardDB.selectable_ids():
		var stats: Dictionary = CardDB.get_card(card_id)
		match String(stats.get("type", "unit")):
			"unit": units.append(card_id)
			"building": buildings.append(card_id)
			"spell":
				if stats.get("spell_kind", "") in ["zap", "lightning", "freeze"]:
					spells.append(card_id)
	units.shuffle()
	buildings.shuffle()
	spells.shuffle()
	var deck := units.slice(0, 5)
	deck.append(buildings[0])
	deck.append(spells[0])
	deck.append("heal" if randi() % 2 == 0 else units[5])
	deck.shuffle()
	return deck

func setup(main: Node) -> void:
	_main = main
	_elixir = ElixirManager.new()
	add_child(_elixir)

func sim_tick(delta: float) -> void:
	if not enabled or _main == null or _main.game_over:
		return
	_think_timer -= delta
	if _think_timer > 0.0:
		return
	_think_timer = THINK_INTERVAL
	var candidates: Dictionary = {}
	for card_id in _main.get_authoritative_hand(1):
		var stats: Dictionary = CardDB.get_card(_main.resolved_card_for_team(1, card_id))
		var cost: float = _main.card_cost_for_team(1, card_id)
		if cost > ElixirManager.MAX_ELIXIR:
			continue
		var pos := _position(card_id, stats)
		if pos.is_finite():
			candidates[card_id] = pos
	# 在可用手牌中先选目标再攒费，避免每到6费就把高费牌永久饿死。
	if not candidates.has(_planned_card):
		_planned_card = "" if candidates.is_empty() else String(candidates.keys()[randi() % candidates.size()])
	var reserve := 0.0 if _planned_card.is_empty() else float(_main.card_cost_for_team(1, _planned_card))
	# 高费计划保留预算；其他时候先评估交战技能，避免出牌一直抢走技能费用。
	_try_skills(reserve if reserve > 6.0 else 0.0)
	if not _planned_card.is_empty() and _elixir.can_afford(reserve):
		if _main.play_card(1, _planned_card, candidates[_planned_card], {"elixir": _elixir}):
			_planned_card = ""

func _try_skills(reserve: float) -> void:
	for ability_value in _main._active_skills.ids():
		var ability_id := int(ability_value)
		var entry: Dictionary = _main._active_skills.entry(ability_id)
		if int(entry.team) != 1 or not _main._can_submit_active_skill(ability_id, 1):
			continue
		var unit: Unit = entry.unit
		if not _main._active_skill_is_legal(ability_id, 1):
			continue
		var skill: Dictionary = entry.skill
		var useful := _skill_useful(unit, skill)
		var cost: float = _main._active_skills.cost(ability_id)
		if useful and _elixir.elixir - cost >= reserve:
			_main.use_active_skill(ability_id, 1)

## 根据效果和当前收益决定是否值得消耗次数；不强制清空所有主动。
func _skill_useful(unit: Unit, skill: Dictionary) -> bool:
	if float(skill.get("heal_amount", 0.0)) > 0.0:
		return unit.max_hp - unit.hp >= minf(float(skill.heal_amount) * 0.6, unit.max_hp * 0.25)
	if skill.get("kind", "") == "permanent_growth":
		return ActiveSkillEffectSystem.growth_target(unit, skill) != null
	if bool(skill.get("uses_skill_resource", false)) and unit.get_skill_resource_ratio() < 0.5 and unit.hp > unit.max_hp * 0.35:
		return false
	var reach := float(skill.get("length", skill.get("range", skill.get("radius", unit.attack_range))))
	if skill.get("kind", "") in ["buff", "timed_form", "sanctuary", "empowered_attack"]:
		reach = unit.attack_range + 40.0
	for enemy in get_tree().get_nodes_in_group("combatants"):
		if enemy.team != 0 or enemy.hp <= 0.0 or not CombatInteraction.can_acquire(enemy, 1) or not CombatInteraction.allows(enemy, unit):
			continue
		if unit.global_position.distance_to(enemy.global_position) <= reach + unit.body_radius + enemy.body_radius:
			return true
	return false

func _position(card_id: String, stats: Dictionary) -> Vector2:
	if stats.get("type", "unit") == "spell":
		return _spell_position(card_id, stats)
	var lane := ArenaRules.BRIDGE_X_LEFT if randi() % 2 == 0 else ArenaRules.BRIDGE_X_RIGHT
	var desired := Vector2(lane, 460.0)
	if stats.get("type", "unit") == "building":
		desired = Vector2(360.0, 500.0)
	elif stats.get("deploy_zone", "") == "global":
		# 敌半场塔前落点；合法性查询仍排除河道、塔和建筑占地。
		desired = Vector2(lane, 900.0)
	return _nearest_legal_position(card_id, desired)

func _nearest_legal_position(card_id: String, desired: Vector2) -> Vector2:
	var snapped: Vector2 = _main._snap_card_position(card_id, desired, 1)
	if _main.is_card_deploy_position_valid(1, card_id, snapped):
		return snapped
	var best := Vector2.INF
	var distance := INF
	for y in ArenaRules.ARENA_ROWS:
		for x in ArenaRules.ARENA_COLUMNS:
			var pos: Vector2 = _main._snap_card_position(card_id, Vector2((x + 0.5) * ArenaRules.TILE_SIZE, (y + 0.5) * ArenaRules.TILE_SIZE), 1)
			var d := pos.distance_squared_to(desired)
			if d < distance and _main.is_card_deploy_position_valid(1, card_id, pos):
				best = pos
				distance = d
	return best

func _spell_position(card_id: String, stats: Dictionary) -> Vector2:
	var healing: bool = stats.get("spell_kind", "") == "heal"
	var stasis: bool = stats.get("spell_kind", "") == "stasis"
	var targets := get_tree().get_nodes_in_group("combatants")
	var best := Vector2.INF
	var best_score := 0.0
	for candidate in targets:
		if candidate.hp <= 0.0 or candidate.team != (1 if healing else 0):
			continue
		var pos: Vector2 = _main._snap_card_position(card_id, candidate.global_position, 1)
		if not _main.is_card_deploy_position_valid(1, card_id, pos):
			continue
		var score := 0.0
		for target in targets:
			if target.hp <= 0.0 or CombatInteraction.in_stasis(target) or pos.distance_to(target.global_position) > float(stats.get("radius", 110.0)) + target.body_radius:
				continue
			if healing:
				if target.team == 1 and target is Unit and not target.is_building:
					score += minf(target.max_hp - target.hp, float(stats.get("heal_amount", 200.0)))
			elif stasis:
				if not (target is Tower and target.is_king):
					score += 1.0 if target.team == 0 else -1.0
			elif target.team == 0:
				# 优先打单位群，伤害法术也可用于削塔；控制不空冻水晶。
				if target is Unit:
					score += 1.0
				elif stats.get("spell_kind", "") in ["zap", "lightning"]:
					score += 0.25
		if score > best_score:
			best_score = score
			best = pos
	return best
