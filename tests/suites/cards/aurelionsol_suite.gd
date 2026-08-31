class_name AurelionSolSuite
extends RefCounted
## 龙王卡牌领域：空中单位表现链路与持续吐息换目标。

var _harness: Object
var _main: Node2D

func _expect(condition: bool, message: String) -> void:
	_harness._expect(condition, message)

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_aurelionsol_art_integration()
	_check_aurelionsol_direct_retarget()
	_check_starfall_and_falling_sky()

func _check_starfall_and_falling_sky() -> void:
	_main._active_skill_effect_system.clear()
	var stats: Dictionary = CardDB.get_card("aurelionsol").duplicate(true)
	stats["deploy_time"] = 0.0
	var skill: Dictionary = stats.active_skill
	var dragon := Unit.new()
	dragon.position = Vector2(360.0, 1000.0)
	dragon.setup(0, stats, stats.name)
	_main.add_child(dragon)
	var kill_dummy := Unit.new()
	var dummy_stats := SuiteUtils.sweep_dummy_stats(CardDB.get_card("garen"))
	kill_dummy.position = Vector2(600.0, 1100.0)
	kill_dummy.setup(1, dummy_stats, "充能木桩")
	_main.add_child(kill_dummy)
	dragon.on_enemy_killed(kill_dummy)
	var disabled_without_loadout := not dragon.is_skill_resource_visible() and is_zero_approx(dragon.skill_resource_value)
	dragon.configure_carried_active_skill(skill)
	var prepared_starfall: Dictionary = _main._active_skill_effect_system.prepare_cast(dragon, skill)
	_main._active_skill_effect_system.apply_forward_area(dragon, prepared_starfall, Vector2.UP)
	var starfall_without_shockwave: bool = (
		not bool(prepared_starfall.get("full_resource", false))
		and is_equal_approx(float(prepared_starfall.damage), float(skill.damage))
		and is_equal_approx(float(prepared_starfall.stun_duration), float(skill.stun_duration))
		and String(prepared_starfall.visual_action) == "active"
		and _main._active_skill_effect_system.expanding_shockwaves.is_empty()
	)
	for _kill in range(5):
		dragon.on_enemy_killed(kill_dummy)
	var prepared: Dictionary = _main._active_skill_effect_system.prepare_cast(dragon, skill)
	_expect(
		disabled_without_loadout
		and starfall_without_shockwave
		and is_equal_approx(float(prepared.damage), float(skill.damage) * 1.5)
		and is_equal_approx(float(prepared.stun_duration), float(skill.stun_duration) * 1.5)
		and String(prepared.visual_action) == "active_strong"
		and is_zero_approx(dragon.skill_resource_value),
		"龙王只有携带星落/天瀑时击杀敌方单位才充能；普通星落没有冲击波，5 层升级天瀑并把区域伤害与眩晕提高至 1.5 倍",
	)
	var center := Unit.new()
	var wave := Unit.new()
	var behind := Unit.new()
	center.position = Vector2(360.0, 825.0)
	wave.position = Vector2(760.0, 825.0)
	behind.position = Vector2(360.0, 1180.0)
	for target in [center, wave, behind]:
		target.setup(1, dummy_stats, "天瀑木桩")
		_main.add_child(target)
	dragon.begin_active_skill_cast(float(prepared.cast_duration), Vector2.UP, prepared.cast_locks)
	var center_before := center.hp
	var wave_before := wave.hp
	var behind_before := behind.hp
	_main._active_skill_effect_system.apply(dragon, prepared)
	var impact_ok := (
		is_equal_approx(center_before - center.hp, float(skill.damage) * 1.5)
		and is_equal_approx(center.stun_timer, float(skill.stun_duration) * 1.5)
		and is_equal_approx(wave.hp, wave_before) and is_equal_approx(behind.hp, behind_before)
	)
	_main._active_skill_effect_system._tick_expanding_shockwaves(float(skill.shockwave_duration))
	var wave_ok := (
		is_equal_approx(wave_before - wave.hp, float(skill.shockwave_damage))
		and is_equal_approx(behind_before - behind.hp, float(skill.shockwave_damage))
		and is_equal_approx(wave.slow_timer, float(skill.shockwave_slow_duration))
		and is_equal_approx(center_before - center.hp, float(skill.damage) * 1.5)
	)
	_expect(
		impact_ok and wave_ok
		and dragon.is_active_skill_movement_locked() and dragon.is_active_skill_attack_locked() and dragon.is_active_skill_facing_locked(),
		"星落/天瀑锁定行动，在龙王前方圆形区域造成伤害与眩晕；只有天瀑的落地冲击波从区域外围扩至全场，造成公主塔单次伤害并减速且不重复命中中心",
	)
	var breath_target := Unit.new()
	breath_target.position = Vector2(360.0, 940.0)
	breath_target.setup(1, dummy_stats, "即时吐息木桩")
	_main.add_child(breath_target)
	dragon.active_skill_cast_timer = 0.0
	dragon.active_skill_cast_locks.clear()
	dragon._target = breath_target
	dragon._attacking = true
	dragon._attack_windup = 0.0
	var breath_before := breath_target.hp
	dragon._attack(_main.SIM_DT)
	_expect(is_zero_approx(dragon.first_hit_time) and breath_target.hp < breath_before, "龙王移除人为攻击前摇，进入攻击距离的第一个固定 tick 就开始造成持续吐息伤害")
	for unit in [dragon, kill_dummy, center, wave, behind, breath_target]:
		if is_instance_valid(unit):
			unit.free()
	_main._active_skill_effect_system.clear()

## 龙王是首个空中 3D 单位：模型悬空，移动四段循环，吐息进入/循环与退出衔接均由表现状态驱动。
func _check_aurelionsol_art_integration() -> void:
	var stats: Dictionary = CardDB.get_card("aurelionsol").duplicate(true)
	stats["deploy_time"] = 0.0
	var packed := load(stats.visual_scene_path) as PackedScene
	if packed == null:
		return
	var sample := packed.instantiate() as Node3D
	var model_node := sample.get_node_or_null("Model") as Node3D
	_expect(
		model_node != null and model_node.position.y > 2.0 and is_equal_approx(model_node.scale.x, 0.006),
		"龙王模型以独立表现高度悬在地面上方，权威空中坐标仍留在 2D 地面",
	)
	var anim_names: Dictionary = stats.visual_animations
	_expect(anim_names.deploy == "Respawn" and is_equal_approx(anim_names.deploy_clip_ratio, 0.5), "龙王部署使用 Respawn 前半段翻滚动画")
	_expect(
		anim_names.move_cycle == ["Run1B", "Run1C", "Run1D", "Run1A"]
		and anim_names.attack_enter == "AurelionSol_Spell1_newtst_anm"
		and anim_names.attack_retarget_enter == ["AurelionSol_Spell1_new_looptoin_anm", "AurelionSol_Spell1_newtst_anm"]
		and anim_names.attack_loop == "AurelionSol_Spell1_loop_anm"
		and anim_names.transitions.get("attack>move", "") == "Spell1_2Run"
		and anim_names.move_enter == "RunIn"
		and not anim_names.has("move_enter_after_attack")
		and not anim_names.has("move_enter_from_deploy_only"),
		"龙王不再保留旧规则覆盖；RunIn 走通用入口，初次攻击 newtst，原地换目标按 new_looptoin→newtst",
	)
	_expect(
		anim_names.visual_actions.active.animation == "Spell4"
		and anim_names.visual_actions.active_strong.animation == "AurelionSol_Spell4_base_anm",
		"龙王星落使用 Spell4，满层天瀑使用 Spell4 Base",
	)
	var beam_color: Color = stats.continuous_beam_color
	_expect(
		is_equal_approx(beam_color.a, 0.7)
		and stats.continuous_beam_start_width < stats.continuous_beam_end_width,
		"龙王临时吐息为 70% 不透明度、嘴部窄目标端宽的浅蓝梯形光柱",
	)
	var unit := Unit.new()
	var dummy := Unit.new()
	unit.position = Vector2(360.0, 900.0)
	dummy.position = Vector2(360.0, 780.0)
	unit.setup(0, stats, stats.name)
	dummy.setup(1, SuiteUtils.sweep_dummy_stats(CardDB.get_card("ashe")), "龙息木桩")
	_main.add_child(unit)
	_main.add_child(dummy)
	var attached: bool = _main._battle_presentation.attach_unit(unit, stats)
	var view: UnitModel3D = null
	for child in _main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == unit:
			view = child as UnitModel3D
			break
	var attack_transition_ok := false
	var retarget_transition_ok := false
	var move_transition_ok := false
	var move_cycle_ok := false
	var generic_run_in_ok := false
	var immediate_stop_ok := false
	var mouth_binding_ok := false
	var continuous_generic_fallback_ok := false
	if view != null:
		view._current_state = 0
		unit._move_intent = Vector2.UP * unit.move_speed
		view._transition_to_basic_state(2, 0.0)
		var deployed_to_run_in := view._animation_player.current_animation == "RunIn"
		view._on_animation_finished(&"RunIn")
		var deployed_to_run_b := view._animation_player.current_animation == "Run1B"
		unit._move_intent = Vector2.ZERO
		view._sync_visual(false, 0.05)
		unit._move_intent = Vector2.UP * unit.move_speed
		view._sync_visual(false, 0.05)
		var idle_to_run_in := view._animation_player.current_animation == "RunIn"
		view._on_animation_finished(&"RunIn")
		generic_run_in_ok = deployed_to_run_in and deployed_to_run_b and idle_to_run_in and view._animation_player.current_animation == "Run1B"
		unit._move_intent = Vector2.ZERO
		unit._target = dummy
		unit._attacking = true
		view._sync_visual(false, 0.05)
		view._update_continuous_beam_origin()
		mouth_binding_ok = unit.continuous_beam_origin_tracks_model and not unit.continuous_beam_origin_world_position.is_zero_approx()
		var entered_attack := (
			view._animation_player.current_animation == "AurelionSol_Spell1_newtst_anm"
			and is_equal_approx(view._last_clip_blend_time, view._transition_blend(&"action_in"))
			and unit.continuous_beam_visible
		)
		view._on_animation_finished(&"AurelionSol_Spell1_newtst_anm")
		attack_transition_ok = (
			entered_attack
			and view._animation_player.current_animation == "AurelionSol_Spell1_loop_anm"
			and is_equal_approx(view._last_clip_blend_time, view._transition_blend(&"sequence"))
			and unit.continuous_beam_visible
		)
		# 攻击状态未退出但目标序号推进：表示原目标被击败后在范围内直接换目标。
		unit._attack_visual_serial += 1
		view._sync_visual(false, 0.05)
		var entered_retarget := (
			view._animation_player.current_animation == "AurelionSol_Spell1_new_looptoin_anm"
			and is_equal_approx(view._last_clip_blend_time, view._transition_blend(&"sequence"))
			and unit.continuous_beam_visible
		)
		view._on_animation_finished(&"AurelionSol_Spell1_new_looptoin_anm")
		var retarget_to_newtst := view._animation_player.current_animation == "AurelionSol_Spell1_newtst_anm"
		view._on_animation_finished(&"AurelionSol_Spell1_newtst_anm")
		retarget_transition_ok = (
			entered_retarget
			and retarget_to_newtst
			and view._animation_player.current_animation == "AurelionSol_Spell1_loop_anm"
			and unit.continuous_beam_visible
		)
		unit._attacking = false
		unit._move_intent = Vector2.UP * unit.move_speed
		view._sync_visual(false, 0.05)
		var attack_to_run := (
			view._animation_player.current_animation == "Spell1_2Run"
			and is_equal_approx(view._last_clip_blend_time, view._transition_blend(&"sequence"))
		)
		view._on_animation_finished(&"Spell1_2Run")
		var run_b := (
			view._animation_player.current_animation == "Run1B"
			and is_equal_approx(view._last_clip_blend_time, view._transition_blend(&"sequence"))
		)
		view._on_animation_finished(&"Run1B")
		var run_c := view._animation_player.current_animation == "Run1C"
		view._on_animation_finished(&"Run1C")
		var run_d := view._animation_player.current_animation == "Run1D"
		view._on_animation_finished(&"Run1D")
		var run_a := view._animation_player.current_animation == "Run1A"
		view._on_animation_finished(&"Run1A")
		var looped_to_b := view._animation_player.current_animation == "Run1B"
		move_transition_ok = attack_to_run and run_b and not unit.continuous_beam_visible
		move_cycle_ok = run_b and run_c and run_d and run_a and looped_to_b
		# 同一 continuous route 临时移除专用片段，确认 fallback 仍是较长 action_out。
		var saved_transitions: Dictionary = view._animation_names.get("transitions", {}).duplicate(true)
		var saved_move_enter = view._animation_names.get("move_enter", "")
		view._animation_names["transitions"] = {}
		view._animation_names["move_enter"] = ""
		view._start_move_sequence(&"attack")
		continuous_generic_fallback_ok = (
			view._animation_player.current_animation == "Run1B"
			and is_equal_approx(view._last_clip_blend_time, view._transition_blend(&"action_out"))
		)
		view._animation_names["transitions"] = saved_transitions
		view._animation_names["move_enter"] = saved_move_enter
		unit._move_intent = Vector2.ZERO
		unit._attacking = true
		view._sync_visual(false, 0.05)
		view._on_animation_finished(&"AurelionSol_Spell1_newtst_anm")
		unit._attacking = false
		view._sync_visual(false, 0.05)
		immediate_stop_ok = (
			view._animation_player.current_animation == "Idle1_Base"
			and not unit.continuous_beam_visible
		)
	_expect(attached and attack_transition_ok, "龙王进入攻击距离立即开始吐息，newtst 与 loop 全程保持光柱")
	_expect(retarget_transition_ok, "龙王原地击败目标并直接换目标时播放 new_looptoin→newtst→loop")
	_expect(generic_run_in_ok, "龙王 RunIn 按新通用规则用于部署与 Idle 后进入移动，首尾均为 sequence blend")
	_expect(mouth_binding_ok, "龙王吐息起点每帧绑定当前动画 Pose 的 Jaw 骨骼，不再使用固定屏幕高度近似嘴部")
	_expect(move_transition_ok, "龙王吐息后按 Spell1_2Run→Run1B 直接接入移动循环")
	_expect(move_cycle_ok, "龙王移动按 Run1B→Run1C→Run1D→Run1A 循环")
	_expect(continuous_generic_fallback_ok, "continuous attack 无专用转跑片段时仍使用 action_out generic crossfade")
	_expect(immediate_stop_ok, "龙王退出攻击时立即打断吐息循环，不等待循环动画播完")
	unit.take_damage(unit.max_hp + 1.0)
	var death_view_found := view != null and view._dying and view._animation_player.current_animation == "Death"
	_expect(death_view_found, "龙王死亡时由独立 3D 代理播放 Death")
	if view != null:
		view.free()
	if is_instance_valid(unit):
		unit.free()
	if is_instance_valid(dummy):
		dummy.free()
	if sample != null:
		sample.free()

## 持续吐息的真实换目标：两个目标都在射程内时，击败其一后不移动，直接推进表现序号攻击另一个。
func _check_aurelionsol_direct_retarget() -> void:
	var dragon_stats: Dictionary = CardDB.get_card("aurelionsol").duplicate(true)
	dragon_stats["deploy_time"] = 0.0
	var dummy_stats: Dictionary = CardDB.training_dummy_stats().duplicate(true)
	dummy_stats["deploy_time"] = 0.0
	dummy_stats["hp"] = 30.0
	var dragon := Unit.new()
	var first_dummy := Unit.new()
	var second_dummy := Unit.new()
	dragon.position = Vector2(360.0, 1100.0)
	first_dummy.position = Vector2(360.0, 990.0)
	# 与第一目标相距超过吐息溅射判定，同时仍在龙王攻击范围内。
	second_dummy.position = Vector2(430.0, 980.0)
	dragon.setup(0, dragon_stats, dragon_stats.name)
	first_dummy.setup(1, dummy_stats, "换目标木桩一")
	second_dummy.setup(1, dummy_stats, "换目标木桩二")
	_main.add_child(dragon)
	_main.add_child(first_dummy)
	_main.add_child(second_dummy)
	var start_position := dragon.global_position
	var retargeted_without_move := false
	for _tick in 80:
		dragon.sim_tick(_main.SIM_DT)
		if dragon.get_attack_visual_serial() >= 2 and dragon._target == second_dummy and dragon._attacking:
			retargeted_without_move = true
			break
	_expect(
		first_dummy.hp <= 0.0
		and second_dummy.hp > 0.0
		and retargeted_without_move
		and dragon.global_position.is_equal_approx(start_position),
		"龙王击败射程内第一个目标后不移动，直接推进目标序号并攻击第二个目标",
	)
	for unit in [dragon, first_dummy, second_dummy]:
		if is_instance_valid(unit):
			unit.free()
