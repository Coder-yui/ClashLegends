class_name MissFortuneSuite
extends "res://tests/suites/battle_suite.gd"
## 赏金猎人卡牌领域：先声夺人首击倍率（对每个目标的首次普攻）与大步流星 buff 配置。

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_card_config()
	_check_first_strike_damage()
	_check_w_visual()

func _check_card_config() -> void:
	var stats: Dictionary = CardDB.get_card("missfortune").duplicate(true)
	var animations: Dictionary = stats.get("visual_animations", {})
	var skill: Dictionary = stats.get("active_skills", [])[0]
	_expect(
		stats.get("name", "") == "赏金猎人"
		and is_equal_approx(float(stats.get("first_strike_damage_multiplier", 0.0)), 1.5)
		and is_equal_approx(float(stats.get("projectile_speed", 0.0)), 500.0),
		"赏金猎人先声夺人配置为对每个目标的首次普攻 1.5 倍伤害，远程弹速 500",
	)
	_expect(
		String(animations.get("move", "")) == "Run"
		and String(animations.get("haste_move", "")) == "Run2"
		and animations.get("attack", []) == ["Attack1", "Attack2"],
		"赏金猎人普通移动用 Run，加速期间切换 Run2，普攻循环 Attack1/Attack2",
	)
	_expect(
		String(skill.get("kind", "")) == "buff"
		and int(skill.get("cost", -1)) == 0 and int(skill.get("max_uses", 0)) == 1
		and is_equal_approx(float(skill.get("cooldown", 0.0)), 5.0)
		and is_equal_approx(float(skill.get("duration", 0.0)), 3.0)
		and is_equal_approx(float(skill.get("speed_multiplier", 1.0)), 1.5)
		and is_equal_approx(float(skill.get("attack_speed_multiplier", 1.0)), 1.3)
		and is_equal_approx(float(skill.get("damage_multiplier", 1.0)), 1.0),
		"大步流星为 0 费 1 次的 buff：3 秒内移速×1.5、攻速×1.3、伤害不变，冷却 5 秒",
	)

func _spawn_dummy(pos: Vector2, p_team: int = 1) -> Unit:
	var unit := Unit.new()
	var stats := SuiteUtils.sweep_dummy_stats(CardDB.get_card("garen"))
	stats["deploy_time"] = 0.0
	stats["hp"] = 3000.0
	unit.position = pos
	unit.setup(p_team, stats, "技能木桩")
	_main.add_child(unit)
	return unit

## 首击倍率走完整权威弹体路径：出手 tick 固化伤害，弹体抵达后结算。
func _check_first_strike_damage() -> void:
	var mf := _spawn_test_unit("missfortune", 0, Vector2(500.0, 1120.0))
	var first_target := _spawn_dummy(Vector2(500.0, 1070.0))
	var second_target := _spawn_dummy(Vector2(560.0, 1070.0))

	# 对第一个目标的首次攻击：1.5 倍伤害。
	var first_before := first_target.hp
	mf._target = first_target
	_fire_once(mf)
	_flush_projectiles()
	var first_strike_damage := first_before - first_target.hp

	# 对同一目标的第二次攻击：恢复基础伤害。
	var second_before := first_target.hp
	_fire_once(mf)
	_flush_projectiles()
	var repeat_damage := second_before - first_target.hp

	# 换目标后的首次攻击：新目标同样享受 1.5 倍。
	var new_before := second_target.hp
	mf._target = second_target
	_fire_once(mf)
	_flush_projectiles()
	var new_target_damage := new_before - second_target.hp

	_expect(
		is_equal_approx(first_strike_damage, mf.damage * 1.5)
		and is_equal_approx(repeat_damage, mf.damage)
		and is_equal_approx(new_target_damage, mf.damage * 1.5),
		"赏金猎人对每个目标的首次普攻造成 1.5 倍伤害（首击 %.1f、重复 %.1f、新目标首击 %.1f，基础 %.1f）" % [first_strike_damage, repeat_damage, new_target_damage, mf.damage],
	)
	mf.free()
	first_target.free()
	second_target.free()

func _fire_once(unit: Unit) -> void:
	unit._attacking = true
	unit.attack_timeline.windup = 0.0
	unit.attack_timeline.cooldown = 0.0
	unit._attack_visual_pending = false
	unit._attack(_main.SIM_DT)

func _flush_projectiles() -> void:
	for _tick in range(10):
		_main._tick_projectiles(_main.SIM_DT)
		if _main._projectile_system.projectiles.is_empty():
			return

func _check_w_visual() -> void:
	var unit := _spawn_test_unit("missfortune", 0, Vector2(360, 1000))
	_expect(unit.active_buff_clock_visual() == Vector2.ZERO, "赏金未开技能没有W效果")
	unit.apply_active_buff(3.0, 1.5, 1.0, 1.3)
	_expect(unit.active_buff_clock_visual() == Vector2(0, 3), "赏金W表现时钟记录实际窗口")
	unit.buffs.advance(3.0)
	_expect(unit.active_buff_timer == 0.0 and unit.active_buff_clock_visual() == Vector2(3, 3), "W收尾不延长移速和攻速效果")
	var effect = load("res://assets/effects/missfortune_w/buff.tscn").instantiate()
	_main.add_child(effect)
	effect.configure(12.0)
	for kind in ["left", "right", "end_left", "end_right"]:
		_expect(effect._players[kind]._data.emitters.size() == (3 if kind.begins_with("end_") else 6), "W保留原生系统有效层数：" + kind)
	_expect(effect._players.trail._data.emitters.size() == 8, "加速系统保留八个原版有效发射器")
	var model = load("res://assets/units/missfortune/missfortune_view.tscn").instantiate()
	_main.add_child(model)
	effect.bind_model(model)
	_expect(effect._bones.size() == 2, "左右枪焰找到沿枪管的专用挂点")
	for side in ["left", "right"]:
		var weapon: int = effect._skeleton.find_bone("L_WEAPON" if side == "left" else "R_WEAPON")
		var barrel: Vector3 = effect._skeleton.get_bone_global_pose(weapon).basis.x.normalized()
		var flame: Vector3 = effect._skeleton.get_bone_global_pose(effect._bones[side]).basis.z.normalized()
		_expect(barrel.dot(flame) > 0.99, "枪焰前向与枪管长轴一致：" + side)
	var trail = effect._players.trail
	trail.emitting = true
	trail.seek(0.1)
	var births: Dictionary = trail._birth_positions.duplicate()
	trail.position.x += 1.0
	trail.emitting = false
	trail.seek(0.2)
	_expect(not trail._rejected.is_empty(), "停步后拒绝新拖尾粒子")
	var stable := true
	for key in births:
		stable = stable and trail._birth_positions[key] == births[key]
	_expect(stable, "移动不搬走已出生拖尾的世界挂点")
	effect.status_state = Vector2(1.0, 3.0)
	effect.advance_status(true, true, 0.0)
	_expect(effect._players.left.visible and effect._players.right.visible and not effect._players.end_left.visible, "W期间双枪效果持续")
	effect.status_state = Vector2(3.1, 3.0)
	effect.advance_status(true, true, 0.0)
	_expect(not effect._players.left.visible and effect._players.end_left.visible and effect._players.end_right.visible, "W到期切换原生双枪收尾")
	effect.advance_status(false, false, 0.0)
	_expect(not effect.visible and not effect._players.end_left.visible, "死亡或隐藏立即清理收尾")
	unit.buffs.advance(2.15)
	_expect(unit.active_buff_clock_visual() == Vector2.ZERO, "收尾结束归零")
	model.free()
	effect.free()
	unit.queue_free()
