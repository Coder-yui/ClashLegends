extends RefCounted
## 对局权威所有者：受理/账户引用/牌序/排程/规则与固定阶段。没有 Main 引用。
## 会话阶段仍只在 MatchSession；金币仍只在绑定的 ElixirManager。
signal changed
signal event(kind: String, payload: Dictionary)
signal world_step_finished(dt: float)
const SPELL_SYSTEM_SCRIPT = preload("res://scripts/battle/spell_system.gd")
const SIM_DT = FixedStepClock.STEP
const MATCH_TIME = MatchRules.REGULATION_TIME
const DOUBLE_ELIXIR_TIME = 60.0
const OVERTIME_TRIPLE_ELIXIR_TIME = 60.0
const DOUBLE_ELIXIR_START_TIME = MATCH_TIME - DOUBLE_ELIXIR_TIME
const COMMAND_DELAY_TICKS = CommandSchedule.BUFFER_TICKS
const COMMAND_MAX_LATENCY_TICKS = COMMAND_DELAY_TICKS * 2
const COMMAND_CLOCK_FUTURE_TOLERANCE = 2
const MINION_SPAWN_X_OFFSET = 3.0 * ArenaRules.TILE_SIZE
var mode := "local"
var local_team := 0
var game_over := false
var _match_started := false
var session := MatchSession.new()
const WORLD = preload("res://scripts/battle/battle_world.gd")
var world: WORLD
var _workbench: WorkbenchSession
var _accounts: Dictionary = {}
var ai: AIOpponent
var _combat: CombatResolver
var _movement: MovementSystem
var _spell_system: RefCounted
var _skill_lifecycle: ActiveSkillLifecycle
var _team_attack_boost_system: TeamAttackBoostSystem
var _active_skill_effect_system: RefCounted
var _projectile_system: ProjectileSystem
var _skill_presentation: SkillEffectPresentation
## 场景仅提供节点工厂；受理、生成计划、属性/资格和排程归 Runtime。
var spawn_unit: Callable
var _next_command_id := 1
var _commands := CommandSchedule.new()
var _deployment_rules := DeploymentRules.new()
var _active_skills := ActiveSkillRoster.new()
var _next_active_ability_id := 1
var _next_deployment_group_id := 1
var _minion_waves := MinionWaveSchedule.new()
var _minion_waves_enabled := true
var _deck: Array = []
var _active_skill_choices: Dictionary = {}
var _remote_deck: Array = []
var _remote_active_skill_choices: Dictionary = {}
var _server_decks: Dictionary = {}
var _server_skill_choices: Dictionary = {}
var _authoritative_card_cycles: Dictionary = {}
var _card_history := CardPlayHistory.new()
var _card_growth := MatchCardGrowth.new()
var _match_rules := MatchRules.new()
var _simulation_clock := FixedStepClock.new()
var _sim_tick_id := 0
var _sim_step_active := false
var _battle_simulation := BattleSimulation.new()

func _team_deck(p_team: int) -> Array:
	if mode == "server" and _server_decks.has(p_team): return _server_decks[p_team]
	if p_team != local_team:
		return _remote_deck
	return _deck

func _initialize_authoritative_card_cycle(p_team: int, deck: Array) -> bool:
	if is_net_client(): return false
	if deck.size() != 8:
		_authoritative_card_cycles.erase(p_team)
		return false
	var opening_seed := Crypto.new().generate_random_bytes(8).decode_s64(0) & 0x7fffffffffffffff
	var cycle := CardCycle.new(deck, true, opening_seed)
	_authoritative_card_cycles[p_team] = cycle
	if mode == "server" and not session.session_id.is_empty():
		print("[CARD_ORDER] " + JSON.stringify({"session_id": session.session_id, "team": p_team, "seed": str(opening_seed), "deck": deck, "opening": cycle.hand() + cycle.queue()}))
	event.emit("hand_changed", {"team": p_team})
	return true

func _ensure_authoritative_card_cycle(p_team: int) -> bool:
	if is_net_client(): return false
	var deck := _team_deck(p_team)
	if deck.size() != 8: return false
	var cycle: CardCycle = _authoritative_card_cycles.get(p_team)
	if cycle == null or not cycle.matches(deck):
		return _initialize_authoritative_card_cycle(p_team, deck)
	return true

func get_authoritative_hand(p_team: int) -> Array:
	if is_net_client(): return []
	if not _ensure_authoritative_card_cycle(p_team): return []
	return (_authoritative_card_cycles[p_team] as CardCycle).hand()

func get_authoritative_queue(p_team: int) -> Array:
	if is_net_client(): return []
	if not _ensure_authoritative_card_cycle(p_team): return []
	return (_authoritative_card_cycles[p_team] as CardCycle).queue()

func _authoritative_card_in_hand(p_team: int, card_id: String) -> bool:
	return card_id in get_authoritative_hand(p_team)

func _consume_authoritative_card(p_team: int, card_id: String) -> bool:
	if not _ensure_authoritative_card_cycle(p_team): return false
	if not (_authoritative_card_cycles[p_team] as CardCycle).consume(card_id): return false
	return true

func _resolve_command_execute_tick(input_tick: int = -1) -> int:
	var current_tick := _sim_tick_id
	# -1 只表示 Host/单机本地输入；RPC 入口会拒绝缺失的客户端 input_tick。
	if input_tick < 0:
		return current_tick + COMMAND_DELAY_TICKS
	if input_tick < current_tick - COMMAND_MAX_LATENCY_TICKS:
		return -1
	if input_tick > current_tick + COMMAND_CLOCK_FUTURE_TOLERANCE:
		return -1
	var execute_tick := input_tick + COMMAND_DELAY_TICKS
	# 网络延迟已经耗尽整个 Buffer 时，按明确 late policy 拒绝，不再追加一轮 Buffer。
	if execute_tick <= current_tick:
		return -1
	return execute_tick

func _team_active_skill_choices(p_team: int) -> Dictionary:
	if mode == "server" and _server_skill_choices.has(p_team): return _server_skill_choices[p_team]
	if p_team != local_team:
		return _remote_active_skill_choices
	return _active_skill_choices

func _active_skill_choice_for_team(p_team: int, card_id: String, skill_count: int) -> int:
	if skill_count <= 0:
		return -1
	return clampi(int(_team_active_skill_choices(p_team).get(card_id, 0)), 0, skill_count - 1)

func _card_has_active_for_team(p_team: int, card_id: String) -> bool:
	return _active_card_slot_for_team(p_team, card_id) >= 0

func _active_card_slot_for_team(p_team: int, card_id: String) -> int:
	var team_deck := _team_deck(p_team)
	if team_deck.size() != 8:
		return -1
	for slot_index in range(2):
		if String(team_deck[slot_index]) == card_id:
			return slot_index
	return -1

func card_cost_for_team(p_team: int, card_id: String) -> int:
	if CardPlayHistory.is_mirror(card_id):
		return int(_card_history.get_last(p_team).get("cost", 99))
	var stats := CardDB.get_card(card_id)
	var payer := account(p_team)
	var cost := CardDB.deployment_cost(card_id, payer.elixir if payer != null else 0.0)
	if StringName(stats.get("type", "")) != &"spell":
		return cost
	var cost_bonus := int(stats.get("active_cost_bonus", 0))
	if cost_bonus > 0 and _active_card_slot_for_team(p_team, card_id) >= 0:
		return cost + cost_bonus
	return cost

func resolved_card_for_team(p_team: int, card_id: String) -> String:
	return String(_card_history.get_last(p_team).get("card_id", card_id)) if CardPlayHistory.is_mirror(card_id) else card_id

func _snap_card_position(card_id: String, pos: Vector2, p_team: int = -1) -> Vector2:
	return _deployment_rules.snap_card_position(resolved_card_for_team(p_team, card_id), pos, p_team)

func is_card_deploy_position_valid(p_team: int, card_id: String, pos: Vector2) -> bool:
	if CardPlayHistory.is_mirror(card_id) and _card_history.get_last(p_team).is_empty(): return false
	return _deployment_rules.is_card_deploy_position_valid(p_team, resolved_card_for_team(p_team, card_id), pos)

func spawn_summoned(p_team: int, card_id: String, pos: Vector2, deploy_time_override: float = -1.0, visual_transition: String = "", death_replacement_charges_override: int = -1, summon_visual_origin: Vector2 = Vector2.INF, limit_center: Vector2 = Vector2.INF, limit_radius: float = 0.0) -> Unit:
	var stats: Dictionary = CardDB.get_unit_stats(card_id)
	if stats.is_empty():
		push_error("尝试生成不存在的召唤单位：%s" % card_id)
		return null
	var resolved := _deployment_rules.resolve_summoned_spawn(p_team, card_id, stats, pos, limit_center, limit_radius)
	if not resolved.is_finite():
		push_warning("召唤物没有合法出生点：%s team=%d pos=%s" % [card_id, p_team, pos])
		return null
	# 已检查地形/完整建筑占地及凝滞；不再进入手牌区域修正，也不授予塔墟免衰减。
	return spawn_unit.call(UnitSpawnRequest.new(p_team, card_id, resolved, {"position_resolved": true, "deploy_time_override": deploy_time_override, "visual_transition": visual_transition, "death_replacement_charges_override": death_replacement_charges_override, "summon_visual_origin": summon_visual_origin}))

func _deploy_card(p_team: int, card_id: String, pos: Vector2, input_tick: int = -1, deployment_card_id: String = "", mirror_copy: Dictionary = {}) -> int:
	# 玩家、AI 与联机请求统一从 input_tick 进入 10 Tick 权威队列；召唤物不受此延迟影响。
	pos = _snap_card_position(card_id, pos, p_team)
	var resolved_execute_tick := _resolve_command_execute_tick(input_tick)
	if resolved_execute_tick < 0:
		return -1
	var command_id := _announce_network_command("card", p_team, card_id, -1, pos, resolved_execute_tick)
	_commands.enqueue_card(p_team, card_id, pos, resolved_execute_tick, deployment_card_id, mirror_copy, command_id)
	return resolved_execute_tick

func play_card(p_team: int, card_id: String, pos: Vector2, options: Dictionary = {}) -> bool:
	if not session_allows_commands():
		return false
	if is_net_client() or p_team not in [0, 1] or game_over or not pos.is_finite() or not CardDB.has_card(card_id):
		return false
	var mirror_copy := _card_history.get_last(p_team) if CardPlayHistory.is_mirror(card_id) else {}
	if CardPlayHistory.is_mirror(card_id) and mirror_copy.is_empty(): return false
	var stats := CardDB.get_card(card_id)
	if StringName(stats.get("type", "unit")) == &"spell" and not SPELL_SYSTEM_SCRIPT.supports(StringName(stats.get("spell_kind", ""))):
		return false
	var immediate := bool(options.get("immediate", false))
	if not bool(stats.get("selectable", true)) and not immediate:
		return false
	pos = _snap_card_position(card_id, pos, p_team)
	if bool(options.get("validate_position", true)) and not is_card_deploy_position_valid(p_team, card_id, pos):
		return false
	if bool(options.get("require_team_deck", false)):
		var team_deck := _team_deck(p_team)
		if team_deck.size() != 8 or card_id not in team_deck:
			return false
	if not immediate and not _authoritative_card_in_hand(p_team, card_id):
		return false
	var input_tick := int(options.get("input_tick", -1))
	if not immediate and _resolve_command_execute_tick(input_tick) < 0:
		return false
	var elixir := account(p_team)
	if options.has("elixir") and options.elixir != elixir: return false
	# 主动槽法术（如治疗术的主动选项）的实际费用含 active_cost_bonus；扣费、预检与回滚共用。
	var payer := elixir
	var deployment_card_id := _card_growth.resolved_id(p_team, CardDB.deployment_card_id(card_id, payer.elixir if payer != null else 0.0))
	var card_cost := CardDB.deployment_cost(card_id, payer.elixir if payer != null else 0.0) if stats.has("deployment_upgrade_id") else card_cost_for_team(p_team, card_id)
	if is_net_client(): return false
	if not immediate and elixir == null: return false
	var payment := CommandPayment.charge(elixir, card_cost) if elixir != null else null
	if elixir != null and payment == null: return false
	if immediate:
		if payment != null: payment.settle(false)
		if not mirror_copy.is_empty():
			mirror_copy["generation"] = _card_history.begin_mirror(p_team)
			_cast_spell(p_team, card_id, pos, bool(options.get("preview_active_spell", false)), 0, mirror_copy)
			event.emit("history_changed", {"team": p_team})
			return true
		_card_history.record(p_team, card_id, deployment_card_id, int(CardDB.get_card(deployment_card_id).get("cost", card_cost)))
		event.emit("history_changed", {"team": p_team})
		var type := String(stats.get("type", "unit"))
		if type == "spell":
			var active_enabled := _workbench.enabled and bool(options.get("preview_active_spell", false))
			var active_skill_index := int(_workbench.skill_choices.get(card_id, 0)) if active_enabled else 0
			_cast_spell(p_team, card_id, pos, active_enabled, active_skill_index)
		elif type == "building" or float(stats.get("pre_deploy_time", 0.0)) > 0.0:
			_execute_card_deployment(p_team, card_id, pos, deployment_card_id)
		else:
			_spawn_card_units(p_team, card_id, pos, -1.0, -1, -1, deployment_card_id)
		return true
	# 只有命令已完成权威校验、扣费与手牌轮换后才向客户端确认。
	if not _consume_authoritative_card(p_team, card_id):
		# spend 已经成功时理论上不会失败；保留事务式回滚，避免未来扩展插入中间验证后丢费。
		if payment != null: payment.settle(true)
		return false
	if payment != null: payment.settle(false)
	if not mirror_copy.is_empty():
		mirror_copy["generation"] = _card_history.begin_mirror(p_team)
		_clear_active_slot(p_team, _active_card_slot_for_team(p_team, card_id))
	var execute_tick := _deploy_card(p_team, card_id, pos, input_tick, deployment_card_id, mirror_copy)
	if execute_tick < 0:
		# 仅作为未来扩展的兜底；常规异常 Tick 已在扣费/轮换前被拒绝。
		return false
	if mirror_copy.is_empty():
		_card_history.record(p_team, card_id, deployment_card_id, int(CardDB.get_card(deployment_card_id).get("cost", card_cost)))
	event.emit("history_changed", {"team": p_team})
	event.emit("hand_changed", {"team": p_team})
	event.emit("card_accepted", {"peer": int(options.get("requester_peer_id", 0)), "card_id": card_id, "tick": execute_tick, "team": p_team})
	return true

func _tick_pending_card_deployments(_dt: float) -> void:
	var ready := _commands.take_card_commands(_sim_tick_id)
	for deployment in ready:
		_execute_card_deployment(
			int(deployment.team),
			String(deployment.card_id),
			deployment.pos as Vector2, String(deployment.get("deployment_card_id", "")), deployment.get("mirror_copy", {})
		)
		_complete_network_command(int(deployment.get("command_id", 0)), "executed")

func _tick_pending_card_pre_deployments(dt: float) -> void:
	_combat.begin_batch(_sim_tick_id, "pre_deployment")
	var ready := _commands.take_pre_deployments(dt, world.combatants(), _sim_tick_id)
	_combat.commit_batch()
	for deployment in ready:
		_spawn_card_units(
			int(deployment.team), String(deployment.card_id), deployment.pos as Vector2,
			-1.0, int(deployment.get("active_slot", -1)), int(deployment.get("id", -1)), String(deployment.get("deployment_card_id", "")), int(deployment.get("mirror_generation", -1))
		)

func _execute_card_deployment(p_team: int, card_id: String, pos: Vector2, deployment_card_id: String = "", mirror_copy: Dictionary = {}, slot_override: int = -2, mirror_generation: int = -1) -> void:
	if CardPlayHistory.is_mirror(card_id):
		_cast_spell(p_team, card_id, pos, _card_has_active_for_team(p_team, card_id), 0, mirror_copy)
		return
	var stats: Dictionary = CardDB.get_card(card_id)
	var type: String = stats.get("type", "unit")
	var active_slot := _active_card_slot_for_team(p_team, card_id) if slot_override == -2 else slot_override
	var pre_deploy_time := maxf(float(stats.get("pre_deploy_time", 0.0)), 0.0)
	if pre_deploy_time > 0.0 and type != "spell":
		var pre_deploy_id := _commands.allocate_deployment_id()
		_commands.enqueue_deployment(p_team, card_id, pos, pre_deploy_time, active_slot, pre_deploy_id, pre_deploy_time, deployment_card_id, mirror_generation, _sim_tick_id if _sim_step_active else -1)
		event.emit("pre_deploy", {"id": pre_deploy_id, "card_id": card_id, "team": p_team, "pos": pos, "duration": pre_deploy_time})
		card_event(card_id, "pre_deploy:start", pos, p_team)
		return
	match type:
		"spell":
			var active_skill_index := _active_skill_choice_for_team(p_team, card_id, CardDB.active_skills_for(card_id).size()) if active_slot >= 0 else 0
			if _workbench.enabled: active_skill_index = int(_workbench.skill_choices.get(card_id, 0))
			_cast_spell(p_team, card_id, pos, active_slot >= 0, active_skill_index)
		_:
			_spawn_card_units(p_team, card_id, pos, -1.0, active_slot, -1, deployment_card_id, mirror_generation)

func _cast_spell(p_team: int, card_id: String, pos: Vector2, active_enabled: bool = false, active_skill_index: int = 0, mirror_copy: Dictionary = {}, announce: bool = true) -> bool:
	if CardPlayHistory.is_mirror(card_id):
		if mirror_copy.is_empty(): return false
		var slot := _active_card_slot_for_team(p_team, card_id) if active_enabled else -1
		if _workbench.enabled and active_enabled: slot = 0
		var generation := int(mirror_copy.get("generation", -1))
		if not _card_history.is_latest_mirror(p_team, generation): slot = -1
		_clear_active_slot(p_team, slot)
		var source := String(mirror_copy.card_id)
		# 代次只撤销单位槽位资格；已付款的复制法术仍保留强化效果。
		if String(CardDB.get_card(source).get("type", "")) == "spell":
			var choice := _active_skill_choice_for_team(p_team, source, CardDB.active_skills_for(source).size()) if active_enabled else 0
			if _workbench.enabled: choice = int(_workbench.skill_choices.get(source, 0))
			var copied_cast := _cast_spell(p_team, source, pos, active_enabled, choice, {}, false)
			if copied_cast:
				card_event("mirror", "spell:cast", pos, p_team)
				if active_enabled: cast_notice(p_team, "mirror", 0)
			return copied_cast
		_execute_card_deployment(p_team, String(mirror_copy.card_id), pos, String(mirror_copy.deployment_card_id), {}, slot, generation)
		card_event("mirror", "spell:cast", pos, p_team)
		if active_enabled: cast_notice(p_team, "mirror", 0)
		return true
	var cast: bool = _spell_system.cast(p_team, CardDB.get_card(card_id), pos, active_enabled, active_skill_index)
	if cast and active_enabled and announce: cast_notice(p_team, card_id, active_skill_index)
	if cast and card_id not in ["stasis", "explosive_cask"]:
		card_event(card_id, "spell:cast", pos, p_team)
	return cast

func _spawn_card_units(team: int, card_id: String, pos: Vector2, deploy_time_override: float = -1.0, active_slot: int = -1, pre_deploy_id: int = -1, deployment_card_id: String = "", mirror_generation: int = -1) -> Array[Unit]:
	if not _card_history.is_latest_mirror(team, mirror_generation): active_slot = -1
	var spawn_card_id := card_id if deployment_card_id.is_empty() else deployment_card_id
	var stats := CardDB.get_card(spawn_card_id)
	var plan := CardDB.deployment_plan(spawn_card_id)
	if plan.is_empty(): return []
	if String(stats.get("type", "unit")) == "building":
		var resolved := _deployment_rules.nearest_valid_building_spawn(team, card_id, pos)
		if not resolved.is_finite():
			# 全场没有合法占地时保留已付费命令，下个 Tick 再试，绝不丢牌。
			_commands.enqueue_deployment(team, card_id, pos, FixedStepClock.STEP, active_slot, pre_deploy_id, -1.0, deployment_card_id, mirror_generation)
			return []
		pos = resolved
	var built_on_tower_ruin := (
		bool(stats.get("tower_ruin_foundation", false))
		and _deployment_rules.destroyed_princess_tower_at_card_center(pos) != null
	)
	var member_ids: Array = plan.members
	var count := member_ids.size()
	var spacing := float(plan.spacing)
	var group_id := -1
	if count > 1:
		group_id = _next_deployment_group_id
		_next_deployment_group_id += 1
	var formation := String(plan.formation)
	var offsets := _deployment_formation_offsets(count, spacing, team, formation)
	# 先规划整个编队；无落点时沿用建筑已付费等待队列，不能生成半批再重试。
	var positions: Array[Vector2] = []
	for index in range(count):
		var member_pos := pos + offsets[index]
		var member_card_id := String(member_ids[index])
		var member_stats := CardDB.get_unit_stats(member_card_id)
		var member_radius := float(member_stats.radius)
		member_pos.x = clampf(member_pos.x, member_radius, ArenaRules.FIELD_W - member_radius)
		member_pos.y = clampf(member_pos.y, member_radius, ArenaRules.FIELD_H - member_radius)
		var requested_member_pos := member_pos
		if not bool(member_stats.get("is_air", false)) and not bool(member_stats.get("is_building", false)):
			member_pos = world.nearest_valid_ground_spawn(member_pos, member_radius, team)
		if member_pos.is_finite():
			var anchor_origin := requested_member_pos if not _deployment_rules.anchored_spawn_clear(requested_member_pos, member_stats) else member_pos
			member_pos = _deployment_rules.resolve_anchored_spawn(team, card_id, member_stats, anchor_origin, true)
		if not member_pos.is_finite():
			_commands.enqueue_deployment(team, card_id, pos, FixedStepClock.STEP, active_slot, pre_deploy_id, -1.0, deployment_card_id, mirror_generation)
			return []
		positions.append(member_pos)
	if String(stats.get("type", "unit")) == "building":
		world.push_units_around(pos, float(stats.get("radius", 14.0)))
	var spawned: Array[Unit] = []
	for index in range(count):
		var member_slot := active_slot if index == 0 else -1
		var member_card_id := String(member_ids[index])
		var member_pos := positions[index]
		var skill_source_card_id := card_id
		var member: Unit = spawn_unit.call(UnitSpawnRequest.new(team, member_card_id, member_pos, {
			"deploy_time_override": deploy_time_override,
			"active_slot": member_slot,
			"pre_deploy_id": pre_deploy_id,
			"deployment_group_id": group_id,
			"built_on_tower_ruin": built_on_tower_ruin,
			"active_skill_card_id_override": skill_source_card_id,
			"position_resolved": true,
		}))
		if member != null:
			if _workbench.enabled and mirror_generation >= 0: member.set_meta("workbench_no_skill", active_slot < 0)
			spawned.append(member)
	if _workbench.enabled and not spawned.is_empty(): event.emit("preview_spawned", {"unit": spawned[0]})
	return spawned

func _deployment_formation_offsets(count: int, spacing: float, team: int, formation: String = "ring") -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	if count <= 1:
		offsets.append(Vector2.ZERO)
		return offsets
	if formation == "line":
		for index in range(count):
			offsets.append(Vector2((index - (count - 1) * 0.5) * spacing * (1.0 if team == 0 else -1.0), 0.0))
	elif formation == "depth_line":
		for index in range(count):
			offsets.append(Vector2(0.0, (index - (count - 1) * 0.5) * spacing * (1.0 if team == 0 else -1.0)))
	else:
		var ring_count := count
		if count % 2 == 1 and formation != "polygon":
			offsets.append(Vector2.ZERO)
			ring_count -= 1
		var rotation := 0.0 if team == 0 else PI
		var angle_offset := -PI * 0.5
		if formation == "square":
			# 四个顶点落在对角线上，使上/下两条边保持水平，与横向河道平行。
			angle_offset = -PI * 0.25
		for index in range(ring_count):
			var angle := rotation + angle_offset + TAU * float(index) / float(ring_count)
			offsets.append(Vector2.RIGHT.rotated(angle) * spacing)
	# 奇数多边形的外接圆中心不同于阵型范围中心；统一平移，让点击点上下左右居中。
	var bounds := Rect2(offsets[0], Vector2.ZERO)
	for offset in offsets:
		bounds = bounds.expand(offset)
	var center := bounds.get_center()
	for index in offsets.size():
		offsets[index] -= center
	return offsets

func _register_active_skill(unit: Unit, card_id: String, p_team: int) -> void:
	if unit.active_ability_id < 0 or unit.active_ability_slot < 0 or unit.active_ability_slot >= 2 or not CardDB.has_card(card_id):
		return
	var available_skills := CardDB.active_skills_for(unit.card_id if CardDB.get_card(card_id).has("growth_ranged_id") else card_id)
	if available_skills.is_empty():
		return
	# 备战信息页只允许从候选集合中携带一个；场上实例不会同时获得多个主动技能。
	var chosen_skill_index := int(_workbench.skill_choices.get(card_id, 0)) if _workbench.enabled else _active_skill_choice_for_team(p_team, card_id, available_skills.size())
	var carried_skill: Dictionary = available_skills[chosen_skill_index]
	unit.configure_carried_active_skill(carried_skill)
	var ability_id := unit.active_ability_id
	var replaced_id := _active_skills.register(unit, card_id, p_team, carried_skill)
	if replaced_id >= 0:
		_cancel_pending_active_skill(replaced_id)
		event.emit("skill_removed", {"id": replaced_id})
	unit.died.connect(_on_active_skill_unit_died.bind(ability_id), CONNECT_ONE_SHOT)
	event.emit("skill_registered", {"id": ability_id})

func _on_active_skill_unit_died(ability_id: int) -> void:
	var replacement := _active_skills.transfer(ability_id, living_deployment_members)
	if replacement != null:
		replacement.died.connect(_on_active_skill_unit_died.bind(ability_id), CONNECT_ONE_SHOT)
		return
	_active_skills.remove(ability_id)
	_cancel_pending_active_skill(ability_id, false)
	event.emit("skill_removed", {"id": ability_id})

func _queue_active_skill(ability_id: int, expected_team: int = -1, requester_peer_id: int = 0, input_tick: int = -1) -> bool:
	if is_net_client() or not _can_submit_active_skill(ability_id, expected_team):
		return false
	var entry: Dictionary = _active_skills.entry(ability_id)
	var p_team := int(entry.team)
	var execute_tick := _resolve_command_execute_tick(input_tick)
	if execute_tick < 0:
		return false
	var payment := CommandPayment.charge(account(p_team), _active_skills.cost(ability_id))
	if payment == null:
		return false
	var command_id := _announce_network_command("skill", p_team, String(entry.card_id), ability_id, (entry.unit as Unit).position, execute_tick)
	_commands.enqueue_skill(ability_id, p_team, execute_tick, payment, requester_peer_id, command_id)
	changed.emit()
	return true

func _tick_pending_active_skills(_dt: float) -> void:
	var ready := _commands.take_skill_commands(_sim_tick_id)
	for pending in ready:
		var ability_id := int(pending.ability_id)
		var entry: Dictionary = _active_skills.entry(ability_id)
		var unit = entry.get("unit")
		var alive: bool = is_instance_valid(unit) and unit is Unit and (unit.hp > 0.0 or unit.death_form.waiting())
		if _activate_active_skill(ability_id, int(pending.team)):
			_commands.settle_skill(pending, false)
			_complete_network_command(int(pending.get("command_id", 0)), "executed")
			continue
		_commands.settle_skill(pending, alive)
		_complete_network_command(int(pending.get("command_id", 0)), "cancelled")
		# 已接受命令的取消走带Tick的完成通知；不再提前清除客户端pending。
		changed.emit()

func _cancel_pending_active_skill(ability_id: int, refund: bool = true) -> void:
	for pending in _commands.cancel_skill(ability_id, refund):
		_complete_network_command(int(pending.get("command_id", 0)), "cancelled")

func _tick_active_skill_cooldowns(dt: float) -> void:
	_active_skills.tick(dt)

func grant_skill_recast(unit: Unit) -> void:
	_active_skills.grant_recast(unit.active_ability_id)
	changed.emit()

func get_active_skill_snapshot(ability_id: int) -> Dictionary:
	if not _active_skills.has(ability_id):
		return {}
	var entry: Dictionary = _active_skills.entry(ability_id)
	return {
		"uses_remaining": int(entry.uses_remaining),
		"cooldown_left": maxf(float(entry.cooldown_left), 0.0),
		"free_recast": bool(entry.free_recast),
	}

func _queue_active_skill_impact(source: Unit, skill: Dictionary, impact_delay: float) -> void:
	_commands.schedule_cast(source, skill, impact_delay, _combat.next_displacement_order(source))

func _active_skill_has_qualification(ability_id: int, expected_team: int = -1) -> bool:
	if game_over or not _active_skills.has(ability_id): return false
	var entry := _active_skills.entry(ability_id)
	return _active_skills.qualified(ability_id, expected_team, func(team: int, source: String) -> bool:
		var deck := _team_deck(team)
		var slot := int(entry.slot)
		return slot >= 0 and slot < mini(2, deck.size()) and (String(deck[slot]) == source or CardPlayHistory.is_mirror(String(deck[slot])))
	)

func _can_submit_active_skill(ability_id: int, expected_team: int = -1) -> bool:
	if not session_allows_commands(): return false
	if not _active_skill_has_qualification(ability_id, expected_team): return false
	if _commands.has_pending_skill(ability_id): return false
	var entry: Dictionary = _active_skills.entry(ability_id)
	var payer := account(int(entry.team))
	var cost := _active_skills.cost(ability_id)
	return cost <= 0.0 or (payer != null and payer.elixir >= cost)

func _active_skill_is_legal(ability_id: int, expected_team: int = -1) -> bool:
	if not _active_skill_has_qualification(ability_id, expected_team): return false
	var entry := _active_skills.entry(ability_id)
	return (entry.unit as Unit).can_start_active_skill(entry.skill)

func _activate_active_skill(ability_id: int, expected_team: int = -1) -> bool:
	if is_net_client(): return false
	if not _active_skill_is_legal(ability_id, expected_team):
		# 正常死亡会由 died 信号立即清理；这里保留对失效引用/直接调用的兜底。
		if _active_skills.has(ability_id):
			var stale_entry: Dictionary = _active_skills.entry(ability_id)
			var stale_unit = stale_entry.get("unit")
			if not is_instance_valid(stale_unit) or not stale_unit is Unit or (stale_unit.hp <= 0.0 and not stale_unit.death_form.waiting()):
				_on_active_skill_unit_died(ability_id)
		return false
	var entry: Dictionary = _active_skills.entry(ability_id)
	var unit: Unit = entry.unit
	var skill: Dictionary = _active_skills.skill_for_cast(ability_id)
	if String(skill.get("kind", "")) == "permanent_growth":
		skill = skill.duplicate(true)
		var receipt := ActiveSkillEffectSystem.RefundReceipt.new()
		var old_uses := int(entry.uses_remaining)
		var old_cooldown := float(entry.cooldown_left)
		var cost := _active_skills.cost(ability_id)
		var payer := account(int(entry.team))
		receipt.rollback = func() -> void:
			if game_over: return
			if payer != null: payer.elixir = minf(payer.elixir + cost, ElixirManager.MAX_ELIXIR)
			if _active_skills.has(ability_id):
				_active_skills.replace_replica(ability_id, old_uses, old_cooldown)
				_emit_skill_used(ability_id)
				changed.emit()
		skill["refund_receipt"] = receipt
	if not _start_active_skill_cast(unit, skill):
		return false
	_active_skills.consume(ability_id)
	entry = _active_skills.entry(ability_id)
	_emit_skill_used(ability_id)
	changed.emit()
	return true

func _start_active_skill_cast(unit: Unit, skill: Dictionary) -> bool:
	if not _skill_lifecycle.start(unit, skill): return false
	var source := unit.active_skill_card_id if not unit.active_skill_card_id.is_empty() else unit.card_id
	var skills := CardDB.active_skills_for(source)
	var index := 0
	for i in skills.size():
		if String(skills[i].get("icon_path", "")) == String(skill.get("icon_path", "")): index = i
	cast_notice(unit.team, source, index)
	return true

func _tick_minion_waves(dt: float) -> void:
	_apply_minion_entries(_minion_waves.advance(dt, _match_rules.overtime, _enemy_lane_tower_destroyed))

func _spawn_minion_wave(wave_type: String = MinionWaveSchedule.MINION_WAVE_NORMAL) -> void:
	_apply_minion_entries(_minion_waves.wave(wave_type, _enemy_lane_tower_destroyed))

func _apply_minion_entries(entries: Array[Dictionary]) -> void:
	for entry in entries:
		if entry.has("announcement"):
			event.emit("announcement", {"cue": entry.announcement})
		else:
			_spawn_lane_minion(int(entry.team), int(entry.lane), String(entry.card_id))

func _spawn_lane_minion(team: int, lane: int, card_id: String) -> Unit:
	var x := ArenaRules.FIELD_W * 0.5 + (-MINION_SPAWN_X_OFFSET if lane == 0 else MINION_SPAWN_X_OFFSET)
	var y := 29.0 * ArenaRules.TILE_SIZE if team == 0 else 3.0 * ArenaRules.TILE_SIZE
	var stats: Dictionary = CardDB.get_card(card_id)
	var pos := world.nearest_valid_ground_spawn(Vector2(x, y), float(stats.radius), team)
	return spawn_unit.call(UnitSpawnRequest.new(team, card_id, pos, {"deploy_time_override": 0.0}))

func _enemy_lane_tower_destroyed(team: int, lane: int) -> bool:
	# world.towers_snapshot() 顺序：蓝左、蓝右、红左、红右。己方对应路只看敌方同侧公主塔。
	var enemy_team := 1 - team
	var tower_index := enemy_team * 2 + lane
	return tower_index >= 0 and tower_index < 4 and world.towers_snapshot()[tower_index].hp <= 0.0

func _is_double_elixir_phase() -> bool:
	# 正赛 2:05 起双倍金币；加时全程保持双倍。客户端用收到的比赛时钟；兵线时钟只由权威端推进。
	return _match_rules.overtime or _minion_waves.elapsed + 0.001 >= DOUBLE_ELIXIR_START_TIME or _match_rules.time_left <= DOUBLE_ELIXIR_TIME + 0.001

func _tick_match_rules(dt: float) -> void:
	var outcome := _match_rules.advance(dt, world.king(0).hp, world.king(1).hp, _count_destroyed_towers(0), _count_destroyed_towers(1))
	_update_elixir_rate()
	changed.emit()
	if not outcome.is_empty():
		event.emit("match_finished", outcome)

func _on_overtime_started() -> void:
	_minion_waves.begin_overtime()
	if _minion_waves_enabled and not _workbench.enabled:
		_spawn_minion_wave(MinionWaveSchedule.MINION_WAVE_SIEGE)
	changed.emit()
	_update_elixir_rate()

func _count_destroyed_towers(p_team: int) -> int:
	var count := 0
	for t in world.towers_snapshot():
		if t.team == p_team and t.hp <= 0.0:
			count += 1
	return count

func network_match_snapshot(receiver_team: int = 1) -> Dictionary:
	var state := _match_rules.snapshot()
	var wallet := account(receiver_team)
	state["elixir"] = wallet.elixir if wallet != null else 0.0
	return state

func _update_elixir_rate() -> void:
	var mult := 1.0
	if _match_rules.overtime:
		mult = 3.0 if _match_rules.time_left <= OVERTIME_TRIPLE_ELIXIR_TIME else 2.0
	elif _is_double_elixir_phase():
		mult = 2.0
	for wallet in _accounts.values():
		if is_instance_valid(wallet): wallet.regen_multiplier = mult

func _clear_active_slot(team: int, slot: int) -> void:
	if slot < 0: return
	for id in _active_skills.ids():
		var entry := _active_skills.entry(int(id))
		if int(entry.team) != team or int(entry.slot) != slot: continue
		var unit = entry.get("unit")
		if is_instance_valid(unit):
			unit.active_ability_id = -1
			unit.active_ability_slot = -1
			unit.clear_carried_active_skill_resource()
		_cancel_pending_active_skill(int(id))
		_active_skills.remove(int(id))
		event.emit("skill_removed", {"id": int(id)})

func record_growth_hit(unit: Unit, target: Node2D) -> void:
	if not CardDB.get_card(unit.card_id).has("growth_ranged_id"): return
	_card_growth.record_hit(unit, target)
	event.emit("growth_changed", {})

func growth_snapshot(receiver_team: int = 1) -> Dictionary:
	# 私有成长按接收阵营投影，不泄露对方尚未部署的解锁进度。
	var state := _card_growth.snapshot()
	state.erase(1 - receiver_team)
	return state

func apply_growth_snapshot(value: Dictionary) -> void:
	var modified := _card_growth.apply_snapshot(value)
	if modified: event.emit("growth_changed", {})

func schedule_summon_sequence(team: int, card_id: String, pos: Vector2, count: int, interval: float, deploy_time: float) -> void:
	if is_net_client() or game_over: return
	for index in count:
		_commands.enqueue_summon(team, card_id, pos, 0.25 + index * interval, deploy_time, "void_portal")

func _tick_summon_flights(dt: float) -> void:
	if is_net_client() or game_over: return
	for entry in _commands.take_summons(dt):
		var transition := String(entry.get("transition", ""))
		var summoned := spawn_summoned(int(entry.team), String(entry.card_id), entry.pos, float(entry.deploy_time), transition, -1, entry.pos)
		if transition == "void_portal" and is_instance_valid(summoned):
			_skill_presentation.present_fixed_area(entry.pos, 22.0, 22.0, 1.5, int(entry.team), &"voidling_birth")

func living_deployment_members(group_id: int, p_team: int) -> Array[Unit]:
	var members: Array[Unit] = []
	if group_id < 0:
		return members
	for combatant in world.combatants():
		if combatant is Unit and combatant.hp > 0.0 and not combatant.is_queued_for_deletion():
			if combatant.deployment_group_id == group_id and combatant.team == p_team:
				members.append(combatant)
	return members


func setup(battle_world: RefCounted, workbench: WorkbenchSession, combat: CombatResolver, movement: MovementSystem, spells: RefCounted, lifecycle: ActiveSkillLifecycle, effects: RefCounted, boost: TeamAttackBoostSystem, projectiles: ProjectileSystem, presentation: SkillEffectPresentation, factory: Callable) -> void:
	world = battle_world
	_workbench = workbench
	_combat = combat
	_movement = movement
	_spell_system = spells
	_skill_lifecycle = lifecycle
	_active_skill_effect_system = effects
	_team_attack_boost_system = boost
	_projectile_system = projectiles
	_skill_presentation = presentation
	_commands.impact = effects.apply
	_commands.cast_end = effects.apply_cast_end
	spawn_unit = factory
	_match_rules.overtime_started.connect(_on_overtime_started)
	_simulation_clock.max_ticks_per_advance = 4
	_simulation_clock.max_work_usec = 8000
	_simulation_clock.step = step
	_battle_simulation.setup(self, world)

func step(dt: float) -> void:
	if is_net_client() or game_over: return
	_sim_tick_id += 1
	_sim_step_active = true
	_battle_simulation.step(dt)
	_sim_step_active = false

func is_net_client() -> bool:
	return mode == "client"

func session_allows_commands() -> bool:
	return session.session_id.is_empty() or session.phase == MatchSession.Phase.RUNNING

func account(team: int) -> ElixirManager:
	return _accounts.get(team)

func bind_account(team: int, wallet: ElixirManager) -> void:
	if wallet == null: _accounts.erase(team)
	else: _accounts[team] = wallet

func allocate_ability_id(net_id: int) -> int:
	if net_id >= 0: return net_id
	var id := _next_active_ability_id
	_next_active_ability_id += 1
	return id

func visible_hand_state(team: int) -> Dictionary:
	if not _ensure_authoritative_card_cycle(team): return {}
	return (_authoritative_card_cycles[team] as CardCycle).visible_state(maxi(0, session.request_sequence(team)), _card_history.get_last(team))

func _announce_network_command(kind: String, team: int, card_id: String, ability_id: int, pos: Vector2, execute_tick: int) -> int:
	var id := _next_command_id
	_next_command_id += 1
	event.emit("command_scheduled", {"id": id, "kind": kind, "team": team, "card_id": card_id, "ability_id": ability_id, "pos": pos, "input_tick": execute_tick - COMMAND_DELAY_TICKS, "execute_tick": execute_tick})
	return id

func _complete_network_command(id: int, outcome: String) -> void:
	event.emit("command_finished", {"id": id, "outcome": outcome})

func card_event(card_id: String, cue: String, pos: Vector2, team: int) -> void:
	event.emit("card_event", {"card_id": card_id, "cue": cue, "pos": pos, "team": team})

func cast_notice(team: int, card_id: String, index: int) -> void:
	event.emit("cast_notice", {"team": team, "card_id": card_id, "index": index})

func _emit_skill_used(id: int) -> void:
	var data := get_active_skill_snapshot(id)
	data.id = id
	event.emit("skill_used", data)

func can_request_card(team: int, card_id: String, pos: Vector2) -> bool:
	if not session_allows_commands() or game_over or team not in [0, 1] or not pos.is_finite() or not CardDB.has_card(card_id): return false
	if not bool(CardDB.get_card(card_id).get("selectable", true)): return false
	return is_card_deploy_position_valid(team, card_id, _snap_card_position(card_id, pos, team))

func refresh_skill_readiness() -> void:
	for id in _active_skills.ids():
		var unit = _active_skills.entry(id).get("unit")
		if not is_instance_valid(unit) or (unit.hp <= 0.0 and not unit.death_form.waiting()): _on_active_skill_unit_died(id)
	changed.emit()

func advance_economy(dt: float) -> void:
	_update_elixir_rate()
	for wallet in _accounts.values():
		if is_instance_valid(wallet): wallet.sim_tick(dt)
	if is_instance_valid(ai) and ai.enabled: ai.sim_tick(dt)

func stop() -> void:
	game_over = true
	_match_rules.finish()
	_commands.clear()
	_minion_waves.clear()
	if _projectile_system != null: _projectile_system.clear_all()
	if _spell_system != null: _spell_system.clear()
	if _active_skill_effect_system != null: _active_skill_effect_system.clear()
	if _team_attack_boost_system != null: _team_attack_boost_system.clear()

func apply_match_replica(coins: float, remaining: float, extra_time: bool) -> void:
	if not is_net_client(): return
	_match_rules.apply_replica(remaining, extra_time)
	var wallet := account(local_team)
	if wallet != null: wallet.elixir = coins
	_update_elixir_rate()
	changed.emit()

func schedule_summon_flight(source: Unit, card_id: String, pos: Vector2, duration: float, deploy_time: float) -> bool:
	if is_net_client() or game_over: return false
	var stats := CardDB.get_unit_stats(card_id)
	var radius := float(stats.get("radius", 14.0))
	pos = pos.clamp(Vector2.ONE * radius, Vector2(ArenaRules.FIELD_W, ArenaRules.FIELD_H) - Vector2.ONE * radius)
	if not bool(stats.get("is_air", false)): pos = world.nearest_valid_ground_spawn(pos, radius, source.team)
	if not pos.is_finite(): return false
	_commands.enqueue_summon(source.team, card_id, pos, duration, deploy_time)
	var effect := _skill_presentation.add_summon_flight(source, pos, bool(stats.get("is_air", false)), duration)
	event.emit("skill_fx", effect)
	return true


func clear_preview() -> void:
	_card_history.clear()
	_card_growth.clear()
	_commands.clear()

func apply_skill_replica(id: int, uses: int, cooldown: float, recast: bool = false) -> void:
	if not is_net_client(): return
	_active_skills.replace_replica(id, uses, cooldown, recast)

func clear_replica_skill(unit: Unit) -> void:
	var id := unit.active_ability_id
	if _active_skills.entry(id).get("unit") == unit:
		_active_skills.remove(id)
		event.emit("skill_removed", {"id": id})
	unit.active_ability_id = -1
	unit.active_ability_slot = -1
