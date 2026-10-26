extends "res://tests/suites/battle_suite.gd"
const Layout := preload("res://scripts/presentation/unit_bar_layout.gd")

func run(harness: Object) -> void:
	_harness = harness
	_check_lengths()
	_main = preload("res://tests/fixtures/authority_battle.gd").new()
	harness.root.add_child(_main)
	_check_health_sources()
	_check_visibility_and_recovery()
	_check_growth_forms_and_replica()
	_main.free()
	_main = null

func _check_lengths() -> void:
	# H/M/S，普通/溢出/盾/底框宽度，正常满血边界。
	var cases := [
		[300, 300, 0, 60, 0, 0, 60, 60],
		[150, 300, 0, 30, 0, 0, 60, 60],
		[300, 300, 150, 60, 0, 30, 90, 60],
		[300, 300, 900, 22.5, 0, 67.5, 90, 22.5],
		[450, 300, 150, 45, 22.5, 22.5, 90, 45],
		[150, 300, 100, 30, 0, 20, 60, 60],
		[3, 300, 2997, 0.09, 0, 89.91, 90, 9],
		[0, 300, 0, 0, 0, 0, 60, 60],
	]
	for c in cases:
		var layout := Layout.calculate(60, float(c[0]) / c[1], float(c[2]) / c[1])
		for pair in [["normal_width", 3], ["overflow_width", 4], ["shield_width", 5], ["background_width", 6], ["full_health_x", 7]]:
			_expect(is_equal_approx(layout[pair[0]], float(c[pair[1]])), "H/M/S=%s/%s/%s %s" % [c[0], c[1], c[2], pair[0]])
		_expect(is_equal_approx(layout.shield_start, layout.normal_width + layout.overflow_width) and layout.background_width <= 90.00001, "白盾紧接全部生命，总长封顶")
	# 破盾及消耗超额生命逐步恢复正常比例，不锁历史盾容量。
	for state in [[1.5, 0.5], [1.5, 0.0], [1.0, 0.0], [0.5, 0.0]]:
		var layout := Layout.calculate(60, state[0], state[1])
		_expect(is_equal_approx(layout.shield_start, layout.normal_width + layout.overflow_width), "破盾/超额生命消耗后各段连续")
	_expect(Layout.calculate(60, 1, 3).normal_width < Layout.calculate(60, 1, 0).normal_width, "超限盾减少允许生命恢复原宽")

func _spawn(card: String, team: int = 0) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, card, Vector2(280 + team * 160, 900), {"position_resolved": true, "deploy_time_override": 0.0}))

func _check_health_sources() -> void:
	var unit := _spawn("garen")
	var width := unit.presentation_state().base_health_bar_width
	unit.hp = BattleNumbers.quantity(unit.max_hp * 0.5)
	unit.heal_with_overflow(unit.max_hp, 0.5, 10, &"bar_test")
	_expect(unit.hp == unit.max_hp and unit.shield_hp > 0 and unit.presentation_state().health_bar_layout.overflow_width == 0, "治疗溢出只进入白盾，不误画成紫色真实生命")
	unit.apply_attack_lifesteal(1, 1.5)
	unit._try_attack_lifesteal(unit.max_hp)
	var layout := unit.presentation_state().health_bar_layout
	_expect(unit.hp > unit.max_hp and layout.overflow_width > 0 and layout.shield_width > 0 and unit.presentation_state().base_health_bar_width == width, "真实吸血超额HP与治疗白盾同时显示，W不变")
	unit.take_damage(unit.shield_hp)
	_expect(unit.presentation_state().health_bar_layout.shield_width == 0 and unit.presentation_state().health_bar_layout.overflow_width > 0, "正式破盾后仍保留真实紫色生命")
	unit.take_damage(unit.hp - unit.max_hp)
	_expect(unit.presentation_state().health_bar_layout.overflow_width == 0 and unit.hp == unit.max_hp, "正式消耗超额生命后紫条消失")
	unit.free()

func _check_visibility_and_recovery() -> void:
	var unit := _spawn("gnar")
	unit.skill_resource_enabled = false
	_expect(not unit.presentation_state().health_bar_visible, "满血无资源无盾沿用隐藏")
	unit.skill_resource_enabled = true
	for value in [0.0, 2.0]:
		unit.skill_resource_value = value
		_expect(unit.presentation_state().health_bar_visible and unit.is_skill_resource_visible(), "满血且资源底框显示时血条显示，包括零层")
	unit.apply_stasis(0.5)
	_expect(not unit.presentation_state().health_bar_visible and not PresentationConfig.status_indicators_visible(unit), "凝滞优先隐藏所有附属标识")
	unit.control.apply_replica_stasis(false)
	_expect(unit.presentation_state().health_bar_visible, "凝滞解除恢复仍启用资源的血条")
	unit.skill_resource_enabled = false
	unit.hp -= 1
	_expect(unit.presentation_state().health_bar_visible, "残血无资源仍显示")
	unit.free()
	var sion := _spawn("sion")
	sion.take_damage(sion.hp * 2)
	_expect(sion.death_form.waiting() and sion.hp == 0 and sion.presentation_state().health_bar_visible, "赛恩真实零生命进入复生等待并显示进度")
	sion.death_form.waiting_ticks = 10
	var view := sion.presentation_state()
	view.advance_health_bar(0)
	var progress := view.health_ratio
	view.advance_health_bar(1)
	_expect(view.health_ratio >= progress and view.health_ratio <= progress + 0.05 / float(sion._base_form_stats.death_form_delay) + 0.00001, "等待帧间外推最多一个Tick")
	_expect(is_equal_approx(view.health_bar_layout.normal_width, view.base_health_bar_width * view.health_ratio) and view.health_bar_layout.overflow_width == 0 and view.health_bar_layout.shield_width == 0, "复生进度独立于真实H/M，无紫条或白盾")
	sion.death_form.waiting_ticks = 1
	_run_main_ticks(1)
	view.advance_health_bar(0)
	_expect(not sion.death_form.waiting() and sion.hp == sion.max_hp and view.health_ratio == 1, "复生完成恢复新形态普通生命显示")
	sion.free()

func _check_growth_forms_and_replica() -> void:
	var client = preload("res://tests/fixtures/authority_battle.gd").new()
	_harness.root.add_child(client)
	client.runtime.mode = "client"
	client.runtime.local_team = 1
	var widths: Array[float] = []
	for card in ["gnar", "garen", "sion"]:
		var unit := _spawn(card)
		var width := unit.presentation_state().base_health_bar_width
		widths.append(width)
		unit.apply_permanent_growth(0.3, 1.3)
		_expect(unit.presentation_state().base_health_bar_width == width and unit.visual_radius * 2 > width, "成长只放大模型不放大W:" + card)
		_expect(unit.presentation_state().health_bar_layout.overflow_width == 0, "成长的新M就是正常满血:" + card)
		if card == "gnar":
			unit.transform_to_mega(true)
			width = float(unit.transformed_stats.visual_radius) * 2
			_expect(unit.presentation_state().base_health_bar_width == width, "真正换形取大纳尔原生W")
		unit.hp = BattleNumbers.quantity(unit.max_hp * 1.5)
		unit.add_shield(unit.max_hp * 3, 10)
		unit.skill_resource_enabled = true
		var replica: Unit = client._spawn_unit(UnitSpawnRequest.new(0, card, unit.position, {"position_resolved": true, "deploy_time_override": 0.0}))
		replica.net_id = unit.net_id
		client.world.register_replica_unit(replica)
		_expect(replica.growth_body_scale == 1.0, "首次快照前客户端未成长:" + card)
		for phase in [0, 1, 2]:
			if phase == 1: unit.take_damage(unit.shield_hp)
			if phase == 2: unit.take_damage(unit.max_hp * 0.75)
			var payload := preload("res://tests/fixtures/network_fixture.gd").snapshot_payload(_main._snapshot_system, unit.net_id, unit)
			_expect(client._snapshot_system._apply_units([payload]), "正式快照投影成功:" + card)
			_expect(replica.presentation_state().base_health_bar_width == width and _same_layout(replica.presentation_state().health_bar_layout, unit.presentation_state().health_bar_layout), "首次成长/换形及破盾/耗血主客端布局一致:" + card)
			_expect(replica.shield_hp == 0 and replica.presentation_state().health_bar_visible, "客户端使用现有盾比例与资源显示，不依赖本地盾层:" + card)
		unit.apply_stasis(0.5)
		var stasis_payload := preload("res://tests/fixtures/network_fixture.gd").snapshot_payload(_main._snapshot_system, unit.net_id, unit)
		client._snapshot_system._apply_units([stasis_payload])
		_expect(not replica.presentation_state().health_bar_visible, "客户端快照凝滞压过资源显示:" + card)
		unit.control.tick_hard_controls(0.5)
		client._snapshot_system._apply_units([preload("res://tests/fixtures/network_fixture.gd").snapshot_payload(_main._snapshot_system, unit.net_id, unit)])
		_expect(replica.presentation_state().health_bar_visible, "客户端凝滞恢复:" + card)
		_expect(replica.get_health_bar_fill_color() == Color(0.95, 0.25, 0.25), "红方视角蓝方单位显示敌方血色")
		unit.team = 1
		_expect(unit.get_health_bar_fill_color() == Color(0.95, 0.25, 0.25), "蓝方视角红方单位显示敌方血色")
		unit.team = 0
		_expect(unit.get_health_bar_fill_color() == Color(0.2, 0.9, 0.2), "蓝方视角友方血色")
		if card == "gnar":
			unit.transform_to_small()
			_expect(unit.presentation_state().base_health_bar_width == widths[0], "还原小纳尔恢复原生W")
		unit.free()
		replica.free()
	_expect(widths[0] < widths[1] and widths[1] <= widths[2], "原生小中大体型宽度有别")
	client.free()

func _same_layout(a: Dictionary, b: Dictionary) -> bool:
	for key in a:
		if not is_equal_approx(a[key], b[key]): return false
	return true
