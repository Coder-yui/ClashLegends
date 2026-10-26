extends SceneTree
## 只渲染正式技能栏/Unit条；合成只读状态，无比赛、模型或声音。
class DisplayContext extends BattleContext:
	func _init() -> void: super(null, null)
	func has_presentation() -> bool: return true
	func is_net_client() -> bool: return true
	func local_player_team() -> int: return 0
	func has_carried_skill_visual(_unit: Unit) -> bool: return false

var heartbeat: RefCounted
var output := ""
var bars: Array[ActiveSkillBar] = []
var units: Array[Unit] = []
var captions: CanvasLayer
var samples: Array = []
var context := DisplayContext.new()

func _initialize() -> void:
	heartbeat = preload("res://tools/performance/safe_probe_heartbeat.gd").new(self)
	_run.call_deferred()

func _run() -> void:
	if not heartbeat.enabled:
		push_error("按钮渲染须通过监督器启动")
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty():
		quit(2)
		return
	RenderingServer.set_default_clear_color(Color(0.055, 0.08, 0.12))
	root.size = Vector2i(720, 950)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	captions = CanvasLayer.new()
	captions.layer = 10
	root.add_child(captions)
	_label(Vector2(24, 16), "主动技能 · 正式按钮与头顶资源条对照", 22)
	var cases := [
		["kassadin", 0.0, 0, 3, 10, false, "首发0费 · 可用"],
		["kassadin", 0.0, 0, 2, 0, false, "动态1费 · 金币不足"],
		["sett", 0.5, 0, 1, 10, false, "连续豪意 · 未满可释放"],
		["sett", 1.0, 3.7, 1, 0, false, "满豪意＋冷却＋缺钱"],
		["pantheon", 0.5, 0, 2, 10, false, "分段2/4 · 未满可释放"],
		["pantheon", 1.0, 3.7, 2, 10, false, "分段满层＋冷却"],
		["samira", 0.4, 0, 0, 10, false, "无限次数 · 资源不足"],
		["samira", 1.0, 0.1, 0, 10, false, "无限次数 · 最后0.1"],
		["garen", 0.0, 0, 2, 10, true, "指令待执行 · 无冷却遮罩"],
		["garen", 0.0, 3.7, 1, 0, false, "受控＋CD＋缺钱"],
		["jayce", 0.0, 0, 2, 10, false, "现有双形态组合图标"],
		["gwen", 1.0, 0, 1, 10, false, "格温满层色 · 与头顶条相同"],
	]
	for index in cases.size():
		var c: Array = cases[index]
		var position := Vector2(35 + index % 2 * 350, 118 + index / 2 * 140)
		var bar := _bar(String(c[0]), index + 1)
		bar.scale = Vector2.ONE
		bar.offset = position - ActiveSkillBar.LEFT_SLOT_POSITION
		var u := _unit(String(c[0]), position + Vector2(145, 32), float(c[1]))
		var skill: Dictionary = CardDB.active_skills_for(c[0])[0]
		var locked := (bool(skill.get("requires_full_resource", false)) and float(c[1]) < 1.0) or index == 9
		bar.can_submit = func(_id): return not locked and float(c[2]) == 0 and float(c[4]) >= 1
		bar.set_elixir(c[4])
		var cost := ActiveSkillRoster.cost_for_use(skill, int(skill.get("max_uses", 1)) - int(c[3]))
		bar.update_skill_state(index + 1, c[3], c[2], true, cost, 0 if bool(skill.get("unlimited_uses", false)) else int(skill.get("max_uses", 1)), false,
			{"locked": locked, "reason": "资源不足或单位暂时无法起手" if locked else "", "resource": _resource(u)})
		if c[5]:
			bar.set_pending(index + 1, true)
			bar.set_pending_seconds(index + 1, 0.4)
		_label(position + Vector2(-7, -48), c[6], 15)
		_label(position + Vector2(105, 51), "头顶资源条", 12)
	await _capture("01-states")
	_clear()
	_label(Vector2(24, 22), "冷却方向：12点起顺时针露出图标", 22)
	for index in 5:
		var remaining: float = [6.0, 4.5, 3.0, 0.05, 0.0][index]
		var bar := _bar("garen", index + 1)
		bar.scale = Vector2.ONE * 1.8
		bar.offset = Vector2(70 + index % 3 * 215, 190 + index / 3 * 300) - ActiveSkillBar.LEFT_SLOT_POSITION * bar.scale
		bar.set_elixir(10)
		bar.update_skill_state(index + 1, 1, remaining, true, 1, 2)
		_label(Vector2(42 + index % 3 * 215, 130 + index / 3 * 300), "剩余 %.2f / 6.0" % remaining, 18)
	await _capture("02-cooldown")
	_clear()
	for entry in [[Vector2i(720, 1280), "03-layout-720"], [Vector2i(480, 720), "04-layout-480"], [Vector2i(1280, 720), "05-layout-wide"]]:
		root.size = entry[0]
		root.content_scale_size = root.size
		await process_frame
		_label(Vector2(20, 20), "实际槽位布局 · %s" % str(root.size), 20)
		var panel := ColorRect.new()
		panel.color = Color(0.10, 0.14, 0.21)
		panel.position = preload("res://scripts/ui/battle_layout.gd").hand_origin(Vector2(root.size))
		panel.size = Vector2(720, 160) * preload("res://scripts/ui/battle_layout.gd").ui_scale(Vector2(root.size))
		captions.add_child(panel)
		var bar := _bar("pantheon", 1)
		var skill: Dictionary = CardDB.active_skills_for("samira")[0]
		bar.show_skill(1, 2, skill.name, Color.WHITE, 2, 0, 0, skill.cooldown, true, CardArt.skill_icon(skill))
		bar.can_submit = func(_id): return false
		var u := _unit("pantheon", Vector2(300, 300), 1.0)
		bar.set_elixir(0)
		bar.update_skill_state(1, 1, 3.7, true, 1, 2, false, {"resource": _resource(u), "locked": true})
		bar.update_skill_state(2, 0, 0.05, true, 2, 0)
		bar.apply_layout(Vector2(root.size))
		await _capture(entry[1])
		await _verify_click(bar)
		_clear()
	FileAccess.open(output.path_join("render-inputs.json"), FileAccess.WRITE).store_string(JSON.stringify(samples, "\t"))
	captions.free()
	print("[ACTIVE_SKILL_BUTTON_RENDER] completed")
	quit(0)

func _bar(card: String, id: int) -> ActiveSkillBar:
	var bar := ActiveSkillBar.new()
	bar.can_submit = func(_id): return true
	root.add_child(bar)
	var skill: Dictionary = CardDB.active_skills_for(card)[0]
	bar.show_skill(0, id, skill.name, Color.WHITE, skill.get("cost", 0), 0 if bool(skill.get("unlimited_uses", false)) else int(skill.get("max_uses", 1)), int(skill.get("max_uses", 1)), skill.get("cooldown", 0), true, CardArt.skill_icon(skill))
	bars.append(bar)
	return bar

func _unit(card: String, pos: Vector2, ratio: float) -> Unit:
	var u := Unit.new()
	u.setup(0, CardDB.get_unit_stats(card), card)
	u.set_battle_context(context)
	u.configure_carried_active_skill(CardDB.active_skills_for(card)[0])
	u.position = pos
	u._deploy_timer = 0
	u.net_action_permissions = ControlState.ALL_PERMISSIONS
	u.net_skill_resource_enabled = u.skill_resource_enabled
	u.net_skill_resource_ratio = ratio
	u.set_visual_head_world_position(pos + Vector2(0, -20))
	root.add_child(u)
	u.set_process(false)
	units.append(u)
	return u

func _resource(u: Unit) -> Dictionary:
	return {"visible": u.is_skill_resource_visible(), "ratio": u.get_skill_resource_ratio(), "segments": u.get_skill_resource_segment_count(), "stacks": u.get_skill_resource_stacks(), "color": u.get_skill_resource_fill_color()}

func _label(pos: Vector2, text: String, font_size: int) -> void:
	var label := Label.new()
	label.position = pos
	label.text = text
	label.add_theme_font_override("font", CardArt.ui_font())
	label.add_theme_font_size_override("font_size", font_size)
	captions.add_child(label)

func _capture(name: String) -> void:
	heartbeat.set_phase(name, true)
	await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	for bar in bars:
		samples.append({"capture": name, "offset": str(bar.offset), "scale": str(bar.scale), "state": bar._states})

func _clear() -> void:
	for bar in bars: bar.free()
	for unit in units: unit.free()
	bars.clear()
	units.clear()
	for child in captions.get_children(): child.free()

func _verify_click(bar: ActiveSkillBar) -> void:
	bar.can_submit = func(_id): return true
	bar.set_elixir(10)
	bar.update_skill_state(1, 1, 0, true, 1, 2)
	var hits := [0]
	bar.skill_pressed.connect(func(_id): hits[0] += 1)
	var center: Vector2 = bar.offset + (bar._buttons[0].position + ActiveSkillBar.BUTTON_SIZE * 0.5) * bar.scale
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame
	if hits[0] != 1:
		push_error("实际槽位鼠标命中失败: %s hits=%d" % [center, hits[0]])
	samples.append({"viewport": str(root.size), "click_center": str(center), "skill_pressed_count": hits[0]})
