extends "res://tests/suites/battle_suite.gd"
func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var old_mode: String = main.runtime.mode
	var old_p1: ElixirManager = main.runtime.account(1)
	main.runtime.mode = "server"
	main.runtime.bind_account(1, ElixirManager.new())
	main.add_child(main.runtime.account(1))
	for team in [0, 1]:
		var receiver: ElixirManager = main.runtime.account(1 - team)
		receiver.elixir = 5.0
		var crab := spawn(team)
		crab.take_damage(99999)
		_expect(receiver.elixir == 7.0, "双方被击杀都只奖励敌方2金币")
		crab._die()
		_expect(receiver.elixir == 7.0, "重复死亡回调不重复奖励")
		_expect(main._active_skill_effect_system.death_heal_zones.back().radius == 150.0, "死亡治疗圈扩大到150")
		receiver.elixir = 9.0
		spawn(team).take_damage(99999)
		_expect(receiver.elixir == 10.0, "金币奖励遵守10金币上限")
		spawn(team).take_damage(99999)
		receiver.elixir = 5.0
		var suicide := spawn(team)
		suicide.add_shield(9999, 10.0)
		var before: int = main._active_skill_effect_system.death_heal_zones.size()
		main._active_skill_effect_system.apply(suicide, CardDB.active_skills_for("void_scuttle_crab")[0])
		_expect(suicide.hp == 0.0 and receiver.elixir == 5.0, "自尽直接死亡不受护盾阻挡且不给对方金币")
		_expect(main._active_skill_effect_system.death_heal_zones.size() == before + 1, "自尽仍生成治疗区")
		var removed := spawn(team)
		removed.free()
		_expect(receiver.elixir == 5.0, "直接清场不发赏金")
	# 单机保留表现队列；专服只广播后清空，因此单独验证本地表现。
	main.runtime.mode = "local"
	main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team).elixir = 5.0
	var victim := spawn(1)
	victim.take_damage(99999)
	var rewards := _gold_effects(main)
	_expect(rewards.size() == 1, "死亡生成一次金币表现")
	if not rewards.is_empty():
		_expect(rewards.back().team == 0 and rewards.back().pos == victim.global_position and rewards.back().length == 2.0, "提示记录受益方、死亡位置和实际入账")
	victim._die()
	_expect(_gold_effects(main).size() == 1, "重复死亡不重复金币提示")
	main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team).elixir = 9.0
	spawn(1).take_damage(99999)
	_expect(_gold_effects(main).size() == 2 and _gold_effects(main).back().length == 1.0, "临近上限只提示实际增加1金币")
	spawn(1).take_damage(99999)
	_expect(_gold_effects(main).size() == 2, "满金币无虚假入账提示")
	var sacrificed := spawn(1)
	main._active_skill_effect_system.apply(sacrificed, CardDB.active_skills_for("void_scuttle_crab")[0])
	_expect(_gold_effects(main).size() == 2, "自尽不产生金币提示")
	main._skill_presentation.clear()
	main._workbench.enabled = true
	main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team).elixir = 10.0
	spawn(1).take_damage(99999)
	_expect(_gold_effects(main).size() == 1 and _gold_effects(main).back().length == 2.0, "工作台无金币账户限制仍预览完整赏金")
	var preview_suicide := spawn(1)
	main._active_skill_effect_system.apply(preview_suicide, CardDB.active_skills_for("void_scuttle_crab")[0])
	_expect(_gold_effects(main).size() == 1, "工作台自尽仍不显示赏金")
	main._workbench.enabled = false
	main.runtime.mode = "server"
	main._active_skill_effect_system.clear()
	var crab := spawn(0)
	var building: Unit = main._spawn_unit(UnitSpawnRequest.new(1,"target_dummy",Vector2(250,850),{"deploy_time_override":0.0}))
	crab.hp = 500
	for i in 20: crab.sim_tick(0.05)
	_expect(crab.hp == 545 and crab.max_hp == 1260 and crab.structure_mending, "6费坦克生命与每秒45自疗")
	var ally: Unit = main._spawn_unit(UnitSpawnRequest.new(0,"garen",Vector2(390,900),{"deploy_time_override":0.0}))
	ally.hp = 100
	crab.take_damage(99999)
	for i in 116: main._active_skill_effect_system.tick_effects(0.05)
	_expect(ally.hp == 125, "扩大圈覆盖原110范围外友军并每秒治疗25")
	main._active_skill_effect_system.clear()
	building.free()
	ally.free()
	for value in [-1.0, 0.0, NAN, INF, "2"]:
		var stats: Dictionary = CardDB.get_card("void_scuttle_crab").duplicate(true)
		stats.death_enemy_elixir = value
		_expect(not CardDB.VALIDATOR.validate_all({"void_scuttle_crab":stats},false).is_empty(), "拒绝非法死亡赏金")
	main._active_skill_effect_system.clear()
	main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team).elixir = 5.0
	main.runtime.account(1).elixir = 5.0
	var old_deck: Array = main.runtime._deck.duplicate()
	main.runtime._deck[0] = "void_scuttle_crab"
	var caster: Unit = main._spawn_unit(UnitSpawnRequest.new(0,"void_scuttle_crab",Vector2(300,1000),{"deploy_time_override":0.0,"active_slot":0}))
	var ability := caster.active_ability_id
	caster.stun(1.0)
	_expect(not main.runtime._active_skill_is_legal(ability,0), "受控时拒绝执行主动自尽")
	caster.control.clear_on_death()
	_expect(main.use_active_skill(ability,0), "主动从正式入口接受请求")
	_expect(main.runtime.account(0 if main.runtime.mode == "server" else main.runtime.local_team).elixir == 4.0, "自尽请求扣除1金币")
	_expect(not main.use_active_skill(ability,0), "重复提交不重复扣费")
	_run_main_ticks(12)
	_expect(not is_instance_valid(caster) or caster.hp == 0.0, "正式排程执行自尽")
	_expect(main.runtime.account(1).elixir == 5.0, "正式排程自尽不给敌方金币")
	_expect(not main._active_skill_effect_system.death_heal_zones.is_empty(), "正式排程保留死亡治疗")
	main._active_skill_effect_system.clear()
	main.runtime._deck.assign(old_deck)
	main.runtime.account(1).free()
	main.runtime.bind_account(1, old_p1)
	main.runtime.mode = old_mode
func spawn(team: int) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team,"void_scuttle_crab",Vector2(250,900),{"deploy_time_override":0.0}))

func _gold_effects(main: Node2D) -> Array:
	return main._skill_presentation.frontal_effects.filter(func(effect): return String(effect.get("shape", "")) == "gold_reward")
