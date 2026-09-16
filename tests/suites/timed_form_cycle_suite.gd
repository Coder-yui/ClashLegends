extends RefCounted
## 按真实出手、阶段结算与形态入口验证循环；动画不参与数值计算。
var _h: Object
var _main: Node2D
var _units: Array[Unit] = []

func _unit(id: String, team: int) -> Unit:
	var unit := Unit.new()
	unit.setup(team, CardDB.get_card(id), id)
	unit.card_id = id
	unit.position = Vector2(300 + _units.size() * 15, 800)
	_main.add_child(unit)
	_units.append(unit)
	return unit

func _strike(source: Unit, target: Node2D) -> void:
	source._target = target
	source.attack_timeline.cancel(true)
	source._attack_visual_pending = true
	source._attack(0.0)

func run(harness: Object, main: Node2D) -> void:
	_h = harness
	_main = main
	var source := _unit("aatrox", 0)
	var target := _unit("garen", 1)
	source.hp = 100
	for index in 4:
		var before := target.hp
		_strike(source, target)
		_h._expect(before - target.hp == (193 if index == 3 else 88), "剑魔普通循环第%d段独立附伤" % (index + 1))
	_h._expect(source.hp == 158, "第四刀193点实际掉血按30%回血58")
	_h._expect(source.transform_to_mega(true) and source.hp == 458 and source.max_hp == 1350 and source.is_air and source.can_attack_air, "大灭增加等额当前生命并切换空中对地对空")
	for index in 3:
		target.hp = 1050
		var before := source.hp
		_strike(source, target)
		_h._expect(source.hp - before == (97 if index == 0 else 18), "强化第%d段按被动50%%/普通20%%吸血" % (index + 1))
	# 100%护盾不吸血；余血7只回4，无过量收益。
	target.add_shield(1000, 10)
	source.hp = 100
	_strike(source, target)
	_h._expect(source.hp == 100, "被动全盾吸收不回血")
	var victim := _unit("garen", 1)
	victim.hp = 7
	source._attack_swing_count = 0
	source.form_lifetime_left = 0.5
	var max_before_refresh := source.max_hp
	_main._combat.begin_batch(0, "timed_form_cycle")
	_strike(source, victim)
	_main._combat.commit_batch()
	_h._expect(source.hp == 104 and source.form_lifetime_left == 5.0 and source._attack_swing_count == 0, "阶段结算按实际7血回4并在击杀后刷新计时和下一次被动")
	_h._expect(source.max_hp == max_before_refresh, "击杀刷新不再增加最大生命")
	var fresh := _unit("garen", 1)
	_strike(source, fresh)
	_h._expect(fresh.hp == 857 and posmod(source._attack_visual_serial - 1, 3) == 0, "刷新后伤害和动画均从被动开始")
	# 提前取消的前摇不能消耗攻击段。
	source._attack_visual_pending = true
	source._try_start_attack_visual(0.0)
	var next_segment := posmod(source._attack_visual_serial - 1, 3)
	source._attack_visual_pending = true
	source._try_start_attack_visual(0.0)
	_h._expect(posmod(source._attack_visual_serial - 1, 3) == next_segment, "前摇取消重播仍对齐同一未出手段")
	var tower := Tower.new()
	tower.setup(1, CardDB.PRINCESS_TOWER_STATS, false)
	_main.add_child(tower)
	source._attack_swing_count = 0
	var tower_before := tower.hp
	_strike(source, tower)
	_h._expect(tower_before - tower.hp == 108, "塔和水晶类目标被动固定附加20")
	tower.free()
	source.hp = 1250
	source.form_transition_timer = 0.0
	source.form_lifetime_left = 0.05
	source.freeze(2.0)
	source.sim_tick(0.05)
	_h._expect(source.form_index == 0 and source.hp == 1050 and not source.is_air and not source.can_attack_air, "冻结不延长5秒形态，到期地面还原并截到基础上限")
	source.hp = 600
	source.transform_to_mega()
	source.transform_to_small()
	_h._expect(source.hp == 900, "结束保留基础上限以内的当前生命")
	source.transform_to_mega()
	source.position = Vector2(360, 640)
	source.transform_to_small()
	_h._expect(_main.is_ground_position_walkable(source.position, source.body_radius, source), "河道上空到期时回到合法地面位置")
	var replica := _unit("aatrox", 0)
	replica.hp = 100
	replica.sync_network_form(1, 1)
	_h._expect(replica.hp == 100 and replica.max_hp == 1350 and replica.is_air, "客户端形态快照更新属性但不自行发放增量治疗")
	for field in ["passive_first_hit", "attack_passive_multipliers", "attack_lifesteal_ratios", "form_lifetime", "form_refresh_on_kill", "form_lifetime_after_transition", "form_speed_boost_duration", "form_speed_boost_multiplier"]:
		for bad in [null, "bad", {}]:
			var invalid := CardDB.get_card("aatrox").duplicate(true)
			invalid[field] = bad
			_h._expect(not CardDB.VALIDATOR.validate_all({"aatrox": invalid}).is_empty(), "新字段类型校验：" + field)
	var timed := _unit("aatrox", 0)
	timed._deploy_timer = 0.0
	timed.transform_to_mega(true)
	_h._expect(is_equal_approx(timed.active_speed_multiplier, 1.3), "开启大灭立即获得30%移速")
	for i in 20: timed.sim_tick(0.05)
	_h._expect(is_equal_approx(timed.form_lifetime_left, 5.0), "开启动画期间不消耗5秒大灭时间")
	_h._expect(is_equal_approx(timed.active_speed_multiplier, 1.0), "开启加速1秒后还原")
	timed.sim_tick(0.05)
	_h._expect(is_equal_approx(timed.form_lifetime_left, 4.95), "动画结束下一模拟步开始5秒倒计时")
	timed.on_enemy_killed(target)
	_h._expect(is_equal_approx(timed.form_lifetime_left, 5.0) and is_equal_approx(timed.active_speed_multiplier, 1.3), "击杀同时刷新5秒持续及30%移速")
	_check_passive_windup()
	_check_animation_revision()
	_check_audio_revision()
	for unit in _units:
		if is_instance_valid(unit): unit.free()

func _check_audio_revision() -> void:
	var audio: GameAudioManager = _main._audio_manager
	var cues: Array[StringName] = []
	var listener := func(id: String, cue: StringName, _pos: Vector2):
		if id == "aatrox": cues.append(cue)
	audio.cue_played.connect(listener)
	for form in [0, 1]:
		var config := PresentationConfig.audio_for(CardDB.get_card("aatrox"), 0, form)
		for field in ["attack_swing", "attack_hit_by_segment"]:
			_h._expect(config[field].all(func(pool): return pool.size() > 0 and pool.size() <= 5), "剑魔每个cast/hit池最多5种")
		_h._expect(config.events["death:voice"].pool.size() == 3 and config.events["death:voice"].bus == "Voice", "两形态死亡语音均为3种随机变体")
		_h._expect(config.events["deploy:voice"].pool.size() == 3 and config.events["deploy:voice"].bus == "Voice", "两形态部署使用三句指定语音随机池")
		var unit := _unit("aatrox", 0)
		var before_deploy := cues.count(&"deploy:voice")
		audio.attach_unit(unit, CardDB.get_card("aatrox"))
		_h._expect(cues.count(&"deploy:voice") == before_deploy + 1, "真实部署派发一条语音")
		audio.attach_unit(unit, CardDB.get_card("aatrox"))
		_h._expect(cues.count(&"deploy:voice") == before_deploy + 1, "重绑不重复部署语音")
		if form == 1:
			unit.transform_to_mega(true)
			audio._process(0.0)
			_h._expect(cues.count(&"transform_active:start") == 1, "大灭首次启动音只触发一次")
			var victim := _unit("garen", 1)
			victim.hp = 0
			unit.form_lifetime_left = 1.0
			unit.on_enemy_killed(victim)
			_h._expect(cues.count(&"form:refresh") == 1 and unit.form_lifetime_left == 5.0, "技能真实刷新再次派发音频")
			var r_pool: Array = config.events["form:refresh"].pool
			_h._expect(r_pool == config.events["transform_active:start"].pool and is_equal_approx(load(r_pool[0]).get_length(), 2.0), "开启与刷新使用同一2秒音轨")
		var before_sfx := cues.count(&"death")
		var before_voice := cues.count(&"death:voice")
		unit.take_damage(99999)
		_h._expect(cues.count(&"death") == before_sfx + 1 and cues.count(&"death:voice") == before_voice + 1, "死亡同时播放SFX和一条语音")
		audio._on_unit_death(unit.get_instance_id())
		_h._expect(cues.count(&"death:voice") == before_voice + 1, "重复死亡通知不重播语音")
	audio.cue_played.disconnect(listener)

func _check_animation_revision() -> void:
	var unit := _unit("aatrox", 0)
	unit._deploy_timer = 0.0
	_h._expect(not unit.is_empowered_attack_ready_visual(), "首刀不是被动，不使用持剑移动")
	unit._attack_swing_count = 3
	_h._expect(unit.is_empowered_attack_ready_visual(), "第三刀提交后下一击被动就绪")
	var payload: Array = _main._snapshot_system._unit_snapshot_payload(0, unit)
	_h._expect(payload[NetworkSnapshotSystem.U_EMPOWERED_READY] == 1, "权威快照发送循环被动就绪，不只发送技能强化标记")
	unit._attack_visual_pending = true
	unit._try_start_attack_visual(0.0)
	unit.attack_timeline.cancel(true)
	_h._expect(unit.is_empowered_attack_ready_visual(), "被动前摇取消仍保留持剑姿态")
	_main._battle_presentation.attach_unit(unit, CardDB.get_card("aatrox"))
	for child in _main._battle_presentation._world_root.get_children():
		if not child is UnitModel3D or child._source != unit:
			continue
		var view := child as UnitModel3D
		view._playing_deploy_sequence = false
		var saved_serial := unit._attack_visual_serial
		unit._attack_visual_serial = 0
		view._animation_player.play("Respawn")
		view._transition_to_basic_state(2, -1.0, &"deploy")
		_h._expect(view._animation_player.current_animation == "Aatrox_sheath_run01_anm", "剑魔首次攻击前保持背剑移动")
		unit.form_change_serial = 2
		view._transition_to_basic_state(2)
		_h._expect(view._animation_player.current_animation == "Passive_Run", "开技能后即使未攻击也不再背剑跑")
		unit.form_change_serial = 0
		unit.net_form_change_serial = 2
		view._transition_to_basic_state(2)
		_h._expect(view._animation_player.current_animation == "Passive_Run", "晚加入快照保留已变形记录，不恢复背剑跑")
		unit.net_form_change_serial = 0
		unit._attack_visual_serial = saved_serial

		view._transition_to_basic_state(2)
		_h._expect(view._animation_player.current_animation == "Passive_Run", "被动就绪移动使用 Passive_Run")
		view._play_state(1)
		_h._expect(view._animation_player.current_animation == "Passive_Idle", "被动就绪待机使用 Passive_Idle")
		unit._attacking = true
		view._play_attack(4)
		unit._attack_swing_count = 4
		unit._attacking = false
		view._transition_to_basic_state(2, -1.0, &"attack")
		_h._expect(view._animation_player.current_animation == "Passive_Attack_out", "被动出手转移动使用源表专用退出动作")
		view._on_animation_finished(&"Passive_Attack_out")
		_h._expect(view._animation_player.current_animation == "Run_Base", "退出动作完成后恢复普通跑步")
		var wrapper: Node3D = view._model_root
		_h._expect(wrapper._normal_mesh.get_surface_count() == 3 and wrapper._wing_mesh.get_surface_count() == 3, "普通保留三部件，收翼前段用翅膀替换肩甲")
		wrapper._update_surfaces(&"ULT_out", 0.2)
		_h._expect(wrapper._mesh.mesh == wrapper._wing_mesh, "大灭结束前11帧仍保留翅膀")
		wrapper._update_surfaces(&"ULT_out", 0.4)
		_h._expect(wrapper._mesh.mesh == wrapper._normal_mesh, "大灭结束第11帧后恢复普通部件")
		_h._expect(CardDB.get_card("aatrox").transformed_stats.visual_animations.visual_actions.transform_active.clip_ranges == [[0.0, 1.0]], "Spell4只取源动作前1秒")
		view._animation_player.play("Attack2")
		view._transition_to_basic_state(2, -1.0, &"attack")
		_h._expect(view._animation_player.current_animation == "Attack_INTO_Run" and is_equal_approx(view._last_clip_blend_time, 0.03), "二刀转跑使用原版动作和0.03入口混合")
		view._on_animation_finished(&"Attack_INTO_Run")
		_h._expect(view._animation_player.current_animation == "Run_Base" and is_equal_approx(view._last_clip_blend_time, 0.1), "转跑结束0.1秒接普通跑")
		unit._attack_swing_count = 3
		view._animation_player.play("Attack3")
		view._transition_to_basic_state(2, -1.0, &"attack")
		_h._expect(view._animation_player.current_animation == "Passive_Run" and is_equal_approx(view._last_clip_blend_time, 0.15) and not view._move_sequence_active, "第三刀直接0.15秒混到被动移动，不经过转跑")
		_h._expect(is_equal_approx(view._transition_blend(&"action_out"), 0.1), "部署退出等通用动作混合0.1秒")
		view._animation_player.play("Run_Base")
		_h._expect(view._resolve_clip_blend(&"Spell4", &"action_in") == 0.0, "原表普通跑到Spell4零混合")
		view._animation_player.play("Spell4")
		_h._expect(is_equal_approx(view._resolve_clip_blend(&"Run_Ult", &"action_out"), 0.25), "原表Spell4到大灭跑0.25秒")
		var same_model := view._model_root
		var same_player := view._animation_player
		var ground_y: float = view._model_root.position.y
		unit.transform_to_mega(true)
		_h._expect(view._model_root == same_model and view._animation_player == same_player, "开启大灭复用模型骨骼和播放器")
		view._animation_player.play("Run_Base")
		view._play_visual_action(&"transform_active")
		view._seek_visual_action(0.1)
		_h._expect(view._last_clip_blend_time == 0.0, "技能对齐进度不重播同片段、不覆盖原表入口混合")
		_h._expect(unit.is_air and not unit.is_active_skill_movement_locked() and unit.is_form_transitioning(), "大灭开始立即成为空军，变形窗口只禁攻击可移动")
		_h._expect(is_equal_approx(view._model_root.position.y, ground_y), "开启换模型时继承当前地面高度")
		_h._expect(is_equal_approx(view._height_to + view._visual_bounds_bottom_y(), CardDB.AIR_VISUAL_ELEVATION), "大灭沿用通用空军底部对齐，不扣原生浮空")
		var attack_clip := view._animation_player.get_animation("Passive_Attack_Ult")
		var lift_track := attack_clip.find_track(NodePath("."), Animation.TYPE_POSITION_3D)
		_h._expect(lift_track >= 0 and is_equal_approx(attack_clip.position_track_interpolate(lift_track, 0.0).y, 0.998591), "大灭地面版被动补回浮空量")
		view._tick_form_elevation(0.0)
		view._tick_form_elevation(0.5)
		var middle_y: float = view._model_root.position.y
		_h._expect(is_equal_approx(middle_y, lerpf(ground_y, view._height_to, 0.5)), "开启动画中点高度线性升至一半")
		unit.transform_to_small()
		_h._expect(view._model_root == same_model and view._animation_player == same_player, "收翼复用同一模型与播放器")
		_h._expect(not unit.is_air and not unit.is_active_skill_movement_locked() and unit.is_form_transitioning(), "结束开始立即成为地面，变形窗口只禁攻击可移动")
		_h._expect(is_equal_approx(view._model_root.position.y, middle_y), "中途结束从实际显示高度下降，不跳到完整空中高度")
		view._tick_form_elevation(0.0)
		view._tick_form_elevation(unit.revert_duration / 2.0)
		_h._expect(is_equal_approx(view._model_root.position.y, lerpf(middle_y, view._height_to, 0.5)), "结束动画中点下降一半")
		view._tick_form_elevation(unit.revert_duration / 2.0)
		_h._expect(not view._height_transition and is_equal_approx(view._model_root.position.y, view._height_to), "结束动画末帧抵达地面高度")
		_h._expect(absf(unit.revert_duration - view._animation_player.get_animation("ULT_out").length) < 0.005, "收翼窗口保留源动作完整原长")
		_h._expect(unit.max_hp == 1050 and not unit.can_attack_air and (unit.get_action_permissions_visual() & 2) == 0, "收翼开始恢复生命上限和对地属性，全程禁攻击")
		for i in 14: unit.sim_tick(0.05)
		_h._expect((unit.get_action_permissions_visual() & 2) == 0, "收翼0.7秒仍禁止攻击")
		unit.sim_tick(0.05)
		_h._expect((unit.get_action_permissions_visual() & 2) != 0, "完整收翼窗口结束后恢复攻击")
		view.free()
		break

func _check_passive_windup() -> void:
	for form in 2:
		for rate in [0.5, 1.0, 2.0]:
			var source := _unit("aatrox", 0)
			var target := _unit("garen", 1)
			source.position = Vector2(300, 420)
			target.position = Vector2(300, 370)
			target.hp = 100000
			target.max_hp = 100000
			source._deploy_timer = 0.0
			if form == 1:
				source.transform_to_mega()
				source.form_transition_timer = 0.0
				source.form_lifetime_left = 100.0
			source.active_buff_timer = 100.0
			if rate < 1.0:
				source.apply_attack_speed_slow(100.0, rate)
			else:
				source.active_attack_speed_multiplier = rate
			source._target = target
			var previous_hp := target.hp
			var previous_hit := -1.0
			var hits := 0
			for tick in 500:
				source.sim_tick(0.05)
				if target.hp >= previous_hp: continue
				var segment := hits % (4 if form == 0 else 3)
				var expected := 0.4 if segment == (3 if form == 0 else 0) else 0.25
				_h._expect(is_equal_approx(source.get_attack_first_hit_time_visual(), expected), "命中后表现仍读取本刀前摇，不提前读取下一刀")
				_h._expect(absf(source.get_attack_elapsed_visual() - expected) <= 0.051 * rate, "普通0.25/被动0.4秒前摇随攻速缩放且在伤害提交时对齐")
				if previous_hit >= 0.0:
					_h._expect(absf(tick * 0.05 - previous_hit - 1.1 / rate) <= 0.051, "切换普通/被动仍保持1.1秒基础命中间隔")
				previous_hit = tick * 0.05
				previous_hp = target.hp
				hits += 1
				if hits == 6: break
			_h._expect(hits == 6, "双形态和攻速场景完成连续六次攻击")
			if form == 1:
				source.on_enemy_killed(target)
				_h._expect(is_equal_approx(source._next_attack_first_hit_time(), 0.4), "击杀刷新下一刀使用被动0.4秒前摇")
				_h._expect(is_equal_approx(source.attack_timeline.recovery, maxf(source.attack_timeline.cooldown - 0.4 / rate, 0.0)), "击杀刷新重算待攻窗口，不延长下一命中冷却")
			source.free()
			target.free()
	for bad in [-0.1, 0.0, 1.1, INF, NAN]:
		var invalid := CardDB.get_card("aatrox").duplicate(true)
		invalid.passive_first_hit = bad
		_h._expect(not CardDB.VALIDATOR.validate_all({"aatrox": invalid}).is_empty(), "拒绝非法被动前摇")
