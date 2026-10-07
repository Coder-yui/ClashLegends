extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var unit := spawn("nocturne", 0, Vector2(200, 900))
	var foe := spawn("nocturne", 1, Vector2(245, 900))
	var neighbour := spawn("nocturne", 1, Vector2(200, 950))
	foe.hp = 10000.0
	neighbour.hp = 10000.0
	for index in 10:
		var before := foe.hp
		var nearby := neighbour.hp
		unit._target = foe
		unit._attacking = true
		unit.attack_timeline.cooldown = 0.0
		unit.attack_timeline.windup = 0.0
		unit.attack_timeline.recovery = 0.0
		unit._attack(0.05)
		_expect(before - foe.hp == 95.0, "普通攻击不再有第五击被动 %d" % index)
		_expect(nearby - neighbour.hp == 0.0, "普通攻击不溅射 %d" % index)
	var cleave: Dictionary = CardDB.active_skills_for("nocturne")[1]
	_expect(cleave.cost == 1 and cleave.max_uses == 2 and cleave.cooldown == 8.0 and cleave.cleave_damage == CardDB.PRINCESS_TOWER_STATS.damage, "暗影之刃费用次数冷却与塔伤一致")
	var animations: Dictionary = CardDB.get_card("nocturne").visual_animations
	_expect(animations.attack == ["Attack1", "Attack2"] and animations.empowered_attack == "Attack3", "普通双段循环与专用强化动画")
	_expect(animations.death_clip_end == 1.5 and animations.death_duration == 0.8, "死亡前1.5秒压缩到0.8秒")
	unit.hp = 100.0
	_expect(_main.preview_active_skill(unit, cleave), "可选溅射技能正式入口")
	var primary_before := foe.hp
	var neighbour_before := neighbour.hp
	strike(unit, foe)
	_expect(primary_before - foe.hp == 150.0 and neighbour_before - neighbour.hp == 55.0, "强化攻击主目标150旁目标55")
	_expect(unit.hp == 162.0, "总实际伤害205的30%四舍五入回血62")
	_expect(not unit.empowered_attack_ready and unit.empowered_attack_effects.is_empty(), "强化命中消耗一次")
	primary_before = foe.hp
	neighbour_before = neighbour.hp
	strike(unit, foe)
	_expect(primary_before - foe.hp == 95.0 and neighbour_before == neighbour.hp and unit.hp == 162.0, "后续普攻不残留溅射或回血")
	# Shield absorption and overkill do not contribute to healing.
	foe.hp = 10.0
	neighbour.hp = 10000.0
	neighbour.add_shield(1000.0, 10.0)
	unit.hp = 100.0
	_main.preview_active_skill(unit, cleave)
	strike(unit, foe)
	_expect(unit.hp == 103.0, "只按实际掉血回血，排除过量与护盾吸收")
	foe = spawn("nocturne", 1, Vector2(245, 900))
	foe.hp = 10000.0
	neighbour.shields.clear()
	unit.hp = 100.0
	_main.preview_active_skill(unit, cleave)
	arm(foe)
	arm(neighbour)
	strike(unit, foe)
	_expect(unit.hp == 100.0 and not unit.empowered_attack_ready, "完全被效果盾抵挡不回血且消耗强化")
	unit.hp = 100.0
	_main.preview_active_skill(unit, cleave)
	unit.apply_blind(1)
	primary_before = foe.hp
	strike(unit, foe)
	_expect(unit.hp == 100.0 and foe.hp == primary_before and not unit.empowered_attack_ready, "致盲消耗强化且不伤害不回血")
	# 施法者中心到目标身体边缘：覆盖缩小后的范围边界。
	var probe := spawn("nocturne", 0, Vector2(450, 900))
	var primary := spawn("nocturne", 1, Vector2(490, 900))
	var inside := spawn("nocturne", 1, Vector2(450, 987.9))
	var outside := spawn("nocturne", 1, Vector2(450, 988.1))
	inside.hp = 10000.0
	outside.hp = 10000.0
	_main.preview_active_skill(probe, cleave)
	strike(probe, primary)
	_expect(inside.hp == 9945.0 and outside.hp == 10000.0, "P半径70加目标身体18：边缘内命中、边缘外不命中")
	var invalid: Dictionary = CardDB.get_card("nocturne").duplicate(true)
	invalid.active_skills[1].cleave_radius = 0.0
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all({"nocturne": invalid}, false).is_empty(), "强化溅射缺有效半径被拒绝")
	var skill: Dictionary = CardDB.active_skills_for("nocturne")[0]
	var rewarded := spawn("nocturne", 0, Vector2(550, 900))
	_main.preview_active_skill(rewarded, skill)
	_expect(is_equal_approx(rewarded.active_attack_speed_multiplier, 1.0), "W仅开盾不增加攻速")
	var reward_context := CombatInteraction.effect_context(foe)
	var reward_delivery := CombatInteraction.Delivery.new()
	reward_context.delivery = reward_delivery
	_expect(CombatInteraction.blocks_effect(rewarded, reward_context), "W成功抵挡触发奖励")
	_expect(is_equal_approx(rewarded.active_attack_speed_multiplier, 1.3) and not rewarded.get_active_buff_active_visual(), "抵挡后30%攻速且护盾表现关闭")
	var reward_snapshot: Array = _main._snapshot_system._unit_snapshot_payload(4243, rewarded)
	_expect(is_equal_approx(float(reward_snapshot[NetworkSnapshotSystem.U_ACTIVE_ATTACK_SPEED_MULTIPLIER]), 1.3) and not reward_snapshot[NetworkSnapshotSystem.U_ACTIVE_BUFF_ACTIVE], "攻速奖励快照1.3且护盾关闭")
	rewarded.buffs.advance(0.5)
	CombatInteraction.blocks_effect(rewarded, reward_context)
	_expect(is_equal_approx(rewarded.buffs.remaining(&"hit_haste"), 1.5), "同次效果多段不刷新攻速奖励")
	rewarded.buffs.advance(1.45)
	_expect(is_equal_approx(rewarded.active_attack_speed_multiplier, 1.3), "奖励第39Tick仍有效")
	rewarded.buffs.advance(0.05)
	_expect(is_equal_approx(rewarded.active_attack_speed_multiplier, 1.0), "奖励第40Tick到期")
	_main.preview_active_skill(rewarded, skill)
	rewarded.buffs.advance(1.5)
	_expect(is_equal_approx(rewarded.active_attack_speed_multiplier, 1.0), "护盾自然到期不奖励攻速")
	var enemy := CombatInteraction.effect_context(foe)
	var friend := CombatInteraction.effect_context(unit)
	arm(unit)
	unit.apply_stasis(1.0, &"friend", friend)
	_expect(unit.buffs.remaining(&"effect_shield") == 1.5 and CombatInteraction.in_stasis(unit), "友方凝滞生效且不耗盾")
	unit.control.hard.clear_family(&"stasis")
	unit.buffs.suppressed = false
	unit.apply_slow(2.0, 0.5, &"new_slow", enemy)
	_expect(unit.control.slow_timer == 0.0 and unit.buffs.remaining(&"effect_shield") == 0.0, "新敌方减速被整体抵挡")
	unit.apply_slow(2.0, 0.5, &"existing", enemy)
	arm(unit)
	var attached := enemy.duplicate()
	attached.attached = true
	unit.apply_slow(2.0, 0.5, &"existing", attached)
	var before := unit.hp
	unit.take_damage(10, foe, foe.team, foe.global_position, true)
	_expect(unit.hp == before - 10 and unit.buffs.remaining(&"effect_shield") == 1.5, "已有持续伤害和减速不被护盾抵挡")
	var resolver: CombatResolver = unit.battle_context.damage_batch()
	resolver.begin_batch(0, "nocturne")
	var first := BattleNumbers.hit(unit, 50, foe, foe.team, foe.global_position)
	var second := BattleNumbers.hit(unit, 70, foe, foe.team, foe.global_position)
	resolver.commit_batch()
	_expect(not first.landed and second.landed and unit.hp == before - 80, "同Tick两次独立攻击只挡一次")
	arm(unit)
	var delivery := CombatInteraction.Delivery.new()
	var previous := CombatInteraction.current_delivery
	CombatInteraction.current_delivery = delivery
	var context := CombatInteraction.effect_context(foe)
	before = unit.hp
	BattleNumbers.hit(unit, 60, foe, foe.team, foe.global_position)
	unit.stun(1.0, &"skill", context)
	BattleNumbers.hit(unit, 60, foe, foe.team, foe.global_position)
	CombatInteraction.current_delivery = previous
	_expect(unit.hp == before and not unit.is_stunned(), "一次技能各段伤害与附带眩晕一起被挡")
	arm(unit)
	unit.buffs.advance(1.45)
	_expect(unit.buffs.remaining(&"effect_shield") > 0, "第29Tick仍有盾")
	unit.buffs.advance(0.05)
	_expect(unit.buffs.remaining(&"effect_shield") == 0, "第30Tick到期")
	# Exercise real skill and spell consumers, not only direct status methods.
	unit.control.modifiers.clear_family(&"slow")
	unit.control.modifiers.clear_family(&"attack_slow")
	unit.control.clear_on_death()
	arm(unit)
	before = unit.hp
	_main._spell_system._resolve_cast(1, CardDB.get_card("zap"), unit.global_position, false, 0)
	_expect(unit.hp == before and not unit.is_stunned() and unit.buffs.remaining(&"effect_shield") == 0.0, "真实电击伤害和附带眩晕同时抵挡")
	arm(unit)
	_main._spell_system.apply_freeze(unit.global_position, 80.0, 0.1, 1, 2.0, 0.5, 0.5)
	_expect(not unit.is_frozen() and unit.buffs.remaining(&"effect_shield") == 0.0, "强化冰冻起始控制被挡")
	for index in 4: _main._spell_system.tick(0.05)
	_expect(unit.control.slow_timer == 0.0 and unit.control.attack_speed_slow_timer == 0.0, "同次强化冰冻后续减速不穿盾")
	_main._spell_system.clear()
	_main._spell_system.apply_freeze(unit.global_position, 80.0, 0.0, 1, 2.0, 0.5, 0.5)
	_main._spell_system.tick(0.05)
	arm(unit)
	_main._spell_system.tick(0.05)
	_expect(unit.control.slow_timer > 0.0 and unit.buffs.remaining(&"effect_shield") == 1.5, "已有强化冰冻区域继续生效且不耗盾")
	unit.control.clear_on_death()
	unit.buffs.clear_family(&"effect_shield")
	var cooldown := unit.attack_timeline.cooldown
	_expect(_main.preview_active_skill(unit, skill), "正式主动生命周期可开盾")
	_expect(unit.buffs.remaining(&"effect_shield") == 1.5 and unit.attack_timeline.cooldown == cooldown, "开盾即时生效且保留普攻进度")
	var snap: Array = _main._snapshot_system._unit_snapshot_payload(4242, unit)
	_expect(snap[NetworkSnapshotSystem.U_ACTIVE_BUFF_ACTIVE], "护盾表现通过既有快照状态同步")
	_expect(skill.cost == 2 and skill.max_uses == 1 and skill.cooldown == 10.0, "主动费用次数冷却契约")

	_check_shield_visual_refresh()
	var old_deck: Array = _main._deck.duplicate()
	var old_choices: Dictionary = _main._active_skill_choices.duplicate(true)
	_main._deck = ["nocturne", "xin", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	_main._active_skill_choices["nocturne"] = 1
	var selected: Unit = _main._spawn_unit(UnitSpawnRequest.new(0, "nocturne", Vector2(360, 1100), {"deploy_time_override": 0.0, "active_slot": 0}))
	var carried: Dictionary = _main._active_skills.entry(selected.active_ability_id).skill
	_expect(carried.name == "暗影之刃" and carried.kind == "empowered_attack" and carried.icon_path == "res://assets/skills/nocturne_p.png", "备战选择只携带暗影之刃及原版被动图标")
	_main._on_active_skill_unit_died(selected.active_ability_id)
	selected.free()
	_main._active_skill_choices = old_choices
	_main._deck = old_deck

func arm(unit: Unit) -> void:
	unit.buffs.apply(&"effect_shield", &"test", 1.5, {})

func spawn(id: String, team: int, pos: Vector2) -> Unit:
	var unit: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, id, pos, {"deploy_time_override": 0.0}))
	unit._deploy_timer = 0.0
	return unit

func strike(unit: Unit, foe: Unit) -> void:
	unit._target = foe
	unit._attacking = true
	unit.attack_timeline.cooldown = 0.0
	unit.attack_timeline.windup = 0.0
	unit.attack_timeline.recovery = 0.0
	unit._attack(0.05)

func _check_shield_visual_refresh() -> void:
	var effect = load("res://assets/effects/nocturne/nocturne_effects.tscn").instantiate()
	_main.add_child(effect)
	effect.configure(18.0, 0)
	var previous_id := 0
	for use in 3:
		effect.on_cue(&"effect_shield:start")
		effect.advance(true, 0.4)
		_expect(effect.shield.get_instance_id() != previous_id and effect.shield._particles.size() > 0, "第%d次连续开盾重新生成特效" % (use + 1))
		previous_id = effect.shield.get_instance_id()
		effect.advance(true, 0.9)
		_expect(effect.shield._particles.size() > 0, "第%d次护盾1.3秒仍有主体" % (use + 1))
	effect.advance(false, 0.0)
	_expect(effect.shield == null, "护盾结束停止主体发射")
	effect.advance(false, 1.1)
	_expect(effect.bursts.is_empty() and not effect.visible, "结束尾粒子正常回收")
	effect.on_cue(&"effect_shield:start")
	effect.advance(true, 0.4)
	_expect(effect.shield._particles.size() > 0 and effect.visible, "完全结束后再次开盾可见")
	effect.free()
