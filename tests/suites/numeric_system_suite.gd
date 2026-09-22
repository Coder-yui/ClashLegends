extends RefCounted
## 走真实结算路径，验证整数状态、实际掉血收益与持续效果总量。
var _h: Object
var _main: Node2D
var _units: Array[Unit] = []

func run(harness: Object, main: Node2D) -> void:
	_h = harness
	_main = main
	_check_attack_timeline_owner()
	_check_control_owner()
	_check_configuration()
	_check_lifesteal()
	_check_continuous()
	_check_decay()
	for unit in _units:
		if is_instance_valid(unit):
			unit.free()

func _unit(card_id: String, team: int = 1) -> Unit:
	var unit := Unit.new()
	unit.setup(team, CardDB.get_card(card_id), card_id)
	unit.position = Vector2(3000 + _units.size() * 500, 3000)
	_main.add_child(unit)
	_units.append(unit)
	return unit

func _check_configuration() -> void:
	for id in ["pix", "imp"]:
		var stats := CardDB.get_card(id)
		_h._expect(stats.hp == CardDB.PRINCESS_TOWER_STATS.damage and stats.damage == stats.hp, "%s 生命与攻击均锚定防御塔单次伤害55" % id)
	var invalid := CardDB.get_card("gwen").duplicate(true)
	invalid.hp = 580.25
	invalid.interval = 1.234
	invalid.active_skills[0].resource_hit_damage_sequences[0][0] = 40.5
	var errors := preload("res://scripts/data/card_validator.gd").validate_all({"gwen": invalid})
	var message := "\n".join(errors)
	_h._expect("gwen.hp" in message and "gwen.interval" in message and "resource_hit_damage_sequences[0][0]" in message, "数值校验拒绝小数生命、三位时间和嵌套小数伤害")
	var valid := CardDB.get_card("pix").duplicate(true)
	valid.active_skills[0].heal_ratio = 0.125
	_h._expect(preload("res://scripts/data/card_validator.gd").validate_all({"pix": valid}).is_empty(), "12.50%比例保留内部0.125，不被错误截成13%")
	_h._expect(BattleNumbers.format_value(1.2) == "1.20" and BattleNumbers.format_value(1.999) == "2" and BattleNumbers.format_value(0.125 * 100) == "12.50", "统一显示整数或两位小数，先舍入再判断整数")

func _hit(source: Unit, target: Unit, amount: float) -> void:
	_main.apply_damage_pulse(source, target, amount, 0.0, source.position, true)

func _check_lifesteal() -> void:
	var source := _unit("pix", 0)
	source.apply_attack_lifesteal(0.25, 1.5)
	var target := _unit("garen")
	source.hp = 20
	target.add_shield(100, 2)
	_hit(source, target, 55)
	_h._expect(source.hp == 20 and target.hp == target.max_hp and target.shield_hp == 45, "全护盾吸收的55点攻击不产生吸血")
	_hit(source, target, 55)
	_h._expect(source.hp == 23 and target.hp == target.max_hp - 10, "破盾后实际掉血10，25%吸血四舍五入回复3")
	target.hp = 7
	_hit(source, target, 55)
	_h._expect(source.hp == 25 and target.hp == 0, "击杀只按剩余7点生命吸血2，不计48点过量伤害")
	var fresh := _unit("garen")
	source.hp = 20
	source.on_hit_max_health_ratio = 0.05
	fresh.max_hp = 101
	fresh.hp = 101
	_hit(source, fresh, 50.5)
	_h._expect(fresh.hp == 45 and source.hp == 34, "半伤50.5取51，独立5%被动取5，实际掉血56参与吸血14")
	var tower := Tower.new()
	tower.setup(1, CardDB.PRINCESS_TOWER_STATS, false)
	_main.add_child(tower)
	tower.hp = 101
	tower.add_shield(10.5, 2)
	var result := BattleNumbers.hit(tower, 50.5, source, 0, source.position)
	_h._expect(result.health_lost == 40 and result.shield_absorbed == 11 and tower.hp == 61 and tower._health_text() == "61", "防御塔51点结算伤害扣除11护盾后掉血40，文本与整数生命一致")
	tower.free()

func _check_continuous() -> void:
	var source := _unit("aurelionsol", 0)
	var target := _unit("garen")
	var hp_before := target.hp
	var integer_steps := true
	for tick in range(20):
		_main.apply_damage_pulse(source, target, 55.0 * 0.05, 0.0, source.position, true, 0, {"continuous_damage": true})
		integer_steps = integer_steps and target.hp == roundf(target.hp)
	_h._expect(integer_steps and hp_before - target.hp == 55, "持续55DPS连续20Tick恰好扣55，每次掉血保持整数")
	var bonus_before := target.hp
	source.on_hit_max_health_ratio = 0.01
	for tick in range(20):
		_main.apply_damage_pulse(source, target, 55.0 * 0.05, 0.0, source.position, true, 0, {"continuous_damage": true})
	_h._expect(bonus_before - target.hp == 55 + 20 * BattleNumbers.quantity(target.max_hp * 0.01), "持续基础伤害余量与独立命中被动分别结算，不互相污染")
	source.on_hit_max_health_ratio = 0.0
	var other := _unit("garen")
	var other_before := other.hp
	var stream := BattleNumbers.DamageStream.new()
	stream.hit(target, 0.4, source, 0, source.position)
	stream.hit(other, 0.4, source, 0, source.position)
	_h._expect(other.hp == other_before, "切换目标不会把第一个目标的0.4余量转移给第二个目标")
	stream.hit(other, 0.4, source, 0, source.position)
	_h._expect(other.hp == other_before - 1, "低于1点的连续伤害积累后仍能造成整数伤害")
	var splash := _unit("garen")
	splash.position = target.position + Vector2(10, 0)
	var before_a := target.hp
	var before_b := splash.hp
	for tick in range(20):
		_main.apply_damage_pulse(source, target, 55.0 * 0.05, 35.0, source.position, true, 0, {"continuous_damage": true})
	_h._expect(before_a - target.hp == 55 and before_b - splash.hp == 55, "持续溅射对每个实际覆盖目标分别累计55DPS")

func _check_decay() -> void:
	var building := _unit("apex_turret")
	building.hp = 101
	building.max_hp = 101
	building.lifespan = 2.0
	building._lifespan_left = 2.0
	building.add_shield(50, 5)
	var integer_steps := true
	for tick in range(40):
		building._building_tick(0.05)
		integer_steps = integer_steps and building.hp == roundf(building.hp)
	_h._expect(integer_steps and building.hp == 0 and building.shield_hp == 50, "建筑101生命在2秒内整数衰减归零，自然衰减不消耗护盾")
	var unit := _unit("pix")
	unit.add_shield(101, 2, true)
	for tick in range(20):
		unit._tick_active_statuses(0.05)
	_h._expect(unit.shield_hp == 50, "101点衰减护盾一秒累计扣51，保留剩余50")

func _check_control_owner() -> void:
	var state := ControlState.new()
	state.refresh_freeze(0.1)
	state.refresh_stun(0.2)
	state.tick_hard_controls(0.05)
	_h._expect(is_equal_approx(state.frozen_timer, 0.05) and is_equal_approx(state.stun_timer, 0.15), "控制所有者同时推进冻结与眩晕")
	state.apply_replica_flags(false, true)
	_h._expect(state.frozen_timer == 0 and state.stun_timer == 0.15, "副本状态替换旧冻结，不把快照当叠加")
	state.apply_replica_flags(false, false)
	_h._expect(state.frozen_timer == 0 and state.stun_timer == 0, "副本控制解除清除两种状态")
	var tower := Tower.new()
	tower.freeze(0.123)
	tower.stun(0.234)
	tower.control.tick_hard_controls(0.05)
	_h._expect(is_equal_approx(tower.frozen_timer, 0.1) and is_equal_approx(tower.control.stun_timer, 0.2), "防御塔与单位共用正时长向上取整的20Hz窗口")
	tower.free()

func _check_attack_timeline_owner() -> void:
	var timeline := AttackTimeline.new()
	timeline.commit_hit(0.8)
	timeline.begin_windup(0.3, 1.0)
	timeline.begin_recovery(0.8, 0.3, 1.0)
	timeline.cancel()
	_h._expect(timeline.cooldown == 0.8 and timeline.windup == 0 and timeline.recovery == 0, "丢失目标取消挥击但保留已出手间隔")
	timeline.begin_windup(0.3, 1.0)
	_h._expect(timeline.windup == 0.8, "重入射程前摇与剩余间隔重叠，不能额外叠加等待")
	timeline.rescale(1.0, 2.0)
	timeline.tick_cooldown(0.05)
	timeline.tick_windup(0.05)
	_h._expect(is_equal_approx(timeline.cooldown, 0.35) and is_equal_approx(timeline.windup, 0.35), "攻速缩放和固定步推进由攻击时间线统一处理")
	timeline.align_visual(0.3, 0.1, 2.0)
	_h._expect(is_equal_approx(timeline.visual_elapsed, 0.1), "表现进度对齐保持基础攻速秒数")
	timeline.cancel(true)
	_h._expect(timeline.cooldown == 0 and timeline.windup == 0 and timeline.recovery == 0, "施法或变形显式重置全部攻击计时")
