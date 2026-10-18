class_name BattleSimulation
extends RefCounted
## 单机、独立服务器、工作台共用的权威阶段编排。客户端不得调用。
var _runtime_ref: WeakRef
var _world: RefCounted

func setup(runtime: RefCounted, world: RefCounted) -> void:
	_runtime_ref = weakref(runtime)
	_world = world

func step(dt: float) -> void:
	var _runtime = _runtime_ref.get_ref()
	if _runtime == null: return
	if _runtime.is_net_client(): return
	if _runtime.game_over:
		return
	if not _runtime._sim_step_active: return
	if _runtime._match_started and not _runtime._workbench.enabled:
		_runtime.advance_economy(dt)
	# 在行动阶段前统一处理旧状态到期；本Tick新施加的状态不重复扣时。
	for actor in _world.combatants():
		if actor.hp <= 0.0 and not (actor is Unit and actor.death_form.waiting()): continue
		if actor is Unit:
			actor._tick_active_statuses(dt)
			actor.prepare_action_clocks(dt)
			actor._apply_pending_form()
		elif actor is Tower: actor.prepare_statuses(dt)
		if _runtime.game_over: return
	# 已存在的施法时间线先推进；本 Tick 新执行的命令从当前 Tick 边界开始计时。
	_runtime._tick_active_skill_cooldowns(dt)
	_runtime._combat.begin_batch(_runtime._sim_tick_id, "skill_impacts")
	_runtime._tick_summon_flights(dt)
	_runtime._commands.tick_impacts(dt)
	_runtime._combat.commit_batch()
	if _runtime.game_over: return # 契约失败在本批提交收尾后立即停，不再推进后续阶段。
	_runtime._combat.begin_batch(_runtime._sim_tick_id, "skill_effects")
	_runtime._active_skill_effect_system.tick_effects(dt)
	_runtime._combat.commit_batch()
	if _runtime.game_over: return # 契约失败在本批提交收尾后立即停，不再推进后续阶段。
	_runtime._tick_pending_card_deployments(dt)
	if _runtime.game_over: return
	_runtime._combat.begin_batch(_runtime._sim_tick_id, "skill_commands")
	_runtime._tick_pending_active_skills(dt)
	_runtime._combat.commit_batch()
	if _runtime.game_over: return # 契约失败在本批提交收尾后立即停，不再推进后续阶段。
	_runtime._combat.begin_batch(_runtime._sim_tick_id, "spell_zones")
	_runtime._spell_system.tick(dt)
	_runtime._combat.commit_batch()
	if _runtime.game_over: return # 契约失败在本批提交收尾后立即停，不再推进后续阶段。
	if not _runtime._workbench.enabled and _runtime._minion_waves_enabled:
		_runtime._tick_minion_waves(dt)
		if _runtime.game_over: return
	# 固定本阶段参与者；自然到期退出及死亡生成不能回头加入预处理或行动批次。
	var combatants: Array = _world.combatants()
	for c in combatants:
		if c is Unit: c.prepare_natural_lifecycle(dt)
		if _runtime.game_over: return
	_runtime._combat.begin_batch(_runtime._sim_tick_id, "combatants")
	for c in combatants:
		c.bleeding.advance(c, dt)
	for c in combatants:
		if _runtime.game_over: break
		if c is Unit:
			c.sim_tick(dt, true, true)
		elif c is Tower:
			c.sim_tick(dt, true)
	_runtime._combat.commit_batch()
	if _runtime.game_over: return # 契约失败在本批提交收尾后立即停，不再推进后续阶段。
	_runtime._team_attack_boost_system.tick(dt)
	if _runtime.game_over: return
	# 预部署在本 Tick 边界完成；新单位从下一 Tick 推进实际部署，避免两阶段共用一个 Tick。
	_runtime._tick_pending_card_pre_deployments(dt)
	if _runtime.game_over: return
	_runtime.refresh_skill_readiness()
	_runtime._movement.tick(dt)
	for actor in _world.combatants():
		if actor is Unit: actor.target_protection.check_position(actor.global_position)
	_runtime._combat.begin_batch(_runtime._sim_tick_id, "projectiles")
	_runtime._projectile_system.tick(dt)
	_runtime._combat.commit_batch()
	if _runtime.game_over: return # 契约失败在本批提交收尾后立即停，不再推进后续阶段。
	_world.finish_tower_step()
	_runtime.world_step_finished.emit(dt)

	if _runtime._match_started and not _runtime._workbench.enabled:
		_runtime._tick_match_rules(dt)
