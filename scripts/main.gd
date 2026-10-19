extends Node2D
## 场景装配、输入、资源准备及RPC/表现适配。权威对局归MatchRuntime，实体与空间归BattleWorld。

const BATTLE_LAYOUT := preload("res://scripts/ui/battle_layout.gd")
const WORKBENCH_SCRIPT := preload("res://scripts/ui/development_workbench.gd")
const ACTIVE_SKILL_BAR_SCRIPT := preload("res://scripts/ui/active_skill_bar.gd")
const SPELL_SYSTEM_SCRIPT := preload("res://scripts/battle/spell_system.gd")
const ACTIVE_SKILL_EFFECT_SYSTEM_SCRIPT := preload("res://scripts/battle/active_skill_effect_system.gd")
const AUDIO_MANAGER_SCRIPT := preload("res://scripts/audio/game_audio_manager.gd")
const ARENA_BACKGROUND_PATH := "res://assets/arena/arena_rift_v4.png"

# 比赛计时：3 分 05 秒正赛，平局进 2 分钟加时（先破塔者胜），再平则平局
const MATCH_TIME := MatchRules.REGULATION_TIME
const OVERTIME_TIME := MatchRules.OVERTIME_TIME
const SIM_DT := FixedStepClock.STEP
const DOUBLE_ELIXIR_TIME := 60.0
const OVERTIME_TRIPLE_ELIXIR_TIME := 60.0
const DOUBLE_ELIXIR_START_TIME := MATCH_TIME - DOUBLE_ELIXIR_TIME
## 所有玩家命令使用 20Hz 权威 Tick 排程，0.5 秒对应 10 个模拟 Tick。
const COMMAND_DELAY_TICKS := CommandSchedule.BUFFER_TICKS
## 网络请求的 input_tick 最多允许落后两个 Buffer；更早的输入直接视为异常。
const COMMAND_MAX_LATENCY_TICKS := COMMAND_DELAY_TICKS * 2
## 允许少量客户端时钟领先 Host；这只是校验窗口，不是客户端执行权。
const COMMAND_CLOCK_FUTURE_TOLERANCE := 2
## 水晶兵线由主机固定 tick 驱动：普通阶段 5/50/95 秒，2:05 切换炮车并改为每 30 秒一波，第二只延迟 0.5 秒。
const MINION_SPAWN_X_OFFSET := 3.0 * ArenaRules.TILE_SIZE

# 联机
const NET_PORT := 39152
var _network_port := NET_PORT
var _network_peer: ENetMultiplayerPeer
var runtime := preload("res://scripts/battle/match_runtime.gd").new()
var _network_request_id := 0
var _client_hand := ClientHandState.new()
var _client_inputs := ClientInputState.new()
var _network_clock := NetworkClock.new()
var _network_playback := NetworkPlayback.new()
var _network_commands := NetworkCommandState.new()
var _clock_probe_timer := 0.0
var _clock_probe_last_by_peer: Dictionary = {}
signal network_command_announced(command: Dictionary)
signal network_command_finished(command: Dictionary, outcome: String)

var _network_loading_started := 0

var _presentation_event_id := 0
var _last_card_event_id := -1
var _effects_view: Node2D
var _resources := MatchResources.new()
var _combat: CombatResolver
var _movement: MovementSystem
var _terminal_result: Dictionary = {}
const WORLD_SCRIPT = preload("res://scripts/battle/battle_world.gd")
var world = WORLD_SCRIPT.new(self)
var battle_context: BattleContext
var _server_reset_pending := false
var server_auto_restart := true
## 强化冰冻结束后的权威减速区域与客户端纯视觉区域分开保存。
## 治疗术淡黄光效区域；治疗本身立即结算，这里只保存表现。
var _spell_system: RefCounted
## 纳尔 Spell2：固定模拟延迟到手掌触地才结算；范围框是独立纯表现数据。
var _skill_lifecycle: ActiveSkillLifecycle
var _skill_presentation: SkillEffectPresentation
var _team_attack_boost_system: TeamAttackBoostSystem
var _active_skill_effect_system: RefCounted
var _projectile_system: ProjectileSystem

var _hand: CardHand
var _cast_notice: Node2D
var _active_skill_bar: ActiveSkillBar
var _arena_background_sprite: Sprite2D
var _ai: AIOpponent
var _selected_card := ""
## 选卡后的落点预览：单位以单格格心为目标，点击时使用当前预览而不是重新猜测落点。
var _deployment_preview_pos := Vector2.ZERO
var _deployment_preview_tile := Vector2i(-1, -1)
var _deployment_preview_valid := false
var _deployment_preview_visible := false
var _skin_choices: Dictionary = {}
var _deck_builder: DeckBuilder
var _timer_label: Label
var _battle_presentation: Node
var _audio_manager: GameAudioManager
var _workbench := WorkbenchSession.new()
var _art_dev_panel: DevelopmentWorkbench

# 主菜单
var _menu_layer: CanvasLayer
var _menu_status: Label
var _ip_input: LineEdit
# 主机端：对手（客户端玩家）的金币
# 主机端：net_id -> Unit
var _snapshot_system: NetworkSnapshotSystem
var _snapshot_timer := 0.0
const SNAPSHOT_INTERVAL := 0.05
# 客户端：net_id -> Unit
var _snapshots_received := 0
var _auto_projectile_seen := false
var _auto_audio_source_seen := false
var _auto_continuous_target_seen := false
var _auto_gnar_form_seen := false
var _auto_gnar_revert_seen := false
var _auto_gnar_skill_fx_seen := false
var _auto_gnar_revert_unit: Unit = null
var _auto_gnar_revert_timer := 0.0
# 命令行联机测试钩子（--auto-test：主机 2 秒后生成近战、远程、持续攻击与双形态样本）
var _auto_test := false
var _auto_timer := 2.0
## 客户端由快照提供的最后已知主机 Tick，用于生成 input_tick。
var _authoritative_server_tick := 0
## 客户端只估计服务器时钟，不推进任何战斗状态；快照到达时向前校正，间隔内按本地时间补 Tick。
var _estimated_server_tick := 0
var _estimated_server_tick_fraction := 0.0
var _has_estimated_server_tick := false

func _ready() -> void:
	var cli := _parse_cli()
	if get_tree().has_meta("return_to_main_menu"):
		get_tree().remove_meta("return_to_main_menu")
		cli["mode"] = ""
	if cli.get("mode", "") == "server":
		runtime.mode = "server"
		runtime.local_team = -1
	if has_presentation():
		if not get_tree().has_meta("display_window_initialized"):
			BATTLE_LAYOUT.fit_window(get_window())
			get_tree().set_meta("display_window_initialized", true)
		get_viewport().size_changed.connect(_refresh_display_layout)
		_setup_arena_background()
		_refresh_display_layout()
	_combat = CombatResolver.new()
	_combat.attack_hit.connect(_notify_attack_presentation)
	add_child(_combat)
	_movement = MovementSystem.new()
	_movement.terrain_walkable = world.is_ground_terrain_walkable
	_movement.structure_gap = world.structure_gap_to_circle
	add_child(_movement)
	runtime._deployment_rules.combatants = world.combatants
	runtime._deployment_rules.towers = world.towers_snapshot
	runtime._deployment_rules.ground_walkable = world.is_ground_position_walkable
	_workbench.place = _place_art_dev_item
	_workbench.clear_battle = clear_preview_battle
	_workbench.rebuild_arena = _rebuild_workbench_arena
	_workbench.selected_unit = _art_dev_selected_unit
	_workbench.sync_view = _sync_art_dev_panel_state
	_workbench.pause_battle = _pause_workbench_battle
	battle_context = BattleContext.new(self, world)
	_spell_system = SPELL_SYSTEM_SCRIPT.new(self)
	_skill_presentation = SkillEffectPresentation.new(self)
	_team_attack_boost_system = TeamAttackBoostSystem.new(self)
	_active_skill_effect_system = ACTIVE_SKILL_EFFECT_SYSTEM_SCRIPT.new(self, _skill_presentation)
	_skill_lifecycle = ActiveSkillLifecycle.new(_active_skill_effect_system, _skill_presentation, runtime._commands, _combat)
	if has_presentation():
		_effects_view = load("res://scripts/presentation/battle_effects_2d.gd").new()
		_effects_view.spells = _spell_system
		_effects_view.skills = _skill_presentation
		add_child(_effects_view)
	child_entered_tree.connect(_provide_battle_context)
	_projectile_system = ProjectileSystem.new()
	_projectile_system.setup(battle_context)
	_projectile_system.skill_hit.connect(present_skill_projectile_hit)
	_projectile_system.wave_audio.connect(present_skill_projectile_hit)
	_projectile_system.launch_audio_started.connect(_on_projectile_launch_audio_started)
	_projectile_system.launch_audio_stopped.connect(_on_projectile_launch_audio_stopped)
	add_child(_projectile_system)
	runtime.setup(world, _workbench, _combat, _movement, _spell_system, _skill_lifecycle, _active_skill_effect_system, _team_attack_boost_system, _projectile_system, _skill_presentation, _spawn_unit)
	runtime.changed.connect(_on_runtime_changed)
	runtime.event.connect(_on_runtime_event)
	runtime.world_step_finished.connect(_tick_development_adapter)
	runtime._simulation_clock.running = can_advance_simulation
	_snapshot_system = NetworkSnapshotSystem.new(self, _projectile_system)
	if has_presentation():
		_audio_manager = AUDIO_MANAGER_SCRIPT.new()
		add_child(_audio_manager)
		_projectile_system.launch_audio_cleared.connect(_audio_manager.clear_projectile_launch_audio)
	randomize()
	var card_errors := CardDB.validate_all(false)
	if not card_errors.is_empty():
		for error in card_errors:
			push_error("[CardDB] " + error)
		_fail_startup("卡牌配置校验失败：" + card_errors[0])
		return
	_network_port = int(cli.get("port", NET_PORT))
	_auto_test = cli.get("auto_test", false)
	match cli.get("mode", ""):
		"server":
			_start_server()
		"join":
			_show_menu()
			_start_client(cli.get("ip", "127.0.0.1"))
		"local":
			_start_local_with_loading()
		"workbench":
			_start_art_dev()
		_:
			_show_menu()

	if cli.get("release_smoke", "") in ["menu", "match"]:
		preload("res://scripts/diagnostics/release_smoke.gd").run(self, cli.release_smoke == "menu")

func _exit_tree() -> void:
	_resources.cancel_async(get_tree())
	if _battle_loading:
		get_tree().paused = false
		if is_instance_valid(_battle_presentation): _battle_presentation.model_pool.cancelled = true
	if _network_peer != null:
		_network_peer.close()
		if multiplayer.multiplayer_peer == _network_peer:
			multiplayer.multiplayer_peer = null

func _provide_battle_context(node: Node) -> void:
	world.bind_entity(node, battle_context, _combat)

## 解析命令行用户参数（-- 之后的部分），用于无界面联机测试
func _parse_cli() -> Dictionary:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a == "--auto-test":
			args["auto_test"] = true
		elif a.begins_with("--release-smoke="):
			args["release_smoke"] = a.trim_prefix("--release-smoke=")
		elif a.begins_with("--mode="):
			args["mode"] = a.trim_prefix("--mode=")
		elif a.begins_with("--port="):
			args["port"] = clampi(int(a.trim_prefix("--port=")), 1024, 65535)
		elif a.begins_with("--ip="):
			args["ip"] = a.trim_prefix("--ip=")
	return args

# ============================================================
#  主菜单
# ============================================================

func _show_menu() -> void:
	_menu_layer = CanvasLayer.new()
	add_child(_menu_layer)
	var root := Control.new()
	root.name = "ModeMenu"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_layer.add_child(root)
	# 菜单图片属于屏幕层，与战场取景/红方翻转无关；峡谷沿原图中心等比裁切。
	var background := TextureRect.new()
	background.name = "MenuBackground"
	background.texture = load(ARENA_BACKGROUND_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.name = "MenuShade"
	shade.color = Color(0, 0, 0, 0.20)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	root.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.name = "ModeOptions"
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)
	var resize_menu := func(): vbox.custom_minimum_size.x = minf(560.0, maxf(0.0, root.size.x - 96.0))
	root.resized.connect(resize_menu)
	resize_menu.call()
	var title := Label.new()
	title.name = "Title"
	title.text = "Clash Legends"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	title.add_theme_constant_override("outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var btn_solo := _make_menu_button("单机对战 AI")
	btn_solo.name = "Solo"
	btn_solo.pressed.connect(func(): _pick_deck_ui(_start_local_with_loading))
	vbox.add_child(btn_solo)
	var btn_art_dev := _make_menu_button("卡牌开发工作台")
	btn_art_dev.name = "Workbench"
	btn_art_dev.pressed.connect(_start_art_dev)
	vbox.add_child(btn_art_dev)
	_ip_input = LineEdit.new()
	_ip_input.name = "ServerIP"
	_ip_input.text = "127.0.0.1"
	_ip_input.custom_minimum_size = Vector2(0, 60)
	_ip_input.add_theme_font_size_override("font_size", 24)
	_ip_input.placeholder_text = "服务器 IP 地址"
	vbox.add_child(_ip_input)
	var btn_join := _make_menu_button("连接服务器")
	btn_join.name = "Join"
	btn_join.pressed.connect(func(): _pick_deck_ui(func(): _start_client(_ip_input.text.strip_edges())))
	vbox.add_child(btn_join)
	_menu_status = Label.new()
	_menu_status.name = "Status"
	_menu_status.custom_minimum_size.y = 48.0
	_menu_status.add_theme_font_size_override("font_size", 20)
	_menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_menu_status)

func _make_menu_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 72)
	b.add_theme_font_size_override("font_size", 26)
	return b

func _pick_deck_ui(after_start: Callable) -> void:
	if _network_peer != null: return
	if _deck_builder != null and is_instance_valid(_deck_builder):
		_deck_builder.queue_free()
	_deck_builder = DeckBuilder.new()
	add_child(_deck_builder)
	_deck_builder.open(runtime._deck, runtime._active_skill_choices, _skin_choices, func(selected_deck: Array, active_choices: Dictionary, skin_choices: Dictionary) -> void:
		runtime._deck = selected_deck
		runtime._active_skill_choices = active_choices
		_skin_choices = skin_choices
		after_start.call()
	)

func _hide_menu() -> void:
	if _menu_layer != null:
		_menu_layer.queue_free()
		_menu_layer = null

# ============================================================
#  三种开局
# ============================================================

var _battle_loading := false
var _startup_failure_message := ""
var preparation_metrics := {}

func _start_local_with_loading() -> void:
	await _load_battle(_start_local)

func _load_battle(start_battle: Callable, network: bool = false) -> void:
	if runtime.game_over or _battle_loading or runtime._match_started:
		return
	_battle_loading = true
	if network:
		_network_loading_started = Time.get_ticks_msec()
		_watch_network_loading(runtime.session.session_id)
	var tree := get_tree()
	var loading := CanvasLayer.new()
	loading.layer = 100
	loading.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(loading)
	var background := TextureRect.new()
	background.texture = load(ARENA_BACKGROUND_PATH)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	loading.add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading.add_child(shade)
	var label := Label.new()
	label.text = "正在加载对局…"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading.add_child(label)
	# 先绘制加载页，再建立战场；暂停树同时冻结模拟、动画与音频播放器。
	tree.paused = true
	await tree.process_frame
	await tree.process_frame
	if network and runtime.session.phase != MatchSession.Phase.LOADING:
		loading.queue_free()
		_battle_loading = false
		tree.paused = false
		return
	var started := Time.get_ticks_msec()
	var stage_start := Time.get_ticks_usec()
	var loading_started := stage_start
	start_battle.call()
	preparation_metrics.scene_usec = Time.get_ticks_usec() - stage_start
	stage_start = Time.get_ticks_usec()
	await _prepare_match_assets()
	preparation_metrics.assets_usec = Time.get_ticks_usec() - stage_start
	preparation_metrics.resources_usec = _resources.preparation_usec
	preparation_metrics.memory_loaded = OS.get_static_memory_usage()
	preparation_metrics.objects_loaded = Performance.get_monitor(Performance.OBJECT_COUNT)
	await tree.process_frame
	await tree.process_frame
	var remaining := maxf(1.0 - float(Time.get_ticks_msec() - started) / 1000.0, 0.0)
	preparation_metrics.display_padding_ms = remaining * 1000.0
	if remaining > 0.0:
		await tree.create_timer(remaining, true, false, true).timeout
	stage_start = Time.get_ticks_usec()
	if network and runtime.session.phase == MatchSession.Phase.LOADING:
		runtime.session.local_ready = true
		runtime.session.deck_confirmed = true
		_rpc_loaded.rpc_id(1, runtime.session.session_id)
		label.text = "等待对方加载完成…"
		while runtime.session.phase == MatchSession.Phase.LOADING:
			if Time.get_ticks_msec() - _network_loading_started > 30000:
				_network_failed("等待对方加载超时")
				break
			await tree.process_frame
	if network and runtime.session.phase == MatchSession.Phase.DISCONNECTED and not runtime.game_over:
		_end_game(-1, "disconnect")
	preparation_metrics.opponent_wait_usec = Time.get_ticks_usec() - stage_start
	preparation_metrics.total_usec = Time.get_ticks_usec() - loading_started
	loading.hide()
	loading.queue_free()
	_battle_loading = false
	tree.paused = false

## SceneTree 暂停时仍检查加载超时；准备和等待对手共用同一截止时间。
func _watch_network_loading(epoch: String) -> void:
	var tree := get_tree()
	while _battle_loading and runtime.session.session_id == epoch and runtime.session.phase == MatchSession.Phase.LOADING:
		if Time.get_ticks_msec() - _network_loading_started > 30000:
			_network_failed("对局加载超时")
			return
		await tree.process_frame

func _prepare_match_assets() -> void:
	preparation_metrics.card_art_cache = CardArt.retain_match_textures(runtime._deck + runtime._remote_deck)
	var stage_started := Time.get_ticks_usec()
	_resources.plan = preload("res://scripts/presentation/match_resource_plan.gd").for_match([runtime._deck, runtime._remote_deck], [runtime._active_skill_choices, runtime._remote_active_skill_choices])
	if not _resources.plan.errors.is_empty():
		_fail_preparation(_resources.plan.errors)
		return
	preparation_metrics.plan_usec = Time.get_ticks_usec() - stage_started
	stage_started = Time.get_ticks_usec()
	await _resources.prepare_async(runtime._deck + runtime._remote_deck + MatchResources.SYSTEM_UNIT_BUDGET.keys(), get_tree(), func(): return runtime.game_over)
	preparation_metrics.resource_stage_usec = Time.get_ticks_usec() - stage_started
	preparation_metrics.threaded_requests = _resources.threaded_requests
	preparation_metrics.threaded_wait_usec = _resources.threaded_wait_usec
	if runtime.game_over: return
	if not _resources.errors.is_empty():
		_fail_preparation(_resources.errors)
		return
	stage_started = Time.get_ticks_usec()
	for id in _resources.cards:
		_audio_manager.prepare_audio(_resources.plan.definition(String(id)).get("audio", {}))
	_audio_manager.prepare_audio(preload("res://scripts/data/world_audio.gd").DEFINITIONS)
	_audio_manager.prepare_audio(preload("res://scripts/data/match_audio.gd").EVENTS)
	if not _audio_manager.preparation_errors.is_empty():
		_fail_preparation(_audio_manager.preparation_errors)
		return
	preparation_metrics.audio_usec = Time.get_ticks_usec() - stage_started
	if not is_instance_valid(_battle_presentation): return
	stage_started = Time.get_ticks_usec()
	_battle_presentation.resource_plan = _resources.plan
	await _battle_presentation.model_pool.prepare(_resources.resources, _battle_presentation._world_root, _battle_presentation._camera, _resources.cards, _resources.plan)
	preparation_metrics.model_pool_usec = Time.get_ticks_usec() - stage_started
	if is_instance_valid(_battle_presentation) and not _battle_presentation.model_pool.errors.is_empty(): _fail_preparation(_battle_presentation.model_pool.errors)
	if is_instance_valid(_battle_presentation) and not runtime.game_over and not _battle_presentation.model_pool.cancelled:
		stage_started = Time.get_ticks_usec()
		_battle_presentation.prepare_target_states(_resources.plan.target_states)
		await _battle_presentation.spell_warmup.prepare_ground(_battle_presentation, _resources.plan, func(): return runtime.game_over)
		preparation_metrics.ground_usec = Time.get_ticks_usec() - stage_started
		if not is_instance_valid(_battle_presentation) or runtime.game_over: return
		stage_started = Time.get_ticks_usec()
		await _battle_presentation.spell_warmup.prepare(_resources.cards, _battle_presentation._world_root, _battle_presentation._camera, func(): return runtime.game_over, _resources.plan)
		preparation_metrics.effects_usec = Time.get_ticks_usec() - stage_started
		if is_instance_valid(_battle_presentation) and not _battle_presentation.spell_warmup.errors.is_empty(): _fail_preparation(_battle_presentation.spell_warmup.errors)

func _fail_preparation(errors: PackedStringArray) -> void:
	if runtime.mode in ["server", "client"]: _network_failed("本局资源准备失败：" + "；".join(errors))
	else: _fail_startup("本局资源准备失败：" + "；".join(errors))

func _start_local() -> void:
	# CLI/直接启动没有备战页：先确定同一份默认卡组，再创建显示与权威循环。
	if runtime._deck.is_empty():
		runtime._deck = CardDB.selectable_ids().slice(0, 8)
	runtime._remote_deck = AIOpponent.build_deck()
	runtime._remote_active_skill_choices.clear()
	for card_id in runtime._remote_deck.slice(0, 2):
		var skills := CardDB.active_skills_for(card_id)
		if not skills.is_empty():
			runtime._remote_active_skill_choices[card_id] = randi() % skills.size()
	_audio_manager.begin_battle()
	runtime.mode = "local"
	runtime.local_team = 0
	runtime._match_started = true
	queue_redraw()
	_hide_menu()
	_setup_battle_presentation()
	_setup_player_ui()
	_ai = AIOpponent.new()
	add_child(_ai)
	_ai.setup(self)
	_create_towers()
	world.build_navigation()
	_create_timer_ui()

## 美术开发模式复用正式模拟与表现，但不创建金币、手牌、AI 和比赛倒计时。
func _start_art_dev() -> void:
	if _network_peer != null: return
	_audio_manager.begin_battle()
	_resources.prepare(CardDB.all().keys())
	runtime.mode = "local"
	runtime.local_team = 0
	runtime._match_started = true
	queue_redraw()
	_workbench.enabled = true
	_workbench.inspect_enabled = true
	_hide_menu()
	_setup_battle_presentation()
	StealthTransition3D.prepare_visual(_battle_presentation)
	_create_towers()
	world.build_navigation()
	_art_dev_panel = WORKBENCH_SCRIPT.new()
	add_child(_art_dev_panel)
	_art_dev_panel.setup(CardDB.all())
	_art_dev_panel.item_selected.connect(_set_art_dev_selection)
	_art_dev_panel.team_changed.connect(_set_art_dev_team)
	_art_dev_panel.form_selected.connect(func(form): _workbench.form = form)
	_art_dev_panel.active_skill_selected.connect(_on_art_dev_active_skill_selected)
	_art_dev_panel.active_skill_requested.connect(_use_art_dev_active_skill)
	_art_dev_panel.scenario_requested.connect(_run_workbench_scenario)
	_art_dev_panel.spell_active_changed.connect(func(enabled): _workbench.spell_active = enabled)
	_art_dev_panel.workspace_changed.connect(_set_workbench_battle_active)
	_art_dev_panel.skill_resource_requested.connect(_set_art_dev_skill_resource)
	_art_dev_panel.clear_requested.connect(_clear_art_dev_units)
	_set_art_dev_selection("garen")
	_set_art_dev_team(0)
	_set_workbench_battle_active(false)
	_art_dev_panel.enable_desktop_layout()
	_art_dev_panel.exit_requested.connect(func():
		get_tree().reload_current_scene()
	)

func _start_server() -> void:
	if runtime.game_over or _network_peer != null: return
	runtime.mode = "server"
	runtime.local_team = -1
	runtime.session = MatchSession.new()
	runtime.session.open(Crypto.new().generate_random_bytes(16).hex_encode())
	var peer := ENetMultiplayerPeer.new()
	var err := _bind_server_peer(peer)
	if err != OK:
		peer.close()
		_fail_startup("服务器启动失败：端口 %d，错误 %d" % [_network_port, err])
		return
	_network_peer = peer
	multiplayer.server_relay = false
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("[联机] 服务器已启动，端口 %d，等待两个客户端" % _network_port)

## 端口绑定单独注入验证失败分支；生产仍使用同一ENet绑定。
func _bind_server_peer(peer: ENetMultiplayerPeer) -> Error:
	return peer.create_server(_network_port)

func _on_peer_connected(peer_id: int) -> void:
	if runtime.mode != "server": return
	if runtime.session.team_for_peer(peer_id) >= 0: return
	var team := runtime.session.bind_player(peer_id)
	if team < 0:
		_network_peer.disconnect_peer(peer_id)
		return
	print("[联机] 玩家 %d 已绑定" % team)
	_network_loading_started = Time.get_ticks_msec()
	_snapshot_system.reset_session(runtime.session.session_id)
	_rpc_offer.rpc_id(peer_id, runtime.session.session_id, MatchSession.PROTOCOL_VERSION, MatchSession.content_fingerprint(), team)

func _network_failed(message: String) -> void:
	if runtime.session.phase in [MatchSession.Phase.FINISHED, MatchSession.Phase.DISCONNECTED]: return
	print("[联机] " + message)
	if runtime.mode == "server": _broadcast(_rpc_abort, [runtime.session.session_id, message])
	var was_running := runtime.session.phase == MatchSession.Phase.RUNNING
	runtime.session.finish(true)
	if was_running:
		_end_game(-1, "disconnect")
	else:
		_fail_startup(message)
	if _audio_manager != null: _audio_manager.end_battle()
	if runtime.mode == "server":
		_schedule_server_reset()
	else:
		_close_network()

func _close_network() -> void:
	if _network_peer == null: return
	_network_peer.close()
	if multiplayer.multiplayer_peer == _network_peer: multiplayer.multiplayer_peer = null
	_network_peer = null

func _schedule_server_reset() -> void:
	if not server_auto_restart or _server_reset_pending: return
	_server_reset_pending = true
	# 留出可靠终局/中止消息发送窗口；新场景生成新 match_id 并清除全部状态。
	await get_tree().create_timer(1.0, true).timeout
	get_tree().reload_current_scene()

func _on_peer_disconnected(peer_id: int) -> void:
	if runtime.mode != "server" or runtime.session.team_for_peer(peer_id) < 0: return
	if runtime.game_over or runtime.session.phase == MatchSession.Phase.FINISHED:
		if multiplayer.get_peers().is_empty(): _schedule_server_reset()
	else:
		_network_failed("玩家已断线，对局停止")

@rpc("authority", "call_remote", "reliable")
func _rpc_abort(epoch: String, message: String) -> void:
	if runtime.mode != "client" or epoch != runtime.session.session_id: return
	_network_failed(message)

@rpc("authority", "call_remote", "reliable")
func _rpc_offer(epoch: String, protocol: int, fingerprint: String, assigned_team: int) -> void:
	if runtime.mode != "client" or runtime._match_started or not runtime.session.join(epoch): return
	if protocol != MatchSession.PROTOCOL_VERSION or fingerprint != MatchSession.content_fingerprint() or assigned_team not in [0, 1]:
		_network_failed("协议或卡牌规则版本不一致")
		return
	runtime.local_team = assigned_team
	DisplayServer.window_set_title("Clash Legends — 玩家 %d" % (runtime.local_team + 1))
	_network_loading_started = Time.get_ticks_msec()
	_snapshot_system.reset_session(epoch)
	_rpc_register_deck.rpc_id(1, runtime._deck, runtime._active_skill_choices, epoch, protocol, fingerprint)
	if _menu_status != null: _menu_status.text = "已连接，等待另一名玩家…"

func _start_client(ip: String) -> void:
	if _network_peer != null or runtime._match_started: return
	runtime.session = MatchSession.new()
	if runtime._deck.is_empty(): runtime._deck = CardDB.selectable_ids().slice(0, 8)
	runtime.mode = "client"
	runtime.local_team = -1
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, _network_port)
	if err != OK:
		if _menu_status != null: _menu_status.text = "连接失败：%s" % ip
		return
	_network_peer = peer
	multiplayer.multiplayer_peer = peer
	if _menu_status != null: _menu_status.text = "正在连接 %s:%d …" % [ip, _network_port]
	print("[联机] 客户端：正在连接 %s:%d" % [ip, _network_port])
	if not multiplayer.connection_failed.is_connected(_on_connection_failed): multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected): multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_connection_failed() -> void:
	if runtime.mode == "client": _network_failed("连接失败")

func _on_server_disconnected() -> void:
	if runtime.mode == "client": _network_failed("服务器已断线，对局停止")

func _begin_net_match_server() -> void:
	# 服务器只建立规则实体与两队钱包，不创建玩家界面或准备美术/音频资源。
	runtime.bind_account(0 if runtime.mode == "server" else runtime.local_team, ElixirManager.new())
	runtime.bind_account(1, ElixirManager.new())
	add_child(runtime.account(0 if runtime.mode == "server" else runtime.local_team))
	add_child(runtime.account(1))
	for team in [0, 1]: runtime._initialize_authoritative_card_cycle(team, runtime._team_deck(team))
	_create_towers()
	world.build_navigation()
	runtime.session.local_ready = true

@rpc("authority", "call_remote", "reliable")
func _rpc_start(epoch: String, remote_deck: Array, remote_choices: Dictionary) -> void:
	if runtime.mode != "client" or runtime._match_started or _battle_loading or runtime.session.local_ready or not runtime.session.accepts(1, epoch, MatchSession.Phase.LOADING): return
	if not MatchSession.valid_deck(remote_deck, remote_choices):
		_network_failed("服务器卡组信息无效")
		return
	runtime._remote_deck = remote_deck.duplicate()
	runtime._remote_active_skill_choices = remote_choices.duplicate()
	_network_loading_started = Time.get_ticks_msec()
	await _load_battle(_begin_net_match_client, true)

func _begin_net_match_client() -> void:
	_audio_manager.begin_battle()
	_hide_menu()
	if runtime.local_team == 1: _flip_camera()
	_setup_battle_presentation()
	_setup_player_ui()
	_create_towers()
	world.build_navigation()
	_create_timer_ui()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_loaded(epoch: String) -> void:
	if runtime.mode != "server" or not runtime.session.mark_remote_ready(multiplayer.get_remote_sender_id(), epoch): return
	_try_start_network_match()

func _try_start_network_match() -> void:
	if not runtime.session.start(): return
	runtime._match_started = true
	for team in [0, 1]:
		_rpc_running.rpc_id(runtime.session.peer_for_team(team), runtime.session.session_id, visible_hand_state(team))
	print("[联机] 双客户端就绪，开始模拟")

@rpc("authority", "call_remote", "reliable")
func _rpc_running(epoch: String, state: Dictionary) -> void:
	if runtime.mode != "client" or not runtime.session.mark_remote_ready(1, epoch): return
	if not _apply_client_hand_state(state):
		_network_failed("初始手牌数据无效")
		return
	if runtime.session.start(): runtime._match_started = true

func visible_hand_state(team: int) -> Dictionary:
	return runtime.visible_hand_state(team)

func _apply_client_hand_state(state: Dictionary) -> bool:
	if not _client_hand.apply(state, runtime._deck): return false
	if _hand != null: _hand.set_visible_state(_client_hand.hand, _client_hand.next_card)
	runtime._card_history.replace_replica(runtime.local_team, _client_hand.history)
	_refresh_mirror_hand(runtime.local_team)
	return true

func get_next_card(team: int) -> String:
	if is_net_client(): return _client_hand.next_card if team == runtime.local_team else ""
	var queue := runtime.get_authoritative_queue(team)
	return String(queue[0]) if not queue.is_empty() else ""

func has_presentation() -> bool:
	return runtime.mode != "server"

const BUFFERED_BATTLE_EVENTS := {
	&"_rpc_action_cancelled": true,
	&"_rpc_active_skill_used": true,
	&"_rpc_attack_audio_hit": true,
	&"_rpc_attack_hit_visual": true,
	&"_rpc_card_event": true,
	&"_rpc_card_pre_deploy_started": true,
	&"_rpc_corrosion_fx": true,
	&"_rpc_summoning_fx": true,
	&"_rpc_freeze_fx": true,
	&"_rpc_heal_fx": true,
	&"_rpc_lightning_area": true,
	&"_rpc_lightning_fx": true,
	&"_rpc_projectile_impact_fx": true,
	&"_rpc_projectile_launch_audio": true,
	&"_rpc_restoration_heal": true,
	&"_rpc_skill_fx": true,
	&"_rpc_spawn_unit": true,
	&"_rpc_spell_arrival": true,
	&"_rpc_spell_flight": true,
	&"_rpc_tower_hit": true,
	&"_rpc_unit_audio_event": true,
	&"_rpc_unit_died": true,
	&"_rpc_unit_forge_audio": true,
	&"_rpc_unit_hit": true,
	&"_rpc_zone_audio": true,
	&"_rpc_command_finished": true,
}

## 公共战场事件仅发给绑定的两名玩家，未握手连接不能旁听。
func _broadcast(endpoint: Callable, args: Array) -> void:
	if _network_peer == null: return
	for team in runtime.session.players:
		var peer := runtime.session.peer_for_team(team)
		if not multiplayer.get_peers().has(peer): continue
		var method := endpoint.get_method()
		if BUFFERED_BATTLE_EVENTS.has(method):
			if method in [&"_rpc_unit_audio_event", &"_rpc_attack_audio_hit"]:
				_rpc_battle_event_unreliable.rpc_id(peer, runtime.session.session_id, runtime._sim_tick_id, method, args)
			else:
				_rpc_battle_event.rpc_id(peer, runtime.session.session_id, runtime._sim_tick_id, method, args)
		else:
			callv("rpc_id", [peer, method] + args)

@rpc("authority", "call_remote", "reliable")
func _rpc_battle_event(epoch: String, tick: int, method: StringName, args: Array) -> void:
	_receive_battle_event(epoch, tick, method, args)

@rpc("authority", "call_remote", "unreliable", 1)
func _rpc_battle_event_unreliable(epoch: String, tick: int, method: StringName, args: Array) -> void:
	_receive_battle_event(epoch, tick, method, args)

func _receive_battle_event(epoch: String, tick: int, method: StringName, args: Array) -> void:
	if runtime.mode != "client" or runtime.game_over or not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING): return
	if not BUFFERED_BATTLE_EVENTS.has(method) or tick < 0: return
	_observe_network_arrival(tick)
	if not _network_playback.enqueue(tick, method, args): _network_failed("网络表现队列已满，对局停止")

func _observe_network_arrival(tick: int) -> void:
	if _network_clock.synchronized:
		_network_playback.observe_delay(maxf(0.0, _network_clock.estimate(Time.get_ticks_msec()) - float(tick)) * SIM_DT * 1000.0)

func _advance_network_playback() -> void:
	var server_time := float(get_estimated_server_tick()) + _estimated_server_tick_fraction / SIM_DT
	for event in _network_playback.advance(server_time):
		if runtime.game_over: break
		# 更新的快照已包含次数/CD，迟到旧通知不能把它们回拨。
		if event.method == &"_rpc_active_skill_used" and int(event.tick) < _snapshot_system.lifecycle.snapshot_tick: continue
		callv(event.method, event.args)

func get_presentation_tick() -> float:
	if not is_net_client(): return float(runtime._sim_tick_id)
	return _network_playback.tick if _network_peer != null else float(get_estimated_server_tick())

func _update_command_countdowns() -> void:
	if _active_skill_bar == null: return
	_network_commands.visit(func(command):
		if command.kind == "skill" and int(command.team) == runtime.local_team:
			_active_skill_bar.set_pending_seconds(int(command.ability_id), maxf(0.0, float(command.execute_tick) - get_presentation_tick()) * SIM_DT))

## 独立时钟通道；客户端时钟只用于提交时间和播放时间，不驱动规则。
@rpc("any_peer", "call_remote", "unreliable", 2)
func _rpc_clock_probe(epoch: String, probe_id: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if runtime.mode != "server" or not runtime.session.accepts(sender, epoch, MatchSession.Phase.RUNNING) or probe_id <= 0: return
	var now := Time.get_ticks_msec()
	if now - int(_clock_probe_last_by_peer.get(sender, -1000)) < 200: return
	_clock_probe_last_by_peer[sender] = now
	# 固定时钟积压不能冒充已执行Tick；只携带不足一Tick的相位。
	var tick_time := float(runtime._sim_tick_id) + minf(runtime._simulation_clock.remainder / SIM_DT, 0.999)
	_rpc_clock_sample.rpc_id(sender, epoch, probe_id, tick_time)

@rpc("authority", "call_remote", "unreliable", 2)
func _rpc_clock_sample(epoch: String, probe_id: int, tick_time: float) -> void:
	if runtime.mode != "client" or runtime.game_over or not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING): return
	if not _network_clock.accept_probe(probe_id, tick_time, Time.get_ticks_msec()): return
	_network_playback.observe_delay(_network_clock.rtt_msec * 0.5 + _network_clock.jitter_msec)
	var corrected := _network_clock.estimate(Time.get_ticks_msec())
	_estimated_server_tick = int(floor(corrected))
	_estimated_server_tick_fraction = (corrected - floor(corrected)) * SIM_DT
	_has_estimated_server_tick = true

func _tick_network_clock(delta: float) -> void:
	if _network_peer == null or not runtime._match_started or runtime.session.phase != MatchSession.Phase.RUNNING: return
	_clock_probe_timer -= delta
	if _clock_probe_timer > 0.0: return
	_clock_probe_timer = 1.0 if _network_clock.synchronized else 0.25
	var probe := _network_clock.begin_probe(Time.get_ticks_msec())
	_rpc_clock_probe.rpc_id(1, runtime.session.session_id, probe)

@rpc("authority", "call_remote", "reliable")
func _rpc_command_scheduled(epoch: String, command: Dictionary) -> void:
	if runtime.mode != "client" or runtime.game_over or not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING): return
	if not _network_commands.receive(command): return
	# 只准备已知资源/记录时序，不创建实体，不提前暴露对方的操作提示。
	_resources.prepare([command.card_id])
	if command.kind == "skill" and int(command.team) == runtime.local_team:
		_client_inputs.forget_skill(int(command.ability_id))
		if _active_skill_bar != null: _active_skill_bar.set_pending(int(command.ability_id), true)
	network_command_announced.emit(command.duplicate(true))

func _complete_network_command(id: int, outcome: String) -> void:
	var command := _network_commands.finish(id)
	if command.is_empty(): return
	if runtime.mode == "server": _broadcast(_rpc_command_finished, [runtime.session.session_id, id, outcome])

@rpc("authority", "call_remote", "reliable")
func _rpc_command_finished(epoch: String, id: int, outcome: String) -> void:
	if runtime.mode != "client" or runtime.game_over or not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING): return
	if outcome not in ["executed", "cancelled"]: return
	var command := _network_commands.finish(id)
	if command.is_empty(): return
	if command.kind == "skill" and int(command.team) == runtime.local_team:
		var pending := _network_commands.has_skill(int(command.ability_id))
		if not pending: _client_inputs.forget_skill(int(command.ability_id))
		if _active_skill_bar != null: _active_skill_bar.set_pending(int(command.ability_id), pending)
	network_command_finished.emit(command, outcome)

## 红方使用同一画布构图翻转，让自己半场显示在屏幕下方。
func _flip_camera() -> void:
	_refresh_display_layout()

func _refresh_display_layout() -> void:
	if _workbench.enabled or not has_presentation(): return
	var size := get_viewport_rect().size
	var transform := BATTLE_LAYOUT.canvas(size, runtime.local_team == 1)
	get_viewport().canvas_transform = transform
	if is_instance_valid(_battle_presentation):
		_battle_presentation.set_view_rect(BATTLE_LAYOUT.visible_world(size, transform))
	if is_instance_valid(_hand): _hand.apply_layout(size)
	if is_instance_valid(_active_skill_bar): _active_skill_bar.apply_layout(size)
	if is_instance_valid(_timer_label):
		var ui_scale := BATTLE_LAYOUT.ui_scale(size)
		_timer_label.scale = Vector2.ONE * ui_scale
		_timer_label.position = Vector2(size.x * 0.5 + 228.0 * ui_scale, 8.0 * ui_scale)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var window := get_window()
		window.mode = Window.MODE_WINDOWED if window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN] else Window.MODE_FULLSCREEN
		get_viewport().set_input_as_handled()

func _setup_player_ui() -> void:
	if not _battle_loading:
		_resources.prepare(CardDB.selectable_ids() if runtime._deck.is_empty() else runtime._deck)
		_resources.prepare(runtime._remote_deck + MatchResources.SYSTEM_UNIT_BUDGET.keys())
	runtime.bind_account(0 if runtime.mode == "server" else runtime.local_team, ElixirManager.new())
	add_child(runtime.account(0 if runtime.mode == "server" else runtime.local_team))
	_hand = CardHand.new()
	add_child(_hand)
	_hand.setup(runtime.account(0 if runtime.mode == "server" else runtime.local_team), runtime._deck)
	_hand.growth_progress_query = func(id: String) -> Dictionary: return runtime._card_growth.progress(runtime.local_team, id)
	_hand.visual_card_query = func(id: String) -> String: return runtime._card_growth.resolved_id(runtime.local_team, id)
	_hand.cost_query = func(id: String) -> int: return runtime.card_cost_for_team(runtime.local_team, id)
	_hand.set_active_skill_cards(runtime._deck.slice(0, 2))
	_hand.card_selected.connect(_on_card_selected)
	if not is_net_client(): runtime._initialize_authoritative_card_cycle(runtime.local_team, runtime._deck)
	if runtime.mode == "local":
		runtime._initialize_authoritative_card_cycle(1, runtime._remote_deck)
	_active_skill_bar = ACTIVE_SKILL_BAR_SCRIPT.new()
	_active_skill_bar.can_submit = _can_submit_active_skill
	add_child(_active_skill_bar)
	_active_skill_bar.skill_pressed.connect(_on_active_skill_pressed)
	_active_skill_bar.set_elixir(runtime.account(0 if runtime.mode == "server" else runtime.local_team).elixir)
	runtime.account(0 if runtime.mode == "server" else runtime.local_team).changed.connect(_active_skill_bar.set_elixir)

func _is_local_player_team(p_team: int) -> bool:
	return runtime.mode != "server" and p_team == runtime.local_team

func _sync_card_cycle_ui(p_team: int) -> void:
	if _hand != null and _is_local_player_team(p_team):
		var cycle: CardCycle = runtime._authoritative_card_cycles.get(p_team)
		if cycle == null: return
		_hand.set_cycle_state(cycle.hand(), cycle.queue())

## 客户端只用本地时间估计服务器 Tick；这里不调用 _sim_step，也不触碰任何战斗状态。
func _advance_estimated_server_tick(delta: float) -> void:
	if runtime.mode != "client" or not _has_estimated_server_tick or delta <= 0.0:
		return
	_estimated_server_tick_fraction += delta
	while _estimated_server_tick_fraction >= SIM_DT:
		_estimated_server_tick += 1
		_estimated_server_tick_fraction -= SIM_DT

## 接收快照中的权威时钟。乱序快照被拒绝；若本地估计已经领先，则不让旧快照把命令时钟拨回去。
func _accept_authoritative_server_tick(server_tick: int) -> bool:
	if runtime.mode != "client" or server_tick < 0 or server_tick < _authoritative_server_tick:
		return false
	_authoritative_server_tick = server_tick
	if not _has_estimated_server_tick or server_tick >= _estimated_server_tick:
		_estimated_server_tick = server_tick
		_estimated_server_tick_fraction = 0.0
	_has_estimated_server_tick = true
	return true

func network_session_id() -> String:
	return runtime.session.session_id

func reset_network_clock() -> void:
	_network_clock.reset()
	_client_hand.clear()
	_client_inputs.clear()
	_network_playback.clear()
	_network_commands.clear()
	_clock_probe_timer = 0.0
	_clock_probe_last_by_peer.clear()
	_authoritative_server_tick = 0
	_estimated_server_tick = 0
	_estimated_server_tick_fraction = 0.0
	_has_estimated_server_tick = false
	_snapshots_received = 0

func get_estimated_server_tick() -> int:
	return _estimated_server_tick if _has_estimated_server_tick else _authoritative_server_tick

## Host/单机本地输入发生在当前权威 Tick；客户端请求则携带点击时观察到的 input_tick。
func _input_tick_for_new_command() -> int:
	return _current_authority_tick()

## 仅供 Host/单机本地命令读取其固定的 10 Tick 目标；网络请求不能直接提交 execute_tick。
func _authority_tick_for_new_command() -> int:
	return _input_tick_for_new_command() + COMMAND_DELAY_TICKS

func _current_authority_tick() -> int:
	return get_estimated_server_tick() if runtime.mode == "client" else runtime._sim_tick_id

func get_authoritative_server_tick() -> int:
	return _authoritative_server_tick if runtime.mode == "client" else runtime._sim_tick_id

func is_net_client() -> bool:
	return runtime.mode == "client"

## 固定模拟完成后剩余时间占一个 tick 的比例。所有本地表现共用该值，避免各节点
## 独立累计插值进度，或因 Unit / 3D 代理的 _process 顺序不同而前后跳动。
func get_sim_interpolation_alpha() -> float:
	if runtime.mode == "client":
		return 1.0
	return clampf(runtime._simulation_clock.remainder / SIM_DT, 0.0, 1.0)

func _setup_battle_presentation() -> void:
	if _battle_presentation != null:
		return
	_battle_presentation = load("res://scripts/presentation/battle_presentation_3d.gd").new()
	_battle_presentation.tool_material_mode = _workbench.enabled
	_battle_presentation.resource_failed.connect(_fail_preparation)
	add_child(_battle_presentation)
	_battle_presentation.setup(Vector2(ArenaRules.FIELD_W, ArenaRules.FIELD_H), ArenaRules.TILE_SIZE, runtime.local_team == 1)
	_battle_presentation.spells = _spell_system
	_battle_presentation.skills = _skill_presentation
	_battle_presentation.projectiles = _projectile_system
	_battle_presentation.pending_deployments = runtime._commands.inspect_deployments
	_arena_background_sprite.hide()
	_refresh_display_layout()

## 顶部右侧的比赛计时器
func _create_timer_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 32)
	# CR 计时器位于顶部右侧；避开按官方格位上移后的敌方国王塔血条。
	_timer_label.position = Vector2(get_viewport_rect().size.x * 0.5 + 228.0, 8.0)
	layer.add_child(_timer_label)
	_update_timer_label()

func _create_towers() -> void:
	world.create_towers()
	if _battle_presentation != null:
		for tower in world.towers_snapshot():
			_battle_presentation.attach_tower(tower, CardDB.NEXUS_VISUAL_CONFIG if tower.is_king else CardDB.PRINCESS_TOWER_VISUAL_CONFIG)
	if has_presentation():
		if _cast_notice == null:
			var notice_layer := CanvasLayer.new()
			notice_layer.layer = 2
			add_child(notice_layer)
			_cast_notice = preload("res://scripts/presentation/cast_notice.gd").new()
			notice_layer.add_child(_cast_notice)
		_cast_notice.nexuses = [world.king(0), world.king(1)]
		_cast_notice.presentation = _battle_presentation
	for tower in world.towers_snapshot():
		var audio_id := PresentationConfig.world_card_id(tower)
		tower.destroyed.connect(_on_world_building_destroyed.bind(audio_id, weakref(tower)))
		if _audio_manager != null:
			_audio_manager.attach_building_audio(tower, CardDB.NEXUS_VISUAL_CONFIG if tower.is_king else CardDB.PRINCESS_TOWER_VISUAL_CONFIG)

func _on_world_building_destroyed(audio_id: String, tower_ref: WeakRef) -> void:
	var tower = tower_ref.get_ref()
	if is_instance_valid(tower) and _audio_manager != null:
		_audio_manager.stop_building_audio(tower.get_instance_id())
		if tower.is_king:
			_audio_manager.play_nexus_destruction(tower)
		else:
			_audio_manager.play_card_event(audio_id, "death", tower.global_position, 0, tower.team)

## 构建导航网格：河道（除两座桥）与所有防御塔为障碍

func _on_card_selected(card_id: String) -> void:
	_selected_card = card_id
	_update_deployment_preview(get_global_mouse_position())
	queue_redraw()

func _clear_deployment_preview() -> void:
	_deployment_preview_pos = Vector2.ZERO
	_deployment_preview_tile = Vector2i(-1, -1)
	_deployment_preview_valid = false
	_deployment_preview_visible = false

## 把鼠标位置转换成当前卡牌的部署预览。预览会保留在非法格上并显示红色，
## 让玩家知道为什么点击不会生效，而不是把鼠标悄悄吸到另一个格子。
func _update_deployment_preview(pointer_pos: Vector2) -> void:
	_clear_deployment_preview()
	if _selected_card.is_empty() or not CardDB.has_card(_selected_card):
		queue_redraw()
		return
	if pointer_pos.x < 0.0 or pointer_pos.x >= ArenaRules.FIELD_W or pointer_pos.y < 0.0 or pointer_pos.y >= ArenaRules.FIELD_H:
		queue_redraw()
		return
	var my_team := runtime.local_team
	var tile := runtime._deployment_rules.world_to_arena_tile(pointer_pos)
	tile.x = clampi(tile.x, 0, ArenaRules.ARENA_COLUMNS - 1)
	tile.y = clampi(tile.y, 0, ArenaRules.ARENA_ROWS - 1)
	_deployment_preview_tile = tile
	_deployment_preview_pos = runtime._snap_card_position(_selected_card, pointer_pos, my_team)
	_deployment_preview_visible = true
	_deployment_preview_valid = runtime.is_card_deploy_position_valid(my_team, _selected_card, _deployment_preview_pos)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if _workbench.enabled:
		if _art_dev_panel == null or not _art_dev_panel.accepts_battle_input(): return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_workbench_map_click(get_viewport().canvas_transform.affine_inverse() * event.position)
		return
	if runtime.game_over or _selected_card == "":
		return
	if event is InputEventMouseMotion:
		_update_deployment_preview(get_viewport().canvas_transform.affine_inverse() * event.position)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 点击前再刷新一次，确保刚进入目标格时使用的是屏幕上看到的那一格。
		_update_deployment_preview(get_viewport().canvas_transform.affine_inverse() * event.position)
		if not _deployment_preview_visible:
			return
		var my_team := runtime.local_team
		var pos := _deployment_preview_pos
		if not _deployment_preview_valid:
			return
		var used_card := _selected_card
		var accepted := play_card(my_team, used_card, pos, {
			"elixir": runtime.account(0 if runtime.mode == "server" else runtime.local_team),
			"client_request": runtime.mode == "client",
		})
		if not accepted:
			return
		_selected_card = ""
		_clear_deployment_preview()
		_hand.clear_selection()
		queue_redraw()

func _workbench_map_click(position: Vector2) -> void:
	if not _workbench.enabled or _art_dev_panel == null or not _art_dev_panel.accepts_battle_input(): return
	if not Rect2(0, 0, ArenaRules.FIELD_W, ArenaRules.FIELD_H).has_point(position): return
	if _art_dev_panel.is_select_mode():
		_workbench.pick(get_tree().get_nodes_in_group("combatants"), position, get_viewport().canvas_transform)
		_sync_art_dev_panel_state()
		queue_redraw()
	elif _art_dev_panel.has_placeable_selection():
		_place_art_dev_item(position)

func _art_dev_skill_source(unit: Unit) -> String:
	if unit == null or bool(unit.get_meta("workbench_no_skill", false)): return ""
	var source := unit.active_skill_card_id if not unit.active_skill_card_id.is_empty() else unit.card_id
	return unit.card_id if CardDB.get_card(source).has("growth_ranged_id") else source

func _place_art_dev_item(pos: Vector2) -> void:
	if _workbench.selection == "training_dummy":
		pos = runtime._deployment_rules.snap_to_tile_center(pos)
		var stats := CardDB.training_dummy_stats()
		var dummy := Unit.new()
		dummy.position = pos
		dummy.setup(1 - _workbench.team, stats, stats.name)
		dummy.card_id = "training_dummy"
		add_child(dummy)
		world.register_dynamic_building(dummy)
		_workbench.last_units[_art_dev_unit_key("training_dummy", 1 - _workbench.team)] = weakref(dummy)
		if _workbench.inspect_enabled: _workbench.inspect(dummy)
		_sync_art_dev_panel_state()
		return
	if not CardDB.has_card(_workbench.selection):
		return
	var deployment_id := preload("res://scripts/ui/workbench/card_catalog.gd").deployment_id(_workbench.selection, _workbench.form)
	pos = runtime._snap_card_position(deployment_id, pos, _workbench.team)
	if play_card(_workbench.team, deployment_id, pos, {"immediate": true, "validate_position": false, "preview_active_spell": _workbench.spell_active}):
		var source_card := runtime.resolved_card_for_team(_workbench.team, deployment_id)
		var unit := _latest_unit_for_card(source_card, _workbench.team)
		if CardPlayHistory.is_mirror(_workbench.selection) and _workbench.spell_active:
			for id in runtime._active_skills.ids():
				var entry := runtime._active_skills.entry(int(id))
				if int(entry.team) == _workbench.team and int(entry.slot) == 0: unit = entry.unit
		if unit != null:
			if _workbench.form == 1 and CardDB.get_card(_workbench.selection).has("transformed_stats"):
				unit.transform_to_mega(true)
			_workbench.last_units[_art_dev_unit_key(_workbench.selection, _workbench.team)] = weakref(unit)
			_workbench.last_groups[_art_dev_unit_key(_workbench.selection, _workbench.team)] = unit.deployment_group_id
			if not CardPlayHistory.is_mirror(_workbench.selection) or _workbench.spell_active:
				_configure_art_dev_unit_skill(unit)
			_sync_art_dev_panel_state()

func _latest_unit_for_card(card_id: String, p_team: int) -> Unit:
	var latest: Unit = null
	for combatant in get_tree().get_nodes_in_group("combatants"):
		if combatant is Unit and combatant.hp > 0.0 and not combatant.is_queued_for_deletion() and combatant.team == p_team:
			if combatant.active_skill_card_id == card_id:
				latest = combatant as Unit
	return latest

func _art_dev_selected_unit() -> Unit:
	if _workbench.inspect_enabled: return _workbench.inspected_unit()
	var selection_team := 1 - _workbench.team if _workbench.selection == "training_dummy" else _workbench.team
	var candidate_ref = _workbench.last_units.get(_art_dev_unit_key(_workbench.selection, selection_team))
	var candidate = (candidate_ref as WeakRef).get_ref() if candidate_ref is WeakRef else null
	if is_instance_valid(candidate) and candidate is Unit and candidate.hp > 0.0:
		return candidate as Unit
	var group_id := int(_workbench.last_groups.get(_art_dev_unit_key(_workbench.selection, _workbench.team), -1))
	var members := runtime.living_deployment_members(group_id, _workbench.team)
	if not members.is_empty():
		_workbench.last_units[_art_dev_unit_key(_workbench.selection, _workbench.team)] = weakref(members[0])
		return members[0]
	return null

func _art_dev_unit_key(card_id: String, p_team: int) -> String:
	return "%s:%d" % [card_id, p_team]

func _set_art_dev_selection(item_id: String) -> void:
	_workbench.select(item_id)

func _set_art_dev_team(team: int) -> void:
	_workbench.set_team(team)

func _art_dev_selected_skill(card_id: String = "", requested_index: int = -1) -> Dictionary:
	var resolved_card_id := _workbench.selection if card_id.is_empty() else card_id
	if CardPlayHistory.is_mirror(resolved_card_id):
		var unit := _art_dev_selected_unit()
		if unit == null or unit.active_ability_id < 0: return {}
		resolved_card_id = unit.active_skill_card_id
	if CardDB.get_card(resolved_card_id).has("growth_ranged_id"):
		var selected := _art_dev_selected_unit()
		if selected != null: resolved_card_id = selected.card_id
	var skills := CardDB.active_skills_for(resolved_card_id)
	if skills.is_empty():
		return {}
	var selected_index := requested_index
	if selected_index < 0:
		selected_index = int(_workbench.skill_choices.get(resolved_card_id, 0))
	selected_index = clampi(selected_index, 0, skills.size() - 1)
	return skills[selected_index]

func _configure_art_dev_unit_skill(unit: Unit) -> void:
	var skill := _art_dev_selected_skill(unit.active_skill_card_id if not unit.active_skill_card_id.is_empty() else unit.card_id)
	if skill.is_empty():
		unit.clear_carried_active_skill_resource()
	else:
		unit.configure_carried_active_skill(skill)

func _on_art_dev_active_skill_selected(item_id: String, skill_index: int) -> void:
	var skills := CardDB.active_skills_for(item_id)
	if skills.is_empty():
		return
	_workbench.skill_choices[item_id] = clampi(skill_index, 0, skills.size() - 1)
	var unit := _art_dev_selected_unit()
	if unit != null and item_id == (_art_dev_skill_source(unit) if _workbench.inspect_enabled else runtime.resolved_card_for_team(_workbench.team, _workbench.selection)):
		_configure_art_dev_unit_skill(unit)
	_sync_art_dev_panel_state()

## 工作台不消耗正式主动资格；技能取显式目标的来源卡，不取待放置卡。
func _use_art_dev_active_skill(skill_index: int = -1) -> void:
	var unit := _art_dev_selected_unit()
	if unit == null or not unit.is_deployed() or unit.is_active_skill_rush_locked() or unit.is_form_transitioning() or unit.is_active_skill_casting():
		return
	if _workbench.inspect_enabled and _art_dev_skill_source(unit).is_empty(): return
	var skill := _art_dev_selected_skill(_art_dev_skill_source(unit) if _workbench.inspect_enabled else _workbench.selection, skill_index)
	if skill.is_empty():
		return
	var skill_source := _art_dev_skill_source(unit)
	_workbench.skill_choices[skill_source] = clampi(skill_index, 0, CardDB.active_skills_for(skill_source).size() - 1) if skill_index >= 0 else int(_workbench.skill_choices.get(skill_source, 0))
	unit.configure_carried_active_skill(skill)
	# 工作台无限预览按本实例循环次数变体，不消费正式对局资格。
	var preview_key := "workbench_skill_use_" + str(int(_workbench.skill_choices.get(skill_source, 0)))
	var preview_use := int(unit.get_meta(preview_key, 0))
	var prepared := ActiveSkillRoster.prepare_use(skill, preview_use)
	if preview_active_skill(unit, prepared):
		unit.set_meta(preview_key, (preview_use + 1) % maxi(int(skill.get("max_uses", 1)), 1))
	_sync_art_dev_panel_state()

func _set_art_dev_skill_resource(value: float) -> void:
	var unit := _art_dev_selected_unit()
	if unit == null or not unit.is_skill_resource_visible() or unit.skill_resource_max <= 0.0:
		return
	unit.skill_resource_value = clampf(value, 0.0, unit.skill_resource_max)
	unit.record_combat_activity()
	unit.queue_redraw()
	_sync_art_dev_panel_state()

## 开发场景操作使用现有单位/出牌接口，不能进入正式比赛。
func _run_workbench_scenario(action: String) -> void:
	_workbench.run_scenario(action)

func _load_workbench_preset(id: String) -> void:
	await _workbench.load_preset(id)

func _rebuild_workbench_arena() -> void:
	world.clear_towers()
	await get_tree().process_frame
	_create_towers()
	world.build_navigation()

func _set_workbench_battle_active(active: bool) -> void:
	_workbench.set_battle_active(active)

func _pause_workbench_battle(paused: bool) -> void:
	for child in get_children():
		if child != _art_dev_panel:
			child.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	if _audio_manager != null: _audio_manager.set_battle_paused(paused)

func _sync_art_dev_panel_state() -> void:
	if _art_dev_panel == null:
		return
	var unit := _art_dev_selected_unit()
	if _workbench.inspect_enabled:
		_art_dev_panel.bind_inspected_unit(unit, _art_dev_skill_source(unit))
	elif CardPlayHistory.is_mirror(_workbench.selection):
		_art_dev_panel.set_mirror_source(unit.active_skill_card_id if unit != null else runtime.resolved_card_for_team(_workbench.team, _workbench.selection), unit != null and unit.active_ability_id >= 0)
	_art_dev_panel.update_selected_unit_state(
		unit != null,
		unit != null and unit.is_deployed(),
		unit != null and (unit.is_active_skill_rush_locked() or unit.is_form_transitioning() or unit.is_active_skill_casting()),
		unit != null and unit.is_skill_resource_visible(),
		unit.skill_resource_value if unit != null else 0.0,
		unit.skill_resource_max if unit != null else 0.0,
	)
	_art_dev_panel.update_live_details(unit)

func preview_active_skill(unit: Unit, skill: Dictionary) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	# ArtDev 只绕过玩家命令缓冲；普通主动仍必须经过 CastStart → EffectExecution → Recovery。
	return runtime._start_active_skill_cast(unit, skill)


func _clear_art_dev_units() -> void:
	_workbench.clear()
	runtime.clear_preview()

func clear_preview_battle() -> void:
	runtime.clear_preview()
	_network_commands.clear()
	_client_inputs.clear()
	_network_playback.clear()
	world.clear_units()
	_projectile_system.clear_all()
	if _cast_notice != null: _cast_notice.clear()
	_spell_system.clear()
	if is_instance_valid(_audio_manager): _audio_manager.clear_spell_flight_audio()
	if _audio_manager != null:
		_audio_manager.begin_battle()
	_active_skill_effect_system.clear()
	_skill_presentation.clear()
	if is_instance_valid(_battle_presentation): _battle_presentation.clear_death_visuals()
	_team_attack_boost_system.clear()
	_sync_art_dev_panel_state()
	queue_redraw()























func launch_attack(attacker: Node2D, target: Node2D, amount: float, projectile_speed: float, splash_radius: float, knockback: float, projectile_color: Color, effects: Dictionary = {}) -> bool:
	var launched := _projectile_system.launch(attacker, target, amount, projectile_speed, splash_radius, knockback, projectile_color, effects)
	if launched and attacker is Tower and is_instance_valid(target) and target.hp > 0.0:
		var source := PresentationConfig.attack_source(attacker)
		present_skill_projectile_hit(source, "attack", attacker.global_position, "cast")
		present_skill_projectile_hit(source, "attack", attacker.global_position, "launch")
	return launched

## 弹体命中表现与伤害结算分离；半径只用于绘制对应的权威溅射范围。
func show_projectile_impact(position: Vector2, radius: float, color: Color, visual: StringName) -> void:
	if has_presentation(): _projectile_system.add_impact_visual(position, radius, color, visual)
	if runtime.mode == "server":
		_broadcast(_rpc_projectile_impact_fx, [runtime.session.session_id, position, radius, color, String(visual)])

## 持续伤害（龙王吐息、审判等）共用的战斗层入口。调用方决定脉冲频率和命中目标，
## 这里统一处理攻击来源、护盾、受击表现、击杀以及可选的普攻击中回调。
func apply_damage_pulse(source: Node2D, target: Node2D, amount: float, splash_radius: float = 0.0, origin: Vector2 = Vector2(INF, INF), counts_as_attack: bool = false, source_form_index: int = -1, effects: Dictionary = {}) -> Dictionary:
	if source == null or not is_instance_valid(source) or target == null or not is_instance_valid(target):
		return BattleNumbers.pending_hit(false, amount)
	if target.hp <= 0.0 or amount <= 0.0:
		return BattleNumbers.pending_hit(false, amount)
	var source_team := int(source.team)
	var source_position := source.global_position if origin.x == INF else origin
	return _combat.resolve_attack_hit(source_team, source_position, target, amount, maxf(splash_radius, 0.0), 0.0, source, source_position, source_form_index, effects, counts_as_attack)

func _tick_projectiles(dt: float) -> void:
	_projectile_system.tick(dt)

func _notify_attack_presentation(source: Dictionary, position: Vector2, first_strike: bool) -> void:
	if source.is_empty():
		return
	if _audio_manager != null:
		_audio_manager.play_attack_source(source, position, first_strike)
	if runtime.mode == "server":
		_broadcast(_rpc_attack_audio_hit, [runtime.session.session_id, source, position, first_strike])
	if source.has("hit_origin"):
		_play_attack_hit_visual(source, position)
		if runtime.mode == "server":
			_broadcast(_rpc_attack_hit_visual, [runtime.session.session_id, source, position])

func _play_attack_hit_visual(source: Dictionary, position: Vector2) -> void:
	if has_presentation() and is_instance_valid(_projectile_system._hit_visuals):
		_projectile_system._hit_visuals.play_hit(source, position, _battle_presentation._world_root, _battle_presentation._camera)

@rpc("authority", "call_remote", "reliable")
func _rpc_attack_hit_visual(epoch: String, source: Dictionary, position: Vector2) -> void:
	if runtime.mode != "client" or runtime.game_over or not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING): return
	_play_attack_hit_visual(source, position)

## 一次范围脉冲即使命中多个目标也只播放一次；空挥/免疫不产生命中声。
func _on_projectile_launch_audio_started(id: int, source: Dictionary, position: Vector2) -> void:
	if _audio_manager != null:
		_audio_manager.start_projectile_launch(id, source, position)
	if runtime.mode == "server":
		_broadcast(_rpc_projectile_launch_audio, [runtime.session.session_id, id, source, position, true])

func _on_projectile_launch_audio_stopped(id: int) -> void:
	if _audio_manager != null:
		_audio_manager.stop_projectile_launch(id)
	if runtime.mode == "server":
		_broadcast(_rpc_projectile_launch_audio, [runtime.session.session_id, id, {}, Vector2.ZERO, false])

@rpc("authority", "call_remote", "reliable")
func _rpc_projectile_launch_audio(epoch: String, id: int, source: Dictionary, position: Vector2, started: bool) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over:
		return
	if runtime.mode != "client" or _audio_manager == null:
		return
	if started:
		_audio_manager.start_projectile_launch(id, source, position)
	else:
		_audio_manager.stop_projectile_launch(id)

func notify_unit_audio_event(unit: Unit, cue: StringName, position: Vector2) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	unit.presentation_cue.emit(cue)
	if cue == &"revival:end" and _audio_manager != null:
		_audio_manager.complete_revival(unit)
	if cue in [&"deploy:hit", &"replacement:start", &"revival:end", &"shield:cast", &"shield:applied"]:
		present_skill_projectile_hit(PresentationConfig.attack_source(unit), String(cue).get_slice(":", 0), position, String(cue).get_slice(":", 1))
		return
	if _audio_manager != null:
		_audio_manager.play_event(unit, cue, position)
	if runtime.mode == "server" and unit.net_id >= 0:
		if cue in [&"forge:pulse", &"forge:cancel"]:
			_broadcast(_rpc_unit_forge_audio, [runtime.session.session_id, unit.net_id, String(cue), position])
		else:
			_broadcast(_rpc_unit_audio_event, [runtime.session.session_id, unit.net_id, String(cue), position, unit.presentation_state().attack_serial, unit.get_visual_action_serial() if unit.active_skill_cast_timer > 0.0 else -1])

@rpc("authority", "call_remote", "unreliable")
func _rpc_unit_audio_event(epoch: String, net_id: int, cue: String, position: Vector2, attack_serial: int = -1, action_serial: int = -1) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over:
		return
	if runtime.mode != "client":
		return
	var unit: Unit = world.find_replica_unit(net_id)
	if unit != null and is_instance_valid(unit):
		unit.presentation_cue.emit(StringName(cue))
		if _audio_manager != null:
			_audio_manager.play_event(unit, StringName(cue), position, attack_serial, false, action_serial)

func _present_mirror_cast(team: int, pos: Vector2) -> void:
	_presentation_event_id += 1
	_play_card_event(_presentation_event_id, "mirror", "spell:cast", pos, 0, team)
	if runtime.mode == "server":
		_broadcast(_rpc_card_event, [runtime.session.session_id, _presentation_event_id, "mirror", "spell:cast", pos, 0, team])

func _apply_freeze(pos: Vector2, radius: float, duration: float, p_team: int, slow_duration: float = 0.0, slow_multiplier: float = 1.0) -> void:
	_spell_system.apply_freeze(pos, radius, duration, p_team, slow_duration, slow_multiplier)

func _tick_slow_zones(dt: float) -> void:
	_spell_system.tick(dt)

func _tick_slow_effect_visuals(delta: float) -> void:
	_spell_system.tick_visuals(delta)
	_audio_manager.update_spell_flight_audio(_spell_system.stasis_effects)

func _spawn_unit(request: UnitSpawnRequest) -> Unit:
	if runtime.game_over: return null
	var team := request.team
	var card_id := request.card_id
	var pos := request.position
	if not pos.is_finite():
		_fail_contract("生成请求位置无效：card=%s pos=%s" % [card_id, pos])
		return null
	var stats: Dictionary = CardDB.get_unit_stats(card_id)
	if stats.is_empty():
		push_error("尝试生成不存在的单位：%s" % card_id)
		return null
	if request.deploy_time_override >= 0.0:
		stats = stats.duplicate()
		stats["deploy_time"] = request.deploy_time_override
	# 部署资格按网格统一，但真实体积从落地开始生效。若格心与河岸、桥边、塔或水晶重叠，
	# 先把地面移动单位推到最近的完整合法位置，再加入场景，避免第一帧就被静态碰撞锁死。
	if not request.position_resolved:
		if not bool(stats.get("is_air", false)) and not bool(stats.get("is_building", false)):
			pos = world.nearest_valid_ground_spawn(pos, float(stats.get("radius", 14.0)), team)
		if not pos.is_finite():
			_fail_contract("生成物没有合法地面落点：card=%s requested=%s" % [card_id, request.position])
			return null
		var resolved := runtime._deployment_rules.resolve_anchored_spawn(team, card_id, stats, pos, false)
		if not resolved.is_finite():
			_fail_contract("生成物没有可避让落点：card=%s requested=%s" % [card_id, request.position])
			return null
		pos = resolved
	var u := Unit.new()
	u.card_id = card_id
	u.active_skill_card_id = card_id if request.active_skill_card_id_override.is_empty() else request.active_skill_card_id_override
	u.deployment_group_id = request.deployment_group_id
	u.visual_spawn_transition = StringName(request.visual_transition)
	u.summon_visual_origin = request.summon_visual_origin
	u.built_on_tower_ruin = request.built_on_tower_ruin
	u.position = pos
	u.setup(team, stats, stats.name)
	if request.death_replacement_charges_override >= 0:
		u.death_replacement_charges = request.death_replacement_charges_override
	if request.deploy_time_override >= 0.0:
		# 自动兵线不经过卡牌部署读条，生成当帧即可行动；仍标记为新落地单位供碰撞分离使用。
		u._just_deployed = true
	u.lifecycle_birth_tick = runtime._sim_tick_id if runtime._sim_step_active else -1
	add_child(u)
	if _battle_presentation != null:
		_battle_presentation.attach_unit(u, stats)
	if _audio_manager != null:
		_audio_manager.attach_unit(u, stats)
	world.register_authority_unit(u, runtime.mode == "server")
	var skill_card_id := u.active_skill_card_id
	if request.active_slot >= 0 and request.active_slot < 2 and not CardDB.active_skills_for(skill_card_id).is_empty():
		u.active_ability_id = runtime.allocate_ability_id(u.net_id)
		u.active_ability_slot = request.active_slot
		runtime._register_active_skill(u, skill_card_id, team)
	if runtime.mode == "server":
		var spawn_args := [card_id, team, pos, u.net_id, request.deploy_time_override, u.active_ability_id, u.active_ability_slot, request.pre_deploy_id, request.deployment_group_id, request.visual_transition, request.death_replacement_charges_override, request.built_on_tower_ruin, u.active_skill_card_id, u.summon_visual_origin]
		_snapshot_system.register_spawn(spawn_args)
		_broadcast(_rpc_spawn_unit, [card_id, team, pos, u.net_id, request.deploy_time_override, u.active_ability_id, u.active_ability_slot, request.pre_deploy_id, request.deployment_group_id, request.visual_transition, request.death_replacement_charges_override, request.built_on_tower_ruin, u.active_skill_card_id, u.summon_visual_origin, _snapshot_system.lifecycle.session_id, runtime._sim_tick_id, _snapshot_system.lifecycle.revision])
	return u

## 部署期间技能按钮保持不可点击；部署计时归零后只同步可用表现，不改变权威技能判定。
func _sync_active_skill_deployment_readiness() -> void:
	for ability_value in runtime._active_skills.ids():
		var ability_id := int(ability_value)
		var entry: Dictionary = runtime._active_skills.entry(ability_id)
		var unit = entry.get("unit")
		if not is_instance_valid(unit): continue
		var valid_unit := unit as Unit
		var deployed := valid_unit.is_deployed() and not valid_unit.death_form.used
		if _is_local_player_team(int(entry.team)) and _active_skill_bar != null:
			var pending := _client_inputs.has_skill(ability_id) or _network_commands.has_skill(ability_id) or runtime._commands.has_pending_skill(ability_id)
			# 仅比较投影视图以保留正在显示的倒数；它不参与提交资格。
			if _active_skill_bar.is_pending(ability_id) != pending:
				_active_skill_bar.set_pending(ability_id, pending)
			_active_skill_bar.update_skill_state(
				ability_id,
				int(entry.uses_remaining),
				float(entry.cooldown_left),
				deployed,
				runtime._active_skills.cost(ability_id),
				0 if bool(entry.skill.get("unlimited_uses", false)) else int(entry.max_uses),
				bool(entry.free_recast)
			)

func _on_active_skill_pressed(ability_id: int) -> void:
	use_active_skill(ability_id, runtime.local_team, 0, runtime.mode == "client")

## 玩家、AI 和联机 RPC 共用的主动技能请求入口；客户端提交 input_tick，Host 统一计算 10 Tick 目标。
func use_active_skill(ability_id: int, expected_team: int = -1, requester_peer_id: int = 0, client_request: bool = false, input_tick: int = -1) -> bool:
	if _network_peer != null and runtime.session.phase != MatchSession.Phase.RUNNING:
		return false
	if client_request:
		if runtime.mode != "client" or _client_inputs.has_skill(ability_id) or _network_commands.has_skill(ability_id) or not runtime._can_submit_active_skill(ability_id, runtime.local_team):
			return false
		_network_request_id += 1
		_client_inputs.skill(ability_id, _network_request_id)
		if _active_skill_bar != null: _active_skill_bar.set_pending(ability_id, true)
		_send_skill_request(ability_id, _input_tick_for_new_command(), _network_request_id)
		return true
	if is_net_client(): return false
	return runtime._queue_active_skill(ability_id, expected_team, requester_peer_id, input_tick)

func begin_sacrifice(unit: Unit, target: Node2D) -> void:
	_active_skill_effect_system.begin_sacrifice(unit, target)

func queue_expiry_explosion(unit: Unit, skill: Dictionary) -> void:
	_active_skill_effect_system.queue_expiry_explosion(unit, skill)

## 解除导航网格阻挡格（建筑卡死亡 / 塔被摧毁时调用）



func on_unit_died(id: int, play_death_visual: bool = true) -> void:
	world.forget_authority_unit(id)
	if runtime.mode == "server":
		_snapshot_system.lifecycle.host_death(id, runtime._sim_tick_id)
		_broadcast(_rpc_unit_died, [id, play_death_visual, _snapshot_system.lifecycle.session_id, runtime._sim_tick_id])

## 单位受击回调：本地模型已由 Unit 信号闪白，主机只负责可靠转发给客户端表现层。
func on_unit_hit(id: int) -> void:
	if runtime.mode == "server":
		_broadcast(_rpc_unit_hit, [runtime.session.session_id, id])

## 塔受击回调：本地模型已由 Tower 信号闪白，主机按 world.towers_snapshot() 下标可靠转发给客户端。
func on_tower_hit(tower: Tower) -> void:
	if runtime.mode == "server":
		var index := world.towers_snapshot().find(tower)
		if index >= 0:
			_broadcast(_rpc_tower_hit, [runtime.session.session_id, index])

## 固定 20Hz 模拟步：驱动全部战斗单位与塔，处理国王塔激活与障碍移除。
## 帧率高低只影响每帧跑多少步，不改变战斗结果（联机两端行为一致）。

func _sim_step(dt: float) -> void:
	runtime.step(dt)

## 输入许可与模拟推进分开：工作台暂停时仍可摆放，但不累计暂停墙钟。
func can_advance_simulation() -> bool:
	if runtime.mode == "client" or not runtime._match_started or runtime.game_over:
		return false
	if _workbench.enabled:
		return _workbench.battle_active and _art_dev_panel != null and _art_dev_panel.can_advance_simulation()
	return true

func _process(delta: float) -> void:
	if runtime.mode == "server":
		if runtime.session.phase == MatchSession.Phase.LOADING and Time.get_ticks_msec() - _network_loading_started > 30000:
			_network_failed("等待客户端加载超时")
		if runtime.session.phase == MatchSession.Phase.LOBBY and not runtime.session.players.is_empty() and Time.get_ticks_msec() - _network_loading_started > 30000:
			_network_failed("等待玩家或卡组超时")
		if not can_advance_simulation(): return
		runtime._simulation_clock.advance(delta)
		_snapshot_timer -= delta
		if _snapshot_timer <= 0.0 and not runtime.game_over:
			_snapshot_timer = SNAPSHOT_INTERVAL
			_send_snapshot()
		return
	if runtime.session.phase == MatchSession.Phase.LOADING and Time.get_ticks_msec() - _network_loading_started > 30000:
		_network_failed("等待对方加载超时")
	if runtime.game_over:
		return
	if _workbench.enabled and not can_advance_simulation():
		return
	_update_command_countdowns()
	if runtime.mode == "client":
		_sync_active_skill_deployment_readiness()
	_projectile_system.tick_visuals(delta)
	# 客户端：只更新冰冻视觉与重绘，逻辑状态全靠主机快照
	if runtime.mode == "client":
		_advance_estimated_server_tick(delta)
		_tick_network_clock(delta)
		_advance_network_playback()
		_projectile_system.tick_client_interpolation(delta)
		_tick_card_pre_deploy_visuals(delta)
		_tick_slow_effect_visuals(delta)
		_skill_presentation.tick_visuals(delta)
		queue_redraw()
		return
	if _workbench.enabled:
		_tick_slow_effect_visuals(delta)
		_skill_presentation.tick_visuals(delta)
		queue_redraw()
		runtime._simulation_clock.advance(delta)
		_sync_art_dev_panel_state()
		return
	if not can_advance_simulation():
		return
	# 更新冰冻视觉效果
	_tick_slow_effect_visuals(delta)
	_skill_presentation.tick_visuals(delta)
	queue_redraw()
	# 固定 20Hz 战斗模拟：与渲染帧率解耦（auto-test 出兵也在模拟内计时）
	runtime._simulation_clock.advance(delta)
	_update_timer_label()

## 网络适配提交比赛副本，规则对象和界面在本地编排入口统一更新。
func apply_network_match_snapshot(coins: float, remaining: float, extra_time: bool) -> void:
	runtime.apply_match_replica(coins, remaining, extra_time)
	_snapshots_received += 1
	if _auto_test and _snapshots_received % 40 == 0:
		print("[测试] 客户端已收快照 ", _snapshots_received, " 份，单位数=", world.replica_unit_ids().size())

func _update_timer_label() -> void:
	if _timer_label == null:
		return
	var t := maxi(int(runtime._match_rules.time_left), 0)
	var text := "%d:%02d" % [t / 60, t % 60]
	if runtime._match_rules.overtime:
		text += " 加时"
	_timer_label.text = text

func _end_game(winner_team: int, reason: String) -> void:
	if runtime.game_over:
		return
	var terminal_frame: Array = []
	if runtime.mode != "client":
		terminal_frame = _snapshot_system.capture_public_frame()
		if terminal_frame.is_empty(): return
		_terminal_result = {"session_id": _snapshot_system.lifecycle.session_id, "final_tick": runtime._sim_tick_id, "winner_team": winner_team, "reason": reason, "terminal_state": _snapshot_system.encode_frame(terminal_frame)}
	if runtime.mode == "server":
		for team in runtime.session.players:
			var peer := runtime.session.peer_for_team(team)
			if _network_peer == null or not multiplayer.get_peers().has(peer): continue
			var result := _terminal_result.duplicate()
			result.terminal_state = _snapshot_system.encode_frame(terminal_frame, team)
			_rpc_end.rpc_id(peer, result)
	runtime.game_over = true
	runtime.session.finish(reason == "disconnect")
	_stop_battle_activity()
	if _audio_manager != null:
		var destroyed_nexuses: Array = []
		if reason == "nexus":
			for tower in [world.king(0), world.king(1)]:
				if tower.hp <= 0.0: destroyed_nexuses.append(tower)
		var result_cue := ("victory" if _is_local_player_team(winner_team) else "defeat") if winner_team >= 0 else ""
		_audio_manager.finish_match_audio(result_cue, destroyed_nexuses)
	_show_stop_overlay(_match_result_text(winner_team, reason), "MatchResult")

## 准备失败没有胜负、比分或终局快照；可在场景装配前后重复调用。
func _fail_startup(message: String) -> void:
	_fail_with_error(message, "StartupFailure", "无法开始对局")

## 内部契约损坏必须终止；既不伪造胜负，也不继续发送不完整状态。
func _fail_contract(message: String) -> void:
	if runtime.game_over: return
	if runtime.mode == "server": _broadcast(_rpc_abort, [runtime.session.session_id, message])
	_fail_with_error(message, "ContractFailure", "对局数据错误")
	if runtime.mode == "server": _schedule_server_reset()
	elif runtime.mode == "client": _close_network()

func _fail_with_error(message: String, overlay_name: String, title: String) -> void:
	if runtime.game_over:
		return
	runtime.game_over = true
	_startup_failure_message = message
	_terminal_result.clear()
	runtime.session.finish(true)
	_resources.cancel_async(get_tree())
	if is_instance_valid(_battle_presentation):
		_battle_presentation.model_pool.cancelled = true
	_stop_battle_activity()
	if is_instance_valid(_audio_manager): _audio_manager.end_battle()
	print("[%s] %s" % [overlay_name, message])
	_show_stop_overlay(title + "\n" + message, overlay_name)

## 失败与正常终局复用已有停止边界，表现与权威排程均不能继续。
func _stop_battle_activity() -> void:
	runtime.stop()
	_network_commands.clear()
	_client_inputs.clear()
	_network_playback.clear()
	if _cast_notice != null: _cast_notice.clear()
	if is_instance_valid(_audio_manager): _audio_manager.clear_spell_flight_audio()
	_skill_presentation.clear()
	if is_instance_valid(_battle_presentation): _battle_presentation.clear_death_visuals()
	_clear_deployment_preview()
	if _hand != null:
		_hand.hide()
	if _active_skill_bar != null:
		_active_skill_bar.hide()

func _show_stop_overlay(message: String, overlay_name: String) -> void:
	if not has_presentation(): return
	var overlay := CanvasLayer.new()
	overlay.name = overlay_name
	overlay.layer = 100
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 600.0
	label.add_theme_font_size_override("font_size", 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	var back := Button.new()
	back.text = "返回主菜单"
	back.custom_minimum_size = Vector2(200, 70)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(return_to_main_menu)
	column.add_child(back)

func _match_result_text(winner_team: int, reason: String) -> String:
	if reason == "disconnect":
		return "连接已断开，对局停止"
	var my_team := runtime.local_team
	if winner_team < 0:
		return "平局！双方战成 %d:%d" % [runtime._count_destroyed_towers(1 - my_team), runtime._count_destroyed_towers(my_team)]
	var won := winner_team == my_team
	if reason == "nexus":
		return "胜利！敌方国王塔已被摧毁" if won else "失败……我方国王塔被摧毁"
	return ("胜利！破塔 %d:%d" if won else "失败……破塔 %d:%d") % [runtime._count_destroyed_towers(1 - my_team), runtime._count_destroyed_towers(my_team)]

# ============================================================
#  联机 RPC
# ============================================================

## 加载阶段仅允许绑定对手确认一次完整卡组，双方加载就绪后才开局。
@rpc("any_peer", "call_remote", "reliable")
func _rpc_register_deck(deck: Array, active_skill_choices: Dictionary = {}, epoch: String = "", protocol: int = -1, fingerprint: String = "") -> void:
	var sender := multiplayer.get_remote_sender_id()
	if runtime.mode != "server" or not runtime.session.accepts(sender, epoch, MatchSession.Phase.LOBBY) or runtime.session.has_deck(sender): return
	if protocol != MatchSession.PROTOCOL_VERSION or fingerprint != MatchSession.content_fingerprint():
		_network_failed("协议或卡牌规则版本不一致")
		return
	if not _accept_remote_deck(sender, epoch, deck, active_skill_choices):
		_network_failed("玩家卡组或技能选择无效")
		return
	if not runtime.session.begin_loading(): return
	_network_loading_started = Time.get_ticks_msec()
	_begin_net_match_server()
	for team in [0, 1]:
		_rpc_start.rpc_id(runtime.session.peer_for_team(team), epoch, runtime._team_deck(1 - team), runtime._team_active_skill_choices(1 - team))

func _accept_remote_deck(sender: int, epoch: String, deck: Array, choices: Dictionary) -> bool:
	if not MatchSession.valid_deck(deck, choices) or not runtime.session.confirm_deck(sender, epoch): return false
	var team := runtime.session.team_for_peer(sender)
	runtime._server_decks[team] = deck.duplicate()
	runtime._server_skill_choices[team] = choices.duplicate()
	return true

@rpc("any_peer", "call_remote", "reliable")
func _rpc_active_skill_request(ability_id: int, input_tick: int = -1, epoch: String = "", request_id: int = 0) -> void:
	if runtime.mode != "server" or runtime.game_over:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not runtime.session.accept_command(sender, epoch, request_id):
		return
	if input_tick < 0 or not use_active_skill(ability_id, runtime.session.team_for_peer(sender), sender, false, input_tick):
		_rpc_active_skill_rejected.rpc_id(sender, runtime.session.session_id, ability_id, request_id)

func _tick_card_pre_deploy_visuals(delta: float) -> void:
	runtime._commands.tick_deployment_visuals(delta)

func _remove_card_pre_deploy_visual(pre_deploy_id: int) -> void:
	runtime._commands.remove_deployment(pre_deploy_id)

@rpc("authority", "call_remote", "reliable")
func _rpc_active_skill_used(epoch: String, ability_id: int, uses_remaining: int = 0, cooldown_left: float = 0.0, free_recast: bool = false) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over:
		return
	if runtime.mode != "client" or runtime.game_over:
		return
	if runtime._active_skills.has(ability_id):
		var entry: Dictionary = runtime._active_skills.entry(ability_id)
		runtime.apply_skill_replica(ability_id, uses_remaining, cooldown_left, free_recast)
		if _active_skill_bar != null: _active_skill_bar.set_pending(ability_id, _network_commands.has_skill(ability_id))
		_sync_active_skill_deployment_readiness()

@rpc("authority", "call_remote", "reliable")
func _rpc_active_skill_rejected(epoch: String, ability_id: int, request_id: int) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over:
		return
	if runtime.mode == "client" and _client_inputs.finish_skill(ability_id, request_id) and _active_skill_bar != null:
		_active_skill_bar.set_pending(ability_id, _network_commands.has_skill(ability_id))

func _send_card_request(card_id: String, pos: Vector2, input_tick: int, request_id: int) -> void:
	_rpc_deploy_request.rpc_id(1, card_id, pos, input_tick, runtime.session.session_id, request_id)

func _send_skill_request(ability_id: int, input_tick: int, request_id: int) -> void:
	_rpc_active_skill_request.rpc_id(1, ability_id, input_tick, runtime.session.session_id, request_id)

## 客户端 → 主机：部署请求。客户端只携带点击时观察到的 input_tick，目标 Tick 由 Host 计算。
@rpc("any_peer", "call_remote", "reliable")
func _rpc_deploy_request(card_id: String, pos: Vector2, input_tick: int = -1, epoch: String = "", request_id: int = 0) -> void:
	if runtime.mode != "server" or runtime.game_over:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not runtime.session.accept_command(sender, epoch, request_id):
		return
	var team := runtime.session.team_for_peer(sender)
	var accepted := input_tick >= 0 and play_card(team, card_id, pos, {
		"elixir": runtime.account(team),
		"require_team_deck": true,
		"requester_peer_id": sender,
		"input_tick": input_tick,
	})
	if not accepted:
		_rpc_deploy_rejected.rpc_id(sender, runtime.session.session_id, card_id, request_id)

## 主机 → 客户端：仅在权威扣费、轮换手牌并排程成功后确认出牌。
@rpc("authority", "call_remote", "reliable")
func _rpc_deploy_accepted(epoch: String, card_id: String, execute_tick: int, state: Dictionary) -> void:
	if runtime.mode != "client" or runtime.game_over or not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING): return
	if execute_tick < 0 or not ClientHandState.valid(state, runtime._deck): return
	# 即使旧状态被版本屏障拒绝，也只能结束完全对应的旧请求，不能清新pending。
	if _client_inputs.finish_card(card_id, int(state.ack)) and _hand != null:
		_hand.set_card_pending(card_id, false)
	_apply_client_hand_state(state)

@rpc("authority", "call_remote", "reliable")
func _rpc_deploy_rejected(epoch: String, card_id: String, request_id: int) -> void:
	if runtime.mode != "client" or runtime.game_over or not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING): return
	if _client_inputs.finish_card(card_id, request_id) and _hand != null:
		_hand.set_card_pending(card_id, false)

## 主机 → 客户端：单位生成
@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_unit(card_id: String, p_team: int, pos: Vector2, net_id: int, deploy_time_override: float, active_ability_id: int, active_ability_slot: int, pre_deploy_id: int, deployment_group_id: int, visual_transition: String, death_replacement_charges_override: int, built_on_tower_ruin: bool, active_skill_card_id: String, summon_visual_origin: Vector2, session_id: String, birth_tick: int, birth_revision: int) -> void:
	_snapshot_system.receive_spawn(session_id, {"birth_tick": birth_tick, "birth_revision": birth_revision, "args": [card_id, p_team, pos, net_id, deploy_time_override, active_ability_id, active_ability_slot, pre_deploy_id, deployment_group_id, visual_transition, death_replacement_charges_override, built_on_tower_ruin, active_skill_card_id, summon_visual_origin]})

## 生命周期协议已校验的创建入口；RPC 与快照重建共用。
func create_network_unit(card_id: String, p_team: int, pos: Vector2, net_id: int, deploy_time_override: float = -1.0, active_ability_id: int = -1, active_ability_slot: int = -1, pre_deploy_id: int = -1, deployment_group_id: int = -1, visual_transition: String = "", death_replacement_charges_override: int = -1, built_on_tower_ruin: bool = false, active_skill_card_id: String = "", summon_visual_origin: Vector2 = Vector2.INF) -> void:
	if runtime.mode != "client" or runtime.game_over:
		return
	_remove_card_pre_deploy_visual(pre_deploy_id)
	var stats: Dictionary = CardDB.get_unit_stats(card_id)
	if deploy_time_override >= 0.0:
		stats = stats.duplicate()
		stats["deploy_time"] = deploy_time_override
	var u := Unit.new()
	u.card_id = card_id
	u.active_skill_card_id = card_id if active_skill_card_id.is_empty() else active_skill_card_id
	u.deployment_group_id = deployment_group_id
	u.visual_spawn_transition = StringName(visual_transition)
	u.summon_visual_origin = summon_visual_origin
	u.built_on_tower_ruin = built_on_tower_ruin
	u.position = pos
	u.setup(p_team, stats, stats.name)
	if death_replacement_charges_override >= 0:
		u.death_replacement_charges = death_replacement_charges_override
	if deploy_time_override >= 0.0:
		u._just_deployed = true
	u.net_id = net_id
	u.active_ability_id = active_ability_id
	u.active_ability_slot = active_ability_slot
	u.net_target_pos = pos
	add_child(u)
	if _battle_presentation != null:
		_battle_presentation.attach_unit(u, stats)
	if _audio_manager != null:
		_audio_manager.attach_unit(u, stats)
	world.register_replica_unit(u)
	if active_ability_id >= 0:
		runtime._register_active_skill(u, u.active_skill_card_id, p_team)
	if _auto_test:
		print("[测试] 客户端收到单位生成: ", card_id, " net_id=", net_id)

## 主机 → 客户端：两段式部署的第一段落点提示。客户端只计时和绘制标记，
## 真正生成仍以随后到达的 _rpc_spawn_unit 为准。
@rpc("authority", "call_remote", "reliable")
func _rpc_card_pre_deploy_started(epoch: String, pre_deploy_id: int, card_id: String, p_team: int, pos: Vector2, duration: float) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over:
		return
	if runtime.mode != "client" or runtime.game_over:
		return
	_remove_card_pre_deploy_visual(pre_deploy_id)
	runtime._commands.enqueue_deployment(p_team, card_id, pos, maxf(duration, 0.0), -1, pre_deploy_id, maxf(duration, 0.0))
	queue_redraw()

## 主机 → 客户端：可靠触发一次短暂闪白，不依赖不可靠血量快照是否刚好采到该帧。
@rpc("authority", "call_remote", "reliable")
func _rpc_unit_hit(epoch: String, net_id: int) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over:
		return
	if runtime.mode != "client" or runtime.game_over:
		return
	var u = world.find_replica_unit(net_id)
	if u != null and is_instance_valid(u):
		u.notify_visual_hit()
		if _auto_test:
			print("[测试] 客户端收到受击闪白事件: net_id=", net_id)

## 主机 → 客户端：一次真实普攻命中对应一个短促的纯表现音频事件；允许丢失，绝不阻塞快照。
@rpc("authority", "call_remote", "unreliable")
func _rpc_attack_audio_hit(epoch: String, source: Dictionary, position: Vector2, first_strike: bool = false) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over:
		return
	if runtime.mode != "client" or runtime.game_over:
		return
	if _auto_test and not _auto_audio_source_seen:
		_auto_audio_source_seen = true
		print("[测试] 客户端收到独立攻击来源命中事件：", source)
	if _audio_manager != null:
		_audio_manager.play_attack_source(source, position, first_strike)

@rpc("authority", "call_remote", "reliable")
func _rpc_tower_hit(epoch: String, index: int) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over:
		return
	if runtime.mode != "client" or runtime.game_over:
		return
	if index >= 0 and index < world.towers_snapshot().size():
		world.towers_snapshot()[index].notify_visual_hit()

## 主机 → 客户端：可靠播放一次弹体命中表现；伤害结果仍只来自主机快照。
@rpc("authority", "call_remote", "reliable")
func _rpc_projectile_impact_fx(epoch: String, pos: Vector2, radius: float, color: Color, visual: String) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over:
		return
	if runtime.mode != "client" or runtime.game_over:
		return
	_projectile_system.add_impact_visual(pos, radius, color, StringName(visual))

## 主机 → 客户端：可靠触发死亡动作。逻辑单位立即释放，3D 代理独立播完动作。
@rpc("authority", "call_remote", "reliable")
func _rpc_unit_died(net_id: int, play_death_visual: bool, session_id: String, death_tick: int) -> void:
	_snapshot_system.receive_death(session_id, net_id, death_tick, play_death_visual)

## World拥有实体索引；Main保留网络适配与表现收尾。



func apply_network_skill_state(unit: Unit, uses: int, cooldown_left: float, free_recast: bool = false) -> void:
	if runtime._active_skills.entry(unit.active_ability_id).get("unit") != unit:
		return
	runtime.apply_skill_replica(unit.active_ability_id, uses, cooldown_left, free_recast)

## 网络适配层收尾技能与表现，World统一移除实体和空间占位。
func remove_network_unit(net_id: int, play_death_visual: bool = true) -> void:
	if runtime.mode != "client" or runtime.game_over:
		return
	_skill_presentation.remove_source(net_id)
	var u: Unit = world.find_replica_unit(net_id)
	if u == null: return
	clear_network_unit_skill(u)
	if not play_death_visual and not u.timed_revival_id.is_empty() and _audio_manager != null:
		_audio_manager.complete_revival(u)
	if play_death_visual:
		u.notify_visual_death()
	world.remove_unit(u)

func clear_network_unit_skill(unit: Unit) -> void:
	runtime.clear_replica_skill(unit)

func sync_network_unit_skill(unit: Unit, ability_id: int, slot: int) -> void:
	if unit.active_ability_id == ability_id and unit.active_ability_slot == slot:
		return
	clear_network_unit_skill(unit)
	unit.active_ability_id = ability_id
	unit.active_ability_slot = slot
	if ability_id >= 0:
		runtime._register_active_skill(unit, unit.active_skill_card_id if not unit.active_skill_card_id.is_empty() else unit.card_id, unit.team)

## 主机 → 客户端：定期快照（位置/血量/金币/计时）。
## 兵线会稳定增加单位数，直接 RPC 传嵌套 Variant 数组很快超过 ENet MTU；
## 因此先序列化并 DEFLATE 压缩成单个字节载荷，客户端解包后仍只做表现插值。
@rpc("authority", "call_remote", "unreliable")
func _rpc_snapshot(snapshot_bytes: PackedByteArray) -> void:
	if runtime.mode != "client" or runtime.game_over or _snapshot_system.terminal_applied: return
	if _network_peer != null and runtime.session.phase != MatchSession.Phase.RUNNING: return
	var decoded := _snapshot_system.decode_validated(snapshot_bytes)
	if decoded == null or not _snapshot_system.lifecycle.accepts_session(decoded.packet[NetworkSnapshotSystem.S_SESSION]): return
	if _network_peer == null:
		_snapshot_system.apply_decoded(decoded)
		return
	var tick: int = decoded.packet[NetworkSnapshotSystem.S_SERVER_TICK]
	_observe_network_arrival(tick)
	if not _has_estimated_server_tick:
		_estimated_server_tick = tick
		_has_estimated_server_tick = true
	if not _network_playback.enqueue_snapshot(decoded): _network_failed("网络快照队列已满，对局停止")

func _apply_buffered_snapshot(decoded: NetworkSnapshotSystem.DecodedSnapshot) -> void:
	_snapshot_system.apply_decoded(decoded)

## 主机 → 客户端：冰冻法术视觉
@rpc("authority", "call_remote", "reliable")
func _rpc_freeze_fx(epoch: String, pos: Vector2, radius: float, duration: float, slow_duration: float = 0.0, _slow_multiplier: float = 1.0, p_team: int = 0, slow_radius: float = 0.0) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over:
		return
	if runtime.mode != "client" or runtime.game_over:
		return
	_spell_system.show_freeze(pos, radius, duration, slow_duration, p_team, slow_radius)

## 主机 → 客户端：治疗法术视觉。治疗数值由主机权威结算，客户端按施法阵营显示范围边界。
@rpc("authority", "call_remote", "reliable")
func _rpc_heal_fx(epoch: String, pos: Vector2, radius: float, duration: float, p_team: int, enhanced: bool = false, global_heal: bool = false) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over:
		return
	if runtime.mode != "client" or runtime.game_over:
		return
	if p_team not in [0, 1]: return
	_spell_system.show_heal(pos, radius, duration, p_team, enhanced, global_heal)

## 主机 → 客户端：比赛结束
@rpc("authority", "call_remote", "reliable")
func _rpc_end(result: Dictionary) -> void:
	if runtime.mode != "client" or runtime.game_over:
		return
	if not result.get("session_id") is String or not _snapshot_system.lifecycle.accepts_session(result.session_id):
		return
	if not result.get("final_tick") is int or not result.get("winner_team") is int or result.winner_team not in [-1, 0, 1]:
		return
	if result.get("reason") not in MatchRules.END_REASONS or not result.get("terminal_state") is PackedByteArray:
		return
	# 最终快照可靠传输；先落地塔/单位终态，再冻结表现和拒绝后续快照。
	if not _snapshot_system.apply_decoded(_snapshot_system.decode_validated(result.terminal_state), true, int(result.final_tick)):
		return
	_terminal_result = result.duplicate(true)
	_end_game(int(result.winner_team), String(result.reason))

## 主机端：组装并发送快照
func _send_snapshot() -> void:
	_snapshot_system.send()

func _draw() -> void:
	if not has_presentation(): return
	if _workbench.enabled and _workbench.inspect_enabled:
		var inspected := _workbench.inspected_unit()
		if inspected != null:
			draw_arc(inspected.position, maxf(inspected.body_radius, 20.0) + 7.0, 0, TAU, 48, Color("ffe27a"), 3.0, true)
	# 正式 3D 地图在下层视口绘制；此处只画部署提示。
	# 选中卡牌时高亮可部署区域
	if _selected_card != "":
		var sel_stats: Dictionary = CardDB.get_card(runtime.resolved_card_for_team(runtime.local_team, _selected_card))
		var deploy_zone: String = String(sel_stats.get("deploy_zone", "own_side"))
		match deploy_zone:
			"global":
				# global 级卡（冰冻、卡牌大师）：整个竞技场提示为范围提示色；
				# 具体水面/塔上等占位不可点的位置，由红/绿圆形落点预览精确反馈。
				draw_rect(Rect2(0, 0, ArenaRules.FIELD_W, ArenaRules.FIELD_H), Color(0.40, 0.70, 1.00, 0.08))
			_:
				# own_side：逐格按己方部署掩码绘制
				var deploy_team := runtime.local_team
				for row in ArenaRules.ARENA_ROWS:
					for column in ArenaRules.ARENA_COLUMNS:
						var tile := Vector2i(column, row)
						if runtime._deployment_rules.tile_in_ground_deploy_zone(tile, deploy_team, bool(sel_stats.get("deploy_pocket_requires_both_towers", false))):
							draw_rect(Rect2(Vector2(tile) * ArenaRules.TILE_SIZE, Vector2.ONE * ArenaRules.TILE_SIZE), Color(0.40, 0.70, 1.00, 0.15))
		_draw_deployment_preview(sel_stats)
	# 两段式部署的第一段只显示一个落点卡牌标记，不创建单位或战斗碰撞体。
	runtime._commands.draw_deployments(_draw_card_pre_deploy_indicator)
	_network_commands.visit(_draw_command_indicator)
	_client_inputs.visit_cards(_draw_unconfirmed_input)

func _draw_unconfirmed_input(center: Vector2) -> void:
	# 点击即刻反馈；没有实体、碰撞和伤害，服务器拒绝时撤掉。
	draw_circle(center, 19.0, Color(0.8, 0.9, 1.0, 0.10))
	for segment in 4:
		var angle := TAU * float(segment) / 4.0
		draw_arc(center, 22.0, angle, angle + PI * 0.3, 12, Color(0.8, 0.9, 1.0, 0.7), 2.0, true)

func _draw_command_indicator(command: Dictionary) -> void:
	if command.kind != "card" or int(command.team) != runtime.local_team: return
	if _client_inputs.has_card(String(command.card_id)): return
	# 仅自己的已接受落点提示；没有碰撞/单位/法术效果，不显示对方的意图。
	var remaining := maxf(0.0, float(command.execute_tick) - get_presentation_tick())
	var progress := clampf(1.0 - remaining / float(COMMAND_DELAY_TICKS), 0.0, 1.0)
	var center: Vector2 = command.pos
	draw_circle(center, 19.0, Color(0.3, 0.75, 1.0, 0.12))
	draw_arc(center, 22.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, Color(0.45, 0.85, 1.0, 0.85), 2.0, true)

func _setup_arena_background() -> void:
	_arena_background_sprite = Sprite2D.new()
	_arena_background_sprite.name = "ArenaBackground2D"
	_arena_background_sprite.texture = load(ARENA_BACKGROUND_PATH)
	_arena_background_sprite.visible = true
	_arena_background_sprite.centered = false
	_arena_background_sprite.position = Vector2.ZERO
	_arena_background_sprite.z_index = -100
	add_child(_arena_background_sprite)
	move_child(_arena_background_sprite, 0)

func _draw_card_pre_deploy_indicator(deployment: Dictionary) -> void:
	if not String(CardDB.get_card(String(deployment.get("card_id", ""))).get("visual_pre_deploy_scene", "")).is_empty(): return
	var center: Vector2 = deployment.get("pos", Vector2.ZERO)
	var duration := maxf(float(deployment.get("duration", 1.0)), 0.001)
	var remaining := clampf(float(deployment.get("time_left", duration)), 0.0, duration)
	var progress := 1.0 - remaining / duration
	var team_color := Color(0.28, 0.68, 1.0, 0.96) if int(deployment.get("team", 0)) == 0 else Color(1.0, 0.34, 0.24, 0.96)
	var pulse := 0.5 + 0.5 * sin(progress * TAU * 2.0)
	draw_circle(center, 34.0, Color(team_color.r, team_color.g, team_color.b, 0.10 + 0.04 * pulse))
	draw_arc(center, 34.0, 0.0, TAU, 48, Color(team_color.r, team_color.g, team_color.b, 0.42), 2.0, true)
	draw_arc(center, 34.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, team_color, 4.0, true)
	for index in range(8):
		var angle := TAU * float(index) / 8.0 - PI * 0.5
		var direction := Vector2.from_angle(angle)
		var tangent := Vector2(-direction.y, direction.x)
		var card_center := center + direction * 31.0
		var card_points := PackedVector2Array([
			card_center - direction * 8.0 - tangent * 5.0,
			card_center + direction * 8.0 - tangent * 5.0,
			card_center + direction * 8.0 + tangent * 5.0,
			card_center - direction * 8.0 + tangent * 5.0,
		])
		draw_colored_polygon(card_points, Color(0.98, 0.97, 0.90, 0.94))
		draw_polyline(PackedVector2Array([card_points[0], card_points[1], card_points[2], card_points[3], card_points[0]]), Color(0.35, 0.18, 0.08, 0.96), 1.5, true)
		draw_line(card_center - direction * 2.0, card_center + direction * 3.0, team_color, 1.5, true)
	draw_circle(center, 4.0, Color(1.0, 0.95, 0.66, 0.96))

func _draw_deployment_preview(stats: Dictionary) -> void:
	if not _deployment_preview_visible:
		return
	var color := ArenaRules.DEPLOY_PREVIEW_VALID if _deployment_preview_valid else ArenaRules.DEPLOY_PREVIEW_INVALID
	var footprint: Vector2i = stats.get("footprint_tiles", Vector2i.ONE)
	var type: String = stats.get("type", "unit")
	var preview_rect: Rect2
	if type == "building" and footprint != Vector2i.ONE:
		preview_rect = Rect2(
			_deployment_preview_pos - Vector2(footprint) * ArenaRules.TILE_SIZE * 0.5,
			Vector2(footprint) * ArenaRules.TILE_SIZE
		)
	else:
		preview_rect = Rect2(Vector2(_deployment_preview_tile) * ArenaRules.TILE_SIZE, Vector2.ONE * ArenaRules.TILE_SIZE)
	draw_rect(preview_rect, Color(color.r, color.g, color.b, 0.18), true)
	draw_rect(preview_rect, color, false, 3.0)

	if type == "spell":
		var spell_radius: float = stats.get("radius", ArenaRules.TILE_SIZE * 0.5)
		draw_circle(_deployment_preview_pos, spell_radius, Color(color.r, color.g, color.b, 0.12))
		draw_arc(_deployment_preview_pos, spell_radius, 0.0, TAU, 48, color, 2.0, true)
	elif type == "unit":
		var unit_stats: Dictionary = CardDB.get_unit_stats(String(stats.spawn_plan.members[0])) if stats.has("spawn_plan") else stats
		var unit_radius: float = minf(float(unit_stats.radius), ArenaRules.TILE_SIZE * 0.42)
		draw_circle(_deployment_preview_pos, unit_radius, Color(color.r, color.g, color.b, 0.26))
		draw_arc(_deployment_preview_pos, unit_radius, 0.0, TAU, 32, color, 2.0, true)
	else:
		# 建筑额外画中心十字，明确规则占地中心；奇数格在格心，偶数格在线交点。
		var cross_size := 7.0
		draw_line(_deployment_preview_pos - Vector2(cross_size, 0.0), _deployment_preview_pos + Vector2(cross_size, 0.0), color, 2.0, true)
		draw_line(_deployment_preview_pos - Vector2(0.0, cross_size), _deployment_preview_pos + Vector2(0.0, cross_size), color, 2.0, true)

func _present_cast_notice(team: int, card_id: String, skill_index: int) -> void:
	_presentation_event_id += 1
	_play_card_event(_presentation_event_id, card_id, "cast:notice", Vector2.ZERO, skill_index, team)
	if runtime.mode == "server":
		_broadcast(_rpc_card_event, [runtime.session.session_id, _presentation_event_id, card_id, "cast:notice", Vector2.ZERO, skill_index, team])

func _play_card_event(event_id: int, card_id: String, cue: String, pos: Vector2, form: int = 0, team: int = 0) -> void:
	if not has_presentation(): return
	if event_id <= _last_card_event_id:
		return
	_last_card_event_id = event_id
	if cue == "cast:notice":
		if _cast_notice != null: _cast_notice.show_cast(card_id, form, team)
		return
	if card_id == "match":
		if not runtime.game_over and _audio_manager != null: _audio_manager.play_match_event(cue)
		return
	if card_id == "mirror" and cue == "spell:cast" and _effects_view != null:
		var mirror := preload("res://scripts/presentation/mirror_cast_effect.gd").new()
		mirror.position = pos
		mirror.team = team
		_effects_view.add_child(mirror)
	if card_id == "explosive_cask" and cue == "spell:hit" and _battle_presentation != null:
		_spell_system.cask_hits.append({"id": event_id, "pos": pos, "timer": 0.7})
	if cue == "shield:cast":
		_skill_presentation.present_area_shield(card_id, form, pos)
	if _audio_manager != null:
		_audio_manager.play_card_event(card_id, cue, pos, form, team)

func present_skill_projectile_hit(source: Dictionary, action: String, pos: Vector2, phase: String = "hit") -> void:
	if action.is_empty():
		return
	_presentation_event_id += 1
	var card_id := String(source.get("card_id", ""))
	var form := int(source.get("form", 0))
	_play_card_event(_presentation_event_id, card_id, action + ":" + phase, pos, form, int(source.get("team", 0)))
	if runtime.mode == "server":
		_broadcast(_rpc_card_event, [runtime.session.session_id, _presentation_event_id, card_id, action + ":" + phase, pos, form, int(source.get("team", 0))])

func present_team_attack_boost(source: Unit, target: Unit, duration: float) -> void:
	if not is_instance_valid(source) or not is_instance_valid(target):
		return
	var effect := _skill_presentation.add_team_attack_boost(source, target, duration)
	if not effect.is_empty():
		publish_skill_fx(effect)

func present_ornn_charge_impact(source: Unit, radius: float, center: Vector2) -> void:
	if not is_instance_valid(source) or radius <= 0.0:
		return
	var effect := _skill_presentation.add_ornn_charge_impact(center, radius, source.team)
	if not effect.is_empty():
		publish_skill_fx(effect)

func present_zone_audio(source: Unit, action: String, pos: Vector2, duration: float) -> void:
	_presentation_event_id += 1
	if _audio_manager != null:
		_audio_manager.start_zone_audio(_presentation_event_id, source.card_id, source.form_index, action, pos, duration, source.team)
	if runtime.mode == "server":
		_broadcast(_rpc_zone_audio, [runtime.session.session_id, _presentation_event_id, source.card_id, source.form_index, action, pos, duration, source.team])

@rpc("authority", "call_remote", "reliable")
func _rpc_zone_audio(epoch: String, event_id: int, card_id: String, form: int, action: String, pos: Vector2, duration: float, team: int = 0) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over:
		return
	if runtime.mode == "client" and _audio_manager != null:
		_audio_manager.start_zone_audio(event_id, card_id, form, action, pos, duration, team)

@rpc("authority", "call_remote", "reliable")
func _rpc_card_event(epoch: String, event_id: int, card_id: String, cue: String, pos: Vector2, form: int = 0, team: int = 0) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over:
		return
	if runtime.mode == "client":
		_play_card_event(event_id, card_id, cue, pos, form, team)

func _present_match_announcement(cue: String) -> void:
	_presentation_event_id += 1
	_play_card_event(_presentation_event_id, "match", cue, Vector2.ZERO)
	if runtime.mode == "server":
		_broadcast(_rpc_card_event, [runtime.session.session_id, _presentation_event_id, "match", cue, Vector2.ZERO])

## 权威治疗完成后派发跟随单位的纯表现；可靠消息不依赖客户端猜测血量变化。
func present_restoration_heal(unit: Unit) -> void:
	if has_presentation(): unit.show_restoration_heal()
	if runtime.mode == "server" and unit.net_id >= 0:
		_broadcast(_rpc_restoration_heal, [runtime.session.session_id, unit.net_id])

@rpc("authority", "call_remote", "reliable")
func _rpc_restoration_heal(epoch: String, net_id: int) -> void:
	if runtime.mode != "client" or not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over:
		return
	var unit: Unit = world.find_replica_unit(net_id)
	if is_instance_valid(unit) and unit.hp > 0.0:
		if has_presentation(): unit.show_restoration_heal()

func notify_action_cancelled(unit: Unit, payload: Dictionary) -> void:
	if not is_net_client() and String(payload.get("reason", "")) in ["stun", "freeze", "stasis", "knockback", "death_form"]:
		_team_attack_boost_system.interrupt(unit)
	if runtime.mode == "server" and unit.net_id >= 0:
		_broadcast(_rpc_action_cancelled, [runtime.session.session_id, unit.net_id, payload])

@rpc("authority", "call_remote", "reliable")
func _rpc_action_cancelled(epoch: String, net_id: int, payload: Dictionary) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over or runtime.mode != "client":
		return
	var unit: Unit = world.find_replica_unit(net_id)
	if is_instance_valid(unit):
		unit.apply_action_cancellation(payload)

func publish_skill_fx(payload: Dictionary) -> void:
	if runtime.mode != "server": return
	payload = payload.duplicate(true)
	payload.erase("source_ref")
	_presentation_event_id += 1
	_broadcast(_rpc_skill_fx, [runtime.session.session_id, _presentation_event_id, payload])
	_skill_presentation.clear()

@rpc("authority", "call_remote", "reliable")
func _rpc_skill_fx(epoch: String, event_id: int, payload: Dictionary) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over or runtime.mode != "client": return
	_skill_presentation.show_skill_effect(event_id, payload)
	if _auto_test and not _auto_gnar_skill_fx_seen:
		_auto_gnar_skill_fx_seen = true
		print("[测试] 客户端已收到固定方向技能范围表现")

func simulation_step_active() -> bool:
	return runtime._sim_step_active

func combat_service() -> CombatResolver:
	return _combat

func projectile_service() -> ProjectileSystem:
	return _projectile_system

func present_freeze_spell(pos: Vector2, radius: float, duration: float, slow_duration: float, slow_multiplier: float, p_team: int = 0, slow_radius: float = 0.0) -> void:
	if runtime.mode == "server":
		_broadcast(_rpc_freeze_fx, [network_session_id(), pos, radius, duration, slow_duration, slow_multiplier, p_team, slow_radius])

func present_heal_spell(pos: Vector2, radius: float, duration: float, p_team: int, enhanced: bool, global_heal: bool) -> void:
	if runtime.mode == "server":
		_broadcast(_rpc_heal_fx, [network_session_id(), pos, radius, duration, p_team, enhanced, global_heal])

func _refresh_mirror_hand(team: int) -> void:
	if _hand != null and _is_local_player_team(team):
		_hand.set_mirror_copy(runtime._card_history.get_last(team))
	queue_redraw()

@rpc("authority", "call_remote", "reliable")
func _rpc_unit_forge_audio(epoch: String, net_id: int, cue: String, position: Vector2) -> void:
	if cue not in ["forge:pulse", "forge:cancel"]: return
	_rpc_unit_audio_event(epoch, net_id, cue, position)

func present_lightning_spell(card_id: String, pos: Vector2, radius: float, team: int) -> void:
	_presentation_event_id += 1
	_show_lightning_spell(_presentation_event_id, card_id, pos, radius, team)
	if runtime.mode == "server":
		_broadcast(_rpc_lightning_fx, [network_session_id(), _presentation_event_id, card_id, pos, radius, team])

func _show_lightning_spell(event_id: int, card_id: String, pos: Vector2, radius: float, team: int) -> void:
	if not has_presentation(): return
	if event_id <= _last_card_event_id: return
	_spell_system.show_lightning(card_id, pos, radius)
	_play_card_event(event_id, card_id, "spell:strike", pos, 0, team)

@rpc("authority", "call_remote", "reliable")
func _rpc_lightning_fx(epoch: String, event_id: int, card_id: String, pos: Vector2, radius: float, team: int) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over or runtime.mode != "client": return
	if card_id not in ["zap", "lightning"]: return
	_show_lightning_spell(event_id, card_id, pos, radius, team)

func present_lightning_area(card_id: String, pos: Vector2, radius: float, duration: float, team: int) -> void:
	_presentation_event_id += 1
	_show_lightning_area(_presentation_event_id, card_id, pos, radius, duration, team)
	if runtime.mode == "server":
		_broadcast(_rpc_lightning_area, [network_session_id(), _presentation_event_id, card_id, pos, radius, duration, team])

func _show_lightning_area(event_id: int, card_id: String, pos: Vector2, radius: float, duration: float, team: int) -> void:
	if not has_presentation(): return
	if event_id <= _last_card_event_id: return
	_last_card_event_id = event_id
	_spell_system.show_lightning_area(card_id, pos, radius, duration, team)

@rpc("authority", "call_remote", "reliable")
func _rpc_lightning_area(epoch: String, event_id: int, card_id: String, pos: Vector2, radius: float, duration: float, team: int) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over or runtime.mode != "client": return
	if card_id not in ["zap", "lightning"]: return
	_show_lightning_area(event_id, card_id, pos, radius, duration, team)

func project_effect_height(point: Vector2, height: float) -> Vector2:
	return _battle_presentation.project_height(point, height) if _battle_presentation != null else point - Vector2(0.0, height * 28.0)

func present_growth_wave(target: Unit, radius: float) -> void:
	var effect := _skill_presentation.add_growth_wave(target, radius)
	publish_skill_fx(effect)

func present_spell_flight(flight_id: int, kind: String, origin: Vector2, pos: Vector2, radius: float, start_tick: int, impact_tick: int, team: int) -> void:
	_presentation_event_id += 1
	_show_spell_flight(_presentation_event_id, flight_id, kind, origin, pos, radius, start_tick, impact_tick, team)
	if runtime.mode == "server":
		_broadcast(_rpc_spell_flight, [network_session_id(), _presentation_event_id, flight_id, kind, origin, pos, radius, start_tick, impact_tick, team])

func _show_spell_flight(event_id: int, flight_id: int, kind: String, origin: Vector2, pos: Vector2, radius: float, start_tick: int, impact_tick: int, team: int) -> void:
	if not has_presentation(): return
	if event_id <= _last_card_event_id: return
	_spell_system.show_flight(flight_id, kind, origin, pos, radius, start_tick, impact_tick)
	if kind in ["stasis", "explosive_cask"]:
		_play_card_event(event_id, kind, "spell:cast", origin, 0, team)
		_audio_manager.start_spell_flight_audio(flight_id, kind, team, origin)
	else: _last_card_event_id = event_id

@rpc("authority", "call_remote", "reliable")
func _rpc_spell_flight(epoch: String, event_id: int, flight_id: int, kind: String, origin: Vector2, pos: Vector2, radius: float, start_tick: int, impact_tick: int, team: int) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over or runtime.mode != "client": return
	_show_spell_flight(event_id, flight_id, kind, origin, pos, radius, start_tick, impact_tick, team)

func present_spell_arrival(flight_id: int, kind: String, pos: Vector2, team: int) -> void:
	_presentation_event_id += 1
	_show_spell_arrival(_presentation_event_id, flight_id, kind, pos, team)
	if runtime.mode == "server":
		_broadcast(_rpc_spell_arrival, [network_session_id(), _presentation_event_id, flight_id, kind, pos, team])

func _show_spell_arrival(event_id: int, flight_id: int, kind: String, pos: Vector2, team: int) -> void:
	if not has_presentation(): return
	if event_id <= _last_card_event_id: return
	_spell_system.show_arrival(flight_id)
	_audio_manager.stop_spell_flight_audio(flight_id)
	if kind in ["stasis", "explosive_cask"]: _play_card_event(event_id, kind, "spell:strike", pos, 0, team)
	else: _last_card_event_id = event_id

@rpc("authority", "call_remote", "reliable")
func _rpc_spell_arrival(epoch: String, event_id: int, flight_id: int, kind: String, pos: Vector2, team: int) -> void:
	if not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING) or runtime.game_over or runtime.mode != "client": return
	_show_spell_arrival(event_id, flight_id, kind, pos, team)

func present_corrosion_spell(pos: Vector2, radius: float, duration: float, p_team: int) -> void:
	_presentation_event_id += 1
	if _audio_manager != null:
		_audio_manager.start_zone_audio(_presentation_event_id, "corrosion", 0, "spell", pos, duration, p_team)
	if runtime.mode == "server":
		_broadcast(_rpc_zone_audio, [network_session_id(), _presentation_event_id, "corrosion", 0, "spell", pos, duration, p_team])
		_broadcast(_rpc_corrosion_fx, [network_session_id(), _presentation_event_id, pos, radius, duration, p_team])

@rpc("authority", "call_remote", "reliable")
func _rpc_corrosion_fx(epoch: String, event_id: int, pos: Vector2, radius: float, duration: float, p_team: int) -> void:
	if runtime.mode != "client" or runtime.game_over or not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING): return
	if p_team not in [0, 1] or not pos.is_finite() or not is_finite(radius) or not is_finite(duration) or radius <= 0.0 or duration <= 0.0: return
	if event_id <= _last_card_event_id: return
	_last_card_event_id = event_id
	_spell_system.show_corrosion(pos, radius, duration, p_team)

## 返回菜单不能再次执行 CLI 的 join/local 自动启动，服务器进程的自动重建不走此入口。
func return_to_main_menu() -> void:
	get_tree().set_meta("return_to_main_menu", true)
	get_tree().reload_current_scene()

func present_cask_hit(pos: Vector2, team: int) -> void:
	_presentation_event_id += 1
	_play_card_event(_presentation_event_id, "explosive_cask", "spell:hit", pos, 0, team)
	if runtime.mode == "server":
		_broadcast(_rpc_card_event, [network_session_id(), _presentation_event_id, "explosive_cask", "spell:hit", pos, 0, team])

func present_summoning_spell(pos: Vector2, radius: float, duration: float, p_team: int) -> void:
	_presentation_event_id += 1
	if _audio_manager != null:
		_audio_manager.start_zone_audio(_presentation_event_id, "void_summoning", 0, "spell", pos, duration, p_team)
	if runtime.mode == "server":
		_broadcast(_rpc_zone_audio, [network_session_id(), _presentation_event_id, "void_summoning", 0, "spell", pos, duration, p_team])
		_broadcast(_rpc_summoning_fx, [network_session_id(), _presentation_event_id, pos, radius, duration, p_team])

@rpc("authority", "call_remote", "reliable")
func _rpc_summoning_fx(epoch: String, event_id: int, pos: Vector2, radius: float, duration: float, p_team: int) -> void:
	if runtime.mode != "client" or runtime.game_over or not runtime.session.accepts(1, epoch, MatchSession.Phase.RUNNING): return
	if p_team not in [0, 1] or not pos.is_finite() or not is_finite(radius) or not is_finite(duration) or radius <= 0.0 or duration <= 0.0: return
	if event_id <= _last_card_event_id: return
	_last_card_event_id = event_id
	_spell_system.show_summoning(pos, radius, duration, p_team)

## 请求适配只管理客户端反馈，领域准入不读取手牌控件或按钮 pending。
func play_card(p_team: int, card_id: String, pos: Vector2, options: Dictionary = {}) -> bool:
	if not bool(options.get("client_request", false)):
		return runtime.play_card(p_team, card_id, pos, options)
	if runtime.mode != "client" or p_team != runtime.local_team or not runtime.can_request_card(p_team, card_id, pos) or bool(options.get("immediate", false)):
		return false
	var payer := runtime.account(p_team)
	if payer == null or not payer.can_afford(runtime.card_cost_for_team(p_team, card_id)) or card_id not in _client_hand.hand:
		return false
	if _client_inputs.has_card(card_id): return false
	if CardPlayHistory.is_mirror(card_id):
		for id in _client_hand.hand:
			if not CardPlayHistory.is_mirror(id) and _client_inputs.has_card(id): return false
	pos = runtime._snap_card_position(card_id, pos, p_team)
	_network_request_id += 1
	_client_inputs.card(card_id, _network_request_id, pos)
	_send_card_request(card_id, pos, _input_tick_for_new_command(), _network_request_id)
	if _hand != null: _hand.set_card_pending(card_id, true)
	queue_redraw()
	return true

func _on_runtime_changed() -> void:
	_sync_active_skill_deployment_readiness()
	_update_timer_label()

func _on_runtime_event(kind: String, data: Dictionary) -> void:
	match kind:
		"hand_changed": _sync_card_cycle_ui(int(data.team))
		"history_changed": _refresh_mirror_hand(int(data.team))
		"preview_spawned":
			if _workbench.inspect_enabled: _workbench.inspect(data.unit)
		"command_scheduled":
			_network_commands.receive(data)
			if runtime.mode == "server": _broadcast(_rpc_command_scheduled, [runtime.session.session_id, data])
		"command_finished": _complete_network_command(int(data.id), String(data.outcome))
		"card_accepted":
			if runtime.mode == "server" and int(data.peer) > 0:
				_rpc_deploy_accepted.rpc_id(int(data.peer), runtime.session.session_id, String(data.card_id), int(data.tick), runtime.visible_hand_state(int(data.team)))
		"skill_removed":
			_client_inputs.forget_skill(int(data.id))
			if _active_skill_bar != null: _active_skill_bar.remove_skill(int(data.id))
		"skill_registered": _show_registered_skill(int(data.id))
		"skill_used":
			if runtime.mode == "server": _broadcast(_rpc_active_skill_used, [runtime.session.session_id, int(data.id), int(data.uses_remaining), float(data.cooldown_left), bool(data.free_recast)])
		"skill_fx": publish_skill_fx(data)
		"card_event": _emit_card_event(String(data.card_id), String(data.cue), data.pos, int(data.team))
		"pre_deploy":
			if runtime.mode == "server": _broadcast(_rpc_card_pre_deploy_started, [runtime.session.session_id, int(data.id), String(data.card_id), int(data.team), data.pos, float(data.duration)])
		"cast_notice": _present_cast_notice(int(data.team), String(data.card_id), int(data.index))
		"announcement": _present_match_announcement(String(data.cue))
		"match_finished": _end_game(int(data.winner_team), String(data.reason))
		"growth_changed":
			if _hand != null: _hand._refresh(0.0)

func _emit_card_event(card_id: String, cue: String, pos: Vector2, team: int) -> void:
	_presentation_event_id += 1
	_play_card_event(_presentation_event_id, card_id, cue, pos, 0, team)
	if runtime.mode == "server": _broadcast(_rpc_card_event, [runtime.session.session_id, _presentation_event_id, card_id, cue, pos, 0, team])

func _show_registered_skill(id: int) -> void:
	var entry: Dictionary = runtime._active_skills.entry(id)
	if entry.is_empty() or not _is_local_player_team(int(entry.team)) or _active_skill_bar == null: return
	var skill: Dictionary = entry.skill
	var unit: Unit = entry.unit
	_active_skill_bar.show_skill(int(entry.slot), id, String(skill.name), CardDB.get_card(String(entry.card_id)).get("color", CardArt.DEFAULT_ACCENT), float(skill.get("cost", 0.0)), 0 if bool(skill.get("unlimited_uses", false)) else int(entry.max_uses), int(entry.max_uses), float(skill.get("cooldown", 0.0)), unit.is_deployed(), CardArt.skill_icon(skill))

func spawn_summoned(p_team: int, card_id: String, pos: Vector2, deploy_time_override: float = -1.0, visual_transition: String = "", death_replacement_charges_override: int = -1, summon_visual_origin: Vector2 = Vector2.INF, limit_center: Vector2 = Vector2.INF, limit_radius: float = 0.0) -> Unit:
	return runtime.spawn_summoned(p_team, card_id, pos, deploy_time_override, visual_transition, death_replacement_charges_override, summon_visual_origin, limit_center, limit_radius)

func get_authoritative_hand(p_team: int) -> Array:
	if is_net_client(): return _client_hand.hand.duplicate() if p_team == runtime.local_team else []
	return runtime.get_authoritative_hand(p_team)

func _cast_spell(p_team: int, card_id: String, pos: Vector2, active_enabled: bool = false, active_skill_index: int = 0, mirror_copy: Dictionary = {}, announce: bool = true) -> bool:
	return runtime._cast_spell(p_team, card_id, pos, active_enabled, active_skill_index, mirror_copy, announce)

func _tick_development_adapter(dt: float) -> void:
	# 联机测试钩子：主动变大序列结束后再强制变小，覆盖双向形态序号与动作快照。
	if _auto_gnar_revert_timer > 0.0:
		_auto_gnar_revert_timer = maxf(0.0, _auto_gnar_revert_timer - dt)
		if _auto_gnar_revert_timer <= 0.0 and _auto_gnar_revert_unit != null and is_instance_valid(_auto_gnar_revert_unit):
			_auto_gnar_revert_unit.transform_to_small()
	# 进入模拟 2 秒后生成近战、远程、弹道、持续吐息与双形态样本。
	if _auto_test:
		_auto_timer -= dt
		if _auto_timer <= 0.0:
			_auto_test = false
			runtime._deploy_card(0, "garen", Vector2(360, 1000))
			runtime._deploy_card(0, "ashe", Vector2(300, 700))
			runtime._deploy_card(0, "aurelionsol", Vector2(410, 700))
			runtime._deploy_card(1, "xin", Vector2(300, 580))
			var auto_gnar: Unit = _spawn_unit(UnitSpawnRequest.new(0, "gnar", Vector2(520, 760), {"deploy_time_override": 0.0}))
			preview_active_skill(auto_gnar, CardDB.active_skills_for("gnar")[0])
			_auto_gnar_revert_unit = auto_gnar
			_auto_gnar_revert_timer = 2.4

func _can_submit_active_skill(id: int, team: int = -1) -> bool:
	if runtime.mode == "client" and (_client_inputs.has_skill(id) or _network_commands.has_skill(id)): return false
	return runtime._can_submit_active_skill(id, team)
