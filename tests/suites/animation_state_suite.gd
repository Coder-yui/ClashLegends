class_name AnimationStateSuite
extends RefCounted
## locomotion + action 动画通道、任意 Pose 打断、施法权限与网络载荷回归。

var _harness: Object
var _main: Node2D

func _expect(condition: bool, message: String) -> void:
	_harness._expect(condition, message)

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_locomotion_attack_interrupts()
	_check_skill_recovery_routes()
	_check_dedicated_move_transition_blends()
	_check_cast_policies_and_snapshot()

func _view_for(unit: Unit) -> UnitModel3D:
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			return child as UnitModel3D
	return null

func _check_locomotion_attack_interrupts() -> void:
	var stats := CardDB.get_card("gnar").duplicate(true)
	stats["deploy_time"] = 0.0
	var unit := Unit.new()
	var dummy := Unit.new()
	unit.position = Vector2(360.0, 900.0)
	dummy.position = Vector2(360.0, 860.0)
	unit.setup(0, stats, stats.name)
	dummy.setup(1, SuiteUtils.sweep_dummy_stats(CardDB.get_card("garen")), "动画木桩")
	_main.add_child(unit)
	_main.add_child(dummy)
	_main._battle_presentation.attach_unit(unit, stats)
	var view := _view_for(unit)
	var run_in_interrupted := false
	var attack_to_move := false
	var run_interrupted := false
	if view != null:
		unit._move_intent = Vector2.UP * unit.move_speed
		view._sync_visual(false, 0.05)
		view._animation_player.advance(0.12)
		var run_in_was_mid_clip := view._animation_player.current_animation == "Run1_In" and view._animation_player.current_animation_position > 0.05
		unit._target = dummy
		unit._attacking = true
		unit._attack_visual_serial += 1
		view._sync_visual(false, 0.05)
		run_in_interrupted = run_in_was_mid_clip and view._animation_player.current_animation == "Gnar_Attack1_anm"

		view._animation_player.advance(0.08)
		unit._attacking = false
		unit._move_intent = Vector2.UP * unit.move_speed
		view._sync_visual(false, 0.05)
		attack_to_move = view._animation_player.current_animation == "Run1_In"
		view._on_animation_finished(&"Run1_In")
		view._animation_player.advance(0.12)
		var run_was_mid_clip := view._animation_player.current_animation == "Run_Base" and view._animation_player.current_animation_position > 0.05
		unit._target = dummy
		unit._attacking = true
		unit._attack_visual_serial += 1
		view._sync_visual(false, 0.05)
		run_interrupted = run_was_mid_clip and view._animation_player.current_animation == "Gnar_Attack2_anm"
	_expect(run_in_interrupted, "Run_In 播放到中途可在同帧从当前 Pose 混合切入 Attack")
	_expect(run_interrupted, "Run 循环播放到任意进度可在同帧从当前 Pose 混合切入 Attack")
	_expect(attack_to_move, "Attack 播放中退出攻击时立即混合到 Move，不等待攻击素材结束")
	if view != null:
		view.free()
	unit.free()
	dummy.free()

func _check_skill_recovery_routes() -> void:
	var stats: Dictionary = CardDB.get_card("gnar").get("transformed_stats", {}).duplicate(true)
	stats["deploy_time"] = 0.0
	var unit := Unit.new()
	var dummy := Unit.new()
	unit.position = Vector2(360.0, 900.0)
	dummy.position = Vector2(360.0, 860.0)
	unit.setup(0, stats, stats.name)
	dummy.setup(1, SuiteUtils.sweep_dummy_stats(CardDB.get_card("garen")), "技能衔接木桩")
	_main.add_child(unit)
	_main.add_child(dummy)
	_main._battle_presentation.attach_unit(unit, stats)
	var view := _view_for(unit)
	var spell_to_idle := false
	var spell_to_move := false
	var spell_to_attack := false
	var animation_is_read_only := false
	var transition_policy_applied := false
	var generic_move_uses_action_out := false
	if view != null:
		unit.begin_active_skill_cast(1.2, Vector2.UP)
		unit.play_visual_action(&"active", 1.2)
		view._sync_visual(false, 0.05)
		transition_policy_applied = (
			view._active_action_kind == &"skill"
			and view._active_action_priority > int(UnitModel3D.ACTION_PRIORITY.get(&"attack", 20))
			and is_equal_approx(view._transition_blend(&"action_in"), 0.08)
			and is_equal_approx(view._active_action_blend_out, 0.12)
		)
		var cast_timer_before_finish := unit.active_skill_cast_timer
		view._on_animation_finished(&"GnarBig_Spell2_anm")
		spell_to_idle = view._animation_player.current_animation == "Idle1_Base"
		animation_is_read_only = is_equal_approx(unit.active_skill_cast_timer, cast_timer_before_finish)

		unit.active_skill_cast_timer = 0.0
		unit.active_skill_cast_locks.clear()
		unit.play_visual_action(&"active", 1.2)
		view._sync_visual(false, 0.05)
		unit._move_intent = Vector2.UP * unit.move_speed
		view._on_animation_finished(&"GnarBig_Spell2_anm")
		spell_to_move = view._animation_player.current_animation == "Run_Base"
		generic_move_uses_action_out = (
			is_equal_approx(view._last_clip_blend_time, 0.12)
		)

		unit._move_intent = Vector2.ZERO
		unit.play_visual_action(&"active", 1.2)
		view._sync_visual(false, 0.05)
		unit._target = dummy
		unit._attacking = true
		unit._attack_visual_serial += 1
		view._sync_visual(false, 0.05)
		var attack_waited := view._animation_player.current_animation == "GnarBig_Spell2_anm" and view._pending_attack_serial > 0
		view._on_animation_finished(&"GnarBig_Spell2_anm")
		spell_to_attack = attack_waited and view._animation_player.current_animation == "GnarBig_Attack1_anm"
	_expect(spell_to_idle, "纳尔 Spell2 结束当帧按统一 blend-out 恢复 Idle")
	_expect(spell_to_move, "纳尔 Spell2 没有专用 ToRun 时按 action_out 直接衔接基础 Run")
	_expect(spell_to_attack, "纳尔 Spell2 期间排队的普攻在动作结束当帧立即衔接 Attack")
	_expect(transition_policy_applied, "Skill 优先级高于 Attack，blend-in/out 统一从 transition policy 读取")
	_expect(generic_move_uses_action_out, "没有 dedicated transition 时，Skill→Move 使用动作描述覆盖的 action_out generic crossfade")
	_expect(animation_is_read_only, "animation_finished 只切换表现，不会提前结束权威 cast timing")
	if view != null:
		view.free()
	unit.free()
	dummy.free()

func _check_dedicated_move_transition_blends() -> void:
	var xin_stats: Dictionary = CardDB.get_card("xin").duplicate(true)
	xin_stats["deploy_time"] = 0.0
	# 复用真实赵信转跑素材构造 transform route 探针，验证 action kind 通用分派，无角色特判。
	xin_stats.visual_animations.transitions["transform>move"] = "Spell4_To_Run"
	var xin := Unit.new()
	xin.position = Vector2(180.0, 900.0)
	xin.setup(0, xin_stats, xin_stats.name)
	_main.add_child(xin)
	_main._battle_presentation.attach_unit(xin, xin_stats)
	var xin_view := _view_for(xin)
	var deploy_route_ok := false
	var skill_route_ok := false
	var transform_route_ok := false
	var indexed_attack_route_ok := false
	if xin_view != null:
		var sequence_blend := xin_view._transition_blend(&"sequence")
		var action_out_blend := xin_view._transition_blend(&"action_out")
		_expect(
			is_equal_approx(sequence_blend, 0.04)
			and is_equal_approx(xin_view._transition_blend(&"action_in"), 0.08)
			and is_equal_approx(action_out_blend, 0.14)
			and is_equal_approx(xin_view._transition_blend(&"locomotion"), 0.10)
			and is_equal_approx(xin_view._transition_blend(&"death"), 0.10)
			and is_equal_approx(xin_view._transition_blend(&"model_swap"), 0.02),
			"全局默认混合为 action_in 0.08、action_out 0.14、sequence 0.04、locomotion/death 0.10、model_swap 0.02",
		)

		xin_view._current_state = 0
		xin_view._play_state(0, 0.0)
		xin_view._transition_to_basic_state(2, action_out_blend, &"deploy")
		var deploy_entry_short := (
			xin_view._animation_player.current_animation == "Spell4_To_Run"
			and is_equal_approx(xin_view._last_clip_blend_time, sequence_blend)
			and not is_equal_approx(xin_view._last_clip_blend_time, action_out_blend)
		)
		xin_view._on_animation_finished(&"Spell4_To_Run")
		deploy_route_ok = (
			deploy_entry_short
			and xin_view._animation_player.current_animation == "RunBase"
			and is_equal_approx(xin_view._last_clip_blend_time, sequence_blend)
		)

		xin.play_visual_action(&"active", 1.0)
		xin_view._sync_visual(false, 0.05)
		xin._move_intent = Vector2.UP * xin.move_speed
		xin_view._on_animation_finished(&"Spell4")
		var skill_entry_short := (
			xin_view._animation_player.current_animation == "Spell4_To_Run"
			and is_equal_approx(xin_view._last_clip_blend_time, sequence_blend)
		)
		xin_view._on_animation_finished(&"Spell4_To_Run")
		skill_route_ok = (
			skill_entry_short
			and xin_view._animation_player.current_animation == "RunBase"
			and is_equal_approx(xin_view._last_clip_blend_time, sequence_blend)
		)

		xin_view._transition_to_basic_state(2, action_out_blend, &"transform")
		var transform_entry_short := (
			xin_view._animation_player.current_animation == "Spell4_To_Run"
			and is_equal_approx(xin_view._last_clip_blend_time, sequence_blend)
		)
		xin_view._on_animation_finished(&"Spell4_To_Run")
		transform_route_ok = (
			transform_entry_short
			and xin_view._animation_player.current_animation == "RunBase"
			and is_equal_approx(xin_view._last_clip_blend_time, sequence_blend)
		)

		xin_view._play_attack(3)
		xin_view._transition_to_basic_state(2, action_out_blend, &"attack")
		var indexed_entry_short := (
			xin_view._animation_player.current_animation == "PassiveAA_to_Run_XinZhaoRework_anm"
			and is_equal_approx(xin_view._last_clip_blend_time, sequence_blend)
		)
		xin_view._on_animation_finished(&"PassiveAA_to_Run_XinZhaoRework_anm")
		indexed_attack_route_ok = (
			indexed_entry_short
			and xin_view._animation_player.current_animation == "RunBase"
			and is_equal_approx(xin_view._last_clip_blend_time, sequence_blend)
		)

		# 前两段没有专用 attack_to_move，统一复用 move_enter RunIn，首尾同样是 sequence。
		xin_view._play_attack(1)
		xin_view._transition_to_basic_state(2, action_out_blend, &"attack")
		var generic_run_in_entry := (
			xin_view._animation_player.current_animation == "RunIn"
			and is_equal_approx(xin_view._last_clip_blend_time, sequence_blend)
		)
		xin_view._on_animation_finished(&"RunIn")
		indexed_attack_route_ok = indexed_attack_route_ok and generic_run_in_entry and (
			xin_view._animation_player.current_animation == "RunBase"
			and is_equal_approx(xin_view._last_clip_blend_time, sequence_blend)
		)

	var teemo_stats: Dictionary = CardDB.get_card("teemo").duplicate(true)
	teemo_stats["deploy_time"] = 0.0
	var teemo := Unit.new()
	teemo.position = Vector2(540.0, 900.0)
	teemo.setup(0, teemo_stats, teemo_stats.name)
	_main.add_child(teemo)
	_main._battle_presentation.attach_unit(teemo, teemo_stats)
	var teemo_view := _view_for(teemo)
	var empowered_route_ok := false
	if teemo_view != null:
		teemo._empowered_attack_visual_serial = 1
		teemo_view._play_attack(1)
		teemo_view._transition_to_basic_state(2, teemo_view._transition_blend(&"action_out"), &"attack")
		empowered_route_ok = (
			teemo_view._animation_player.current_animation == "Spell1_ToRun"
			and is_equal_approx(teemo_view._last_clip_blend_time, teemo_view._transition_blend(&"sequence"))
		)

	_expect(deploy_route_ok, "transitions[deploy>move] 进入专用片段及其进入 Run 均使用 sequence blend")
	_expect(skill_route_ok, "transitions[skill>move] 忽略上层 action_out，专用片段首尾均使用 sequence blend")
	_expect(transform_route_ok, "transitions[transform>move] 的专用片段首尾均使用 sequence blend")
	_expect(indexed_attack_route_ok, "按段 attack_to_move 专用片段与空项回退通用 RunIn 都遵循 sequence 规则")
	_expect(empowered_route_ok, "empowered_attack_to_move 进入专用片段时使用 sequence blend")
	if xin_view != null:
		xin_view.free()
	if teemo_view != null:
		teemo_view.free()
	xin.free()
	teemo.free()

func _check_cast_policies_and_snapshot() -> void:
	var stats: Dictionary = CardDB.get_card("gnar").get("transformed_stats", {}).duplicate(true)
	stats["deploy_time"] = 0.0
	var dummy_stats := SuiteUtils.sweep_dummy_stats(CardDB.get_card("garen"))
	var stationary := Unit.new()
	var mobile := Unit.new()
	var unrestricted := Unit.new()
	var near_dummy := Unit.new()
	var far_dummy := Unit.new()
	stationary.position = Vector2(260.0, 900.0)
	mobile.position = Vector2(360.0, 900.0)
	unrestricted.position = Vector2(300.0, 900.0)
	near_dummy.position = Vector2(260.0, 860.0)
	far_dummy.position = Vector2(360.0, 790.0)
	for unit in [stationary, mobile, unrestricted]:
		unit.setup(0, stats, stats.name)
		_main.add_child(unit)
	near_dummy.setup(1, dummy_stats, "近端木桩")
	far_dummy.setup(1, dummy_stats, "远端木桩")
	_main.add_child(near_dummy)
	_main.add_child(far_dummy)

	stationary._target = near_dummy
	stationary.begin_active_skill_cast(0.15, Vector2.UP)
	var stationary_serial := stationary.get_attack_visual_serial()
	stationary.sim_tick(_main.SIM_DT)
	var stationary_locked := stationary._move_intent.is_zero_approx() and not stationary._attacking and stationary.get_attack_visual_serial() == stationary_serial
	while stationary.active_skill_cast_timer > 0.0:
		stationary.sim_tick(_main.SIM_DT)
	var attacks_after_cast := stationary._attacking and stationary.get_attack_visual_serial() > stationary_serial

	mobile._target = far_dummy
	mobile.begin_active_skill_cast(0.3, Vector2.UP, [Unit.CAST_LOCK_ATTACK, Unit.CAST_LOCK_FACING])
	var mobile_serial := mobile.get_attack_visual_serial()
	mobile.sim_tick(_main.SIM_DT)
	var mobile_cast_policy := mobile._move_intent.length_squared() > 0.01 and not mobile._attacking and mobile.get_attack_visual_serial() == mobile_serial

	unrestricted._target = near_dummy
	unrestricted.begin_active_skill_cast(0.3, Vector2.UP, [])
	unrestricted.sim_tick(_main.SIM_DT)
	var unrestricted_policy := unrestricted._attacking

	stationary.play_visual_action(&"active", 1.2)
	stationary.sim_tick(_main.SIM_DT)
	stationary.empowered_attack_ready = true
	stationary._empowered_attack_visual_serial = 9
	stationary.skill_resource_max = 200.0
	stationary.skill_resource_value = 150.0
	stationary.skill_resource_enabled = true
	stationary.blind_attack_charges = 2
	stationary.shield_max_hp = 200.0
	stationary.shield_hp = 125.0
	stationary.shield_timer = 1.0
	stationary.active_speed_multiplier = 1.5
	stationary.active_attack_speed_multiplier = 1.4
	stationary.active_ability_id = 9001
	_main._active_skills[stationary.active_ability_id] = {
		"unit": stationary, "uses_remaining": 2, "cooldown_left": 1.25,
	}
	var payload := NetworkSnapshotSystem.new(_main)._unit_snapshot_payload(77, stationary)
	var snapshot_system := NetworkSnapshotSystem.new(_main)
	var snapshot_header := snapshot_system.snapshot_header()
	var snapshot_contract: bool = (
		payload.size() == 37
		and int(payload[NetworkSnapshotSystem.U_ACTION_SERIAL]) == stationary.get_visual_action_serial()
		and String(payload[NetworkSnapshotSystem.U_ACTION_NAME]) == "active"
		and is_equal_approx(float(payload[NetworkSnapshotSystem.U_ACTION_DURATION]), 1.2)
		and is_equal_approx(float(payload[NetworkSnapshotSystem.U_ACTION_TIME_LEFT]), 1.2 - _main.SIM_DT)
		and int(payload[NetworkSnapshotSystem.U_LOCOMOTION]) == stationary.get_locomotion_visual_state_code()
		and int(payload[NetworkSnapshotSystem.U_EMPOWERED_READY]) == 1
		and int(payload[NetworkSnapshotSystem.U_EMPOWERED_ATTACK_SERIAL]) == 9
		and is_equal_approx(float(payload[NetworkSnapshotSystem.U_SKILL_RESOURCE_RATIO]), 0.75)
		and int(payload[NetworkSnapshotSystem.U_BLIND_ATTACK_CHARGES]) == 2
		and int(payload[NetworkSnapshotSystem.U_SKILL_RESOURCE_ENABLED]) == 1
		and is_equal_approx(float(payload[NetworkSnapshotSystem.U_ACTIVE_SPEED_MULTIPLIER]), 1.5)
		and is_equal_approx(float(payload[NetworkSnapshotSystem.U_ACTIVE_ATTACK_SPEED_MULTIPLIER]), 1.4)
		and int(payload[NetworkSnapshotSystem.U_ACTIVE_SKILL_USES_REMAINING]) == 2
		and is_equal_approx(float(payload[NetworkSnapshotSystem.U_ACTIVE_SKILL_COOLDOWN]), 1.25)
		and is_equal_approx(float(payload[NetworkSnapshotSystem.U_SHIELD_RATIO]), 0.625)
		and is_equal_approx(float(payload[NetworkSnapshotSystem.U_SHIELD_CAPACITY_RATIO]), stationary.shield_max_hp / stationary.max_hp)
		and int(snapshot_header[0]) == NetworkSnapshotSystem.SNAPSHOT_PROTOCOL_VERSION
		and int(snapshot_header[1]) == _main._sim_tick_id
	)
	_expect(stationary_locked and attacks_after_cast, "默认技能施法独立锁住移动与普攻，并在窗口结束后立即允许攻击")
	_expect(mobile_cast_policy, "cast_locks 可配置允许移动施法，同时继续禁止普通攻击")
	_expect(unrestricted_policy, "空 cast_locks 的纯 Buff 窗口不影响 locomotion 或普通攻击")
	_expect(snapshot_contract, "网络快照追加同步 action 时间轴、locomotion、强化普攻、豪意、致盲与主动技能次数/CD，旧表现字段下标保持不变")
	for unit in [stationary, mobile, unrestricted, near_dummy, far_dummy]:
		if is_instance_valid(unit):
			unit.free()
	_main._active_skills.erase(9001)
