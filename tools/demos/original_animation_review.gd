extends SceneTree
## 原表调整的表现 fixture：正式 play_card 生成、正式 UnitModel3D 消费，固定步长且不运行战斗。
## Godot --path . --script tools/demos/original_animation_review.gd -- --cards=ashe,teemo --teams=0,1
## --forms=base,mega（仅纳尔） --all-exits（每个攻击/技能都检查两个出口）
## --transition-frames（每个出口 0/33/67/100/180/350 ms 六帧） --validate-only（无渲染）
## --transition-horizon=1.0（可选补 0.4/0.7/1.0 秒，检查较长收势和混合）
const OUTPUT := "/tmp/clash-original-animation-review"
const STEP := 1.0 / 60.0
var main: Node2D
var unit: Unit
var view: UnitModel3D
var focus: SubViewport
var camera: Camera3D
var label: Label
var trace: FileAccess
var folder := ""
var phase := ""
var case_name := ""
var elapsed := 0.0
var capture_index := 0
var failures := 0
var validate_only := false
var all_exits := false
var transition_frames := false
var transition_sample_offset := -1.0
var transition_horizon := 0.35
var initial_camera_size := 5.5
var focus_offset := Vector3.UP

func _initialize() -> void:
	_run.call_deferred()

func _option(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(name + "="):
			return arg.substr(name.length() + 1)
	return fallback

func _run() -> void:
	validate_only = "--validate-only" in OS.get_cmdline_user_args()
	all_exits = "--all-exits" in OS.get_cmdline_user_args()
	transition_frames = "--transition-frames" in OS.get_cmdline_user_args()
	transition_horizon = clampf(float(_option("--transition-horizon", "0.35")), 0.35, 3.0)
	var cards: Array = []
	var requested := _option("--cards", "")
	for id in CardDB.all() if requested.is_empty() else requested.split(",", false):
		if requested.is_empty() and String(CardDB.get_card(id).get("type", "unit")) == "spell":
			continue
		if CardDB.has_card(id) and String(CardDB.get_card(id).get("type", "unit")) != "spell":
			cards.append(String(id))
		else:
			push_error("审查忽略未知卡或法术卡：" + String(id))
			failures += 1
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_art_dev()
	main.set_process(false)
	_setup_closeup()
	for id in cards:
		for team_string in _option("--teams", "0,1").split(",", false):
			var team := int(team_string)
			if team not in [0, 1]:
				failures += 1
				continue
			var forms := _option("--forms", "base,mega").split(",", false) if id == "gnar" else PackedStringArray(["base"])
			for form in forms:
				if form not in ["base", "mega"]:
					failures += 1
					continue
				await _review_card(id, team, form)
	_clear_units()
	main.queue_free()
	await process_frame
	await process_frame
	print("[原表动画审查] 完成，失败 ", failures, "；输出：", OUTPUT)
	quit(1 if failures > 0 else 0)

func _review_card(id: String, team: int, form: String) -> void:
	_clear_units()
	case_name = "%s_%s_%s" % [id, "blue" if team == 0 else "red", form]
	folder = OUTPUT.path_join("validation" if validate_only else "").path_join(case_name)
	DirAccess.make_dir_recursive_absolute(folder)
	# 同一组重跑不留下上次较多采样的旧截图，避免混入 contact sheet。
	for old_file in DirAccess.get_files_at(folder):
		if old_file.ends_with(".png") and old_file.left(2).is_valid_int():
			DirAccess.remove_absolute(folder.path_join(old_file))
	trace = FileAccess.open(folder.path_join("trace.jsonl"), FileAccess.WRITE)
	capture_index = 0
	elapsed = 0.0
	if not main.play_card(team, id, Vector2(360, 820), {"immediate": true, "validate_position": false}):
		_fail("play_card 生成失败")
		trace.close()
		return
	unit = main._latest_unit_for_card(id, team)
	if not is_instance_valid(unit):
		_fail("生成后未找到 Unit")
		trace.close()
		return
	if form == "mega":
		unit._apply_form(1, false) # 仅审查实例；正式 form_changed 更新模型，未改变共享定义。
	view = _view_for(unit)
	if view == null or view._animation_player == null:
		_fail("未找到正式 UnitModel3D/AnimationPlayer")
		trace.close()
		return
	unit.set_process(false)
	_pause_tree(view)
	_fit_camera()
	var animations: Dictionary = view._animation_names
	var deploy_left: float = unit._deploy_timer
	_advance(deploy_left * 0.5)
	await _capture("deploy_mid" if deploy_left > 0.0 else "spawn_idle")
	_advance(deploy_left * 0.5)
	await _capture_exit("deploy_exit_idle", 0.15)
	_set_behavior(false, true)
	_advance(0.22)
	await _capture("move_entry")
	_advance(1.5)
	_set_behavior(false, false)
	await _capture_exit("move_exit_idle")
	if animations.has("haste_move"):
		unit.active_speed_multiplier = 1.5
		_set_behavior(false, true)
		_advance(0.4)
		await _capture("haste_move_mid")
		_set_behavior(false, false)
		await _capture_exit("haste_move_exit_idle")
		unit.active_speed_multiplier = 1.0
	var attacks := _list(animations.get("attack", []))
	if String(animations.get("attack_loop", "")) != "":
		attacks = [animations.attack_loop]
	for index in attacks.size():
		_start_attack(index, attacks.size())
		await _capture_attack_seam("attack_%d" % (index + 1))
		_advance_attack_sample()
		await _capture("attack_%d_mid" % (index + 1))
		if all_exits or index == attacks.size() - 1:
			_set_behavior(false, false)
			await _capture_exit("attack_%d_exit_idle" % (index + 1))
			_start_attack(index, attacks.size())
			_advance_attack_sample()
			_set_behavior(false, true)
			await _capture_exit("attack_%d_exit_move" % (index + 1))
	if animations.has("attack_structure"):
		for target in get_nodes_in_group("combatants"):
			if target is Tower and target.team != team:
				unit._target = target
				break
		var structure_attacks := _list(animations.attack_structure)
		for index in structure_attacks.size():
			_start_attack(index, structure_attacks.size())
			_advance_attack_sample()
			await _capture("structure_attack_%d_mid" % (index + 1))
		unit._target = null
	if animations.has("empowered_attack"):
		_start_attack(0, maxi(attacks.size(), 1), true)
		await _capture_attack_seam("empowered")
		_advance_attack_sample()
		await _capture("empowered_mid")
		_set_behavior(false, true)
		await _capture_exit("empowered_exit_move")
		if all_exits:
			_start_attack(0, maxi(attacks.size(), 1), true)
			_advance_attack_sample()
			_set_behavior(false, false)
			await _capture_exit("empowered_exit_idle")
	var actions: Dictionary = animations.get("visual_actions", {})
	for action in actions:
		var descriptor: Dictionary = actions[action] if actions[action] is Dictionary else {}
		var duration := _action_duration(String(action), descriptor)
		_start_action(StringName(action), duration)
		_advance(duration * 0.5)
		await _capture("action_%s_mid" % action)
		# 主动作消费同一权威窗口，结束后请求 Move；不直接指定某个转场片段。
		_set_behavior(false, true)
		_advance(duration * 0.5)
		await _capture_exit("action_%s_exit_move" % action)
		if all_exits:
			_start_action(StringName(action), duration)
			_advance(duration)
			await _capture_exit("action_%s_exit_idle" % action)
	_set_behavior(false, false)
	_advance(0.2)
	# 只走正式死亡表现通知，避免凤凰替身等玩法额外生成模型干扰本组审查。
	unit.hp = 0.0
	unit.notify_visual_death()
	if String(animations.get("death", "")).is_empty():
		await _capture("death_no_clip")
		trace.close()
		print("[原表动画审查] ", case_name, "：", capture_index, " 张/记录（无死亡片段）")
		return
	var death_duration := float(animations.get("death_duration", 0.8))
	_advance(death_duration * 0.35)
	await _capture("death_mid")
	_advance(death_duration * 0.55)
	await _capture("death_end")
	if animations.has("death_followup_duration"):
		_advance(death_duration * 0.15 + float(animations.death_followup_duration) * 0.6)
		await _capture("death_followup")
	trace.close()
	print("[原表动画审查] ", case_name, "：", capture_index, " 张/记录")

func _start_attack(index: int, count: int, empowered: bool = false) -> void:
	# 状态与序号同次发布，避免 continuous 首次起手被误判为同目标重定向。
	unit._attacking = true
	unit._move_intent = Vector2.ZERO
	unit._attack_visual_serial += 1
	unit._attack_visual_serial += posmod(index - (unit._attack_visual_serial - 1), maxi(count, 1))
	unit._empowered_attack_visual_serial = unit._attack_visual_serial if empowered else -1
	unit.attack_timeline.visual_elapsed = 0.0
	view._process(0.0)

## 可选检查分段攻击的自然接缝，不用 Hit 中段截图代替 Start 尾帧。
func _capture_attack_seam(attack_phase: String) -> void:
	if not transition_frames or not view._attack_hit_pending:
		return
	var hit_time := unit.first_hit_time
	var offsets := [-1.0 / 30.0, 0.0, 1.0 / 30.0, 2.0 / 30.0]
	var suffixes := ["before", "at", "after_1", "after_2"]
	for index in offsets.size():
		var sample_time := maxf(0.0, hit_time + float(offsets[index]))
		_advance(maxf(0.0, sample_time - unit.attack_timeline.visual_elapsed))
		await _capture("%s_start_hit_%s" % [attack_phase, suffixes[index]])

func _advance_attack_sample() -> void:
	var loop_name := StringName(view._animation_names.get("attack_loop", ""))
	if loop_name == &"":
		_advance(maxf(0.0, _attack_sample_time() - unit.attack_timeline.visual_elapsed))
		return
	# 持续攻击必须完整经过 enter/retarget 序列，退出才来自真正的 Loop。
	var budget := 20.0
	while view._animation_player.assigned_animation != loop_name and budget > 0.0:
		_advance(STEP)
		budget -= STEP
	if view._animation_player.assigned_animation != loop_name:
		_fail("continuous 起手未进入稳定循环：" + String(loop_name))
		return
	_advance(0.2)

func _attack_sample_time() -> float:
	# 分段攻击采到出手后 Hit；单片攻击采到命中附近，不强等整个后摇。
	return maxf(unit.first_hit_time + 0.13, minf(unit.attack_interval * 0.5, 0.5))

func _start_action(action: StringName, duration: float) -> void:
	_set_behavior(false, false)
	_advance(0.15)
	unit.play_visual_action(action, duration)
	view._process(0.0)

func _action_duration(action: String, descriptor: Dictionary) -> float:
	var duration := 0.0
	for value in _list(descriptor.get("durations", view._animation_names.get("visual_action_durations", {}).get(action, []))):
		duration += float(value)
	if duration > 0.0:
		return duration
	for clip in _list(descriptor.get("animation", [])):
		if view._animation_player.has_animation(StringName(clip)):
			duration += view._animation_player.get_animation(StringName(clip)).length
	return maxf(duration, 0.1)

func _list(value: Variant) -> Array:
	return value if value is Array else [value]

func _set_behavior(attacking: bool, moving: bool) -> void:
	unit._attacking = attacking
	unit._move_intent = Vector2(0, -1 if unit.team == 0 else 1) * unit.move_speed if moving else Vector2.ZERO
	view._process(0.0)

func _advance(seconds: float) -> void:
	var remaining := maxf(seconds, 0.0)
	while remaining > 0.000001 and is_instance_valid(view) and not view.is_queued_for_deletion():
		var dt := minf(STEP, remaining)
		remaining -= dt
		elapsed += dt
		if unit.hp > 0.0:
			unit._deploy_timer = maxf(0.0, unit._deploy_timer - dt)
			unit._visual_action_time_left = maxf(0.0, unit._visual_action_time_left - dt)
			if unit._attacking:
				unit.attack_timeline.visual_elapsed += dt
			view._process(dt)
		_pause_tree(view) # 模型形态/死亡后续更换时，新 AnimationPlayer 也改为手动时钟。
		if view._model_root.has_method("_process"):
			view._model_root.call("_process", dt)
		if view._animation_player != null:
			view._animation_player.advance(dt)

## 共用出口采样；默认仍推进原来的 0.18 秒（部署 0.15 秒），不改变既有覆盖。
func _capture_exit(exit_phase: String, default_delay: float = 0.18) -> void:
	if not transition_frames:
		_advance(default_delay)
		await _capture(exit_phase)
		return
	var previous := 0.0
	var offsets := [0.0, 1.0 / 30.0, 2.0 / 30.0, 3.0 / 30.0, default_delay, 0.35]
	for extra in [0.4, 0.7, 1.0, transition_horizon]:
		if float(extra) > float(offsets.back()) and float(extra) <= transition_horizon:
			offsets.append(extra)
	for offset in offsets:
		_advance(float(offset) - previous)
		previous = float(offset)
		transition_sample_offset = previous
		var sampled_phase := exit_phase if is_equal_approx(previous, default_delay) else "%s_t%03d" % [exit_phase, roundi(previous * 1000.0)]
		await _capture(sampled_phase)
	transition_sample_offset = -1.0

func _capture(next_phase: String) -> void:
	phase = next_phase
	capture_index += 1
	if phase == "death_no_clip":
		label.text = case_name + " | death: no configured clip / immediate removal"
		var absent_file := "%02d_death_no_clip.png" % capture_index
		trace.store_line(JSON.stringify({"file": absent_file, "phase": phase, "expected_absence": true}))
		if not validate_only:
			await process_frame # queue_free 在帧尾完成；不能把删除前的旧网格截成“死亡后”。
			await RenderingServer.frame_post_draw
			focus.get_texture().get_image().save_png(folder.path_join(absent_file))
		return
	if not is_instance_valid(view) or view.is_queued_for_deletion():
		_fail("捕捉时代理已结束：" + phase)
		return
	for visual in view.find_children("*", "VisualInstance3D", true, false):
		visual.set_layer_mask_value(20, true)
	var target := view.global_position + focus_offset
	camera.global_position = target + Vector3(3.0, 2.6, 5.5)
	camera.look_at(target)
	_expand_camera_to_pose()
	var player := view._animation_player
	var clip_time := player.current_animation_position if player.current_animation != "" else 0.0
	var file_name := ("%04d_%s.png" if transition_frames else "%02d_%s.png") % [capture_index, next_phase.validate_filename()]
	label.text = "%s | %s\n%s | t %.3f | speed %.3f | blend %.3f" % [case_name, phase, player.assigned_animation, clip_time, player.get_playing_speed(), view._last_clip_blend_time]
	trace.store_line(JSON.stringify({"file": file_name, "phase": phase, "elapsed": elapsed, "clip": player.assigned_animation, "clip_time": clip_time, "speed": player.get_playing_speed(), "blend": view._last_clip_blend_time, "transition_kind": view._last_clip_transition_kind, "transition_elapsed": transition_sample_offset, "camera_size": camera.size, "serial": unit._attack_visual_serial, "attack_elapsed": unit.attack_timeline.visual_elapsed, "visual_action_time_left": unit._visual_action_time_left}))
	trace.flush()
	if not validate_only:
		await RenderingServer.frame_post_draw
		var result := focus.get_texture().get_image().save_png(folder.path_join(file_name))
		if result != OK:
			_fail("截图失败：" + file_name)

func _fail(message: String) -> void:
	failures += 1
	push_error(case_name + "：" + message)
	if trace != null:
		trace.store_line(JSON.stringify({"error": message, "phase": phase}))

func _view_for(source: Unit) -> UnitModel3D:
	for child in main._battle_presentation._world_root.get_children():
		if child is UnitModel3D and child._source == source:
			return child
	return null

func _pause_tree(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is AnimationPlayer:
		(node as AnimationPlayer).callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for child in node.get_children():
		_pause_tree(child)

func _clear_units() -> void:
	main._clear_art_dev_units()
	for child in main._battle_presentation._world_root.get_children():
		if child is UnitModel3D:
			child.free()
	for child in get_nodes_in_group("combatants"):
		if child is Unit:
			child.free()

func _fit_camera() -> void:
	var bounds := AABB()
	var has_bounds := false
	for candidate in view.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		if not mesh.is_visible_in_tree():
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = bounds.merge(box) if has_bounds else box
		has_bounds = true
	focus_offset = Vector3.UP
	camera.size = 5.5
	if has_bounds:
		focus_offset = bounds.get_center() - view.global_position
		camera.size = maxf(3.5, maxf(bounds.size.y * 3.0, maxf(bounds.size.x, bounds.size.z) * 2.0))
	initial_camera_size = camera.size

## Rest AABB 不包含龙王抬头/死亡倒地等姿势变化；按当前骨骼再留上下余量。
## 每组镜头只允许放大取景范围，避免连续接缝图来回缩放；预留文字区 70 px。
func _expand_camera_to_pose() -> void:
	var scale_needed := 1.0
	for candidate in view.find_children("*", "Skeleton3D", true, false):
		var skeleton := candidate as Skeleton3D
		if not skeleton.is_visible_in_tree():
			continue
		skeleton.force_update_all_bone_transforms()
		for bone_index in skeleton.get_bone_count():
			var point: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(bone_index).origin
			if camera.is_position_behind(point):
				continue
			var pixel := camera.unproject_position(point)
			scale_needed = maxf(scale_needed, absf(pixel.x - 320.0) / 275.0)
			scale_needed = maxf(scale_needed, absf(pixel.y - 260.0) / 185.0)
	if scale_needed > 1.0:
		# 未加权控制骨可能远离网格（纳尔双形态）；避免它们让每次截图递增到无限远。
		camera.size = minf(initial_camera_size * 1.5, camera.size * scale_needed * 1.12)

func _setup_closeup() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 50
	main.add_child(overlay)
	var panel := SubViewportContainer.new()
	panel.size = Vector2(640, 520)
	panel.stretch = true
	overlay.add_child(panel)
	focus = SubViewport.new()
	focus.size = Vector2i(640, 520)
	focus.world_3d = main._battle_presentation._viewport.find_world_3d()
	focus.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	panel.add_child(focus)
	camera = Camera3D.new()
	camera.cull_mask = 1 << 19
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	var environment: Environment = main._battle_presentation._world_root.get_node("UnitEnvironment3D").environment.duplicate()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.14, 0.18)
	camera.environment = environment
	focus.add_child(camera)
	camera.current = true
	var text_layer := CanvasLayer.new()
	focus.add_child(text_layer)
	label = Label.new()
	label.position = Vector2(10, 8)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	text_layer.add_child(label)
