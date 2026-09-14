extends "res://tests/suites/battle_suite.gd"
func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var stats := CardDB.get_unit_stats("shurima_guard")
	var skill: Dictionary = stats.active_skills[0]
	_expect(stats.cost == 7 and stats.hp == 420 and stats.damage == 60 and stats.interval == 1.6 and stats.range == 72.0, "卫队确认数值")
	_expect(skill.cost == 2 and skill.max_uses == 1 and skill.shield == 180 and skill.shield_duration == 2.0, "卫队技能2费每次部署限1次")
	var first: Array[Unit] = main._spawn_card_units(0, "shurima_guard", Vector2(360, 900), 0.0, 0)
	var other: Array[Unit] = main._spawn_card_units(0, "shurima_guard", Vector2(360, 1100), 0.0)
	var enemy: Array[Unit] = main._spawn_card_units(1, "shurima_guard", Vector2(360, 300), 0.0)
	_expect(first.size() == 6, "一次出牌生成6名独立士兵")
	for i in 6:
		_expect(is_equal_approx(first[i].position.y, 900.0) and is_equal_approx(first[i].position.x, 110.0 + i * 100.0), "六人横排与2.5格间距")
		first[i].hp = 100
	var full: Unit = main._spawn_unit(0, "shurima_guard", Vector2(360, 1000), 0.0)
	full.add_restoration_shield(180, 0.05)
	full._tick_active_statuses(0.05)
	_expect(full.hp == 420 and full.restoration_fx_timer == 0.0, "满血盾到期不伪造回复特效")
	full.free()
	_expect(stats.audio.events["active:cast"].pool.size() == 1 and String(stats.audio.events["active:cast"].pool[0]).ends_with("onbuffcast_r1.wav"), "技能只播放指定r1")
	var source := first[0]
	main._active_skill_effect_system.apply(source, skill)
	for u in first: _expect(u.shield_hp == 180, "同次部署成员获得护盾")
	for u in other + enemy: _expect(u.shield_hp == 0, "其他部署及敌军不获得护盾")
	first[0].take_damage(179)
	first[1].take_damage(180)
	first[2].take_damage(190)
	first[3].add_shield(500, 5)
	first[3].take_damage(180)
	first[4].clear_shields()
	first[5].take_damage(10000)
	for u in first: u._tick_active_statuses(1.95)
	_expect(first[0].hp == 100 and first[0].shield_hp == 1, "未满2秒不提前回血")
	for u in first: u._tick_active_statuses(0.05)
	_expect(first[0].hp == 420 and first[0].shield_hp == 0, "剩余1点盾自然到期回满并移除盾")
	_expect(first[1].hp == 100, "恰好打破不回血")
	_expect(first[2].hp == 90, "破盾溢出伤害不回血")
	_expect(first[3].hp == 100 and first[3].shield_hp == 500, "自身技能盾破裂，其他盾仍存也不回血")
	_expect(first[4].hp == 100, "主动清除不算自然到期")
	_expect(first[5].hp <= 0, "死亡不复活")
	_expect(first[0].restoration_fx_timer > 0.0, "实际恢复触发黄色回复特效")
	for i in range(1, 6): _expect(first[i].restoration_fx_timer == 0.0, "破盾清除死亡不显示回复特效")
	for team in [0, 1]:
		for column in range(18):
			var center := Vector2(column * 40 + 20, 1260 if team == 0 else 20)
			var valid: bool = main.is_card_deploy_position_valid(team, "shurima_guard", center)
			_expect(valid == (column in [6, 7, 8, 9, 10, 11]), "末行合法下牌格受整排宽度限制")
			if valid:
				var left := 0
				for offset in main._deployment_formation_offsets(6, 100, team, "line"):
					if center.x + offset.x < 360: left += 1
				_expect(left == {6: 4, 7: 4, 8: 3, 9: 3, 10: 2, 11: 2}[column], "末行偏左中右自然分兵4/2、3/3、2/4")
	first[0].hp = 150
	first[0]._tick_active_statuses(5)
	_expect(first[0].hp == 150, "到期收益只结算一次")
	var offsets: Array[Vector2] = main._deployment_formation_offsets(6, 100, 1, "line")
	_expect(offsets[0] == Vector2(250, 0) and offsets[5] == Vector2(-250, 0), "红方横排镜像")
	var edge: Array[Unit] = main._spawn_card_units(0, "shurima_guard", Vector2(260, 800), 0.0)
	_expect(edge[0].position.x == 18 and edge[1].position.x == 110, "只将越界边缘士兵挤回场内，不平移整排")
	for i in range(2, 6): _expect(is_equal_approx(edge[i].position.x - edge[i-1].position.x, 100), "非边缘成员保持2.5格间距")
	main._deck = ["shurima_guard", "garen", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	main._active_skill_choices["shurima_guard"] = 0
	var paid: Array[Unit] = main._spawn_card_units(0, "shurima_guard", Vector2(360, 1000), 0.0, 0)
	var ability := -1
	for key in main._active_skills:
		if main._active_skills[key].unit == paid[0]: ability = key
	main._elixir.elixir = 10
	_expect(ability >= 0 and main.use_active_skill(ability, 0), "正式技能请求被接受")
	_expect(main._elixir.elixir == 8, "一次技能扣2金币")
	# Kill leader before activation: the existing group ownership must transfer.
	paid[0].take_damage(10000)
	_run_main_ticks(11)
	_expect(paid[1].shield_hp == 180, "队长阵亡后技能转交存活同队成员")
	_expect(not main.use_active_skill(ability, 0), "同次部署不能再次使用技能")
	for u in paid:
		if is_instance_valid(u): u.free()
	for group in [first, other, enemy, edge]:
		for u in group:
			if is_instance_valid(u): u.free()
	# Malformed new fields must fail validation before consumers run.
	var invalid := CardDB.all().duplicate(true)
	invalid.shurima_guard.deployment_formation = "unknown"
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all(invalid).is_empty(), "拒绝未知编队类型")
