extends RefCounted
## 表现库存账单，不改变经济、手牌、出生或活体上限。
## 首次事件账单与旧有限储备政策分离；总生命周期主动次数不转换为并发库存。
const LEGACY_BASE_RESERVE := 2
const LEGACY_CHILD_RESERVE := 32
const LEGACY_PATH_RESERVE := 64
# 开发计划的审阅预算；超出报错，不截断合法单位或静默压缩库存。
const MAX_DECLARED_BATCH := 64
const MAX_GRAPH_DEPTH := 8
const MAX_GRAPH_VISITS := 512
const MAX_FIRST_PATH := 128
const MAX_FIRST_TOTAL := 256
const MAX_STOCK_TOTAL := 512
const ALIASES := ["growth_ranged_id", "growth_melee_id", "deployment_upgrade_id"]
const EVENTS := ["spawn_id", "death_spawn_id", "death_replacement_id", "timed_revival_id", "rush_spawn_id", "assist_conversion_unit_id", "assist_conversion_building_id"]
var errors := PackedStringArray()
var paths := {}
var sources: Array = []
var events: Array = []
var limitations: Array = []
var _plan: RefCounted
var _include_active := true
var policy_paths := {}
var _visits := 0

static func build(cards: Dictionary, plan: RefCounted = null) -> RefCounted:
	var result: RefCounted = load("res://scripts/presentation/match_model_demand.gd").new()
	result._plan = plan
	var definitions := {}
	for id in cards: definitions[id] = plan.definition(id) if plan != null else CardDB.get_card(id)
	result.errors.append_array(validate_development_definitions(definitions))
	if not result.errors.is_empty(): return result
	for team in 2:
		var roots: Array = plan.decks[team] if plan != null and team < plan.decks.size() else cards.keys()
		var mirror := roots.any(func(id): return CardPlayHistory.is_mirror(String(id)))
		var active_mirror := roots.slice(0, 2).any(func(id): return CardPlayHistory.is_mirror(String(id)))
		for id in roots:
			if CardPlayHistory.is_mirror(String(id)): continue
			var timing: float = result._cycle_lower_bound(String(id), roots)
			result._source(String(id), team, "deck:%d:%s" % [team, id], 1, 1, {"kind": "deck", "mirror": false, "active_enabled": true, "repeat_interval": {"minimum_other_plays": 4, "economic_wait_without_rewards": timing, "guaranteed_seconds": 0.0}})
			if mirror:
				# 普通席镜像不复制主动；不为这些副本预留主动召唤/换形库存。
				result._source(String(id), team, "mirror:%d:%s" % [team, id], 1, 1, {"kind": "mirror", "mirror": true, "active_enabled": active_mirror, "repeat_interval": {"minimum_other_plays": 0, "guaranteed_seconds": 0.0}})
		if plan != null:
			for id in MatchResources.SYSTEM_UNIT_BUDGET:
				result._source(id, team, "system:%d:%s" % [team, id], 2, int(MatchResources.SYSTEM_UNIT_BUDGET[id]), {"kind": "system", "mirror": false, "active_enabled": false, "repeat_interval": {"guaranteed_seconds": MinionWaveSchedule.DOUBLE_MINION_WAVE_INTERVAL}})
	if result.errors.is_empty(): result._apply_legacy_reserve(cards)
	return result

func _definition(id: String, team: int) -> Dictionary:
	return _plan.definition(id, team, _include_active) if _plan != null else CardDB.get_card(id)

func _source(id: String, team: int, label: String, burst: int, reserve: int, info: Dictionary) -> void:
	_include_active = bool(info.get("active_enabled", true))
	var event_start := events.size()
	var branch := _expand(id, team, burst, reserve, [], label)
	info = info.duplicate()
	info.merge({"id": id, "team": team, "source": label, "burst": burst, "reserve": reserve, "paths": branch, "events": events.slice(event_start)})
	sources.append(info)
	for path in branch:
		if not paths.has(path): paths[path] = {"initial": 0, "capacity": 0, "uses": [], "sources": []}
		paths[path].initial += int(branch[path].initial)
		paths[path].capacity += int(branch[path].capacity)
		paths[path].uses.append_array(branch[path].uses)
		paths[path].sources.append({"source": label, "initial": branch[path].initial, "capacity": branch[path].capacity, "kind": info.kind, "mirror": info.mirror, "repeat_interval": info.repeat_interval})

func _expand(id: String, team: int, burst: int, reserve: int, ancestors: Array, source: String) -> Dictionary:
	_visits += 1
	if _visits > MAX_GRAPH_VISITS or ancestors.size() > MAX_GRAPH_DEPTH:
		errors.append("Model first-burst graph exceeds development complexity budget")
		return {}
	if burst > MAX_FIRST_PATH or reserve > MAX_FIRST_PATH:
		errors.append("Model first-burst multiplication exceeds development path budget: " + id)
		return {}
	if not CardDB.has_card(id) or (_plan != null and team not in _plan.cards.get(id, [])):
		errors.append("Model demand outside resource plan: %s team=%d source=%s" % [id, team, source])
		return {}
	var base := _definition(id, team)
	for field in MatchResources.REFERENCES:
		if field not in ALIASES and field not in EVENTS:
			errors.append("Unsupported model demand reference semantics: " + String(field))
	var result := {}
	# 回到同一单位只保留这次表现。实际复活资格由charge控制，不再递归累乘。
	var cycle := id in ancestors
	var chain := ancestors + [id]
	var per_form := []
	for form in range(2 if base.has("transformed_stats") else 1):
		var stats := PresentationConfig.for_form(base, form)
		var branch := {}
		var members: Array = stats.get("spawn_plan", {}).get("members", [])
		var multiplicity := int(stats.get("deployment_count", 1)) if ancestors.is_empty() else 1
		var direct := _visuals(id, team, form, stats, burst * multiplicity, reserve * multiplicity, source)
		_merge(branch, direct, false)
		if not cycle:
			# 编队的每个重复成员是独立需求，不对members去重。
			for member in members: _merge(branch, _expand(String(member), team, burst, reserve, chain, source), true)
			# 成长/费用升级是替代来源，非额外出生；同path取max。
			for field in ALIASES:
				if stats.has(field): _merge(branch, _expand(String(stats[field]), team, burst * multiplicity, reserve * multiplicity, chain, source), false)
			for event in _events(stats):
				var declaration: Dictionary = event.duplicate()
				declaration.merge({"source": source, "producer": id, "team": team, "form": form, "producer_burst": burst * multiplicity, "producer_reserve": reserve * multiplicity})
				events.append(declaration)
				var child := _expand(event.id, team, burst * multiplicity * int(event.burst), reserve * multiplicity * int(event.reserve), chain, source)
				# 死亡替换会skip旧死亡表现（Unit._die）；不能把原身体与其后续复生再相加。
				_merge(branch, child, event.field not in ["timed_revival_id", "death_replacement_id"])
				if event.repeat_interval == 0.0 and event.unbounded:
					limitations.append({"source": source, "id": id, "event": event.field, "reason": "event/target limited; no positive guaranteed replenishment interval", "reserve_events": event.reserve})
				elif event.unbounded:
					limitations.append({"source": source, "id": id, "event": event.field, "reason": "continuing producer can outlive retained generations", "repeat_interval": event.repeat_interval, "reserve_events": event.reserve})
		per_form.append(branch)
	# 两形态的同path互斥，但各自独有的资源始终可达。
	for branch in per_form: _merge(result, branch, false)
	return result

func _visuals(id: String, team: int, form: int, stats: Dictionary, burst: int, reserve: int, source: String) -> Dictionary:
	var result := {}
	var path := PresentationConfig.scene_path(stats, team)
	if not path.is_empty():
		result[path] = {"initial": burst, "capacity": reserve, "uses": [{"id": id, "team": team, "form": form, "stats": stats, "source": source, "count": reserve, "initial": burst}]}
	# 死亡后替身是独立表现；和同一分支的复活/变形互斥时取max。
	var followup := String(stats.get("visual_animations", {}).get("death_followup_scene_path", ""))
	if not followup.is_empty() and followup != path:
		result[followup] = {"initial": burst, "capacity": reserve, "uses": [{"id": id, "team": team, "form": form, "stats": stats, "source": source + ":death-followup", "count": reserve, "initial": burst, "auxiliary": true}]}
	return result

static func _merge(target: Dictionary, extra: Dictionary, additive: bool) -> void:
	for path in extra:
		if not target.has(path):
			target[path] = extra[path].duplicate()
			target[path].uses = extra[path].uses.duplicate()
		else:
			target[path].initial = int(target[path].initial) + int(extra[path].initial) if additive else maxi(int(target[path].initial), int(extra[path].initial))
			target[path].capacity = int(target[path].capacity) + int(extra[path].capacity) if additive else maxi(int(target[path].capacity), int(extra[path].capacity))
			target[path].uses.append_array(extra[path].uses)

static func _events(stats: Dictionary) -> Array:
	var result := []
	for field in EVENTS:
		if not stats.has(field): continue
		var count := int(stats.get(field.trim_suffix("_id") + "_count", 1))
		var interval := 0.0
		var repeats := 1
		var unbounded := false
		if field == "spawn_id":
			interval = float(stats.get("spawn_interval", 0.0))
			if interval > 0.0: unbounded = true
		elif field == "timed_revival_id": interval = float(stats.get("timed_revival_delay", 0.0))
		elif field == "rush_spawn_id" or field.begins_with("assist_conversion_"):
			unbounded = true
		result.append({"id": String(stats[field]), "field": field, "burst": count, "reserve": count * repeats, "repeat_interval": interval, "unbounded": unbounded})
	for skill in stats.get("active_skills", []):
		if not skill.has("spawn_id"): continue
		var count := int(skill.get("spawn_count", 1))
		var unlimited := bool(skill.get("unlimited_uses", false))
		result.append({"id": String(skill.spawn_id), "field": "active_skills.spawn_id", "burst": count, "reserve": count, "lifetime_uses": int(skill.get("max_uses", 1)), "repeat_interval": float(skill.get("cooldown", 0.0)), "unbounded": unlimited})
	return result

## 只作来源说明：4次其他出牌后才能回手；忽略金币奖励可得非保证的经济下界。
## 奖励能缩短等待，故库存初始不依赖此数削减。
func _cycle_lower_bound(id: String, roots: Array) -> float:
	var costs: Array = []
	for other in roots:
		if String(other) != id and not CardPlayHistory.is_mirror(String(other)): costs.append(int(CardDB.get_card(String(other)).get("cost", 0)))
	costs.sort()
	if costs.size() < 4: return 0.0
	var spend := 2 * int(CardDB.get_card(id).get("cost", 0))
	for index in 4: spend += int(costs[index])
	return maxf(0.0, float(spend) - ElixirManager.MAX_ELIXIR) * ElixirManager.REGEN_INTERVAL / 3.0

## 保留任务开始时的有限储备政策，不把“代数×生产批数×主动用途”重新相乘。
## 独立系统4份相加；32/64仅是明确保留的旧缓存政策，不是合法活体上限。
func _apply_legacy_reserve(cards: Dictionary) -> void:
	for team in 2:
		var roots: Array = _plan.decks[team] if _plan != null and team < _plan.decks.size() else cards.keys()
		var mirror := roots.any(func(id): return CardPlayHistory.is_mirror(String(id)))
		var active_mirror := roots.slice(0, 2).any(func(id): return CardPlayHistory.is_mirror(String(id)))
		for replica in range(2 if mirror else 1):
			_include_active = replica == 0 or active_mirror
			var reachable := {}
			for id in roots:
				if not CardPlayHistory.is_mirror(String(id)): _deck_reachable(String(id), team, reachable)
			var summoned := {}
			for id in reachable:
				var base := _definition(id, team)
				var maximum := {}
				for form in range(2 if base.has("transformed_stats") else 1):
					var stats := PresentationConfig.for_form(base, form)
					var counts := {}
					for member in stats.get("spawn_plan", {}).get("members", []): counts[member] = int(counts.get(member, 0)) + 1
					for field in ALIASES:
						if stats.has(field): counts[stats[field]] = int(counts.get(stats[field], 0)) + 1
					for event in _events(stats): counts[event.id] = int(counts.get(event.id, 0)) + int(event.burst)
					for child in counts: maximum[child] = maxi(int(maximum.get(child, 0)), int(counts[child]))
				for child in maximum: summoned[child] = int(summoned.get(child, 0)) + int(maximum[child]) * int(base.get("deployment_count", 1))
			for id in reachable:
				var base := _definition(id, team)
				# 系统成员仅经编队可达时，没有额外的默认出牌来源。
				var own := maxi(LEGACY_BASE_RESERVE, int(base.get("deployment_count", 1))) if not MatchResources.SYSTEM_UNIT_BUDGET.has(id) or id in roots else 0
				var quantity := maxi(own, mini(LEGACY_CHILD_RESERVE, int(summoned.get(id, 0)) * LEGACY_BASE_RESERVE))
				var seen := {}
				for form in range(2 if base.has("transformed_stats") else 1):
					var path := PresentationConfig.scene_path(PresentationConfig.for_form(base, form), team)
					if path.is_empty() or seen.has(path): continue
					seen[path] = true
					_add_policy(path, quantity, {"kind": "legacy-mirror" if replica else "legacy-deck", "id": id, "team": team, "quantity": quantity, "own_floor": own, "one_batch_references": int(summoned.get(id, 0))})
		if _plan != null:
			for id in MatchResources.SYSTEM_UNIT_BUDGET:
				var path := PresentationConfig.scene_path(_definition(id, team), team)
				_add_policy(path, int(MatchResources.SYSTEM_UNIT_BUDGET[id]), {"kind": "system", "id": id, "team": team, "quantity": int(MatchResources.SYSTEM_UNIT_BUDGET[id])})
	var first_total := 0
	var stock_total := 0
	for path in paths:
		var entry: Dictionary = paths[path]
		var first := int(entry.initial)
		# 无旧主模型spec的死亡替身原先有默认2份，不能再当无人领取的附属场景删除。
		var legacy := mini(LEGACY_PATH_RESERVE, int(policy_paths.get(path, {}).get("capacity", 2)))
		entry.first_burst = first
		entry.legacy_reserve = legacy
		entry.capacity = maxi(first, legacy)
		entry.initial = maxi(first, ceili(float(legacy) / 2.0))
		entry.policy = policy_paths.get(path, {"capacity": 2, "sources": [{"kind": "legacy-death-followup-default", "quantity": 2}]})
		first_total += first
		stock_total += int(entry.capacity)
		if first > MAX_FIRST_PATH: errors.append("Model first-burst path exceeds development budget: " + path)
	if first_total > MAX_FIRST_TOTAL: errors.append("Model first-burst total exceeds development review budget: %d > %d" % [first_total, MAX_FIRST_TOTAL])
	if stock_total > MAX_STOCK_TOTAL: errors.append("Model finite stock exceeds development review budget: %d > %d" % [stock_total, MAX_STOCK_TOTAL])

func _add_policy(path: String, quantity: int, source: Dictionary) -> void:
	if not policy_paths.has(path): policy_paths[path] = {"capacity": 0, "sources": []}
	policy_paths[path].capacity += quantity
	policy_paths[path].sources.append(source)

func _deck_reachable(id: String, team: int, reachable: Dictionary) -> void:
	if reachable.has(id): return
	reachable[id] = true
	var base := _definition(id, team)
	for form in range(2 if base.has("transformed_stats") else 1):
		var stats := PresentationConfig.for_form(base, form)
		for member in stats.get("spawn_plan", {}).get("members", []): _deck_reachable(String(member), team, reachable)
		for field in ALIASES:
			if stats.has(field): _deck_reachable(String(stats[field]), team, reachable)
		for event in _events(stats): _deck_reachable(event.id, team, reachable)

## 开发数据门禁，不运行实体。未来一般生产自环须扩展有界合同，不能静默放行。
static func validate_development_definitions(definitions: Dictionary) -> PackedStringArray:
	var failures := PackedStringArray()
	var state := {"visits": 0}
	for id in definitions: _validate_graph(String(id), definitions, [], state, failures)
	return failures

static func _validate_graph(id: String, definitions: Dictionary, chain: Array, state: Dictionary, failures: PackedStringArray, quantity: int = 1) -> void:
	if not failures.is_empty(): return
	state.visits += 1
	if int(state.visits) > MAX_GRAPH_VISITS or chain.size() > MAX_GRAPH_DEPTH:
		failures.append("Model dependency graph exceeds development complexity budget at " + id)
		return
	if not definitions.has(id):
		failures.append("Model dependency outside declared definitions: " + id)
		return
	if quantity > MAX_FIRST_PATH:
		failures.append("Model nested first-burst multiplication exceeds development path budget: " + id)
		return
	var base: Dictionary = definitions[id]
	for form in range(2 if base.has("transformed_stats") else 1):
		var stats := PresentationConfig.for_form(base, form)
		for field in ["deployment_count", "spawn_count", "death_spawn_count", "rush_spawn_count"]:
			if int(stats.get(field, 1)) > MAX_DECLARED_BATCH or int(stats.get(field, 1)) < 1:
				failures.append("Model declared batch requires development review: %s.%s" % [id, field])
		var members: Array = stats.get("spawn_plan", {}).get("members", [])
		if members.size() > MAX_DECLARED_BATCH: failures.append("Model deployment members exceed development batch budget: " + id)
		var edges := []
		for member in members: edges.append({"id": String(member), "field": "spawn_plan"})
		for field in ALIASES:
			if stats.has(field): edges.append({"id": String(stats[field]), "field": field})
		for event in _events(stats):
			if int(event.burst) > MAX_DECLARED_BATCH or int(event.burst) < 1: failures.append("Model event batch requires development review: " + id)
			edges.append(event)
		for edge in edges:
			if edge.id in chain + [id]:
				var other: Dictionary = definitions.get(edge.id, {})
				var finite_revival: bool = (edge.field == "timed_revival_id" and int(stats.get("timed_revival_death_replacement_charges", -1)) == 0 and String(other.get("death_replacement_id", "")) == id and int(other.get("death_replacement_charges", 0)) > 0) or (edge.field == "death_replacement_id" and String(other.get("timed_revival_id", "")) == id and int(other.get("timed_revival_death_replacement_charges", -1)) == 0 and int(stats.get("death_replacement_charges", 0)) > 0)
				var finite_uninherited_active: bool = edge.field == "active_skills.spawn_id" and edge.id == id and not bool(edge.get("unbounded", true)) and int(edge.get("lifetime_uses", 0)) > 0
				if not finite_revival and not finite_uninherited_active: failures.append("Unsupported model production cycle requires explicit bounded contract: " + str(chain + [id, edge.id]))
				continue
			_validate_graph(edge.id, definitions, chain + [id], state, failures, quantity * int(stats.get("deployment_count", 1)) * int(edge.get("burst", 1)))
