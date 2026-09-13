extends SceneTree
## 独立临时展示台，复用正式塔模型与音频；不启动比赛。
var stage: Node2D
var presentation: BattlePresentation3D
var audio: GameAudioManager
var building: Tower
var kind := 0
var team := 0
var elapsed := 0.0
var auto_time := -1.0
var auto_step := 0
var status: Label
var event_label: Label
var title: Label
var stage_buttons: Array[Button] = []
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	stage = Node2D.new()
	root.add_child(stage)
	current_scene = stage
	var bg := ColorRect.new()
	bg.color = Color("101c2a")
	bg.size = Vector2(720,1400)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bg)
	presentation = BattlePresentation3D.new()
	stage.add_child(presentation)
	presentation.setup(Vector2(720,1280),40.0)
	audio = GameAudioManager.new()
	stage.add_child(audio)
	audio.cue_played.connect(func(id, cue, _pos):
		event_label.text = "最近事件：%s\n%s" % [cue,id]
		print("[展示台] ",id," ",cue))
	var layer := CanvasLayer.new()
	stage.add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(24,24)
	box.size = Vector2(672,260)
	box.add_theme_constant_override("separation",12)
	box.theme = Theme.new()
	box.theme.default_font = CardArt.ui_font()
	box.theme.default_font_size = 22
	layer.add_child(box)
	title = Label.new()
	title.text = "水晶 / 防御塔 · 动画与音频展示台"
	box.add_child(title)
	var row := HBoxContainer.new()
	box.add_child(row)
	_button(row,"水晶",func(): kind=0; _reset())
	_button(row,"防御塔",func(): kind=1; _reset())
	_button(row,"切换蓝 / 红方",func(): team=1-team; _reset())
	status = Label.new()
	box.add_child(status)
	var bottom := VBoxContainer.new()
	bottom.position = Vector2(24,1030)
	bottom.size = Vector2(672,320)
	bottom.theme = box.theme
	bottom.add_theme_constant_override("separation",12)
	layer.add_child(bottom)
	var controls := HBoxContainer.new()
	bottom.add_child(controls)
	_button(controls,"重置 / 重播",_reset)
	_button(controls,"自动演示",func(): _reset(); auto_time=0.0)
	_button(controls,"关闭",func(): quit())
	var damage := HBoxContainer.new()
	bottom.add_child(damage)
	stage_buttons.append(_button(damage,"破损一 · 66%",func(): _damage_to(0.65)))
	stage_buttons.append(_button(damage,"破损二 · 33%",func(): _damage_to(0.32)))
	_button(damage,"摧毁",func(): _damage_to(0.0))
	event_label = Label.new()
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(event_label)
	var hint := Label.new()
	hint.text = "水晶：进入即上升 → 出生 → 轻微待机 → 死亡\n防御塔：完整 → 一阶段破损 → 二阶段破损 → 废墟\n音频采用游戏内配置；水晶待机声刻意保持很轻。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(hint)
	_reset()
	process_frame.connect(_tick)
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(4).timeout
		await _capture("nexus_spawn")
		await create_timer(4).timeout
		await _capture("nexus_idle")
		kind=1
		_reset()
		_damage_to(0.65)
		await create_timer(0.5).timeout
		await _capture("tower_stage1")
		_damage_to(0.32)
		await create_timer(0.5).timeout
		await _capture("tower_stage2")
		_damage_to(0.0)
		await create_timer(12.0).timeout
		await _capture("tower_ruin")
		stage.queue_free()
		await process_frame
		presentation = null
		audio = null
		building = null
		stage = null
		await create_timer(0.2).timeout
		quit()
func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 52
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button
func _reset() -> void:
	auto_time = -1.0
	auto_step = 0
	elapsed = 0.0
	for player in audio._world_players: player.stop()
	if is_instance_valid(building): building.free()
	for child in presentation._world_root.get_children():
		if child is TowerModel3D: child.queue_free()
	building = Tower.new()
	building.setup(team, CardDB.NEXUS_STATS if kind==0 else CardDB.PRINCESS_TOWER_STATS,kind==0)
	building.position = Vector2(360,790)
	stage.add_child(building)
	var config: Dictionary = CardDB.NEXUS_VISUAL_CONFIG if kind==0 else CardDB.PRINCESS_TOWER_VISUAL_CONFIG
	presentation.attach_tower(building,config)
	var view = presentation._world_root.get_child(presentation._world_root.get_child_count()-1)
	view.scale = Vector3.ONE * 2.4
	var id := PresentationConfig.world_card_id(building)
	building.destroyed.connect(_on_destroyed.bind(id,weakref(building)))
	event_label.text = "等待事件…"
	audio.attach_building_audio(building,config)
	for button in stage_buttons: button.disabled = kind==0
func _on_destroyed(id: String, ref: WeakRef) -> void:
	var source = ref.get_ref()
	if not is_instance_valid(source): return
	audio.stop_building_audio(source.get_instance_id())
	audio.play_card_event(id,"death",source.global_position)
func _damage_to(ratio: float) -> void:
	if not is_instance_valid(building): return
	var target := roundf(building.max_hp*ratio)
	if building.hp > target: building.take_damage(building.hp-target)
func _tick() -> void:
	var delta := root.get_process_delta_time()
	elapsed += delta
	if is_instance_valid(building):
		status.text = "%s · %s · %.2f 秒\n生命值 %d / %d" % ["水晶" if kind==0 else "防御塔","蓝方" if team==0 else "红方",elapsed,building.hp,building.max_hp]
	if auto_time >= 0.0:
		auto_time += delta
		var deadlines := [10.0] if kind==0 else [2.0,5.0,8.0]
		if auto_step < deadlines.size() and auto_time >= deadlines[auto_step]:
			_damage_to(0.0 if kind==0 else [0.65,0.32,0.0][auto_step])
			auto_step += 1
func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("/tmp/structure-showcase")
	root.get_texture().get_image().save_png("/tmp/structure-showcase/"+name+".png")
