extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	_check_burst_expiry_and_audio()
	# 两种普攻阶段到时均中断，旧冷却不能拖延新形态第一击。
	for phase in ["windup", "recovery"]:
		var changing := _spawn_ready_unit("jayce", 0, Vector2(100, 1100))
		var victim := _spawn_ready_unit("garen", 1, Vector2(110, 1100))
		victim.hp = 2000
		victim.max_hp = 2000
		changing.cyclic_form.elapsed = 8.0
		changing.attack_timeline.set(phase, 0.8)
		changing.attack_timeline.cooldown = 1.0
		changing._target = victim
		changing._attacking = true
		changing.sim_tick(0.05)
		_expect(changing.form_index == 1 and not changing.is_form_transitioning(), phase + "到时瞬时换形，无转换锁")
		_expect(changing.attack_timeline.recovery == 0.0 and victim.hp == 2000, "取消旧攻击，无幽灵命中")
		_expect(changing.attack_timeline.windup > 0.0, "换形同Tick立即开始新普攻前摇")
		_expect(changing.get_visual_action_time_left() > 0.0 and is_equal_approx(changing.get_visual_action_duration(), 0.3), "独立保留换形声光窗口，不阻塞普攻")
		_expect(is_equal_approx(changing.attack_interval, 1.1) and changing.damage == 80 and changing.splash_radius == 0.0, "锤间隔1.1秒80伤害且单体")
		changing._apply_form(0, false)
		_expect(is_equal_approx(changing.attack_interval, 1.4) and changing.damage == 65, "炮间隔1.4秒65伤害")
		changing.queue_free()
		victim.queue_free()
	var displaced := _spawn_ready_unit("jayce", 0, Vector2(80, 1000))
	displaced.cyclic_form.elapsed = 8.0
	displaced.knockback.replace(Vector2.RIGHT, 20.0, 0.1)
	_expect(not displaced.cyclic_form.try_switch(displaced), "击退轨迹存在时延后换形")
	displaced.sim_tick(0.05)
	displaced.sim_tick(0.05)
	_expect(displaced.form_index == 0, "击退最后移动Tick仍延后")
	displaced.sim_tick(0.05)
	_expect(displaced.form_index == 1, "击退结束后立即换形")
	displaced.queue_free()
	await main.get_tree().process_frame
	var source := _spawn_ready_unit("jayce", 0, Vector2(300, 1000))
	var target := _spawn_ready_unit("garen", 1, Vector2(360, 1000))
	var neighbour := _spawn_ready_unit("garen", 1, Vector2(380, 1000))
	target.max_hp = 2000
	target.hp = 2000
	neighbour.max_hp = 2000
	neighbour.hp = 2000
	_expect(source.form_index == 0 and source.can_attack_air and source.cyclic_form.first_attack, "远程部署且首击就绪")
	for tick in 159: source.cyclic_form.advance(source, 0.05)
	_expect(not source.cyclic_form.try_switch(source), "未满8秒不换形")
	source.cyclic_form.advance(source, 0.05)
	source.stun(1.0)
	_expect(not source.cyclic_form.try_switch(source), "眩晕推迟换形")
	source.control.hard.clear_family(&"stun")
	source.freeze(1.0)
	_expect(not source.cyclic_form.try_switch(source), "冰冻推迟换形")
	source.control.hard.clear_family(&"freeze")
	source.control.hard.apply(&"stasis", &"test", 1.0, {})
	_expect(not source.cyclic_form.try_switch(source), "凝滞推迟换形")
	source.control.hard.clear_family(&"stasis")
	_expect(source.cyclic_form.try_switch(source) and source.form_index == 1 and not source.can_attack_air, "解控换锤且不对空")
	_expect(is_equal_approx(source.cyclic_form.elapsed, 0.0), "实际换形后重新计8秒，不补多轮")
	source._attack_visual_serial = 1
	var effects := {}
	source.cyclic_form.consume(source, effects)
	source.battle_context.damage_batch().resolve_attack_hit(0, source.position, target, source.damage, source.splash_radius, 0.0, source, source.position, source.form_index, effects)
	_expect(target.hp == 1760 and neighbour.hp == 2000, "近战主目标80+8%最大生命，邻居不受普攻伤害")
	var next_effects := {}
	source.cyclic_form.consume(source, next_effects)
	_expect(next_effects.is_empty(), "首击只消费一次")
	var tower: Tower = main.world.towers_snapshot()[0]
	var before := tower.hp
	source.battle_context.damage_batch().resolve_attack_hit(1-tower.team, source.position, tower, 80, 0.0, 0.0, null, source.position, 1, effects)
	_expect(before-tower.hp == 140, "塔首击使用60固定额外伤害")
	source.form_transition_timer = 0.0
	source.cyclic_form.advance(source, 80.0)
	_expect(source.cyclic_form.try_switch(source) and source.form_index == 0 and source.splash_radius == 0.0, "换回远程保持单体普攻")
	effects = {}
	source.cyclic_form.consume(source, effects)
	source.form_transition_timer = 0.0
	source.cyclic_form.advance(source, 8.0)
	source.cyclic_form.try_switch(source)
	before = target.hp
	source.battle_context.damage_batch().resolve_attack_hit(0, source.position, target, 65, 0.0, 0.0, source, source.position, 0, effects)
	_expect(before-target.hp == 105, "旧远程出手固定65+40，不受后续换形影响")
	source.form_transition_timer = 0.0
	source.prepare_attack_burst(3, 3.0, 4.0)
	_expect(source.burst_attacks_left == 3 and source._effective_attack_speed_multiplier() == 3.0, "主动准备3次3倍攻速")
	source.freeze(0.2)
	_expect(source.burst_attacks_left == 3, "控制未出手不消费次数")
	source.control.hard.clear_family(&"freeze")
	for strike in 3:
		source._target = target
		source.attack_timeline.cancel(true)
		source._attack(0.0)
		_expect(source.burst_attacks_left == 2-strike, "每次出手消费一次强化")
	_expect(source.burst_finishing, "末击后摇保留该次攻速")
	source.attack_timeline.cancel(true)
	source.sim_tick(0.05)
	_expect(not source.burst_finishing and source._effective_attack_speed_multiplier() == 1.0, "下一次起手恢复基础攻速")
	# 两种W在释放时固化；共用技能不被运行态改写。
	var definition: Dictionary = CardDB.active_skills_for("jayce")[0]
	var effect_system = main._active_skill_effect_system
	source._apply_form(0, false)
	var ranged_skill: Dictionary = effect_system.prepare_cast(source, definition)
	_expect(ranged_skill.kind == "attack_burst" and definition.kind == "attack_burst", "炮形态准备连射且不改共享定义")
	source.prepare_attack_burst(3, 3.0, 4.0)
	source._apply_form(1, false)
	_expect(source.burst_attacks_left == 3 and source._effective_attack_speed_multiplier() == 3.0, "炮W剩余次数跨形态保留")
	var melee_skill: Dictionary = effect_system.prepare_cast(source, definition)
	_expect(melee_skill.kind == "continuous_area" and ranged_skill.kind == "attack_burst", "锤W生成独立领域副本，不改已准备连射")
	source.position = Vector2(300,1000)
	target.position = source.position + Vector2(95.0 + target.body_radius - 0.5, 0)
	neighbour.position = source.position + Vector2(95.0 + neighbour.body_radius + 0.5, 0)
	target.hp = 2000
	neighbour.hp = 2000
	_expect(melee_skill.radius == 95.0, "电场权威半径95，对齐主提示圈")
	main._skill_presentation.frontal_effects.clear()
	effect_system.activate_continuous_area(source, melee_skill)
	for tick in 9: effect_system.tick_effects(0.05)
	_expect(target.hp == 2000, "电场首个0.5秒前不提前扣血")
	effect_system.tick_effects(0.05)
	_expect(target.hp == 1990 and neighbour.hp == 2000, "领域首跳10伤害，范围外不受伤")
	var field_hits: Array = main._skill_presentation.frontal_effects.filter(func(fx): return fx.get("shape", "") == "jayce_field_hit")
	_expect(field_hits.size() == 1 and field_hits[0].target_instance_id == target.get_instance_id(), "仅主圈范围内真实命中发布原版电场受击")
	source._apply_form(0, false)
	_expect(source.active_buff_clock_visual().y == 4.0 and source.burst_attacks_left == 3, "换回炮形态保留电场时钟与连射次数")
	for tick in 70: effect_system.tick_effects(0.05)
	_expect(target.hp == 1920 and effect_system.continuous_area_effects.is_empty(), "换形后完整8跳80伤害且准时结束")
	main._skill_presentation.frontal_effects.clear()
	target.control.hard.apply(&"stasis", &"field-test", 1.0, {})
	effect_system.activate_continuous_area(source, melee_skill)
	effect_system.tick_effects(0.5)
	_expect(target.hp == 1920 and main._skill_presentation.frontal_effects.is_empty(), "凝滞阻止电场伤害和受击特效")
	target.control.hard.clear_family(&"stasis")
	source.hp = 0
	effect_system.tick_effects(0.5)
	_expect(effect_system.continuous_area_effects.is_empty() and target.hp == 1920, "死亡移除随身电场，不追加伤害")
	source.hp = 650
	var malformed := CardDB.get_card("jayce").duplicate(true)
	malformed.active_skills = [definition.duplicate(true)]
	malformed.active_skills[0].form_kinds = ["attack_burst", "unknown"]
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all({"jayce": malformed}, false).is_empty(), "未知形态技能类型被拒绝")
	source._apply_form(0, false)
	source.cyclic_form.first_attack = true
	source._target = target
	source._attack_visual_pending = true
	source._try_start_attack_visual(0.0)
	_expect(source.is_attack_visual_first_strike() and source.is_empowered_attack_ready_visual(), "换形首击在起手发布同步标记与待发状态")
	source._apply_form(1, false)
	source.cyclic_form.first_attack = true
	var first_effects := {}
	source.cyclic_form.consume(source, first_effects)
	target.control.hard.apply(&"stasis", &"test", 1.0, {})
	neighbour.position = target.position + Vector2(20,0)
	var hit_events: Array = []
	var listener := func(presentation, _point, first): hit_events.append([presentation, first])
	main._combat.attack_hit.connect(listener)
	var neighbour_before := neighbour.hp
	main._combat.resolve_attack_hit(0, source.position, target, 80, source.splash_radius, 0, source, source.position, 1, first_effects)
	main._combat.attack_hit.disconnect(listener)
	_expect(neighbour_before == neighbour.hp, "主目标不可受击时邻居也不受单体普攻伤害")
	_expect(hit_events.is_empty(), "主目标未命中不借邻居伤害播放首击特效与声音")
	target.control.hard.clear_family(&"stasis")
	for invalid_icons in [["res://assets/skills/jayce_w.png"], [12, 13], ["res://" + "missing.png", "res://" + "missing.png"]]:
		var bad := CardDB.get_card("jayce").duplicate(true)
		bad.active_skills[0].form_icon_paths = invalid_icons
		_expect(not preload("res://scripts/data/card_validator.gd").validate_all({"jayce": bad}, false).is_empty(), "拒绝错误形态图标配置")
	source._apply_form(0, false)
	source.cyclic_form.first_attack = true
	source.form_transition_timer = 0.0
	source.attack_timeline.cancel(true)
	source.cyclic_form.advance(source, 8.0)
	_expect(source.cyclic_form.try_switch(source), "未使用炮首击时允许换为锤形态")
	var replaced := {}
	source.cyclic_form.consume(source, replaced)
	_expect(replaced.primary_bonus_damage == 0.0 and replaced.primary_bonus_health_ratio == 0.08, "未用炮首击被锤首击替换，不叠加40伤害")
	var consumed := {}
	source.cyclic_form.consume(source, consumed)
	_expect(consumed.is_empty(), "换形后只保留一次首击，不储存旧形态次数")
	source.hp = 0
	source.cyclic_form.advance(source, 8.0)
	_expect(not source.cyclic_form.try_switch(source), "死亡不能换形")

	var walker := _spawn_ready_unit("jayce", 0, Vector2(80, 1100))
	var far_target := _spawn_ready_unit("garen", 1, Vector2(80, 780))
	far_target.can_attack = false
	far_target.root(20.0)
	for tick in 3: main._sim_step(0.05)
	for form in [1,0]:
		walker.cyclic_form.elapsed = 8.0
		walker.attack_timeline.cancel(true)
		walker.form_transition_timer = 0.0
		_expect(walker.cyclic_form.try_switch(walker), "移动中允许切换形态")
		_expect((walker.action_permissions() & ControlState.MOVE) != 0, "换形不锁移动权限")
		var travelled := 0.0
		for tick in 5:
			var previous := walker.position
			main._sim_step(0.05)
			travelled += walker.position.distance_to(previous)
		_expect(travelled > 10.0, "两种方向换形窗口内持续移动")
	var layer := preload("res://assets/units/jayce/weapon_layer.gd").new()
	walker._apply_form(1, false)
	walker.play_visual_action(&"transform", 0.3)
	_expect(is_equal_approx(layer.hammer_weight(walker), 1.0), "炮转锤立即应用完整Hammer姿态")
	walker._visual_action_time_left = 0.15
	_expect(is_equal_approx(layer.hammer_weight(walker), 1.0), "特效时钟不改变武器形态权重")
	walker._apply_form(0, false)
	walker.play_visual_action(&"transform", 0.3)
	_expect(is_zero_approx(layer.hammer_weight(walker)), "锤转炮立即归还Default姿态")
	walker._visual_action_time_left = 0.0
	_expect(is_zero_approx(layer.hammer_weight(walker)), "锤转炮结束归还Default层")
	layer.free()

	walker.form_transition_timer = 0.0
	walker._visual_action_time_left = 0.0
	walker._move_intent = Vector2.UP
	walker._attacking = false
	var view := _view_for(walker)
	_expect(view != null, "换形实模型代理已接入")
	if view != null:
		view._sync_visual(true, 0.0)
		var model := view._model_root
		var player := view._animation_player
		player.seek(player.current_animation_length * 0.4, true)
		walker.toggle_weapon_form()
		_expect(view._model_root == model and view._animation_player == player, "换形复用模型与播放器，不重建腿部动画")
		_expect(absf(player.current_animation_position / player.current_animation_length - 0.4) < 0.001, "换形保留移动步态相位")
		view._sync_visual(false, 0.0)
		_expect(not view._playing_visual_action and player.current_animation == "Run", "原版Passive武器层不抢占移动播放器")
		var mask: Dictionary = model._weapon_layer.weights
		_expect(mask.size() == 32 and mask.has("Weapon_DL_1") and not mask.has("Pelvis") and not mask.has("L_Thigh"), "源97骨骼Hammer遮罩仅包含32个武器挂点")

		var anchor_ref: WeakRef = walker.get_meta("projectile_model_anchor")
		var chest: Variant = preload("res://scripts/presentation/projectile_model_anchor.gd").body_position(walker)
		_expect(chest != null and chest.distance_to(anchor_ref.get_ref().global_position) > 0.1, "目标胸部命中位置与杰斯炮口独立")

		walker._apply_form(0, false)
		walker.cyclic_form.first_attack = true
		walker.prepare_attack_burst(3, 3.0, 4.0)
		model.advance_ambient_visual(0.05)
		model._after_skeleton()
		var mounts := {"ready_r": "BUFFBONE_CSTM_WEAPON_1", "ready_r@gap1": "BUFFBONE_CSTM_WEAPON_GAP_1", "ready_r@gap2": "BUFFBONE_CSTM_WEAPON_GAP_2", "w_ready2": "BUFFBONE_CSTM_WEAPON_GAP_1"}
		for key in mounts:
			var effect: Node3D = model._effects[key]
			var bone: int = model._skeleton.find_bone(mounts[key])
			var expected: Vector3 = model._skeleton.to_global(model._skeleton.get_bone_global_pose(bone).origin)
			_expect(effect.global_position.distance_to(expected) < 0.0001, "原版脚本挂点随骨骼更新：" + key)
			var expected_scale := 0.0095
			_expect(absf(effect.global_basis.get_scale().x - expected_scale) < 0.000001, "粒子与模型统一缩放：" + key)
		walker._apply_form(1, false)
		model.advance_ambient_visual(0.05)
		model._after_skeleton()
		_expect(not model._effects["ready_r"].visible and not model._effects["ready_r@gap1"].visible and not model._effects["ready_r@gap2"].visible, "换锤撤下全部三处炮首击待发光")
		_expect(model._effects["w_ready2"].visible and walker.burst_attacks_left == 3, "远程W跨形态保留剩余次数与武器挂接")
		_expect(not model._effects.has("muzzle") and not model._effects.has("crit"), "不再创建误用的普通命中武器粒子")

		# Reflection compensation must survive seek_motion, not just _attach.
		for mount in [["ready_m", "BUFFBONE_GLB_WEAPON_1"], ["ready_r", "BUFFBONE_CSTM_WEAPON_1"], ["stance_m", "BUFFBONE_GLB_WEAPON_1"], ["stance_r", "BUFFBONE_CSTM_WEAPON_1"], ["stance_hammer", "BUFFBONE_CSTM_WEAPON_1"]]:
			var fx: Node3D = model._effect(mount[0])
			model._attach(fx, mount[1])
			fx.seek_motion(0.15, fx.global_position, fx.global_basis.orthonormalized())
			var pose: Transform3D = model._skeleton.global_transform * model._skeleton.get_bone_global_pose(model._skeleton.find_bone(mount[1]))
			_expect(fx.global_basis.y.normalized().dot(pose.basis.y.normalized()) > 0.999 and fx.global_basis.z.normalized().dot(pose.basis.z.normalized()) > 0.999, "武器光采样后保持原骨骼Y/Z方向：" + mount[0])
			_expect(fx.global_position.distance_to(pose.origin) < 0.00001 and absf(fx.global_basis.get_scale().x - 0.0095) < 0.000001, "方向修正不改挂点位置或统一大小：" + mount[0])

		walker._apply_form(0, false)
		walker.cyclic_form.first_attack = false
		walker._attack_visual_first_strike = false
		walker.prepare_attack_burst(3, 3.0, 4.0)
		walker._attack_visual_serial += 1
		model.advance_ambient_visual(0.05)
		model._after_skeleton()
		var center: Vector3 = Vector3.ZERO
		for side in 2:
			center += model._skeleton.to_global(model._skeleton.get_bone_global_pose(model._skeleton.find_bone("BUFFBONE_CSTM_WEAPON_GAP_%d" % (side + 1))).origin) * 0.5
		for side in 2:
			var jets = model._effects["w_ready2" if side == 0 else "w_ready2@gap2"]
			var bone: int = model._skeleton.find_bone("BUFFBONE_CSTM_WEAPON_GAP_%d" % (side + 1))
			var pose: Transform3D = model._skeleton.global_transform * model._skeleton.get_bone_global_pose(bone)
			_expect(jets.global_position.distance_to(pose.origin) < 0.0001, "W只挂锤头两侧原生GAP骨骼")
			_expect(jets.global_basis.y.normalized().dot((pose.origin - center).normalized()) > 0.99, "喷气从锤头中心朝两侧外喷")
			_expect(jets.global_basis.determinant() > 0.0, "抵消粒子X镜像，避免负缩放二次翻转")
			_expect(absf(jets.global_basis.get_scale().x - 0.0095) < 0.000001, "原始Ready2与模型及其他特效统一缩放")
			_expect(jets.has_live_particles(), "两侧喷气实际发射")
			_expect(Vector4(jets._data.emitters[0].birthColor.constant[0], jets._data.emitters[0].birthColor.constant[1], jets._data.emitters[0].birthColor.constant[2], jets._data.emitters[0].birthColor.constant[3]).is_equal_approx(Vector4(0.38431373, 0.5176471, 1.0, 1.0)), "Ready2保留源出生色，不改白")
			_expect(jets._data.emitters[0].scale0["keys"][-1]["values"] == [3.0, 3.0, 3.0], "保留已确认Ready2原始尺寸曲线")
		for key in model._effects:
			_expect(not String(key).begins_with("w_exhaust") and not String(key).begins_with("w_ready@"), "W不再发射锤柄末端粒子")
		var light = model._effects["ready_r"]
		_expect(light._pools[0][0].material_override.get_shader_parameter("push_pull") == float(light._data.emitters[0].depthPushPull), "仅保留原始深度偏移")
		for form in [1, 0]:
			walker._apply_form(form, false)
			walker.play_visual_action(&"transform", 0.3)
			model.advance_ambient_visual(0.0)
			model._after_skeleton()
			var key := "swap_m" if form == 1 else "swap_r"
			var swap = model._effects[key]
			_expect(swap._data.emitters.size() == (6 if form == 1 else 8), "整身变形包含完整原始层")
			_expect(not swap._attached.is_empty(), "avatar材质层实际挂到蒙皮网格")
			_expect(swap.global_position.distance_to(model.global_position) < 0.0001, "变形整身闪光挂自身根部")
			walker._visual_action_time_left = 0.05
			model.advance_ambient_visual(0.25)
			model._after_skeleton()
			_expect(swap.has_live_particles(), "变形时整身粒子实际存活")
		model.begin_visual_death(0.5)
		for key in ["swap_m", "swap_r"]:
			_expect(not model._effects[key].visible, "死亡关闭整身变形")
			for entry in model._effects[key]._attached:
				_expect(not entry.material.get_shader_parameter("attached_enabled"), "死亡关闭角色闪光材质")

		var restored_meshes: Array = model._base_materials.duplicate()
		model.reset_pool_visual()
		_expect(model._effects.is_empty() and model._base_materials.is_empty(), "模型回收清除粒子与材质引用")
		for saved in restored_meshes:
			_expect(saved.mesh.get_surface_override_material(saved.surface) == saved.material, "模型复用恢复原材质，不叠加旧闪光")

func _check_burst_expiry_and_audio() -> void:
	var unit := _spawn_ready_unit("jayce", 0, Vector2(300, 1000))
	var stats := CardDB.get_card("jayce")
	var audio := GameAudioManager.new()
	_main.add_child(audio)
	audio.set_process(false)
	audio.attach_unit(unit, stats)
	var cues: Array[StringName] = []
	audio.cue_played.connect(func(id: String, cue: StringName, _position: Vector2):
		if id == "jayce": cues.append(cue))
	unit.prepare_attack_burst(3, 3.0, float(stats.active_skills[0].duration))
	audio._process(0.0)
	var key := audio._sustain_key(unit.get_instance_id(), &"buff")
	var sustained: AudioStreamPlayer2D = audio._sustain_players.get(key)
	_expect(sustained != null and sustained.playing and cues.count(&"active_buff:sustain") == 1 and not cues.has(&"active_buff:start"), "远程W开启原音轨由增益持续层持有，不重复播放一次性开启声")
	var expiry := unit.burst_expiry_tick
	unit._apply_form(1, false)
	audio._process(0.0)
	_expect(audio._sustain_players.get(key) == sustained and unit.burst_expiry_tick == expiry, "换形保留W原音轨和原截止Tick，不重播不续时")
	unit.freeze(5.0)
	for tick in 79: unit._tick_active_statuses(0.05)
	_expect(unit.burst_attacks_left == 3 and unit.get_active_buff_active_visual(), "控制与换形期间继续计时，3.95秒仍保留未用次数")
	unit.attack_timeline.windup = 0.2
	unit._tick_active_statuses(0.05)
	audio._process(0.0)
	_expect(unit.burst_attacks_left == 0 and not unit.burst_finishing and not unit.get_active_buff_active_visual() and unit._effective_attack_speed_multiplier() == 1.0, "第80Tick到期撤销全部剩余连射与攻速")
	_expect(is_equal_approx(unit.attack_timeline.windup, 0.6), "到期按速率比例重算在途前摇，保留阶段进度")
	_expect(not audio._sustain_players.has(key) and not sustained.playing, "W到期停止原开启音轨")
	unit.prepare_attack_burst(3, 3.0, 4.0)
	for tick in 20: unit._tick_active_statuses(0.05)
	unit.prepare_attack_burst(3, 3.0, 4.0)
	_expect(unit.burst_expiry_tick == unit.buffs.tick_index + 80 and unit.burst_attacks_left == 3, "重放刷新4秒与3次，不累加")
	audio._process(0.0)
	unit.burst_attacks_left = 0
	unit.burst_finishing = true
	unit._end_attack_burst()
	audio._process(0.0)
	_expect(not audio._sustain_players.has(key) and unit.burst_expiry_tick == -1, "次数提前耗尽时停止音轨并清除截止Tick")
	unit.prepare_attack_burst(3, 3.0, 4.0)
	unit.burst_attacks_left = 0
	unit.burst_finishing = true
	for tick in 80: unit._tick_active_statuses(0.05)
	_expect(not unit.burst_finishing and unit._effective_attack_speed_multiplier() == 1.0, "末次后摇也不能将攻速延长到4秒以后")
	var invalid := stats.duplicate(true)
	invalid.active_skills[0].erase("duration")
	_expect(not preload("res://scripts/data/card_validator.gd").validate_all({"jayce": invalid}, false).is_empty(), "连续攻击配置缺失持续时间时拒绝")
	audio.free()
	unit.free()
