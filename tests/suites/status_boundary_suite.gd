class_name StatusBoundarySuite
extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	for tower in _main._towers: tower.can_attack = false
	_check_thaw_command()
	_check_command_clock()
	_check_first_render_stun()
	_check_revival_order()
	_check_facing_and_replica()
	_check_formal_skill_ticks()
	_check_gnar_transition_edges()
	_check_region_birth()
	_check_submission_boundary()

func _check_thaw_command() -> void:
	var deck: Array = _main._deck.duplicate()
	_main._deck[0] = "gnar"
	_main._elixir.elixir = 10.0
	var unit: Unit = _main._spawn_unit(0, "gnar", Vector2(160, 1000), 0.0, 0)
	var id := unit.active_ability_id
	_expect(_main.use_active_skill(id, 0), "纳尔正式请求合法入队")
	var request: Dictionary = _main._commands.skill_commands.back()
	var due := int(request.execute_tick)
	unit.freeze((due - _main._sim_tick_id) * _main.SIM_DT)
	unit.transform_hit_count = 5
	var target: Unit = _main._spawn_unit(1, "garen", Vector2(160, 900), 0.0)
	target.stun(10.0)
	_main.launch_attack(unit, target, 1.0, 10000.0, 0.0, 0.0, unit.color)
	_main._tick_projectiles(_main.SIM_DT)
	_expect(unit.pending_form_generation == unit.form_change_serial, "冻结中第六枚真实弹体记录同代待变形")
	_run_main_ticks(due - _main._sim_tick_id)
	_expect(unit.form_index == 1 and unit.is_form_transitioning() and unit.active_skill_cast_serial == 0, "解冻边界先兑现被动变形，拒绝新施法")
	_expect(_main._active_skills[id].uses_remaining == _main._active_skills[id].max_uses and _main._active_skills[id].cooldown_left == 0.0, "拒绝请求不消费次数或启动冷却")
	_expect(is_equal_approx(_main._elixir.elixir, 10.0), "变形拒绝经原收据退款")
	_main._elixir.elixir = 4.0
	_main._commands.settle_skill(request, true)
	_expect(is_equal_approx(_main._elixir.elixir, 4.0), "重复结算不重复退款，验证时不依赖上限截断")
	_main._on_active_skill_unit_died(id)
	unit.free()
	target.free()
	_main._deck = deck

func _check_command_clock() -> void:
	var deck: Array = _main._deck.duplicate()
	_main._deck[0] = "sett"
	_main._elixir.elixir = 10.0
	var unit: Unit = _main._spawn_unit(0, "sett", Vector2(160, 1000), 0.0, 0)
	var id := unit.active_ability_id
	_expect(_main.use_active_skill(id, 0), "计时回归从正式请求开始")
	var due := int(_main._commands.skill_commands.back().execute_tick)
	_run_main_ticks(due - _main._sim_tick_id)
	var duration := float(_main._active_skills[id].skill.cast_duration)
	_expect(is_equal_approx(unit.active_skill_cast_timer, duration) and is_equal_approx(unit.get_visual_action_time_left(), duration), "Cast Start 创建边界不扣施法锁或动作窗口")
	_run_main_ticks(int(ceil(duration / _main.SIM_DT)) - 1)
	_expect(unit.is_active_skill_casting(), "结束前一 Tick 仍锁定")
	_run_main_ticks(1)
	_expect(not unit.is_active_skill_casting(), "首个达到时长的边界解锁")
	_main._on_active_skill_unit_died(id)
	unit.free()
	_main._deck = deck

func _check_first_render_stun() -> void:
	var unit: Unit = _main._spawn_unit(0, "sett", Vector2(160, 1000), 0.0)
	var view: UnitModel3D
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit: view = child
	_main._start_active_skill_cast(unit, CardDB.active_skills_for("sett")[0])
	unit.stun(1.0)
	view._process(0.0)
	_expect(view._playing_visual_action and view._active_action_name == &"active", "技能开始后首次模型更新前眩晕，仍消费权威技能动作")
	unit.free()

func _check_revival_order() -> void:
	var results: Array = []
	for egg_first in [true, false]:
		var egg: Unit
		var attacker: Unit
		if egg_first:
			egg = _main._spawn_unit(1, "anivia_egg", Vector2(160, 950), 0.0)
			attacker = _main._spawn_unit(0, "masteryi", Vector2(160, 1000), 0.0)
		else:
			attacker = _main._spawn_unit(0, "masteryi", Vector2(160, 1000), 0.0)
			egg = _main._spawn_unit(1, "anivia_egg", Vector2(160, 950), 0.0)
		egg.position = Vector2(360, 900)
		attacker.position = Vector2(360, 930)
		egg._timed_revival_left = 0.1
		attacker._target = egg
		attacker._attacking = true
		attacker.attack_timeline.windup = 0.05
		attacker.attack_timeline.cooldown = 0.0
		attacker._just_deployed = false
		var before := egg.hp
		_run_main_ticks(1)
		print("EGG_TRACE ", [before, egg.hp, attacker._attacking, attacker._attack_swing_count, attacker.attack_timeline.windup, attacker.attack_timeline.cooldown])
		_expect(egg.hp < before and egg.hp > 0.0, "孵化前一 Tick 的近战实际命中蛋")
		var attack_count := attacker._attack_swing_count
		attacker.attack_timeline.recovery = 0.0
		attacker.attack_timeline.windup = 0.05
		attacker.attack_timeline.cooldown = 0.0
		var receipt: Dictionary = {}
		_main.launch_attack(attacker, egg, 1.0, 1.0, 0.0, 0.0, attacker.color)
		_run_main_ticks(1)
		var phoenix: Unit
		for c in _main.get_tree().get_nodes_in_group("combatants"):
			if c is Unit and c.card_id == "anivia" and c.team == 1: phoenix = c
		_expect(egg.hp == 0.0 and not egg.is_in_group("combatants") and phoenix != null, "孵化边界完整退休旧蛋并生成新凤凰")
		_expect(attacker._attack_swing_count == attack_count and attacker._target != egg, "孵化边界不接受旧蛋近战，不推进未命中攻击段")
		_expect(phoenix.control.permissions() == ControlState.ALL_PERMISSIONS and phoenix._attack_swing_count == 0, "新凤凰不继承控制且不加入出生边界行动")
		receipt = {"hp": phoenix.hp, "attacks": attacker._attack_swing_count, "target_old": attacker._target == egg}
		results.append(receipt)
		_main._tick_projectiles(1000.0)
		_expect(phoenix.hp == receipt.hp, "旧蛋在途弹体不转移给新凤凰")
		attacker.free()
		egg.free()
		phoenix.free()
	_expect(results[0] == results[1], "交换蛋与攻击者创建/更新顺序，孵化和实际攻击结果一致")
	var egg: Unit = _main._spawn_unit(1, "anivia_egg", Vector2(160, 950), 0.0)
	egg._timed_revival_left = 0.05
	_main._combat.begin_batch(_main._sim_tick_id, "skill_impacts")
	var receipt: Dictionary = _main._combat.submit_damage(egg, egg.hp + 1, null, 0, Vector2.ZERO)
	_main._combat.commit_batch()
	egg.prepare_natural_lifecycle(0.05)
	_expect(receipt.landed and egg.hp == 0.0 and egg.timed_revival_id == "anivia", "前阶段判死的蛋不能靠定时孵化撤销致死")
	egg.free()

func _check_facing_and_replica() -> void:
	var unit: Unit = _main._spawn_unit(0, "sett", Vector2(160, 1000), 0.0)
	var target: Unit = _main._spawn_unit(1, "garen", Vector2(220, 1000), 0.0)
	unit.position = Vector2(360, 950)
	target.position = Vector2(420, 950)
	unit._move_direction = Vector2.UP
	unit._target = target
	unit._attacking = true
	var before := unit.get_visual_facing_direction()
	var view: UnitModel3D
	for c in _main._battle_presentation._world_root.get_children():
		if c is UnitModel3D and c._source == unit: view = c
	view._sync_transform(false, 0.01)
	var yaw := view.rotation.y
	unit.freeze(0.3)
	unit.apply_knockback(unit.position + Vector2.LEFT * 40, 45, 0.2)
	_run_main_ticks(1)
	view._process(0.05)
	print("FACING_TRACE ", [before, unit.get_visual_facing_direction(), yaw, view.rotation.y, unit.position])
	_expect(before.dot(Vector2.RIGHT) > 0.99 and unit.get_visual_facing_direction() == before and view.rotation.y == yaw and unit.position.x > 360, "冰冻取消攻击后保持身体和已显示根朝向，击退只平移")
	var old_mode: String = _main.mode
	_main.mode = "client"
	unit.net_facing_direction = before
	unit.net_action_permissions = ControlState.EXTERNAL_MOTION
	unit.active_skill_cast_timer = 0.0
	unit.form_transition_timer = 0.0
	_expect((unit.action_permissions() & ControlState.START_SKILL) == 0, "客户端拒绝依据快照，不用未推进的本地计时器")
	unit.net_action_permissions = ControlState.ALL_PERMISSIONS
	unit.active_skill_cast_timer = 100.0
	unit.form_transition_timer = 100.0
	_expect((unit.action_permissions() & ControlState.START_SKILL) != 0, "客户端解除权限后忽略残留本地施法/变形计时")
	_main.mode = old_mode
	unit.free()
	target.free()

func _check_formal_skill_ticks() -> void:
	var deck: Array = _main._deck.duplicate()
	var choices: Dictionary = _main._active_skill_choices.duplicate()
	for card in ["gwen", "garen", "aurelionsol"]:
		for control_kind in ["none", "stun", "freeze_before", "freeze_after"]:
			_main._commands.impacts.clear()
			_main._active_skill_effect_system.clear()
			_main._projectile_system.clear_all()
			_main._deck[0] = card
			_main._active_skill_choices[card] = 1 if card == "garen" else 0
			_main._elixir.elixir = 10.0
			var unit: Unit = _main._spawn_unit(0, card, Vector2(360, 1000), 0.0, 0)
			var target: Unit = _main._spawn_unit(1, "super_minion", Vector2(360, 910), 0.0)
			unit.position = Vector2(360, 1000)
			target.position = Vector2(360, 910)
			target.max_hp = 100000.0
			target.hp = target.max_hp
			target.freeze(100)
			unit.hp = 200.0
			unit.skill_resource_value = unit.skill_resource_max if card == "gwen" else 0.0
			# Long ordinary windup isolates skill damage without bypassing the command path.
			unit.first_hit_time = 100.0
			var id := unit.active_ability_id
			_expect(_main.use_active_skill(id, 0), "%s 正式命令入队" % card)
			var start := int(_main._commands.skill_commands.back().execute_tick)
			_run_main_ticks(start - _main._sim_tick_id)
			var duration := unit.active_skill_cast_timer
			var end_tick := int(ceil(duration / _main.SIM_DT - 0.000001))
			var expected: Array = [2, 13, 16, 19, 21] if card == "gwen" else ([20, 40, 60] if card == "garen" else [])
			# Derive independent star boundary from its actual queued definition, not visual frames.
			if card == "aurelionsol":
				for impact in _main._commands.impacts:
					if impact.skill.has("independent_result"): expected.append(int(ceil(float(impact.time_left) / _main.SIM_DT - 0.000001)))
			var first := int(expected[0])
			var observed: Array = []
			var previous_hp := target.hp
			var health := unit.hp
			var heal_ticks: Array = []
			var unlock_tick := -1
			for tick in range(1, maxi(end_tick, int(expected.back())) + 2):
				if (control_kind == "freeze_before" and tick == first) or (control_kind == "freeze_after" and tick == first + 1): unit.freeze(10)
				if control_kind == "stun" and tick == first: unit.stun(10)
				_run_main_ticks(1)
				if target.hp < previous_hp: observed.append(tick)
				if unit.hp > health: heal_ticks.append(tick)
				if not unit.is_active_skill_casting() and unlock_tick < 0: unlock_tick = tick
				previous_hp = target.hp
				health = unit.hp
			var wanted := expected.duplicate()
			if card != "aurelionsol" and control_kind.begins_with("freeze"):
				wanted = [] if control_kind == "freeze_before" else [first]
			_expect(observed == wanted, "%s %s 正式技能释放 Tick %s，实际 %s" % [card, control_kind, wanted, observed])
			if not control_kind.begins_with("freeze"):
				_expect(unlock_tick == end_tick, "%s %s 行动锁与 Cast End 同边界" % [card, control_kind])
			if card == "gwen":
				_expect(heal_ticks == ([] if control_kind.begins_with("freeze") else [30]), "格温完成回血只在 K+30 且未取消时发生")
			print("CAST_BOUNDARY ", {"card": card, "control": control_kind, "start": start, "impacts": observed, "unlock": unlock_tick, "heal": heal_ticks})
			_main._on_active_skill_unit_died(id)
			unit.free()
			target.free()
	_main._deck = deck
	_main._active_skill_choices = choices

func _check_gnar_transition_edges() -> void:
	var deck: Array = _main._deck.duplicate()
	_main._deck[0] = "gnar"
	for remaining in [0.05, 0.1]:
		_main._elixir.elixir = 10.0
		var unit: Unit = _main._spawn_unit(0, "gnar", Vector2(360, 1000), 0.0, 0)
		var id := unit.active_ability_id
		_expect(_main.use_active_skill(id, 0), "变形边界请求先合法入队")
		var due := int(_main._commands.skill_commands.back().execute_tick)
		_run_main_ticks(due - _main._sim_tick_id - 1)
		unit.transform_to_mega()
		unit.form_transition_timer = remaining
		var serial := unit.get_visual_action_serial()
		_expect(not _main.use_active_skill(id, 0), "已有待执行请求时拒绝重复提交，不因变形改变去重")
		_run_main_ticks(1)
		_expect((unit.active_skill_cast_serial > 0) == (remaining == 0.05), "转换到期边界先推进旧窗口再判断请求")
		if remaining > 0.05:
			_expect(unit.get_visual_action_serial() == serial and _main._active_skills[id].uses_remaining == _main._active_skills[id].max_uses, "转换中拒绝不发布主动动作或增加次数")
		_main._on_active_skill_unit_died(id)
		unit.free()
	_main._elixir.elixir = 10.0
	var unit: Unit = _main._spawn_unit(0, "gnar", Vector2(360, 1000), 0.0, 0)
	var id := unit.active_ability_id
	_expect(_main.use_active_skill(id, 0), "无待变形的小纳尔正式主动请求合法")
	_run_main_ticks(_main.COMMAND_DELAY_TICKS)
	_expect(unit.form_index == 1 and unit.active_skill_cast_serial == 1 and _main._active_skills[id].uses_remaining == _main._active_skills[id].max_uses - 1, "合法主动变大属于同次施法，不自我拒绝退款")
	_main._on_active_skill_unit_died(id)
	unit.free()
	unit = _main._spawn_unit(0, "gnar", Vector2(360, 1000), 0.0)
	unit.stun(1.0)
	unit.pending_form_generation = unit.form_change_serial
	unit._apply_pending_form()
	var view: UnitModel3D
	for c in _main._battle_presentation._world_root.get_children():
		if c is UnitModel3D and c._source == unit: view = c
	view._process(0.0)
	_expect(unit.form_index == 1 and view._playing_visual_action, "眩晕期间合法被动换形首次更新照常播放")
	var generation := unit.form_change_serial
	unit._apply_pending_form()
	_expect(unit.form_change_serial == generation, "待变形仅兑现一次")
	unit.freeze(1.0)
	unit.pending_form_generation = generation - 1
	unit._apply_pending_form()
	_expect(unit.pending_form_generation == -1, "冻结中也清除失效形态代次")
	unit.pending_form_generation = generation
	unit.take_damage(unit.hp + 1.0)
	_expect(unit.pending_form_generation == -1, "死亡立即清除待变形")
	unit.free()
	_main._deck = deck

func _check_region_birth() -> void:
	var target: Unit = _main._spawn_unit(1, "masteryi", Vector2(360, 900), 0.0)
	_main._sim_step_active = true
	_main._apply_freeze(target.position, 100.0, 0.1, 0, 0.2, 0.5)
	_main._tick_slow_zones(0.05)
	_expect(is_equal_approx(_main._spell_system.slow_zones.back().delay, 0.1), "创建当 Tick 不额外扣法术区域延迟")
	_main._sim_step_active = false
	_run_main_ticks(2)
	_expect(not target.is_frozen() and target.control.slow_timer > 0.0 and is_equal_approx(_main._spell_system.slow_zones.back().timer, 0.2), "冰冻结束边界启动完整减速区，没有空缺或首次重复扣时")
	target.free()
	_main._spell_system.clear()

func _check_submission_boundary() -> void:
	var deck: Array = _main._deck.duplicate()
	_main._deck[0] = "gnar"
	for kind in ["stun", "freeze", "form", "cast", "knockback", "recovery"]:
		for expires in [true, false]:
			var initial := 2.0 if expires else 10.0
			_main._elixir._timer = 0.0
			_main._elixir.elixir = initial
			var unit: Unit = _main._spawn_unit(0, "gnar", Vector2(160, 1000), 0.0, 0)
			var id := unit.active_ability_id
			var uses: int = _main._active_skills[id].uses_remaining
			var duration := 0.1 if expires else 1.0
			match kind:
				"stun": unit.stun(duration)
				"freeze": unit.freeze(duration)
				"form":
					unit.transform_to_mega()
					unit.form_transition_timer = duration
				"cast": unit.begin_active_skill_cast(duration, Vector2.UP)
				"knockback": unit.apply_knockback(unit.position + Vector2.UP, 5.0, duration)
				"recovery":
					unit.structure_rush.phase = StructureRushState.Phase.RECOVERY
					unit.structure_rush.remaining = duration
			_main._sync_active_skill_deployment_readiness()
			_expect(not _main._active_skill_bar._buttons[0].disabled and _main._can_submit_active_skill(id, 0) and not _main._active_skill_is_legal(id, 0), "临时状态只阻止执行、不阻止按钮或提交 " + kind)
			_main._active_skill_bar._on_slot_pressed(0)
			_expect(_main._commands.skill_commands.size() == 1 and _main._active_skill_bar._buttons[0].disabled, "真实按钮点击入队后禁重复请求 " + kind)
			if _main._commands.skill_commands.is_empty():
				_main._on_active_skill_unit_died(id)
				unit.free()
				continue
			var request: Dictionary = _main._commands.skill_commands.back()
			var paid: float = initial - _main._elixir.elixir
			_expect(paid > 0.0 and not _main.use_active_skill(id, 0) and _main._elixir.elixir == initial - paid, "基础去重不二次扣费 " + kind)
			_run_main_ticks(int(request.execute_tick) - _main._sim_tick_id)
			print("SUBMIT_BOUNDARY ", [kind, expires, _main._active_skills[id].uses_remaining, uses, _main._elixir.elixir, paid, unit.hp, unit.action_permissions(), unit.active_skill_cast_serial])
			_expect(_main._active_skills[id].uses_remaining == uses - (1 if expires else 0) and is_equal_approx(_main._elixir.elixir, initial - (paid if expires else 0.0)), "执行时解锁则成功，仍锁则退费不耗次数 %s/%s" % [kind, expires])
			_expect(_main._commands.skill_commands.is_empty() and request.payment.is_settled(), "拒绝不延迟重试，原收据已结算 " + kind)
			_main._elixir.elixir = 4.0
			_main._commands.settle_skill(request, true)
			_expect(_main._elixir.elixir == 4.0, "重复结算不重复退款 " + kind)
			_main._on_active_skill_unit_died(id)
			_main._commands.impacts.clear()
			unit.free()
	_main._deck = deck
