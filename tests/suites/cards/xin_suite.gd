class_name XinSuite
extends RefCounted
## 赵信卡牌领域：横扫千军出场、三段普攻与回血循环。

var _harness: Object
var _main: Node2D

func _expect(condition: bool, message: String) -> void:
	_harness._expect(condition, message)

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_xin_deploy_sweep()
	_check_xin_art_integration()

func _check_xin_deploy_sweep() -> void:
	# 横扫千军：赵信生成当帧挥击并击退，Spell4 → Spell4_To_Idle 整段就是 1.5 秒部署。
	var xin_stats: Dictionary = CardDB.get_card("xin").duplicate()
	var light_stats := SuiteUtils.sweep_dummy_stats(CardDB.imp_stats())            # 质量 1
	var heavy_stats := SuiteUtils.sweep_dummy_stats(CardDB.get_card("garen"))         # 质量 8
	var far_stats := SuiteUtils.sweep_dummy_stats(CardDB.get_card("ashe"))            # 圈外
	var air_stats := SuiteUtils.sweep_dummy_stats(CardDB.get_card("aurelionsol"))     # 空中
	var xin := Unit.new()
	var light := Unit.new()
	var heavy := Unit.new()
	var far := Unit.new()
	var air := Unit.new()
	xin.position = Vector2(360.0, 900.0)
	light.position = Vector2(360.0, 840.0)
	heavy.position = Vector2(420.0, 900.0)
	far.position = Vector2(360.0, 720.0)
	air.position = Vector2(300.0, 900.0)
	xin.setup(0, xin_stats, xin_stats.name)
	light.setup(1, light_stats, light_stats.name)
	heavy.setup(1, heavy_stats, heavy_stats.name)
	far.setup(1, far_stats, far_stats.name)
	air.setup(1, air_stats, air_stats.name)
	# 敌人先进入战场；赵信加入 combatants 的同一帧就应命中它们。
	for u in [light, heavy, far, air]:
		_main.add_child(u)
	var light_start := light.global_position
	var heavy_start := heavy.global_position
	var far_start := far.global_position
	var air_start := air.global_position
	_main.add_child(xin)
	_expect(not xin.is_deployed() and is_equal_approx(xin._deploy_timer, 1.5), "赵信生成后进入 1.5 秒特殊部署阶段")
	_expect(light._knockback_timer > 0.0 and heavy._knockback_timer > 0.0, "赵信生成当帧立即结算横扫击退")
	_expect(xin._sweep_fx_timer > 0.0, "横扫击退触发短暂扇形冲击特效")
	var xin_start := xin.global_position
	# 跑完整段部署；赵信自身不行动，受击单位的权威击退照常推进。
	for _i in 30:
		for u in [xin, light, heavy, far, air]:
			u.sim_tick(_main.SIM_DT)
		_main._apply_unit_movement(_main.SIM_DT)
	_expect(xin.is_deployed(), "Spell4 → Spell4_To_Idle 的 1.5 秒演出结束后赵信解锁行动")
	_expect(xin.global_position.distance_to(xin_start) < 0.01, "赵信在出场演出期间没有自主移动")
	_expect(light.hp == 99999.0 and heavy.hp == 99999.0, "横扫千军只击退不造成伤害")
	var light_push := light.global_position.distance_to(light_start)
	var heavy_push := heavy.global_position.distance_to(heavy_start)
	var far_push := far.global_position.distance_to(far_start)
	var air_push := air.global_position.distance_to(air_start)
	_expect(light_push > 90.0, "圈内轻单位（质量1）被大幅击退出圈（推移 %.1fpx）" % light_push)
	_expect(heavy_push > 10.0 and heavy_push < light_push, "圈内重单位（质量8）被顶开但幅度小于轻单位（推移 %.1fpx < %.1fpx）" % [heavy_push, light_push])
	_expect(far_push < 0.5, "圈外地面单位不受横扫影响（位移 %.2fpx）" % far_push)
	_expect(air_push < 0.5, "空中单位扫不到（位移 %.2fpx）" % air_push)
	for u in [xin, light, heavy, far, air]:
		u.free()

func _check_xin_art_integration() -> void:
	# 赵信素材接入：三段普攻循环、出场技能序列与第三击回血。
	var stats: Dictionary = CardDB.get_card("xin").duplicate(true)
	var anim_names: Dictionary = stats.visual_animations
	_expect(anim_names.deploy == ["Spell4", "Spell4_To_Idle"], "赵信出场技能按 Spell4 → Spell4_To_Idle 序列播放")
	_expect(anim_names.deploy_durations == [1.0, 0.5], "赵信出场技能分段时长为 Spell4 1 秒、Spell4_To_Idle 0.5 秒")
	_expect(anim_names.attack.size() == 3 and anim_names.attack_hit.size() == 3, "赵信三段普攻 Start/收势映射一一对应")
	# 第三击回血：站桩木桩不还手，赵信只应在第 3/6/9…次命中时回复 heal_amount。
	var combat_stats: Dictionary = stats.duplicate()
	combat_stats["deploy_time"] = 0.0
	var xin := Unit.new()
	var dummy := Unit.new()
	xin.position = Vector2(360.0, 900.0)
	dummy.position = Vector2(360.0, 870.0)
	xin.setup(0, combat_stats, combat_stats.name)
	dummy.setup(1, SuiteUtils.sweep_dummy_stats(stats), stats.name)
	_main.add_child(xin)
	_main.add_child(dummy)
	xin.take_damage(xin.max_hp - 300.0)
	var hits := 0
	var heals := 0
	var heal_at_third := false
	var heal_at_sixth := false
	var third_checked := false
	var sixth_checked := false
	var last_self_hp := xin.hp
	var last_dummy_hp := dummy.hp
	# 部署锁定已由上一项独立验证；这里关闭部署时间，只验证三段攻击与回血循环。
	for _i in 280:
		xin.sim_tick(_main.SIM_DT)
		if not is_equal_approx(dummy.hp, last_dummy_hp):
			hits += 1
			last_dummy_hp = dummy.hp
		if xin.hp > last_self_hp + 0.01:
			heals += 1
			last_self_hp = xin.hp
		# 里程碑在 tick 末检查：命中与回血在同一 tick 同步结算。
		if hits >= 3 and not third_checked:
			third_checked = true
			heal_at_third = heals == 1
		if hits >= 6 and not sixth_checked:
			sixth_checked = true
			heal_at_sixth = heals == 2
	_expect(hits >= 7, "赵信在模拟窗口内完成多轮普攻循环（命中 %d 次）" % hits)
	_expect(heal_at_third, "三段循环第三击命中时回复生命")
	_expect(heal_at_sixth, "第六击命中时再次回复，循环持续生效")
	_expect(is_equal_approx(xin.hp, 300.0 + heals * stats.heal_amount), "回血总量与 heal_amount × 触发次数一致（300→%.0f，回复 %d 次）" % [xin.hp, heals])
	xin.free()
	dummy.free()
