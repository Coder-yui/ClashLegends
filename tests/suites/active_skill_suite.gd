class_name ActiveSkillSuite
extends RefCounted

var _harness: Object
var _main: Node2D

func _expect(condition: bool, message: String) -> void:
	_harness._expect(condition, message)

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_active_skill_loadout_rule()
	_check_active_skill_activation()
	_check_pending_active_skill_revalidation()
	_check_empowered_freeze_slow_zone()

func _check_active_skill_loadout_rule() -> void:
	var cards := CardDB.all()
	var data_ok := true
	for card_id in CardDB.selectable_ids():
		var stats: Dictionary = cards[card_id]
		if stats.get("type", "unit") == "spell":
			data_ok = data_ok and CardDB.active_skills_for(card_id).is_empty()
		else:
			var available_skills := CardDB.active_skills_for(card_id)
			data_ok = data_ok and available_skills.size() == 1 and not String(available_skills[0].get("name", "")).is_empty()
	_expect(data_ok, "当前每张可选单位/建筑卡恰有一个可携带主动技能，法术卡不生成主动按钮")
	var left_position: Vector2 = ActiveSkillBar.LEFT_SLOT_POSITION
	var right_position: Vector2 = ActiveSkillBar.RIGHT_SLOT_POSITION
	_expect(
		is_equal_approx(left_position.x + right_position.x + ActiveSkillBar.BUTTON_SIZE.x, _main.FIELD_W)
		and is_equal_approx(left_position.y, right_position.y),
		"主动槽 2 圆位以战场中线严格镜像主动槽 1"
	)
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

func _check_active_skill_activation() -> void:
	var old_deck: Array = _main._deck.duplicate()
	_main._deck = ["garen", "xin", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	var first_source: Unit = _main._spawn_unit(0, "garen", Vector2(340.0, 800.0), 0.0, 0)
	var first_ability_id := first_source.active_ability_id
	var source: Unit = _main._spawn_unit(0, "garen", Vector2(380.0, 800.0), 0.0, 0)
	var enemy_stats: Dictionary = CardDB.imp_stats().duplicate()
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
	_main._active_skill_bar.set_pending(ability_id, true)
	_main._tick_pending_active_skills(0.45)
	_expect(
		queued and is_equal_approx(enemy.hp, hp_before) and is_zero_approx(source.shield_hp)
		and _main._active_skills.has(ability_id) and _main._active_skill_bar.is_slot_visible(0),
		"点击主动技能后 0.45 秒仍处于等待状态，不提前结算"
	)
	_main._tick_pending_active_skills(0.05)
	_expect(enemy.hp < hp_before and source.shield_hp > 0.0, "满 0.5 秒后由权威逻辑造成范围伤害并获得护盾")
	_expect(
		not _main._active_skills.has(ability_id)
		and not _main._activate_active_skill(ability_id, 0)
		and not _main._active_skill_bar.is_slot_visible(0),
		"主动技能结算一次后固定圆位立即隐藏"
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

func _check_pending_active_skill_revalidation() -> void:
	var old_deck: Array = _main._deck.duplicate()
	_main._deck = ["garen", "xin", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	var enemy_stats: Dictionary = CardDB.imp_stats().duplicate(true)
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
	_main._tick_pending_active_skills(_main.ACTIVE_SKILL_CAST_DELAY)
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
	var pending_impacts_before: int = _main._pending_frontal_stun_skills.size()
	var transformed_after_click := gnar.transform_to_mega()
	var transform_action_serial := gnar.get_visual_action_serial()
	_main._tick_pending_active_skills(_main.ACTIVE_SKILL_CAST_DELAY)
	_expect(
		queued_before_transform
		and transformed_after_click
		and _main._active_skills.has(gnar_ability_id)
		and _main._pending_frontal_stun_skills.size() == pending_impacts_before
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
	_main._tick_pending_active_skills(_main.ACTIVE_SKILL_CAST_DELAY)
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
	_main._tick_pending_active_skills(_main.ACTIVE_SKILL_CAST_DELAY)
	_expect(rejected_during_cast, "主动 pending 到期时若已进入另一段 active cast，会拒绝效果/技能动作并恢复按钮")
	_expect(
		queued_after_cast and enemy.hp < hp_before_cast_reject and casting_source.shield_hp > 0.0
		and not _main._active_skills.has(casting_ability_id),
		"pending 期间权威状态始终合法时，主动技能仍在 0.5 秒后正常释放",
	)
	casting_source.free()
	enemy.free()
	_main._deck = old_deck

func _check_empowered_freeze_slow_zone() -> void:
	var stats: Dictionary = CardDB.imp_stats().duplicate()
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
