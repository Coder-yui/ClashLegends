class_name BattleSimulation
extends RefCounted
## 单机、独立服务器、工作台共用的权威阶段编排。客户端不得调用。
var _controller: Node2D

func setup(controller: Node2D) -> void:
	_controller = controller

func step(dt: float) -> void:
	if _controller.is_net_client(): return
	if _controller.game_over:
		return
	_controller._sim_tick_id += 1
	_controller._sim_step_active = true
	if _controller._match_started and not _controller._workbench.enabled:
		_controller._update_elixir_rate()
		_controller._elixir.sim_tick(dt)
		if _controller._elixir_p1 != null:
			_controller._elixir_p1.sim_tick(dt)
		if _controller._ai != null:
			_controller._ai._elixir.sim_tick(dt)
			if _controller._ai.enabled:
				_controller._ai.sim_tick(dt)
	# 在行动阶段前统一处理旧状态到期；本Tick新施加的状态不重复扣时。
	for actor in _controller.get_tree().get_nodes_in_group("combatants"):
		if actor.hp <= 0.0 and not (actor is Unit and actor.death_form.waiting()): continue
		if actor is Unit:
			actor._tick_active_statuses(dt)
			actor.prepare_action_clocks(dt)
			actor._apply_pending_form()
		elif actor is Tower: actor.prepare_statuses(dt)
	# 已存在的施法时间线先推进；本 Tick 新执行的命令从当前 Tick 边界开始计时。
	_controller._tick_active_skill_cooldowns(dt)
	_controller._combat.begin_batch(_controller._sim_tick_id, "skill_impacts")
	_controller._tick_summon_flights(dt)
	_controller._commands.tick_impacts(dt)
	_controller._combat.commit_batch()
	_controller._combat.begin_batch(_controller._sim_tick_id, "skill_effects")
	_controller._active_skill_effect_system.tick_effects(dt)
	_controller._combat.commit_batch()
	_controller._tick_pending_card_deployments(dt)
	_controller._combat.begin_batch(_controller._sim_tick_id, "skill_commands")
	_controller._tick_pending_active_skills(dt)
	_controller._combat.commit_batch()
	_controller._combat.begin_batch(_controller._sim_tick_id, "spell_zones")
	_controller._tick_slow_zones(dt)
	_controller._combat.commit_batch()
	if not _controller._workbench.enabled and _controller._minion_waves_enabled:
		_controller._tick_minion_waves(dt)
	# 固定本阶段参与者；自然到期退出及死亡生成不能回头加入预处理或行动批次。
	var combatants := _controller.get_tree().get_nodes_in_group("combatants")
	for c in combatants:
		if c is Unit: c.prepare_natural_lifecycle(dt)
	_controller._combat.begin_batch(_controller._sim_tick_id, "combatants")
	for c in combatants:
		c.bleeding.advance(c, dt)
	for c in combatants:
		if c is Unit:
			c.sim_tick(dt, true, true)
		elif c is Tower:
			c.sim_tick(dt, true)
	_controller._combat.commit_batch()
	_controller._team_attack_boost_system.tick(dt)
	# 预部署在本 Tick 边界完成；新单位从下一 Tick 推进实际部署，避免两阶段共用一个 Tick。
	_controller._tick_pending_card_pre_deployments(dt)
	_controller._sync_active_skill_deployment_readiness()
	_controller._movement.tick(dt)
	for actor in _controller.get_tree().get_nodes_in_group("combatants"):
		if actor is Unit: actor.target_protection.check_position(actor.global_position)
	_controller._combat.begin_batch(_controller._sim_tick_id, "projectiles")
	_controller._tick_projectiles(dt)
	_controller._combat.commit_batch()
	# 己方任一公主塔被摧毁 → 国王塔参战。
	for king in [_controller._king_player, _controller._king_enemy]:
		if not king.can_attack or king.activated or king.hp <= 0.0:
			continue
		var side: int = king.team
		if _controller._towers[side * 2].hp <= 0.0 or _controller._towers[side * 2 + 1].hp <= 0.0:
			king.activate()
	# 塔被摧毁 → 解除其导航网格占地，路径可穿过原塔位
	for t in _controller._towers:
		if t.hp <= 0.0 and not t.nav_cells.is_empty():
			_controller.unblock_nav_cells(t.nav_cells)
			t.nav_cells = []
	# 联机测试钩子：主动变大序列结束后再强制变小，覆盖双向形态序号与动作快照。
	if _controller._auto_gnar_revert_timer > 0.0:
		_controller._auto_gnar_revert_timer = maxf(0.0, _controller._auto_gnar_revert_timer - dt)
		if _controller._auto_gnar_revert_timer <= 0.0 and _controller._auto_gnar_revert_unit != null and is_instance_valid(_controller._auto_gnar_revert_unit):
			_controller._auto_gnar_revert_unit.transform_to_small()
	# 进入模拟 2 秒后生成近战、远程、弹道、持续吐息与双形态样本。
	if _controller._auto_test:
		_controller._auto_timer -= dt
		if _controller._auto_timer <= 0.0:
			_controller._auto_test = false
			_controller._deploy_card(0, "garen", Vector2(360, 1000))
			_controller._deploy_card(0, "ashe", Vector2(300, 700))
			_controller._deploy_card(0, "aurelionsol", Vector2(410, 700))
			_controller._deploy_card(1, "xin", Vector2(300, 580))
			var auto_gnar: Unit = _controller._spawn_unit(UnitSpawnRequest.new(0, "gnar", Vector2(520, 760), {"deploy_time_override": 0.0}))
			_controller.preview_active_skill(auto_gnar, CardDB.active_skills_for("gnar")[0])
			_controller._auto_gnar_revert_unit = auto_gnar
			_controller._auto_gnar_revert_timer = 2.4

	if _controller._match_started and not _controller._workbench.enabled:
		_controller._tick_match_rules(dt)

	_controller._sim_step_active = false
