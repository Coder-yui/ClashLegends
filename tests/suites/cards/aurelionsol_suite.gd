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
		and anim_names.attack_retarget_enter == "AurelionSol_Spell1_new_looptoin_anm"
		and anim_names.attack_loop == "AurelionSol_Spell1_loop_anm"
		and anim_names.transitions.get("attack>move", "") == "Spell1_2Run"
		and anim_names.move_enter_after_attack == false,
		"龙王区分移动后 newtst 与原地换目标 new_looptoin，并保留吐息转移动链路",
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
	var immediate_stop_ok := false
	if view != null:
		unit._target = dummy
		unit._attacking = true
		view._sync_visual(false, 0.05)
		var entered_attack := (
			view._animation_player.current_animation == "AurelionSol_Spell1_newtst_anm"
			and not unit.continuous_beam_visible
		)
		view._on_animation_finished(&"AurelionSol_Spell1_newtst_anm")
		attack_transition_ok = (
			entered_attack
			and view._animation_player.current_animation == "AurelionSol_Spell1_loop_anm"
			and unit.continuous_beam_visible
		)
		# 攻击状态未退出但目标序号推进：表示原目标被击败后在范围内直接换目标。
		unit._attack_visual_serial += 1
		view._sync_visual(false, 0.05)
		var entered_retarget := (
			view._animation_player.current_animation == "AurelionSol_Spell1_new_looptoin_anm"
			and not unit.continuous_beam_visible
		)
		view._on_animation_finished(&"AurelionSol_Spell1_new_looptoin_anm")
		retarget_transition_ok = (
			entered_retarget
			and view._animation_player.current_animation == "AurelionSol_Spell1_loop_anm"
			and unit.continuous_beam_visible
		)
		unit._attacking = false
		unit._move_intent = Vector2.UP * unit.move_speed
		view._sync_visual(false, 0.05)
		var attack_to_run := view._animation_player.current_animation == "Spell1_2Run"
		view._on_animation_finished(&"Spell1_2Run")
		var run_b := view._animation_player.current_animation == "Run1B"
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
	_expect(attached and attack_transition_ok, "龙王吐息进入段不显示光柱，进入循环吐息后才显示")
	_expect(retarget_transition_ok, "龙王原地击败目标并直接换目标时播放 new_looptoin→loop")
	_expect(move_transition_ok, "龙王吐息后按 Spell1_2Run→Run1B 直接接入移动循环")
	_expect(move_cycle_ok, "龙王移动按 Run1B→Run1C→Run1D→Run1A 循环")
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
