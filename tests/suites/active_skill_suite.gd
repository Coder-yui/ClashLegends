class_name ActiveSkillSuite
extends RefCounted

var _harness: Object
var _main: Node2D

func _expect(condition: bool, message: String) -> void:
	_harness._expect(condition, message)

func _run_main_ticks(count: int) -> void:
	for _tick in count:
		_main._sim_step(_main.SIM_DT)

func _reset_local_elixir() -> void:
	_main._elixir.elixir = ElixirManager.MAX_ELIXIR

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_active_skill_loadout_rule()
	_check_multiple_skill_selection()
	_check_deployment_skill_gate()
	_check_skill_resource_loadout_visibility()
	_check_skill_resource_colors()
	_check_active_skill_activation()
	_check_active_skill_cost_uses_and_refresh()
	_check_pending_active_skill_revalidation()
	_check_pending_control_revalidation()
	_check_cast_impact_recovery_timeline()
	_check_artdev_active_skill_timeline()
	_check_artdev_workbench()
	_check_cast_control_pause_and_death_cancel()
	_check_authoritative_hand_cycle()
	_check_network_hand_confirmation()
	_check_empowered_freeze_slow_zone()
	_check_heal_spell()

func _check_active_skill_loadout_rule() -> void:
	var cards := CardDB.all()
	var data_ok := true
	for card_id in CardDB.selectable_ids():
		var stats: Dictionary = cards[card_id]
		if stats.get("type", "unit") == "spell":
			data_ok = data_ok and CardDB.active_skills_for(card_id).is_empty()
		else:
			var available_skills := CardDB.active_skills_for(card_id)
			var expected_count := 2 if card_id == "garen" else 1
			data_ok = data_ok and available_skills.size() == expected_count and not String(available_skills[0].get("name", "")).is_empty()
	_expect(data_ok, "当前每张可选单位/建筑卡至少有一个主动候选，盖伦有两个候选但每个实例只携带一个，法术卡不生成主动按钮")
	var left_position: Vector2 = ActiveSkillBar.LEFT_SLOT_POSITION
	var right_position: Vector2 = ActiveSkillBar.RIGHT_SLOT_POSITION
	_expect(
		is_equal_approx(left_position.x + right_position.x + ActiveSkillBar.BUTTON_SIZE.x, _main.FIELD_W)
		and is_equal_approx(left_position.y, right_position.y),
		"主动槽 2 圆位以战场中线严格镜像主动槽 1"
	)
	var old_marked_cards: Array = _main._hand._active_skill_cards.keys()
	_main._hand.set_cycle_state(["garen", "freeze", "xin", "ashe"], ["teemo", "masteryi", "tombstone", "aurelionsol"])
	_main._hand.set_active_skill_cards(["garen", "freeze"])
	var active_card_markers_visible: bool = (
		_main._hand._button_slots[0].get_node_or_null("ActiveSkillMarker") != null
		and (_main._hand._button_slots[0].get_node("ActiveSkillMarker") as Control).visible
		and (_main._hand._button_slots[1].get_node("ActiveSkillMarker") as Control).visible
		and not (_main._hand._button_slots[2].get_node("ActiveSkillMarker") as Control).visible
	)
	_main._hand.set_cycle_state(["xin", "ashe", "garen", "freeze"], ["teemo", "masteryi", "tombstone", "aurelionsol"])
	var marker_follows_card: bool = (
		not (_main._hand._button_slots[0].get_node("ActiveSkillMarker") as Control).visible
		and (_main._hand._button_slots[2].get_node("ActiveSkillMarker") as Control).visible
		and (_main._hand._button_slots[3].get_node("ActiveSkillMarker") as Control).visible
	)
	_main._hand.set_active_skill_cards(old_marked_cards)
	_expect(active_card_markers_visible and marker_follows_card, "战斗手牌用无文字主动符印标记主动卡，并随手牌轮换跟随卡牌")
	var old_deck: Array = _main._deck.duplicate()
	_main._deck = ["garen", "freeze", "xin", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	_expect(
		_main._card_has_active_for_team(0, "garen")
		and _main._card_has_active_for_team(0, "freeze")
		and not _main._card_has_active_for_team(0, "xin")
		and _main._active_card_slot_for_team(0, "garen") == 0
		and _main._active_card_slot_for_team(0, "freeze") == 1,
		"只有备战卡组前两个卡位携带主动版本"
	)
	_main._deck = old_deck

func _check_multiple_skill_selection() -> void:
	var old_deck: Array = _main._deck.duplicate()
	var old_choices: Dictionary = _main._active_skill_choices.duplicate(true)
	_main._deck = ["garen", "xin", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	_main._active_skill_choices["garen"] = 1
	var source: Unit = _main._spawn_unit(0, "garen", Vector2(360.0, 1000.0), 0.0, 0)
	var carried_skill: Dictionary = _main._active_skills[source.active_ability_id].skill
	var selected_judgment := (
		String(carried_skill.get("name", "")) == "审判"
		and StringName(carried_skill.get("kind", "")) == &"continuous_area"
	)
	_expect(selected_judgment, "盖伦备战选择第二个候选时，场上主动槽只注册审判而不是同时注册两个技能")
	_main._on_active_skill_unit_died(source.active_ability_id)
	if is_instance_valid(source):
		source.free()
	_main._active_skill_choices = old_choices
	_main._deck = old_deck

func _check_deployment_skill_gate() -> void:
	_reset_local_elixir()
	var old_deck: Array = _main._deck.duplicate()
	_main._deck = ["garen", "xin", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	var source: Unit = _main._spawn_unit(0, "garen", Vector2(360.0, 1000.0), -1.0, 0)
	var ability_id := source.active_ability_id
	var locked_during_deploy: bool = (
		not source.is_deployed()
		and _main._active_skill_bar.is_slot_visible(0)
		and _main._active_skill_bar._buttons[0].disabled
		and not _main._queue_active_skill(ability_id, 0, 0)
	)
	_run_main_ticks(19)
	var locked_until_last_tick: bool = not source.is_deployed() and _main._active_skill_bar._buttons[0].disabled
	_run_main_ticks(1)
	var enabled_after_deploy: bool = (
		source.is_deployed()
		and not _main._active_skill_bar._buttons[0].disabled
		and _main._queue_active_skill(ability_id, 0, 0)
	)
	_expect(
		locked_during_deploy and locked_until_last_tick and enabled_after_deploy,
		"单位部署动画/锁定完整结束前主动技能按钮不可点击，部署完成 Tick 才允许提交技能",
	)
	_main._cancel_pending_active_skill(ability_id)
	_main._on_active_skill_unit_died(ability_id)
	if is_instance_valid(source):
		source.free()
	_main._deck = old_deck

func _check_skill_resource_loadout_visibility() -> void:
	var old_deck: Array = _main._deck.duplicate()
	_main._deck = ["sett", "garen", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	var ordinary_sett: Unit = _main._spawn_unit(0, "sett", Vector2(180.0, 1000.0), 0.0, -1)
	var active_sett: Unit = _main._spawn_unit(0, "sett", Vector2(260.0, 1000.0), 0.0, 0)
	var enabled_only_in_slot := not ordinary_sett.is_skill_resource_visible() and active_sett.is_skill_resource_visible()
	var replacement: Unit = _main._spawn_unit(0, "garen", Vector2(340.0, 1000.0), 0.0, 0)
	_expect(
		enabled_only_in_slot and not active_sett.is_skill_resource_visible()
		and active_sett.active_ability_id == -1 and replacement.active_ability_id >= 0,
		"豪意白条只属于主动槽实际携带蓄意轰拳的瑟提；同槽新单位覆盖资格后旧瑟提立即隐藏并停止积攒",
	)
	for unit in [ordinary_sett, active_sett, replacement]:
		if is_instance_valid(unit):
			unit.take_damage(unit.hp + 1.0)
	_main._deck = old_deck

func _check_skill_resource_colors() -> void:
	var expected_colors := {
		"sett": Color(1.0, 0.82, 0.24, 0.96),
		"gwen": Color(0.28, 0.72, 1.0, 0.96),
		"aurelionsol": Color(0.58, 0.42, 1.0, 0.96),
	}
	var colors_ok := true
	var units: Array[Unit] = []
	for card_id in expected_colors:
		var stats: Dictionary = CardDB.get_card(card_id).duplicate(true)
		var unit := Unit.new()
		unit.setup(0, stats, stats.name)
		unit.configure_carried_active_skill(stats.active_skills[0])
		units.append(unit)
		colors_ok = colors_ok and unit.get_skill_resource_fill_color() == Unit.SKILL_RESOURCE_UNFILLED_COLOR
		unit.add_skill_resource(unit.skill_resource_max)
		colors_ok = colors_ok and unit.get_skill_resource_fill_color() == expected_colors[card_id]
	_expect(colors_ok, "瑟提/格温/龙王资源未满为白色，满层分别切换为黄色/蓝色/蓝紫色")
	for unit in units:
		unit.free()

func _check_active_skill_activation() -> void:
	_reset_local_elixir()
	var old_deck: Array = _main._deck.duplicate()
	_main._deck = ["garen", "xin", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	var first_source: Unit = _main._spawn_unit(0, "garen", Vector2(340.0, 800.0), 0.0, 0)
	var first_ability_id := first_source.active_ability_id
	var source: Unit = _main._spawn_unit(0, "garen", Vector2(380.0, 800.0), 0.0, 0)
	var enemy_stats: Dictionary = CardDB.get_unit_stats("imp").duplicate()
	enemy_stats["deploy_time"] = 0.0
	enemy_stats["hp"] = 500.0
	var enemy := Unit.new()
	enemy.position = Vector2(410.0, 800.0)
	enemy.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(enemy)
	var ability_id := source.active_ability_id
	_expect(
		ability_id >= 0
		and not _main._active_skills.has(first_ability_id)
		and first_source.active_ability_id == -1
		and _main._active_skills.has(ability_id)
		and _main._active_skill_bar.current_ability_id(0) == ability_id,
		"同一主动槽再次部署时，新单位覆盖旧单位的技能资格"
	)
	var hp_before := enemy.hp
	var queued: bool = not _main._queue_active_skill(first_ability_id, 0, 0) and _main._queue_active_skill(ability_id, 0, 0)
	var expected_execute_tick: int = _main._sim_tick_id + _main.COMMAND_DELAY_TICKS
	var command_tick_contract: bool = not _main._pending_active_skill_activations.is_empty() and int(_main._pending_active_skill_activations[0].execute_tick) == expected_execute_tick
	_main._active_skill_bar.set_pending(ability_id, true)
	_run_main_ticks(_main.COMMAND_DELAY_TICKS - 1)
	_expect(
		queued and is_equal_approx(enemy.hp, hp_before) and is_zero_approx(source.shield_hp)
		and _main._active_skills.has(ability_id) and _main._active_skill_bar.is_slot_visible(0),
		"点击主动技能后目标执行 Tick 前仍处于等待状态，不提前结算"
	)
	_run_main_ticks(1)
	_expect(command_tick_contract and is_equal_approx(enemy.hp, hp_before) and source.empowered_attack_ready, "主动技能与卡牌共用 input_tick→execute_tick 解析，Host 本地输入保持 10 Tick 后由权威逻辑结算")
	_expect(
		_main._active_skills.has(ability_id)
		and int(_main._active_skills[ability_id].uses_remaining) == 1
		and float(_main._active_skills[ability_id].cooldown_left) > 0.0
		and not _main._activate_active_skill(ability_id, 0)
		and _main._active_skill_bar.is_slot_visible(0),
		"主动技能结算后保留单位资格，扣除一次使用次数并进入技能 CD"
	)
	var slot_two_unit: Unit = _main._spawn_unit(0, "xin", Vector2(440.0, 840.0), 0.0, 1)
	var slot_two_ability_id := slot_two_unit.active_ability_id
	var slot_two_was_visible: bool = _main._active_skill_bar.is_slot_visible(1)
	slot_two_unit.take_damage(slot_two_unit.hp + 1.0)
	_expect(
		slot_two_was_visible
		and not _main._active_skills.has(slot_two_ability_id)
		and not _main._active_skill_bar.is_slot_visible(1),
		"最新主动实例死亡后对应圆位立即隐藏"
	)
	first_source.free()
	source.free()
	enemy.free()
	_main._deck = old_deck

func _check_active_skill_cost_uses_and_refresh() -> void:
	_reset_local_elixir()
	var old_deck: Array = _main._deck.duplicate()
	_main._deck = ["garen", "xin", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	var garen: Unit = _main._spawn_unit(0, "garen", Vector2(260.0, 760.0), 0.0, 0)
	var ability_id := garen.active_ability_id
	var initial_elixir: float = _main._elixir.elixir
	var combat_rules_visible: bool = (
		_main._active_skill_bar._rule_labels[0].visible
		and _main._active_skill_bar._rule_labels[0].text.contains("金币 1")
		and _main._active_skill_bar._rule_labels[0].text.contains("次数 2/2")
	)
	var queued_first: bool = _main._queue_active_skill(ability_id, 0, 0)
	var paid_on_queue: bool = is_equal_approx(_main._elixir.elixir, initial_elixir - 1.0)
	_run_main_ticks(_main.COMMAND_DELAY_TICKS)
	var first_entry: Dictionary = _main._active_skills[ability_id]
	var first_use_state: bool = int(first_entry.uses_remaining) == 1 and float(first_entry.cooldown_left) > 0.0
	var blocked_during_cooldown: bool = not _main._queue_active_skill(ability_id, 0, 0) and is_equal_approx(_main._elixir.elixir, initial_elixir - 1.0)
	_main._tick_active_skill_cooldowns(6.0)
	var queued_second: bool = _main._queue_active_skill(ability_id, 0, 0)
	_run_main_ticks(_main.COMMAND_DELAY_TICKS)
	_main._tick_active_skill_cooldowns(6.0)
	var queued_third: bool = not _main._queue_active_skill(ability_id, 0, 0)
	var exhausted_entry: Dictionary = _main._active_skills[ability_id]
	var uses_exhausted: bool = int(exhausted_entry.uses_remaining) == 0
	var spent_twice: bool = is_equal_approx(_main._elixir.elixir, initial_elixir - 2.0)

	var refreshed: Unit = _main._spawn_unit(0, "garen", Vector2(320.0, 760.0), 0.0, 0)
	var refreshed_id := refreshed.active_ability_id
	var refreshed_entry: Dictionary = _main._active_skills[refreshed_id]
	var redeploy_resets_uses: bool = refreshed_id != ability_id and int(refreshed_entry.uses_remaining) == 2 and is_equal_approx(float(refreshed_entry.cooldown_left), 0.0)
	var refreshed_queue_paid: bool = _main._queue_active_skill(refreshed_id, 0, 0) and is_equal_approx(_main._elixir.elixir, initial_elixir - 3.0)
	_expect(
		combat_rules_visible and queued_first and paid_on_queue and first_use_state and blocked_during_cooldown and queued_second and queued_third
		and uses_exhausted and spent_twice and redeploy_resets_uses and refreshed_queue_paid,
		"主动技能按各自金币费用进入队列、每个单位独立扣使用次数并进入 CD，次数耗尽后重新下卡会刷新次数",
	)
	_main._cancel_pending_active_skill(refreshed_id)
	_main._on_active_skill_unit_died(refreshed_id)
	for unit in [garen, refreshed]:
		if is_instance_valid(unit):
			unit.free()
	_main._deck = old_deck

func _check_pending_active_skill_revalidation() -> void:
	_reset_local_elixir()
	var old_deck: Array = _main._deck.duplicate()
	_main._deck = ["garen", "xin", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	var enemy_stats: Dictionary = CardDB.get_unit_stats("imp").duplicate(true)
	enemy_stats["deploy_time"] = 0.0
	enemy_stats["hp"] = 1000.0
	var enemy := Unit.new()
	enemy.position = Vector2(330.0, 800.0)
	enemy.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(enemy)

	# 点击时合法，但单位在 0.5 秒等待窗内死亡：资格和 pending 一起作废，绝不落地效果。
	var dead_source: Unit = _main._spawn_unit(0, "garen", Vector2(300.0, 800.0), 0.0, 0)
	var dead_ability_id := dead_source.active_ability_id
	var hp_before_death_reject := enemy.hp
	var queued_before_death: bool = _main._queue_active_skill(dead_ability_id, 0, 0)
	_main._active_skill_bar.set_pending(dead_ability_id, true)
	dead_source.take_damage(dead_source.hp + 1.0)
	_run_main_ticks(_main.COMMAND_DELAY_TICKS)
	_expect(
		queued_before_death
		and is_equal_approx(enemy.hp, hp_before_death_reject)
		and not _main._active_skills.has(dead_ability_id)
		and _main._pending_active_skill_activations.is_empty()
		and not _main._active_skill_bar.is_slot_visible(0),
		"主动 pending 期间单位死亡会取消释放，不产生效果并清理对应按钮",
	)

	# 点击后由其他权威机制开始变形；到期检查应拒绝，而不是把主动解释成大形态技能。
	_main._deck[0] = "gnar"
	var gnar: Unit = _main._spawn_unit(0, "gnar", Vector2(360.0, 800.0), 0.0, 0)
	var gnar_ability_id := gnar.active_ability_id
	var queued_before_transform: bool = _main._queue_active_skill(gnar_ability_id, 0, 0)
	_main._active_skill_bar.set_pending(gnar_ability_id, true)
	var pending_impacts_before: int = _main._pending_active_skill_impacts.size()
	var transformed_after_click := gnar.transform_to_mega()
	var transform_action_serial := gnar.get_visual_action_serial()
	_run_main_ticks(_main.COMMAND_DELAY_TICKS)
	_expect(
		queued_before_transform
		and transformed_after_click
		and _main._active_skills.has(gnar_ability_id)
		and _main._pending_active_skill_impacts.size() == pending_impacts_before
		and gnar.get_visual_action_serial() == transform_action_serial
		and not _main._active_skill_bar._buttons[0].disabled,
		"主动 pending 到期时若已进入 transform，会拒绝效果/技能动作并恢复按钮",
	)
	_main._on_active_skill_unit_died(gnar_ability_id)
	gnar.free()

	# 同理，等待窗内开始另一段 active cast 时必须拒绝；cast 结束后仍可重新请求并正常释放。
	_main._deck[0] = "garen"
	var casting_source: Unit = _main._spawn_unit(0, "garen", Vector2(300.0, 800.0), 0.0, 0)
	var casting_ability_id := casting_source.active_ability_id
	var queued_before_cast: bool = _main._queue_active_skill(casting_ability_id, 0, 0)
	_main._active_skill_bar.set_pending(casting_ability_id, true)
	casting_source.begin_active_skill_cast(1.0, Vector2.UP)
	var cast_action_serial := casting_source.get_visual_action_serial()
	var hp_before_cast_reject := enemy.hp
	_run_main_ticks(_main.COMMAND_DELAY_TICKS)
	var rejected_during_cast: bool = (
		queued_before_cast
		and is_equal_approx(enemy.hp, hp_before_cast_reject)
		and is_zero_approx(casting_source.shield_hp)
		and casting_source.get_visual_action_serial() == cast_action_serial
		and _main._active_skills.has(casting_ability_id)
		and not _main._active_skill_bar._buttons[0].disabled
	)
	casting_source.active_skill_cast_timer = 0.0
	casting_source.active_skill_cast_locks.clear()
	var queued_after_cast: bool = _main._queue_active_skill(casting_ability_id, 0, 0)
	_main._active_skill_bar.set_pending(casting_ability_id, true)
	_run_main_ticks(_main.COMMAND_DELAY_TICKS)
	_expect(rejected_during_cast, "主动 pending 到期时若已进入另一段 active cast，会拒绝效果/技能动作并恢复按钮")
	_expect(
		queued_after_cast and (casting_source.empowered_attack_ready or casting_source.get_empowered_attack_visual_serial() > 0)
		and _main._active_skills.has(casting_ability_id)
		and int(_main._active_skills[casting_ability_id].uses_remaining) == 1
		and float(_main._active_skills[casting_ability_id].cooldown_left) > 0.0,
		"pending 期间权威状态始终合法时，主动技能仍在 0.5 秒后正常释放并进入 CD",
	)
	casting_source.free()
	enemy.free()
	_main._deck = old_deck

func _check_pending_control_revalidation() -> void:
	_reset_local_elixir()
	var old_deck: Array = _main._deck.duplicate()
	_main._deck = ["garen", "xin", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	var enemy_stats: Dictionary = CardDB.get_unit_stats("imp").duplicate(true)
	enemy_stats["deploy_time"] = 0.0
	enemy_stats["hp"] = 1000000.0
	enemy_stats["is_air"] = true
	var enemy := Unit.new()
	enemy.position = Vector2(360.0, 800.0)
	enemy.setup(1, enemy_stats, enemy_stats.name)
	_main.add_child(enemy)

	var frozen_source: Unit = _main._spawn_unit(0, "garen", Vector2(300.0, 800.0), 0.0, 0)
	var frozen_ability_id := frozen_source.active_ability_id
	var frozen_hp := enemy.hp
	var frozen_queued: bool = _main._queue_active_skill(frozen_ability_id, 0, 0)
	_main._active_skill_bar.set_pending(frozen_ability_id, true)
	_run_main_ticks(4)
	frozen_source.freeze(1.0)
	_run_main_ticks(_main.COMMAND_DELAY_TICKS - 4)
	var frozen_rejected: bool = (
		frozen_queued
		and is_equal_approx(enemy.hp, frozen_hp)
		and _main._active_skills.has(frozen_ability_id)
		and not _main._active_skill_bar._buttons[0].disabled
	)

	var stunned_source: Unit = _main._spawn_unit(0, "xin", Vector2(300.0, 900.0), 0.0, 1)
	var stunned_ability_id := stunned_source.active_ability_id
	var stunned_hp := enemy.hp
	var stunned_queued: bool = _main._queue_active_skill(stunned_ability_id, 0, 0)
	_main._active_skill_bar.set_pending(stunned_ability_id, true)
	_run_main_ticks(4)
	stunned_source.stun(1.0)
	_run_main_ticks(_main.COMMAND_DELAY_TICKS - 4)
	var stunned_rejected: bool = (
		stunned_queued
		and is_equal_approx(enemy.hp, stunned_hp)
		and _main._active_skills.has(stunned_ability_id)
		and not _main._active_skill_bar._buttons[1].disabled
	)
	_expect(frozen_rejected and stunned_rejected, "主动技能执行 Tick 重新校验 Freeze/Stun，拒绝释放且保留 ability/UI")
	_main._on_active_skill_unit_died(frozen_ability_id)
	_main._on_active_skill_unit_died(stunned_ability_id)
	frozen_source.free()
	stunned_source.free()
	enemy.free()
	_main._deck = old_deck

func _check_cast_impact_recovery_timeline() -> void:
	_reset_local_elixir()
	var old_deck: Array = _main._deck.duplicate()
	_main._deck = ["garen", "xin", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	var source: Unit = _main._spawn_unit(0, "garen", Vector2(260.0, 680.0), 0.0, 0)
	var ability_id := source.active_ability_id
	var timeline_skill := {
		"name": "测试施法",
		"kind": "buff",
		"duration": 2.0,
		"cast_duration": 1.0,
		"impact_delay": 0.4,
		"shield": 100.0,
		"shield_duration": 2.0,
		"cast_locks": ["movement", "attack", "facing"],
	}
	var timeline_entry: Dictionary = _main._active_skills[ability_id]
	timeline_entry["skill"] = timeline_skill
	_main._active_skills[ability_id] = timeline_entry
	var queued: bool = _main._queue_active_skill(ability_id, 0, 0)
	_main._active_skill_bar.set_pending(ability_id, true)
	_run_main_ticks(_main.COMMAND_DELAY_TICKS)
	var cast_started_no_impact: bool = queued and source.active_skill_cast_timer > 0.0 and is_zero_approx(source.shield_hp)
	_run_main_ticks(7)
	var before_impact := is_zero_approx(source.shield_hp) and source.active_skill_cast_timer > 0.0
	_run_main_ticks(1)
	var impact_at_delay := source.shield_hp > 0.0 and source.active_skill_cast_timer > 0.0
	_run_main_ticks(10)
	var still_casting_before_end := source.active_skill_cast_timer > 0.0
	_run_main_ticks(1)
	var recovered := is_zero_approx(source.active_skill_cast_timer) and source.active_skill_cast_locks.is_empty()
	_expect(cast_started_no_impact and before_impact and impact_at_delay and still_casting_before_end and recovered, "主动技能按 Cast Start→impact_delay→Impact→cast_duration 固定 Tick 结算")
	_main._on_active_skill_unit_died(ability_id)
	source.free()
	_main._deck = old_deck

func _check_artdev_active_skill_timeline() -> void:
	var old_deck: Array = _main._deck.duplicate()
	_main._deck = ["garen", "xin", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	var source: Unit = _main._spawn_unit(0, "garen", Vector2(260.0, 680.0), 0.0, 0)
	var ability_id: int = source.active_ability_id
	var skill: Dictionary = {
		"name": "ArtDev 时间轴",
		"kind": "buff",
		"duration": 2.0,
		"cast_duration": 1.0,
		"impact_delay": 0.4,
		"shield": 100.0,
		"shield_duration": 2.0,
		"cast_locks": ["movement", "attack", "facing"],
	}
	var pending_before: int = _main._pending_active_skill_impacts.size()
	var previewed: bool = _main.preview_active_skill(source, skill)
	var command_buffer_skipped: bool = (
		previewed
		and _main._pending_active_skill_activations.is_empty()
		and _main._pending_active_skill_impacts.size() == pending_before + 1
		and source.active_skill_cast_timer > 0.0
		and is_zero_approx(source.shield_hp)
	)
	_run_main_ticks(7)
	var no_early_impact: bool = is_zero_approx(source.shield_hp)
	_run_main_ticks(1)
	var impact_after_delay: bool = source.shield_hp > 0.0
	_expect(command_buffer_skipped and no_early_impact and impact_after_delay, "ArtDev 只跳过 Command Buffer，普通主动仍按 Cast Start→impact_delay→Gameplay Impact 结算")
	_main._on_active_skill_unit_died(ability_id)
	source.free()
	_main._deck = old_deck

func _check_artdev_workbench() -> void:
	var old_panel: ArtDevPanel = _main._art_dev_panel
	var old_selection: String = _main._art_dev_selection
	var old_team: int = _main._art_dev_team
	var old_last_units: Dictionary = _main._art_dev_last_units.duplicate()
	var old_choices: Dictionary = _main._art_dev_active_skill_choices.duplicate(true)
	var panel := ArtDevPanel.new()
	_main.add_child(panel)
	var initial_cards: Array[String] = [
		"garen", "xin", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol", "freeze",
	]
	panel.setup(CardDB.all(), initial_cards)
	_main._art_dev_panel = panel
	panel.item_selected.connect(_main._set_art_dev_selection)
	panel.team_changed.connect(_main._set_art_dev_team)
	panel.active_skill_selected.connect(_main._on_art_dev_active_skill_selected)
	panel.active_skill_requested.connect(_main._use_art_dev_active_skill)
	panel.skill_resource_requested.connect(_main._set_art_dev_skill_resource)

	var fixed_loadout_ok := panel.get_test_card_ids() == initial_cards and panel._loadout_buttons.size() == ArtDevPanel.LOADOUT_SIZE
	panel._toggle_card_picker()
	var full_pool_opened := panel.is_card_picker_open() and panel._pool_buttons.size() == CardDB.all().size()
	panel._toggle_pool_card("garen")
	panel._toggle_pool_card("gwen")
	panel._close_card_picker()
	var swapped_and_reusable := (
		not panel.is_card_picker_open()
		and panel.get_test_card_ids().size() == ArtDevPanel.LOADOUT_SIZE
		and "garen" not in panel.get_test_card_ids()
		and "gwen" in panel.get_test_card_ids()
	)
	_expect(
		fixed_loadout_ok and full_pool_opened and swapped_and_reusable,
		"ArtDev 底栏固定 8 张测试卡，按需展开完整卡池并可移除旧卡、换入新卡后继续测试",
	)

	panel._select_item("garen")
	panel._on_skill_option_selected(1)
	var skill_switch_ok := (
		panel._skill_option.item_count == 2
		and panel.selected_skill_index() == 1
		and int(_main._art_dev_active_skill_choices.get("garen", -1)) == 1
	)
	_expect(skill_switch_ok, "ArtDev 可在同一英雄的多个主动技能候选之间切换")

	panel._select_item("gwen")
	var gwen_stats: Dictionary = CardDB.get_card("gwen").duplicate(true)
	gwen_stats["deploy_time"] = 0.0
	var gwen := Unit.new()
	gwen.position = Vector2(260.0, 720.0)
	gwen.setup(0, gwen_stats, gwen_stats.name)
	gwen.card_id = "gwen"
	_main.add_child(gwen)
	_main._art_dev_last_units[_main._art_dev_unit_key("gwen", 0)] = weakref(gwen)
	panel._on_team_toggled(false)
	_main._configure_art_dev_unit_skill(gwen)
	gwen.add_skill_resource(2.0)
	_main._sync_art_dev_panel_state()
	var gwen_resource_visible := (
		gwen.is_skill_resource_visible()
		and gwen.get_skill_resource_segment_count() == 3
		and panel._resource_controls.visible
		and is_equal_approx(panel._resource_slider.value, 2.0)
		and is_equal_approx(panel._resource_slider.max_value, 3.0)
	)
	panel._request_resource_value(3.0)
	panel._on_active_skill_pressed()
	var gwen_full_cast_ok := (
		is_zero_approx(gwen.skill_resource_value)
		and gwen.get_visual_action_name() == &"active_3"
		and gwen.is_active_skill_casting()
	)
	_expect(
		gwen_resource_visible and gwen_full_cast_ok,
		"ArtDev 放置格温后显示 3 段资源条，可调满并用满层资源播放对应强化技能动作",
	)

	panel._select_item("sett")
	var sett_stats: Dictionary = CardDB.get_card("sett").duplicate(true)
	sett_stats["deploy_time"] = 0.0
	var sett := Unit.new()
	sett.position = Vector2(460.0, 720.0)
	sett.setup(0, sett_stats, sett_stats.name)
	sett.card_id = "sett"
	_main.add_child(sett)
	_main._art_dev_last_units[_main._art_dev_unit_key("sett", 0)] = weakref(sett)
	_main._configure_art_dev_unit_skill(sett)
	_main._sync_art_dev_panel_state()
	panel._request_resource_value(125.0)
	var sett_resource_visible := (
		sett.is_skill_resource_visible()
		and sett.get_skill_resource_segment_count() == 0
		and is_equal_approx(sett.skill_resource_value, 125.0)
		and is_equal_approx(panel._resource_slider.max_value, 200.0)
	)
	_expect(sett_resource_visible, "ArtDev 腕豪显示 0–200 连续豪意条并允许直接调整测试值")

	_main._pending_active_skill_impacts.clear()
	_main._active_skill_effect_system.clear()
	if is_instance_valid(gwen):
		gwen.free()
	if is_instance_valid(sett):
		sett.free()
	_main._art_dev_panel = old_panel
	_main._art_dev_selection = old_selection
	_main._art_dev_team = old_team
	_main._art_dev_last_units = old_last_units
	_main._art_dev_active_skill_choices = old_choices
	panel.free()

func _check_cast_control_pause_and_death_cancel() -> void:
	_reset_local_elixir()
	var old_deck: Array = _main._deck.duplicate()
	_main._deck = ["garen", "xin", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	var freeze_source: Unit = _main._spawn_unit(0, "garen", Vector2(260.0, 680.0), 0.0, 0)
	var freeze_skill: Dictionary = {
		"name": "冻结施法",
		"kind": "buff",
		"duration": 2.0,
		"cast_duration": 1.0,
		"impact_delay": 0.6,
		"shield": 100.0,
		"shield_duration": 2.0,
		"cast_locks": ["movement", "attack", "facing"],
	}
	var freeze_entry: Dictionary = _main._active_skills[freeze_source.active_ability_id]
	freeze_entry["skill"] = freeze_skill
	_main._active_skills[freeze_source.active_ability_id] = freeze_entry
	var freeze_queued: bool = _main._queue_active_skill(freeze_source.active_ability_id, 0, 0)
	_run_main_ticks(_main.COMMAND_DELAY_TICKS)
	_run_main_ticks(4)
	var freeze_cast_before: float = freeze_source.active_skill_cast_timer
	var freeze_impact_before: float = float(_main._pending_active_skill_impacts[0].time_left)
	freeze_source.freeze(0.3)
	_run_main_ticks(6)
	var freeze_paused: bool = (
		is_zero_approx(freeze_source.active_skill_cast_timer - freeze_cast_before)
		and is_zero_approx(float(_main._pending_active_skill_impacts[0].time_left) - freeze_impact_before)
		and is_zero_approx(freeze_source.shield_hp)
	)
	_run_main_ticks(7)
	var freeze_still_waiting: bool = is_zero_approx(freeze_source.shield_hp)
	_run_main_ticks(2)
	var freeze_resumed: bool = freeze_source.shield_hp > 0.0

	var stun_source: Unit = _main._spawn_unit(0, "xin", Vector2(260.0, 900.0), 0.0, 1)
	var stun_skill: Dictionary = freeze_skill.duplicate(true)
	stun_skill["name"] = "眩晕施法"
	var stun_entry: Dictionary = _main._active_skills[stun_source.active_ability_id]
	stun_entry["skill"] = stun_skill
	_main._active_skills[stun_source.active_ability_id] = stun_entry
	var stun_queued: bool = _main._queue_active_skill(stun_source.active_ability_id, 0, 0)
	_run_main_ticks(_main.COMMAND_DELAY_TICKS)
	_run_main_ticks(4)
	var stun_cast_before: float = stun_source.active_skill_cast_timer
	var stun_impact_before: float = float(_main._pending_active_skill_impacts[0].time_left)
	stun_source.stun(0.3)
	_run_main_ticks(6)
	var stun_paused: bool = (
		is_zero_approx(stun_source.active_skill_cast_timer - stun_cast_before)
		and is_zero_approx(float(_main._pending_active_skill_impacts[0].time_left) - stun_impact_before)
		and is_zero_approx(stun_source.shield_hp)
	)
	_run_main_ticks(7)
	var stun_still_waiting: bool = is_zero_approx(stun_source.shield_hp)
	_run_main_ticks(2)
	var stun_resumed: bool = stun_source.shield_hp > 0.0

	var death_source: Unit = _main._spawn_unit(0, "garen", Vector2(520.0, 680.0), 0.0, 0)
	var death_ability_id: int = death_source.active_ability_id
	var death_entry: Dictionary = _main._active_skills[death_ability_id]
	death_entry["skill"] = freeze_skill
	_main._active_skills[death_ability_id] = death_entry
	var death_queued: bool = _main._queue_active_skill(death_ability_id, 0, 0)
	_run_main_ticks(_main.COMMAND_DELAY_TICKS)
	_run_main_ticks(3)
	death_source.take_damage(death_source.hp + 1.0)
	_run_main_ticks(12)
	var death_cancelled: bool = is_zero_approx(death_source.shield_hp) and _main._pending_active_skill_impacts.is_empty()
	_expect(
		freeze_queued and freeze_paused and freeze_still_waiting and freeze_resumed
		and stun_queued and stun_paused and stun_still_waiting and stun_resumed
		and death_queued and death_cancelled,
		"Cast 中途 Freeze/Stun 暂停 cast/impact 并从剩余时间继续，施法者死亡取消未发生的 Impact",
	)
	_main._on_active_skill_unit_died(freeze_source.active_ability_id)
	_main._on_active_skill_unit_died(stun_source.active_ability_id)
	_main._on_active_skill_unit_died(death_ability_id)
	freeze_source.free()
	stun_source.free()
	death_source.free()
	_main._pending_active_skill_impacts.clear()
	_main._deck = old_deck

func _check_authoritative_hand_cycle() -> void:
	var old_deck: Array = _main._deck.duplicate()
	_main._deck = ["garen", "xin", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	_main._initialize_authoritative_card_cycle(0, _main._deck)
	_main._elixir.elixir = ElixirManager.MAX_ELIXIR
	var hand_before: Array = _main.get_authoritative_hand(0)
	var queue_before: Array = _main.get_authoritative_queue(0)
	var accepted: bool = _main.play_card(0, "garen", Vector2(300.0, 980.0), {"elixir": _main._elixir, "validate_position": false})
	var hand_after: Array = _main.get_authoritative_hand(0)
	var queue_after: Array = _main.get_authoritative_queue(0)
	var elixir_after_accept: float = _main._elixir.elixir
	var duplicate_rejected: bool = not _main.play_card(0, "garen", Vector2(300.0, 980.0), {"elixir": _main._elixir, "validate_position": false})
	var cycle_unchanged_after_duplicate: bool = _main.get_authoritative_hand(0) == hand_after and _main.get_authoritative_queue(0) == queue_after
	_main._elixir.elixir = 0.0
	var insufficient_rejected: bool = not _main.play_card(0, "xin", Vector2(340.0, 980.0), {"elixir": _main._elixir, "validate_position": false})
	var cycle_unchanged_after_insufficient: bool = _main.get_authoritative_hand(0) == hand_after
	var deck_card_not_in_hand_rejected: bool = not _main.play_card(0, "tombstone", Vector2(420.0, 980.0), {"elixir": _main._elixir, "validate_position": false})
	_expect(
		accepted
		and hand_before == ["garen", "xin", "freeze", "ashe"]
		and queue_before == ["teemo", "masteryi", "tombstone", "aurelionsol"]
		and hand_after == ["teemo", "xin", "freeze", "ashe"]
		and queue_after == ["masteryi", "tombstone", "aurelionsol", "garen"]
		and is_equal_approx(elixir_after_accept, 5.0)
		and duplicate_rejected and cycle_unchanged_after_duplicate
		and insufficient_rejected and cycle_unchanged_after_insufficient
		and deck_card_not_in_hand_rejected,
		"权威手牌只接受当前 hand，成功后一次性扣费/轮换，重复、缺牌和金币不足均不改变状态",
	)
	_main._pending_card_deployments.clear()
	_main._elixir.elixir = ElixirManager.MAX_ELIXIR
	_main._deck = old_deck
	_main._initialize_authoritative_card_cycle(0, old_deck)

func _check_network_hand_confirmation() -> void:
	var old_mode: String = _main.mode
	var old_deck: Array = _main._deck.duplicate()
	var old_remote_deck: Array = _main._remote_deck.duplicate()
	var old_cycles: Dictionary = _main._authoritative_card_cycles.duplicate(true)
	var old_elixir_p1: ElixirManager = _main._elixir_p1
	var old_elixir_value: float = _main._elixir.elixir
	var old_sim_tick: int = _main._sim_tick_id
	var deck: Array = ["garen", "xin", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	var network_elixir: ElixirManager = ElixirManager.new()
	_main.add_child(network_elixir)
	_main._elixir_p1 = network_elixir
	_main._remote_deck = deck.duplicate()
	_main.mode = "host"
	_main._sim_tick_id = 103
	_main._initialize_authoritative_card_cycle(1, deck)
	network_elixir.elixir = ElixirManager.MAX_ELIXIR
	var host_initial_hand: Array = _main.get_authoritative_hand(1)
	var host_initial_queue: Array = _main.get_authoritative_queue(1)
	_main._rpc_deploy_request("garen", Vector2(300.0, 580.0), 100)
	var host_accepted_hand: Array = _main.get_authoritative_hand(1)
	var host_accepted_queue: Array = _main.get_authoritative_queue(1)
	var host_elixir_after_accept: float = network_elixir.elixir
	var host_pending_after_accept: int = _main._pending_card_deployments.size()
	var host_hand_before_reject: Array = host_accepted_hand.duplicate()
	var host_queue_before_reject: Array = host_accepted_queue.duplicate()
	var host_elixir_before_reject: float = network_elixir.elixir
	_main._rpc_deploy_request("garen", Vector2(300.0, 580.0), 100)
	var host_reject_kept_state: bool = (
		_main.get_authoritative_hand(1) == host_hand_before_reject
		and _main.get_authoritative_queue(1) == host_queue_before_reject
		and is_equal_approx(network_elixir.elixir, host_elixir_before_reject)
		and _main._pending_card_deployments.size() == host_pending_after_accept
	)
	_main._sim_tick_id = 110
	var host_hand_before_late: Array = _main.get_authoritative_hand(1)
	var host_queue_before_late: Array = _main.get_authoritative_queue(1)
	var host_elixir_before_late: float = network_elixir.elixir
	var host_pending_before_late: int = _main._pending_card_deployments.size()
	_main._rpc_deploy_request("xin", Vector2(300.0, 580.0), 100)
	var host_late_reject_kept_state: bool = (
		_main.get_authoritative_hand(1) == host_hand_before_late
		and _main.get_authoritative_queue(1) == host_queue_before_late
		and is_equal_approx(network_elixir.elixir, host_elixir_before_late)
		and _main._pending_card_deployments.size() == host_pending_before_late
	)
	var host_accept_once: bool = (
		host_initial_hand == ["garen", "xin", "freeze", "ashe"]
		and host_initial_queue == ["teemo", "masteryi", "tombstone", "aurelionsol"]
		and host_accepted_hand == ["teemo", "xin", "freeze", "ashe"]
		and host_accepted_queue == ["masteryi", "tombstone", "aurelionsol", "garen"]
		and is_equal_approx(host_elixir_after_accept, 5.0)
		and host_pending_after_accept == 1
	)

	_main.mode = "client"
	_main._deck = deck.duplicate()
	_main._initialize_authoritative_card_cycle(1, deck)
	_main._elixir.elixir = ElixirManager.MAX_ELIXIR
	_main._hand.set_card_pending("garen", false)
	_main._hand.set_card_pending("xin", false)
	var client_initial_hand: Array = _main.get_authoritative_hand(1)
	var client_initial_queue: Array = _main.get_authoritative_queue(1)
	var client_elixir_before_request: float = _main._elixir.elixir
	# 单元回归不建立第二个 ENet peer；这里模拟客户端请求已发出后的 pending UI 状态。
	_main._hand.set_card_pending("garen", true)
	var client_pending_request: bool = (
		_main._hand.is_card_pending("garen")
		and _main.get_authoritative_hand(1) == client_initial_hand
		and _main.get_authoritative_queue(1) == client_initial_queue
		and is_equal_approx(_main._elixir.elixir, client_elixir_before_request)
	)
	_main._rpc_deploy_accepted("garen", _main.get_estimated_server_tick() + _main.COMMAND_DELAY_TICKS, host_accepted_hand, host_accepted_queue)
	var client_after_accept_hand: Array = _main.get_authoritative_hand(1)
	var client_after_accept_queue: Array = _main.get_authoritative_queue(1)
	var client_accept_synced: bool = (
		client_initial_hand == host_initial_hand
		and client_initial_queue == host_initial_queue
		and client_after_accept_hand == host_accepted_hand
		and client_after_accept_queue == host_accepted_queue
		and not _main._hand.is_card_pending("garen")
	)
	var client_hand_before_reject: Array = client_after_accept_hand.duplicate()
	var client_queue_before_reject: Array = client_after_accept_queue.duplicate()
	var client_elixir_before_reject: float = _main._elixir.elixir
	_main._hand.set_card_pending("xin", true)
	_main._rpc_deploy_rejected("xin")
	var client_reject_kept_state: bool = (
		_main.get_authoritative_hand(1) == client_hand_before_reject
		and _main.get_authoritative_queue(1) == client_queue_before_reject
		and is_equal_approx(_main._elixir.elixir, client_elixir_before_reject)
		and not _main._hand.is_card_pending("xin")
	)
	_expect(host_accept_once and host_reject_kept_state and host_late_reject_kept_state and client_pending_request and client_accept_synced and client_reject_kept_state, "联机出牌 accepted 同步手牌/队列，late/rejected 不扣费不轮换且仅恢复 pending UI")

	_main._pending_card_deployments.clear()
	_main.mode = old_mode
	_main._deck = old_deck
	_main._remote_deck = old_remote_deck
	_main._authoritative_card_cycles = old_cycles
	_main._elixir_p1 = old_elixir_p1
	_main._sim_tick_id = old_sim_tick
	_main._elixir.elixir = old_elixir_value
	if is_instance_valid(network_elixir):
		network_elixir.free()
	_main._initialize_authoritative_card_cycle(0, old_deck)

func _check_empowered_freeze_slow_zone() -> void:
	var stats: Dictionary = CardDB.get_unit_stats("imp").duplicate()
	stats["deploy_time"] = 0.0
	var enemy := Unit.new()
	enemy.position = Vector2(360.0, 600.0)
	enemy.setup(1, stats, stats.name)
	_main.add_child(enemy)
	_main._apply_freeze(enemy.position, 110.0, 3.0, 0, 2.0, 0.5)
	_main._tick_slow_zones(2.95)
	var delayed_ok := enemy.slow_timer <= 0.0
	_main._tick_slow_zones(0.05)
	_main._tick_slow_zones(_main.SIM_DT)
	enemy._prepare_movement(Vector2.UP, _main.SIM_DT)
	var slowed_ok := enemy.slow_timer > 0.0 and is_equal_approx(enemy._move_intent.length(), enemy.move_speed * 0.5)
	_main._tick_slow_zones(2.0)
	_expect(delayed_ok and slowed_ok, "主动版冰冻在 3 秒冻结结束后才开启区域减速")
	_expect(_main._slow_zones.is_empty(), "强化冰冻减速区域持续 2 秒后由权威模拟移除")
	_main._freeze_effects.clear()
	_main._slow_effects.clear()
	enemy.free()

func _check_heal_spell() -> void:
	var heal_stats: Dictionary = CardDB.get_card("heal")
	var heal_amount := float(heal_stats.get("heal_amount", 0.0))
	var enhanced_heal := heal_amount * float(heal_stats.get("active_heal_multiplier", 1.0))
	var shield_amount := float(heal_stats.get("active_shield", 0.0))
	# 以己方公主塔为中心，确保防御塔落在治疗/护盾范围内，便于验证强化版对建筑生效。
	var tower: Tower = _main._towers[0]
	var cast_pos := tower.position
	# 范围内重伤单位 + 范围内轻伤单位（验证不溢出上限）+ 范围外单位 + 范围内建筑卡。
	var hurt: Unit = _main._spawn_unit(0, "masteryi", cast_pos + Vector2(80.0, 0.0), 0.0, -1)
	var nearly_full: Unit = _main._spawn_unit(0, "masteryi", cast_pos + Vector2(-80.0, 0.0), 0.0, -1)
	var distant: Unit = _main._spawn_unit(0, "masteryi", cast_pos + Vector2(0.0, -400.0), 0.0, -1)
	var building: Unit = _main._spawn_unit(0, "tombstone", cast_pos + Vector2(0.0, 80.0), 0.0, -1)
	hurt.take_damage(400.0, null, 1, hurt.position)
	nearly_full.take_damage(50.0, null, 1, nearly_full.position)
	distant.take_damage(400.0, null, 1, distant.position)
	building.take_damage(200.0, null, 1, building.position)
	var tower_damage := 260.0
	tower.take_damage(tower_damage, null, 1, tower.position)
	var hurt_before := hurt.hp
	var nearly_full_before := nearly_full.hp
	var distant_before := distant.hp
	var building_before := building.hp
	var tower_before := tower.hp
	var tower_id := int(tower.get_instance_id())

	# 普通治疗：范围内单位回复，不溢出上限；建筑卡、防御塔不吃治疗也没有护盾。
	_main._cast_spell(0, "heal", cast_pos, false)
	var base_healed: bool = (
		is_equal_approx(hurt.hp, hurt_before + heal_amount)
		and is_equal_approx(nearly_full.hp, nearly_full.max_hp)
		and is_equal_approx(distant.hp, distant_before)
	)
	var base_skips_structures: bool = (
		is_equal_approx(building.hp, building_before)
		and is_equal_approx(tower.hp, tower_before)
		and building.shield_hp <= 0.0
		and tower.shield_hp <= 0.0
		and hurt.shield_hp <= 0.0
	)
	_expect(base_healed and base_skips_structures, "普通治疗术回复范围内友军单位且不超过最大生命值，对建筑卡/防御塔无治疗无护盾")
	_main._heal_effects.clear()

	# 重新压低生命后释放强化治疗：全图单位按提高后的数值回复，范围内友军（含建筑）获得护盾。
	hurt.hp = hurt_before
	nearly_full.hp = nearly_full_before
	distant.hp = distant_before
	tower.hp = tower_before
	_main._cast_spell(0, "heal", cast_pos, true)
	var enhanced_global_heal: bool = (
		is_equal_approx(hurt.hp, hurt_before + enhanced_heal)
		and is_equal_approx(distant.hp, distant_before + enhanced_heal)
		and is_equal_approx(nearly_full.hp, nearly_full.max_hp)
	)
	var enhanced_shield_scope: bool = (
		is_equal_approx(hurt.shield_hp, shield_amount)
		and distant.shield_hp <= 0.0
		and is_equal_approx(building.shield_hp, shield_amount)
		and is_equal_approx(tower.shield_hp, shield_amount)
		and is_equal_approx(building.hp, building_before)
		and is_equal_approx(tower.hp, tower_before)
	)
	_expect(enhanced_global_heal and enhanced_shield_scope, "强化治疗全图友军单位按提高后数值回复且不溢出，范围内友军（含建筑卡/防御塔）获得护盾但生命不变")
	_expect(_main._heal_effects.size() > 0 and bool(_main._heal_effects[0].get("enhanced", false)), "治疗术淡黄光效进入表现队列并标记强化版")
	_main._heal_effects.clear()

	for unit in [hurt, nearly_full, distant, building]:
		(unit as Unit).shield_hp = 0.0
		(unit as Unit).shield_max_hp = 0.0
		(unit as Unit).shield_timer = 0.0
		if is_instance_valid(unit):
			unit.free()
	if is_instance_id_valid(tower_id) and is_instance_valid(tower):
		tower.shield_hp = 0.0
		tower.shield_max_hp = 0.0
		tower.shield_timer = 0.0
		tower.hp = tower.max_hp
		tower.queue_redraw()

	# 主动槽费用：治疗术在卡组前两位时费用 +1，其余位置保持 3 费。
	var old_deck: Array = _main._deck.duplicate()
	var old_elixir: float = _main._elixir.elixir
	_main._deck = ["heal", "garen", "xin", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	_reset_local_elixir()
	_main._elixir.elixir = 6.0
	var played: bool = _main.play_card(0, "heal", cast_pos, {"elixir": _main._elixir, "immediate": true})
	var active_cost_charged: bool = played and is_equal_approx(_main._elixir.elixir, 2.0)
	_main._heal_effects.clear()
	_main._deck = ["garen", "heal", "xin", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	_reset_local_elixir()
	_main._elixir.elixir = 6.0
	played = _main.play_card(0, "heal", cast_pos, {"elixir": _main._elixir, "immediate": true})
	var second_slot_cost_charged: bool = played and is_equal_approx(_main._elixir.elixir, 2.0)
	_main._heal_effects.clear()
	_main._deck = ["garen", "xin", "heal", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	_reset_local_elixir()
	_main._elixir.elixir = 6.0
	played = _main.play_card(0, "heal", cast_pos, {"elixir": _main._elixir, "immediate": true})
	var normal_cost_charged: bool = played and is_equal_approx(_main._elixir.elixir, 3.0)
	_main._heal_effects.clear()
	_expect(active_cost_charged and second_slot_cost_charged and normal_cost_charged, "治疗术位于主动槽（前两个卡位）施放费用 +1，在普通卡位保持原费用")
	_main._deck = old_deck
	_main._elixir.elixir = old_elixir
