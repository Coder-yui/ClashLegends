extends "res://tests/suites/battle_suite.gd"

func spawn(id: String, team: int, point: Vector2) -> Unit:
	return _main._spawn_unit(UnitSpawnRequest.new(team, id, point, {"deploy_time_override": 0.0}))

func clear_units() -> void:
	for c in _main.get_tree().get_nodes_in_group("combatants"):
		if c is Unit: c.free()

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	for tower in main.world.towers_snapshot(): tower.can_attack = false
	clear_units()
	var source := spawn("soul_tentacle", 0, Vector2(360, 1000))
	var target := spawn("target_dummy", 1, Vector2(360, 880))
	source._target = target
	source._attacking = true
	source.attack_timeline.begin_windup(source.first_hit_time, 1.0)
	source._attack_visual_pending = true
	source._attack(0.05)
	_expect(source.fixed_attack_direction.is_equal_approx(Vector2.UP), "触手起手锁定目标方向")
	var hp := target.hp
	target.position.x += 150.0
	for i in 14: source._attack(0.05)
	_expect(target.hp == hp, "目标走出预警后拍空")
	_expect(source._attack_hit_index == 1, "拍空仍消费一个攻击周期")
	clear_units()
	source = spawn("soul_tentacle", 0, Vector2(360, 1000))
	target = spawn("target_dummy", 1, Vector2(360, 880))
	var second := spawn("target_dummy", 1, Vector2(399, 650))
	var outside_width := spawn("target_dummy", 1, Vector2(430, 650))
	var outside_length := spawn("target_dummy", 1, Vector2(360, 600))
	var outside_hp := outside_width.hp
	source._target = target
	source._attacking = true
	source._attack_visual_pending = true
	source.attack_timeline.begin_windup(source.first_hit_time, 1.0)
	source._attack(0.05)
	target.free()
	hp = second.hp
	for i in 14: source._attack(0.05)
	_expect(second.hp == hp - 180.0, "主目标死亡不取消固定区域；扩展到2×9格的区域仍命中")
	_expect(outside_width.hp == outside_hp and outside_length.hp == outside_hp, "新矩形宽度与长度外的目标不受伤")
	source._tick_building_lifetime(1.0)
	_expect(source.hp == 960.0, "1000生命25秒自然衰减每秒40")
	source.control.hard.apply(&"untargetable", &"faith", 8.0, {"pause_lifespan": true})
	var left := source._lifespan_left
	source._tick_building_lifetime(1.0)
	_expect(source.hp == 960.0 and source._lifespan_left == left, "不可选取强化暂停生命与寿命")
	_expect(not CombatInteraction.can_acquire(source, 1), "不可选取时不能新锁定")
	_expect(not CombatInteraction.allows(source, second), "不可选取时拒绝敌方伤害")
	var herald := spawn("rift_herald", 1, Vector2(360, 1200))
	herald.structure_rush.target = source
	_expect(not herald.structure_rush._valid_target(herald), "先锋不能新选不可选取触手")
	_expect(herald.structure_rush._valid_target(herald, true), "先锋已开始的冲撞保留不可选取触手")
	var herald_hp := herald.hp
	herald.structure_rush._impact(herald)
	_expect(herald.hp == herald_hp and source.hp == 960.0, "不可选取触手令冲撞无伤害且不扣先锋生命")
	_expect(herald.structure_rush.phase == StructureRushState.Phase.RECOVERY, "冲撞仍进入收招并消耗一次冲撞")
	source.control.hard.clear_family(&"untargetable")
	source._tick_building_lifetime(1.0)
	_expect(source.hp == 920.0, "强化结束后恢复自然衰减")
	_main._combat.begin_batch(1, "tentacle_buff")
	_main.preview_active_skill(source, CardDB.active_skills_for("soul_tentacle")[0])
	_main._combat.commit_batch()
	_expect(source.control.hard.remaining(&"untargetable") == 8.0, "正式技能入口提交8秒不可选取")
	_expect(is_equal_approx(source._effective_attack_speed_multiplier(), 1.5), "强化攻速提高50%")
	clear_units()

	var player: Node3D = load("res://assets/effects/soul_tentacle/player.gd").new()
	_main.add_child(player)
	player.load_kind("avatar")
	player.setup_native(0.01)
	player.make_overlay(StandardMaterial3D.new())
	player.seek_attached_loop(2.999)
	var before: float = player._attached[0].loop_particle[32]
	player.seek_attached_loop(3.001)
	var after: float = player._attached[0].loop_particle[32]
	_expect(absf(after - before - 0.0002) < 0.00001, "待机3秒边界按原速连续滚动，不跳回纹理")
	player.seek_attached_loop(33.0)
	player.update_attached(true)
	_expect(player._attached[0].material.get_shader_parameter("attached_enabled"), "长时待机不因5秒采样结束而消失")
	player.free()

	for kind in ["indicator_blue", "indicator_red"]:
		var indicator: Node3D = load("res://assets/effects/soul_tentacle/player.gd").new()
		_main.add_child(indicator)
		indicator.load_kind(kind)
		indicator.setup_native(0.01)
		indicator.fit_indicator(Vector2(2.0, 9.0))
		var ground: Array = indicator._data.frames[12][0][0]
		_expect(is_equal_approx(2.0 * ground[5] * indicator.scale.x, 2.0), kind + "原生范围宽度2格")
		_expect(is_equal_approx(2.0 * ground[4] * indicator.scale.z, 9.0), kind + "原生范围长度9格")
		_expect(absf((ground[3] - ground[4]) * indicator.scale.z + indicator.position.z) < 0.00001, kind + "范围起点与触手中心对齐")
		_expect(is_equal_approx(indicator.scale.y, 0.01), kind + "保持原生高度比例")
		indicator.free()

	_check_native_presentation()
	_check_standalone_preview()

func _check_native_presentation() -> void:
	var stats := CardDB.get_card("soul_tentacle")
	var source := Unit.new()
	source.setup(0, stats, stats.name)
	_main.add_child(source)
	_main._battle_presentation.attach_unit(source, stats)
	var view := _view_for(source)
	_expect(view != null, "触手正式模型挂载")
	if view != null:
		var player := view._animation_player
		view._sync_visual(true, 0.0)
		_expect(is_equal_approx(player.get_playing_speed(), 76.0 / 30.0), "出生动作压缩为1秒部署")
		player.advance(1.0)
		source._deploy_timer = 0.0
		view._sync_visual(false, 0.0)
		_expect(player.current_animation == "illaoiminion_idleangry", "完整出生后接原生IdleAngry")
		for kind in [&"locomotion", &"attack", &"action_out", &"death"]:
			_expect(view._transition_blend(kind) == 0.0, "源图零混合:" + String(kind))
		var model: Node3D = view._model_root
		model.sync_combat_visual(source.presentation_state(), 4.05, false)
		_expect(model._players.base_active.visible and model._players.avatar._attached.size() == 3, "正常待机常驻底座与完整三层激活材质")
		_expect(is_equal_approx(model.get_node("Model").scale.x, 0.009), "拍击宽倍率0.01乘源skinScale0.9")
		_expect(not model._players.has("spawn") and not model._players.has("dormant"), "不接出生前蓄生或休眠外观")
		model._players.base_active.seek(180.0)
		_expect(model._players.base_active.has_live_particles(), "常驻特效支持反复强化后长时间存活")
		model._players.activation.seek(0.3)
		_expect(model._players.activation.has_live_particles(), "开启技能显示原AvatarActive橙红生成闪光")
		_expect(model._players.activation._data.emitters.size() == 1 and model._players.activation._data.emitters[0].name == "fireLine", "开启效果只有生成闪光，不含砸地烟尘")
		model._players.activation.seek(0.7)
		_expect(not model._players.activation.has_live_particles(), "生成闪光按原生时长消失，不循环8秒")
		model._players.base_active.seek(19.9)
		model._players.base_active.stop_emitting()
		model._players.base_active.seek(20.1)
		_expect(model._players.base_active.has_live_particles(), "循环边界保留死亡前已出生粒子")
		model._players.base_active.seek(23.1)
		_expect(not model._players.base_active.has_live_particles(), "停发后下一周期不复活旧粒子")
		model._players.base_active.restart_emitting()
		model._players.base_active.seek(180.0)
		model.begin_visual_death(0.8)
		model._process(0.8)
		_expect(not model._players.base_active.has_live_particles(), "死亡0.8秒内清空底座尾迹")
		model.finish_visual_death()
		_expect(not model.get_node("Model").visible, "死亡结束移除底座模型")
	source.free()

func _check_standalone_preview() -> void:
	var preview := WorkbenchModelPreview.new()
	_main.add_child(preview)
	preview.show_definition(CardDB.get_card("soul_tentacle"), 0)
	_expect(preview.model != null and preview._fit_size > 0.1 and preview._fit_size < 30.0, "工作台按模型拟合，不计粒子巨大包围盒")
	for layer in preview.model._players.avatar._attached:
		_expect(layer.material.get_shader_parameter("attached_enabled"), "独立预览无需Unit即可启用附着材质")
	preview.model._process(180.0)
	_expect(preview.model._players.base_active.has_live_particles(), "独立预览长时间仍显示底座")
	preview.free()
