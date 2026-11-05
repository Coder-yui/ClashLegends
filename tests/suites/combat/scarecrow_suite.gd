extends "res://tests/suites/battle_suite.gd"

func run(harness: Object) -> void:
	_harness = harness
	_main = preload("res://tests/fixtures/authority_battle.gd").new()
	harness.root.add_child(_main)
	for team in 2:
		_check_drain(team)
	_check_drain_cycle()
	_check_transform()
	_check_control_and_shield()
	_check_network()
	_check_active_request()
	_check_definition_contract()
	_check_native_parts()
	_main.free()

func _check_drain(team: int) -> void:
	var source := _spawn_ready_unit("scarecrow", team, Vector2(360, 800))
	var ground := _spawn_ready_unit("target_dummy", 1 - team, Vector2(460, 800))
	var air := _spawn_ready_unit("aurelionsol", 1 - team, Vector2(360, 700))
	var ally := _spawn_ready_unit("target_dummy", team, Vector2(260, 800))
	var outside := _spawn_ready_unit("target_dummy", 1 - team, Vector2(650, 800))
	for unit in [source, ground, air, ally, outside]: unit.move_speed = 0.0
	source.hp = 600
	source._target = ground
	var hp_ground := ground.hp
	var hp_air := air.hp
	for tick in 20: source._tick_drain_cycle(0.05)
	_expect(ground.hp == hp_ground - 60 and air.hp == hp_air - 60, "双方范围汲取对地对空每秒60")
	_expect(ally.hp == ally.max_hp and outside.hp == outside.max_hp, "不伤友军与范围外目标")
	_expect(source.hp == 660, "两目标实际伤害合计120回复60")
	ground.hp = 1
	air.global_position = Vector2(650, 700)
	var old_hp := source.hp
	source._deal_continuous_damage(60.0)
	_expect(source.hp <= old_hp + 1, "濒死目标过量伤害不额外吸血")
	ground.free()
	air.free()
	ally.free()
	outside.free()
	source.free()

func _check_drain_cycle() -> void:
	for card_id in ["scarecrow", "fiddlesticks"]:
		var source := _spawn_ready_unit(card_id, 0, Vector2(360, 800))
		var first := _spawn_ready_unit("target_dummy", 1, Vector2(420, 800))
		var late := _spawn_ready_unit("target_dummy", 1, Vector2(680, 800))
		source.sim_tick(0.05)
		late.position = Vector2(450, 800)
		for tick in 39: source.sim_tick(0.05)
		_expect(first.hp == first.max_hp - 120 and late.hp == late.max_hp and source.continuous_targets_snapshot().size() == 1, card_id + "一轮40次汲取只命中开攻时锁定的目标")
		for tick in 15: source.sim_tick(0.05)
		_expect(not source._attacking and source.continuous_targets_snapshot().is_empty() and first.hp == first.max_hp - 120, card_id + "停顿15 Tick期间无伤害与血线")
		source.sim_tick(0.05)
		_expect(source.continuous_targets_snapshot().size() == 2 and late.hp == late.max_hp - 3, card_id + "下一轮重新锁定新目标")
		first.position = Vector2(680, 800)
		source.sim_tick(0.05)
		first.position = Vector2(420, 800)
		source.sim_tick(0.05)
		_expect(source.continuous_targets_snapshot().size() == 1 and first.hp == first.max_hp - 123, card_id + "断线目标本轮不重新连接")
		first.position = Vector2(630, 800)
		late.position = Vector2(630, 800)
		source.sim_tick(0.05)
		_expect(not source._attacking and (source.get_locomotion_visual_state_code() == 2) == (card_id == "fiddlesticks"), card_id + "失去全部目标后立即进入停顿，可移动形态开始追击")
		first.free()
		late.free()
		source.free()

func _check_transform() -> void:
	var source := _spawn_ready_unit("scarecrow", 0, Vector2(360, 800))
	var id := source.net_id
	source.hp = 517
	_expect(source.is_building and not source.nav_cells.is_empty(), "草间人注册建筑导航占地")
	_main._active_skill_effect_system.apply(source, CardDB.active_skills_for("scarecrow")[0])
	_expect(source.form_index == 1 and not source.is_building and source.hp == 517 and source.net_id == id, "主动保留血量和身份变为地面单位")
	_expect(source.nav_cells.is_empty() and not source.is_in_group("combat_structures"), "变形释放导航与建筑组")
	_expect(source.move_speed == 44 and source.lifespan == 0 and not source.lifespan_hp_decay, "移动形态停止自然衰血")
	for tick in 40: source.sim_tick(0.05)
	_expect(source.hp == 517, "变形后不再扣建筑衰血")
	var replica := Unit.new()
	replica.setup(0, CardDB.get_card("scarecrow"), "replica")
	_main.add_child(replica)
	replica.sync_network_form(1, source.form_change_serial)
	_expect(not replica.is_building and replica.move_speed == 44, "客户端按形态同步建筑属性和移速")
	replica.free()
	source.free()

func _check_control_and_shield() -> void:
	var source := _spawn_ready_unit("fiddlesticks", 0, Vector2(360, 800))
	var target := _spawn_ready_unit("target_dummy", 1, Vector2(460, 800))
	source.hp = 600
	source._target = target
	target.add_shield(60, 10.0)
	for tick in 20: source._tick_drain_cycle(0.05)
	_expect(target.hp == target.max_hp and source.hp == 600, "护盾完全吸收时没有吸血")
	source.grievous_wounds = true
	for tick in 20: source._tick_drain_cycle(0.05)
	_expect(source.hp == 600, "重伤禁止持续汲取回复")
	source.grievous_wounds = false
	for control in ["stun", "freeze", "apply_stasis"]:
		source.call(control, 0.5)
		var old_hp := target.hp
		for tick in 5: source.sim_tick(0.05)
		_expect(target.hp == old_hp, "持续汲取在控制期间停止：" + control)
		for tick in 8: source.sim_tick(0.05)
		_expect(target.hp < old_hp, "解控后恢复持续汲取：" + control)
	source.free()
	target.free()

func _check_network() -> void:
	var source := _spawn_ready_unit("scarecrow", 0, Vector2(360, 800))
	var target := _spawn_ready_unit("aurelionsol", 1, Vector2(460, 800))
	source._target = target
	source._tick_drain_cycle(0.05)
	var system: NetworkSnapshotSystem = _main._snapshot_system
	var fixture = preload("res://tests/fixtures/network_fixture.gd")
	var payload := fixture.snapshot_payload(system, source.net_id, source, true, target.position)
	var packet := fixture.packet(system, [payload], [], fixture.tower_payloads(system), 5.0, 180.0, false)
	var decoded := system.decode_validated(var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE))
	_expect(decoded != null, "多目标持续攻击快照可压缩往返")
	var targets: PackedVector3Array = payload[system.U_CONTINUOUS_TARGETS]
	_expect(targets.size() == 1 and int(targets[0].z) == target.net_id, "快照保留空军身份与权威位置")
	for invalid in [PackedVector3Array([Vector3(NAN, 0, 1)]), PackedVector3Array([Vector3(0, 0, -2)]), PackedVector3Array([Vector3(0, 0, 1.5)]), []]:
		var broken := packet.duplicate(true)
		broken[system.S_UNITS][0][system.U_CONTINUOUS_TARGETS] = invalid
		_expect(system.decode_validated(var_to_bytes(broken).compress(FileAccess.COMPRESSION_DEFLATE)) == null, "畸形持续目标集合整包拒绝")
	source.free()
	target.free()

func _check_active_request() -> void:
	var wallet := ElixirManager.new()
	_main.add_child(wallet)
	_main.runtime.bind_account(0, wallet)
	_main.runtime._deck = ["scarecrow", "garen", "xin", "ashe", "teemo", "gnar", "heal", "freeze"]
	wallet.elixir = 10
	var source: Unit = _main._spawn_unit(UnitSpawnRequest.new(0, "scarecrow", Vector2(360, 800), {"active_slot": 0, "deploy_time_override": 0.0}))
	source.hp = 517
	var ability := source.active_ability_id
	_expect(_main.use_active_skill(ability, 0) and wallet.elixir == 9, "正式技能请求扣1金币")
	_main.runtime._sim_tick_id += _main.COMMAND_DELAY_TICKS
	_main.runtime._tick_pending_active_skills(0.05)
	_expect(source.form_index == 1 and source.hp == 517, "正式技能排程保血变形")
	_main.runtime._tick_active_skill_cooldowns(20.0)
	_expect(not _main.use_active_skill(ability, 0) and wallet.elixir == 9, "一次用尽后不再变回建筑或扣费")
	source.free()

func _check_definition_contract() -> void:
	for form in [false, true]:
		var stats := CardDB.get_card("scarecrow").duplicate(true)
		var candidate: Dictionary = stats.transformed_stats if form else stats
		candidate.drain_pause = 0.0
		_expect(not CardDB.VALIDATOR.validate_all({"scarecrow": stats}, false).is_empty(), "两种形态均拒绝零停顿")
		candidate.drain_pause = 0.75
		candidate.innate_lifesteal_ratio = -0.5
		_expect(not CardDB.VALIDATOR.validate_all({"scarecrow": stats}, false).is_empty(), "基础与移动形态都拒绝负吸血比例")
	var rows := CardDetails.attributes(CardDB.get_card("scarecrow"))
	_expect(rows.any(func(row): return row.name == "每秒伤害" and row.value == "60") and not rows.any(func(row): return row.name == "单次伤害"), "持续建筑详情显示DPS而非单次伤害")

func _check_native_parts() -> void:
	var view = load("res://assets/units/fiddlesticks/fiddlesticks_view.tscn").instantiate()
	_main.add_child(view)
	view.prepare_visual_animations()
	var player := view.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_expect(view._optional_parts.size() == 4, "完整接回灯笼、舌头与双黑手")
	for sample in [
		["fiddlesticks_idle1", 0.0, ["Lantern", "R_Demon_Arm"]],
		["fiddlesticks_idle1", 63.9 / 30.0, ["Lantern", "R_Demon_Arm"]],
		["fiddlesticks_idle1", 64.1 / 30.0, ["Lantern", "R_Demon_Arm", "Tongue"]],
		["fiddlesticks_idle1", 91.1 / 30.0, ["Lantern", "R_Demon_Arm"]],
		["fiddlesticks_run", 0.3, []],
		["fiddlesticks_idle1", 2.5, ["Lantern", "R_Demon_Arm", "Tongue"]],
		["fiddlesticks_spell2", 0.1, []],
		["fiddlesticks_spell2_channel", 1.0, []],
		["fiddlesticks_death_v2", 76.9 / 30.0, ["L_Demon_Arm", "R_Demon_Arm"]],
		["fiddlesticks_death_v2", 77.1 / 30.0, []],
		["fiddlesticks_idle1", 0.0, ["Lantern", "R_Demon_Arm"]],
	]:
		player.play(sample[0])
		player.seek(sample[1], true)
		for part in view.OPTIONAL_PARTS:
			_expect(view._optional_parts[part].visible == (part in sample[2]), "原生部件窗口 %s %.3f %s" % [sample[0], sample[1], part])
	# Exercise real crossfades at play() and on the first rendered movement frame.
	var clips := ["fiddlesticks_idle1", "fiddlesticks_run", "fiddlesticks_spell2", "fiddlesticks_spell2_channel", "fiddlesticks_death_v2"]
	for source in clips:
		for target in clips:
			if source == target:
				continue
			player.stop()
			player.play(source)
			player.seek(2.5, true)
			player.play(target, 0.2)
			var expected: Array = []
			if target == "fiddlesticks_idle1":
				expected = ["Lantern", "R_Demon_Arm"]
			elif target == "fiddlesticks_death_v2":
				expected = ["L_Demon_Arm", "R_Demon_Arm"]
			for delta in [0.0, 1.0 / 60.0, 0.1, 0.1]:
				for part in view.OPTIONAL_PARTS:
					_expect(view._optional_parts[part].visible == (part in expected), "动作过渡 %s -> %s %s" % [source, target, part])
				player.advance(delta)
	var tracks := player.get_animation("fiddlesticks_idle1").get_track_count()
	view.prepare_visual_animations()
	_expect(player.get_animation("fiddlesticks_idle1").get_track_count() == tracks, "预热重复准备不重复添加显隐轨道")
	view.reset_pool_visual()
	_expect(view._optional_parts.values().all(func(part): return not part.visible), "模型回池不残留临时部件")
	view.free()
