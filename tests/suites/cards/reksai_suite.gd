extends "res://tests/suites/battle_suite.gd"
func run(harness: Object) -> void:
	_harness = harness
	_main = preload("res://tests/fixtures/authority_battle.gd").new()
	harness.root.add_child(_main)
	for team in 2:
		_check_arrival(team)
		_check_empowered(team)
	_check_sequence_restart()
	_check_audio_contract()
	_check_burrow_paths()
	_check_variable_arrival()
	_main.free()
func _check_arrival(team: int) -> void:
	var center := Vector2(360, 400 if team == 0 else 880)
	_expect(_main.runtime.is_card_deploy_position_valid(team, "reksai", center), "雷克塞可部署敌方半场")
	_expect(not _main.runtime.is_card_deploy_position_valid(team, "reksai", Vector2(360, 640)), "全图仍拒绝河道")
	var enemy := _spawn_ready_unit("garen", 1-team, center+Vector2(60,0))
	var ally := _spawn_ready_unit("target_dummy", team, center+Vector2(-60,0))
	var air := _spawn_ready_unit("anivia", 1-team, center+Vector2(0,60))
	var outside := _spawn_ready_unit("target_dummy", 1-team, center+Vector2(150,0))
	var before := enemy.hp
	if _main.runtime.account(team) == null:
		var wallet := ElixirManager.new()
		_main.add_child(wallet)
		_main.runtime.bind_account(team, wallet)
	_main.runtime.account(team).elixir = 10
	_expect(_main.play_card(team, "reksai", center, {"immediate":true}), "正式出牌接受预部署")
	_expect(_main.runtime._commands.inspect_deployments().size()==1, "地下排程只创建一个部署")
	var pending: Dictionary = _main.runtime._commands.inspect_deployments()[0]
	var route := preload("res://scripts/battle/burrow_deployment_path.gd").curve(pending.route)
	_expect(is_equal_approx(float(pending.duration), route.get_baked_length()/320.0), "权威预部署时长由过桥曲线长度和固定速度计算")
	var ticks := ceili(float(pending.duration)/0.05 - 0.00001)
	for tick in ticks-1: _main.runtime._tick_pending_card_pre_deployments(0.05)
	_expect(_main._latest_unit_for_card("reksai",team)==null and enemy.hp==before, "抵达之前没有实体和路径伤害")
	_main.runtime._tick_pending_card_pre_deployments(0.05)
	var unit: Unit = _main._latest_unit_for_card("reksai",team)
	_expect(unit!=null and is_equal_approx(unit._deploy_timer,0.75), "路径抵达所在Tick生成并开始出土锁定")
	_expect(enemy.hp==before-80 and enemy._knockback_timer>0.0, "出土立即伤害并击退地面敌人")
	_expect(ally.hp==ally.max_hp and air.hp==air.max_hp and outside.hp==outside.max_hp, "出土不伤友军、空军和范围外")
	for tick in 30: _main.runtime._tick_pending_card_pre_deployments(0.05)
	_expect(enemy.hp==before-80 and _main.runtime._commands.inspect_deployments().is_empty(), "抵达效果只发生一次并清理队列")
	for actor in [unit,enemy,ally,air,outside]: actor.free()
func _check_empowered(team: int) -> void:
	var source := _spawn_ready_unit("reksai",team,Vector2(300,800))
	var target := _spawn_ready_unit("target_dummy",1-team,Vector2(340,800))
	var nearby := _spawn_ready_unit("target_dummy",1-team,Vector2(370,830))
	var air := _spawn_ready_unit("anivia",1-team,Vector2(340,830))
	for actor in [source,target,nearby,air]: actor.move_speed=0.0
	var skill: Dictionary = CardDB.active_skills_for("reksai")[0]
	_main._active_skill_effect_system.apply(source,skill)
	_expect(source.empowered_attacks_left==3, "Q赋予三次强化")
	for n in 4:
		source._target=target
		var sequence := source.basic_attack_sequence
		var hp := target.hp
		var near_hp := nearby.hp
		for tick in 40:
			source.sim_tick(0.05)
			if source.basic_attack_sequence>sequence: break
		if n < 3: _expect(posmod(source.get_attack_visual_serial()-1,3)==n, "Q三击表现序号依次对应Spell1/Spell1B/Spell1")
		_expect(target.hp==hp-(90 if n<3 else 60), "三次强化后第四次恢复普通伤害")
		_expect(nearby.hp==near_hp-(90 if n<3 else 0), "只有强化三击产生范围伤害")
		_expect(source.empowered_attacks_left==maxi(2-n,0), "每次攻击消耗一个强化次数")
	_expect(air.hp==air.max_hp and not source.is_empowered_attack_ready_visual(), "Q不伤空军，第三击后待发状态结束")
	_main._active_skill_effect_system.apply(source,skill)
	_main._active_skill_effect_system.apply(source,skill)
	_expect(source.empowered_attacks_left==3, "重复施放刷新而非叠加次数")
	for actor in [source,target,nearby,air]: actor.free()

func _check_sequence_restart() -> void:
	var unit := _spawn_ready_unit("reksai",0,Vector2(300,800))
	var skill: Dictionary = CardDB.active_skills_for("reksai")[0]
	_main._active_skill_effect_system.apply(unit,skill)
	unit._attack_visual_serial = 5
	unit._attack_visual_pending = true
	unit._try_start_attack_visual(0.18)
	var first := unit.get_attack_visual_serial()
	_expect(first > 5 and posmod(first-1,3)==0, "任意普攻序号后Q从第一段开始")
	unit._attack_visual_pending = true
	unit._try_start_attack_visual(0.18)
	_expect(unit.get_attack_visual_serial()>first and posmod(unit.get_attack_visual_serial()-1,3)==0, "取消前摇不消费Q段数，表现序号保持递增")
	unit.empowered_attacks_left = 1
	unit._attack_visual_pending = true
	unit._try_start_attack_visual(0.18)
	_expect(posmod(unit.get_attack_visual_serial()-1,3)==2, "剩一击对应第三段")
	_main._active_skill_effect_system.apply(unit,skill)
	unit._attack_visual_pending = true
	unit._try_start_attack_visual(0.18)
	_expect(posmod(unit.get_attack_visual_serial()-1,3)==0, "刷新Q重置三段动作顺序")
	unit.free()

func _check_audio_contract() -> void:
	for key in ["empowered_swing_by_segment", "empowered_hit_by_segment"]:
		var broken := CardDB.get_card("reksai").duplicate(true)
		broken.audio[key] = [broken.audio[key][0]]
		_expect(not CardDB.VALIDATOR.validate_all({"reksai":broken},false).is_empty(), "强化分段声音数量必须匹配动作")
		broken = CardDB.get_card("reksai").duplicate(true)
		broken.active_skills = []
		_expect(not CardDB.VALIDATOR.validate_all({"reksai":broken},false).is_empty(), "没有强化机制不得配置强化分段声音")

func _check_burrow_paths() -> void:
	var path = preload("res://scripts/battle/burrow_deployment_path.gd")
	var obstacle := _spawn_ready_unit("tombstone",1,Vector2(140,800))
	for team in 2:
		for target in [Vector2(140,300),Vector2(580,300),Vector2(140,1000),Vector2(580,1000),Vector2(140,640),Vector2(30,400)]:
			var route: PackedVector2Array = path.plan(_main.world,team,target,21.0)
			_expect(not route.is_empty(),"双方含建筑、塔、桥面和边缘落点均有可达路径")
			var legal := true
			for i in range(1,route.size()): legal = legal and _main.world._navigation_segment_walkable(route[i-1],route[i],21.0,false)
			_expect(legal,"完整身体净空及曲线连接不穿建筑、塔或河流")
	_main.runtime.account(0).elixir=10
	_main.play_card(0,"reksai",Vector2(300,300),{"immediate":true})
	var entry: Dictionary = _main.runtime._commands.inspect_deployments()[0]
	var frozen: PackedVector2Array = entry.route.duplicate()
	var added := _spawn_ready_unit("tombstone",1,Vector2(580,800))
	_main.runtime._tick_pending_card_pre_deployments(0.05)
	_expect(_main.runtime._commands.inspect_deployments()[0].route==frozen,"开始后新建建筑不重算已冻结路线")
	_main.runtime._commands.remove_deployment(int(entry.id))
	added.free()
	obstacle.free()

func _check_variable_arrival() -> void:
	for value in [0.0, -1.0, "fast"]:
		var broken := CardDB.get_card("reksai").duplicate(true)
		broken.pre_deploy_burrow_speed = value
		_expect(not CardDB.VALIDATOR.validate_all({"reksai":broken},false).is_empty(), "潜行速度拒绝零、负数和非数字")
	for team in 2:
		var durations: Array[float] = []
		for point in [Vector2(500,1000 if team==0 else 280), Vector2(500,240 if team==0 else 1040)]:
			_main.runtime.account(team).elixir = 10
			_expect(_main.play_card(team,"reksai",point,{"immediate":true}), "近远落点经正式出牌入口")
			var entry: Dictionary = _main.runtime._commands.inspect_deployments()[0]
			durations.append(float(entry.duration))
			var curve := preload("res://scripts/battle/burrow_deployment_path.gd").curve(entry.route)
			_expect(is_equal_approx(curve.get_baked_length()/float(entry.duration),320.0), "近远落点均保持每秒320像素")
			_main.runtime._commands.remove_deployment(int(entry.id))
		_expect(durations[1]>durations[0], "双方远端部署等待比近端更久")

	_main.runtime.mode = "client"
	_main.runtime.session.join("burrow-duration")
	_main.runtime.session.phase = MatchSession.Phase.RUNNING
	for seconds in [0.35,3.25]:
		_main._rpc_card_pre_deploy_started("burrow-duration",997,"reksai",0,Vector2(500,400),seconds,PackedVector2Array([Vector2(500,600),Vector2(500,400)]))
		var received: Dictionary = _main.runtime._commands.inspect_deployments()[0]
		_expect(is_equal_approx(received.duration,seconds), "客户端RPC保留每次部署实际时长，不读取固定卡牌时间")
		_expect(received.route == PackedVector2Array([Vector2(500,600),Vector2(500,400)]),"客户端使用主机冻结路径")
		_main.runtime._commands.remove_deployment(997)
