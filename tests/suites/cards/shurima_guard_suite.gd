extends "res://tests/suites/battle_suite.gd"
func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_ward_visual_state()
	_check_centered_wisps()
	_check_formation_boundary_schema()
	_check_two_tower_deployment()
	var stats := CardDB.get_unit_stats("shurima_guard")
	var skill: Dictionary = stats.active_skills[0]
	_expect(stats.cost == 7 and stats.hp == 420 and stats.damage == 60 and stats.interval == 1.6 and stats.range == 72.0, "卫队确认数值")
	_expect(skill.cost == 2 and skill.max_uses == 1 and skill.shield == 180 and skill.shield_duration == 2.0, "卫队技能2费每次部署限1次")
	var first: Array[Unit] = main.runtime._spawn_card_units(0, "shurima_guard", Vector2(360, 900), 0.0, 0)
	var other: Array[Unit] = main.runtime._spawn_card_units(0, "shurima_guard", Vector2(360, 1100), 0.0)
	var enemy: Array[Unit] = main.runtime._spawn_card_units(1, "shurima_guard", Vector2(360, 300), 0.0)
	_expect(first.size() == 6, "一次出牌生成6名独立士兵")
	for i in 6:
		_expect(is_equal_approx(first[i].position.y, 900.0) and is_equal_approx(first[i].position.x, 110.0 + i * 100.0), "六人横排与2.5格间距")
		first[i].hp = 100
	var full: Unit = main._spawn_unit(UnitSpawnRequest.new(0, "shurima_guard", Vector2(360, 1000), {"deploy_time_override": 0.0}))
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
	_expect(first[0].restoration_fx_timer > 0.0, "实际恢复触发通用回复特效")
	for i in range(1, 6): _expect(first[i].restoration_fx_timer == 0.0, "破盾清除死亡不显示回复特效")
	for team in [0, 1]:
		for column in range(18):
			var center := Vector2(column * 40 + 20, 1260 if team == 0 else 20)
			var valid: bool = main.runtime.is_card_deploy_position_valid(team, "shurima_guard", center)
			_expect(valid == (column in [6, 7, 8, 9, 10, 11]), "末行合法下牌格受整排宽度限制")
			if valid:
				var left := 0
				for offset in main.runtime._deployment_formation_offsets(6, 100, team, "line"):
					if center.x + offset.x < 360: left += 1
				_expect(left == {6: 4, 7: 4, 8: 3, 9: 3, 10: 2, 11: 2}[column], "末行偏左中右自然分兵4/2、3/3、2/4")
	first[0].hp = 150
	first[0]._tick_active_statuses(5)
	_expect(first[0].hp == 150, "到期收益只结算一次")
	var offsets: Array[Vector2] = main.runtime._deployment_formation_offsets(6, 100, 1, "line")
	_expect(offsets[0] == Vector2(250, 0) and offsets[5] == Vector2(-250, 0), "红方横排镜像")
	var edge: Array[Unit] = main.runtime._spawn_card_units(0, "shurima_guard", Vector2(260, 800), 0.0)
	_expect(edge[0].position.x == 18 and edge[1].position.x == 110, "只将越界边缘士兵挤回场内，不平移整排")
	for i in range(2, 6): _expect(is_equal_approx(edge[i].position.x - edge[i-1].position.x, 100), "非边缘成员保持2.5格间距")
	main.runtime._deck = ["shurima_guard", "garen", "freeze", "ashe", "teemo", "masteryi", "tombstone", "aurelionsol"]
	main.runtime._active_skill_choices["shurima_guard"] = 0
	var paid: Array[Unit] = main.runtime._spawn_card_units(0, "shurima_guard", Vector2(360, 1000), 0.0, 0)
	var ability := -1
	for key in main.runtime._active_skills.ids():
		if main.runtime._active_skills.entry(key).unit == paid[0]: ability = key
	main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team).elixir = 10
	_expect(ability >= 0 and main.use_active_skill(ability, 0), "正式技能请求被接受")
	_expect(main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team).elixir == 8, "一次技能扣2金币")
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

func _check_formation_boundary_schema() -> void:
	for invalid in [null, 1, "true"]:
		var stats := CardDB.get_card("shurima_guard").duplicate(true)
		stats.deploy_formation_requires_in_bounds = invalid
		_expect("deploy_formation_requires_in_bounds" in "；".join(CardDB.VALIDATOR.validate_all({"shurima_guard": stats}, false)), "整排边界开关拒绝非布尔值")
	for invalid in [{"deployment_formation": "polygon"}, {"deployment_count": 1}, {"type": "building"}, {"deployment_spacing": 200.0}]:
		var stats := CardDB.get_card("shurima_guard").duplicate(true)
		stats.merge(invalid, true)
		_expect("deploy_formation_requires_in_bounds" in "；".join(CardDB.VALIDATOR.validate_all({"shurima_guard": stats}, false)), "整排边界开关要求可放入场内的多单位横排")

func _check_two_tower_deployment() -> void:
	var old_deck: Array = _main.runtime._deck.duplicate()
	var old_cycles: Dictionary = _main.runtime._authoritative_card_cycles.duplicate()
	var old_balances := [_main.runtime.account(0).elixir, _main.runtime.account(1).elixir]
	var old_remote_deck: Array = _main.runtime._remote_deck
	_main.runtime._deck = ["shurima_guard", "garen", "ashe", "heal", "xin", "teemo", "freeze", "pix"]
	_main.runtime._remote_deck = _main.runtime._deck.duplicate()
	for team in [0, 1]:
		var left: Tower = _main.world.towers_snapshot()[2 if team == 0 else 0]
		var right: Tower = _main.world.towers_snapshot()[3 if team == 0 else 1]
		preload("res://tests/fixtures/network_fixture.gd").fixed_cycle(_main, team, _main.runtime._deck)
		var hp := Vector2(left.hp, right.hp)
		var baseline: Array[bool] = []
		for row in ArenaRules.ARENA_ROWS:
			for column in ArenaRules.ARENA_COLUMNS:
				baseline.append(_main.runtime.is_card_deploy_position_valid(team, "shurima_guard", _main.runtime._deployment_rules.arena_tile_center(Vector2i(column, row))))
		var enemy_y := 500.0 if team == 0 else 780.0
		var target := Vector2(340, enemy_y)
		for side in [0, 1]:
			left.hp = 0.0 if side == 0 else hp.x
			right.hp = 0.0 if side == 1 else hp.y
			var unchanged := true
			for row in ArenaRules.ARENA_ROWS:
				for column in ArenaRules.ARENA_COLUMNS:
					var pos: Vector2 = _main.runtime._deployment_rules.arena_tile_center(Vector2i(column, row))
					unchanged = unchanged and _main.runtime.is_card_deploy_position_valid(team, "shurima_guard", pos) == baseline[row * ArenaRules.ARENA_COLUMNS + column]
			_expect(unchanged, "卫队单路破塔与未破塔全场合法格完全一致：阵营%d/路%d" % [team, side])
			var lane_pos := Vector2(300 if side == 0 else 420, enemy_y)
			_expect(_main.runtime.is_card_deploy_position_valid(team, "garen", lane_pos), "普通卡继续单路解锁")
			_expect(not _main.runtime._deployment_rules.tile_in_ground_deploy_zone(_main.runtime._deployment_rules.world_to_arena_tile(lane_pos), team, true), "卫队区域高亮同样禁止单路解锁")
			_main.runtime.account(team).elixir = 10
			var hand: Array = _main.get_authoritative_hand(team)
			var commands: int = _main.runtime._commands.inspect_cards().size()
			var accepted: bool = _main.play_card(team, "shurima_guard", lane_pos, {"elixir": _main.runtime.account(team)})
			_expect(not accepted and _main.runtime.account(team).elixir == 10 and _main.get_authoritative_hand(team) == hand and _main.runtime._commands.inspect_cards().size() == commands, "单路非法出牌不扣费、不轮换、不入队")
			if team == 0:
				_main._on_card_selected("shurima_guard")
				_main._update_deployment_preview(lane_pos)
				_expect(not _main._deployment_preview_valid, "卫队单路破塔落点预览为非法")
		left.hp = 0
		right.hp = 0
		_expect(_main.runtime.is_card_deploy_position_valid(team, "shurima_guard", target) and _main.runtime.is_card_deploy_position_valid(team, "shurima_guard", Vector2(420, enemy_y)), "双路破塔后卫队两侧合法区域均开放")
		_expect(not _main.runtime.is_card_deploy_position_valid(team, "shurima_guard", Vector2(20, enemy_y)) and not _main.runtime.is_card_deploy_position_valid(team, "shurima_guard", Vector2(340, 620)) and not _main.runtime.is_card_deploy_position_valid(team, "shurima_guard", Vector2(340, 180 if team == 0 else 1100)), "双破仍遵守横排边界、河道及敌方深处区域限制")
		var blocker: Unit = _main._spawn_unit(UnitSpawnRequest.new(team, "tombstone", target, {"deploy_time_override": 0.0}))
		_expect(not _main.runtime.is_card_deploy_position_valid(team, "shurima_guard", target), "双破仍拒绝存活建筑占地")
		blocker.free()
		if team == 0:
			_main._update_deployment_preview(target)
			_expect(_main._deployment_preview_valid, "卫队双路破塔落点预览变为合法")
		_main.runtime.account(team).elixir = 10
		_expect(_main.play_card(team, "shurima_guard", target, {"elixir": _main.runtime.account(team)}) and _main.runtime.account(team).elixir == 3 and "shurima_guard" not in _main.get_authoritative_hand(team) and _main.runtime._commands.inspect_cards().size() == 1, "双破正式出牌扣7金币、轮换并进入部署队列")
		_main.runtime._commands.clear_cards()
		left.hp = hp.x
		right.hp = hp.y
	_main._on_card_selected("")
	_main.runtime._deck = old_deck
	_main.runtime._remote_deck = old_remote_deck
	_main.runtime._authoritative_card_cycles = old_cycles
	for team in [0, 1]: _main.runtime.account(team).elixir = old_balances[team]
	var stats := CardDB.get_card("shurima_guard").duplicate(true)
	for invalid in [null, 1, "true"]:
		stats.deploy_pocket_requires_both_towers = invalid
		_expect("deploy_pocket_requires_both_towers" in "；".join(CardDB.VALIDATOR.validate_all({"shurima_guard": stats}, false)), "双塔部署开关拒绝非布尔值")
	stats.deploy_pocket_requires_both_towers = true
	stats.deploy_zone = "global"
	_expect("deploy_pocket_requires_both_towers" in "；".join(CardDB.VALIDATOR.validate_all({"shurima_guard": stats}, false)), "双塔部署开关拒绝无效的全图搭配")

func _check_ward_visual_state() -> void:
	var shield := ShieldState.new()
	shield.add(500, 5)
	_expect(shield.restoration_visual_state() == Vector2.ZERO, "普通护盾不触发黄沙表现")
	shield.add(180, 2, false, true)
	_expect(shield.restoration_visual_state() == Vector2(2, 2), "黄沙盾保存完整表现窗口")
	shield.tick(0.25)
	_expect(shield.restoration_visual_state() == Vector2(1.75, 2), "表现时钟读取技能盾实际剩余时间")
	shield.absorb(180)
	_expect(shield.total_hp() == 500 and shield.restoration_visual_state() == Vector2.ZERO, "黄沙盾破即清表现，普通盾不能续特效")
	shield.add(180, 2, false, true)
	shield.tick(2)
	_expect(shield.restoration_visual_state() == Vector2.ZERO, "黄沙盾自然到期清表现")
	shield.add(180, 2, false, true)
	shield.clear()
	_expect(shield.restoration_visual_state() == Vector2.ZERO, "清盾同步清表现")
	var effect = preload("res://assets/effects/sand_ward/buff.tscn").instantiate()
	_main.add_child(effect)
	effect.configure(18)
	effect.status_state = Vector2(1.8, 2)
	effect.advance_status(true, true, 0)
	_expect(effect.visible and effect._grains.size() == 24, "技能盾启用沙粒和护盾轮廓")
	effect.advance_status(true, false, 0)
	_expect(not effect.visible and effect.active, "凝滞只隐藏表现，保留盾状态")
	effect.status_state = Vector2(0.5, 2)
	effect.advance_status(true, true, 0)
	_expect(effect.visible and is_equal_approx(effect._shell.material_override.get_shader_parameter("elapsed"), 1.5), "恢复可见时不重播获得特效")
	effect.advance_status(false, false, 0)
	_expect(not effect.visible and not effect.active, "盾失效立即隐藏")
	effect.free()

func _check_centered_wisps() -> void:
	for path in ["res://assets/effects/pix_lifesteal/player.gd", "res://assets/effects/voidfish_regeneration/player.gd"]:
		var effect = load(path).new()
		_main.add_child(effect)
		effect.configure(12)
		for age in [0.04, 0.13, 0.4, 0.7]:
			effect.seek(age)
			var center := Vector3.ZERO
			for wisp in effect._wisps:
				if wisp.visible:
					center += wisp.position * float(wisp.material_override.get_shader_parameter("opacity"))
			_expect(absf(center.x) < 0.00001 and absf(center.z) < 0.00001, "光流各阶段亮度加权分布保持中心")
		effect.free()
