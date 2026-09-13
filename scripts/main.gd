extends Node2D
## 主场景：战场搭建、部署输入、敌方占位出兵、胜负判定。

const WORKBENCH_SCRIPT := preload("res://scripts/ui/development_workbench.gd")
const ACTIVE_SKILL_BAR_SCRIPT := preload("res://scripts/ui/active_skill_bar.gd")
const SPELL_SYSTEM_SCRIPT := preload("res://scripts/battle/spell_system.gd")
const ACTIVE_SKILL_EFFECT_SYSTEM_SCRIPT := preload("res://scripts/battle/active_skill_effect_system.gd")
const AUDIO_MANAGER_SCRIPT := preload("res://scripts/audio/game_audio_manager.gd")
const ARENA_BACKGROUND_TEXTURE := preload("res://assets/arena/arena_rift_v4.png")

# 比赛计时：3 分 05 秒正赛，平局进 2 分钟加时（先破塔者胜），再平则平局
const MATCH_TIME := MatchRules.REGULATION_TIME
const OVERTIME_TIME := MatchRules.OVERTIME_TIME
const SIM_DT := FixedStepClock.STEP
const DOUBLE_ELIXIR_TIME := 60.0
const OVERTIME_TRIPLE_ELIXIR_TIME := 60.0
const DOUBLE_ELIXIR_START_TIME := MATCH_TIME - DOUBLE_ELIXIR_TIME
## 所有玩家命令使用 20Hz 权威 Tick 排程，0.5 秒对应 10 个模拟 Tick。
const COMMAND_DELAY_TICKS := 10
## 网络请求的 input_tick 最多允许落后两个 Buffer；更早的输入直接视为异常。
const COMMAND_MAX_LATENCY_TICKS := COMMAND_DELAY_TICKS * 2
## 允许少量客户端时钟领先 Host；这只是校验窗口，不是客户端执行权。
const COMMAND_CLOCK_FUTURE_TOLERANCE := 2
## 水晶兵线由主机固定 tick 驱动：普通阶段 5/50/95 秒，2:05 切换炮车并改为每 30 秒一波，第二只延迟 0.5 秒。
const FIRST_MINION_WAVE_TIME := 5.0
const NORMAL_MINION_WAVE_INTERVAL := 45.0
const DOUBLE_MINION_WAVE_INTERVAL := 30.0
const MINION_WAVE_STAGGER := 0.5
const MINION_SPAWN_X_OFFSET := 3.0 * ArenaRules.TILE_SIZE
const MINION_WAVE_NORMAL := "normal"
const MINION_WAVE_SIEGE := "siege"

# 联机
const NET_PORT := 39152

var _presentation_event_id := 0
var _last_card_event_id := -1
var _commands := CommandSchedule.new()
var _effects_view: BattleEffects2D
var _resources := MatchResources.new()
var _combat: CombatResolver
var _movement: MovementSystem
var game_over := false
var nav: NavGrid
var battle_context: BattleContext
var mode := "local"  # local=单机 / host=主机 / client=客户端
var _match_started := false  # 比赛是否已开始（联机时主机需等对手加入）
## 强化冰冻结束后的权威减速区域与客户端纯视觉区域分开保存。
## 治疗术淡黄光效区域；治疗本身立即结算，这里只保存表现。
var _spell_system: RefCounted
## 纳尔 Spell2：固定模拟延迟到手掌触地才结算；范围框是独立纯表现数据。
var _active_skill_effect_system: RefCounted
var _projectile_system: ProjectileSystem
var _projectiles := {}  # 主机/单机：id -> {pos, target, team, damage, speed, ...}
var _client_projectiles := {}  # 客户端仅保存插值表现

var _elixir: ElixirManager
var _hand: CardHand
var _active_skill_bar: ActiveSkillBar
var _arena_background_sprite: Sprite2D
## ability_id -> {unit, card_id, team, skill, uses_remaining, cooldown_left}；按钮只是这份权威状态的视图。
var _active_skills: Dictionary = {}
var _next_active_ability_id := 1
## 一次卡牌部署生成的单位共享同一编队 id；单体卡保持 -1。
var _next_deployment_group_id := 1
## 主动请求确认后按 Host 由 input_tick 计算出的 execute_tick 等待；同一 ability_id 只能存在一次。
## Cast Start 后的统一 Gameplay Impact 队列，所有主动技能 kind 共用。
var _ai: AIOpponent
var _selected_card := ""
## 选卡后的落点预览：单位以单格格心为目标，点击时使用当前预览而不是重新猜测落点。
var _deployment_preview_pos := Vector2.ZERO
var _deployment_preview_tile := Vector2i(-1, -1)
var _deployment_preview_valid := false
var _deployment_preview_visible := false
## 主机/单机权威卡牌队列：单位、建筑和法术都在 Host 计算的 execute_tick 才真正生效。
## 两段式单位部署：第一段只有落点提示，第二段才生成单位并进入 Unit.deploy_time。
## 客户端也复用这份表现队列，直到收到权威生成 RPC 后移除标记。
## 兵线第二只单位的权威延迟队列；不经过手牌 0.5 秒部署队列，也不扣金币。
var _pending_lane_minions: Array[Dictionary] = []
var _battle_elapsed := 0.0
var _next_minion_wave_time := FIRST_MINION_WAVE_TIME
var _minion_waves_enabled := true
# 本次对战选定的 8 张卡组（空表示未指定，随机取）
var _deck: Array = []
## card_id -> active_skills 候选下标。界面与联机协议保留多候选选择，但每次出战只携带一项。
var _active_skill_choices: Dictionary = {}
var _skin_choices: Dictionary = {}
## 主机收到的客户端卡组；用于校验出牌归属及前两槽主动资格。
var _remote_deck: Array = []
var _remote_active_skill_choices: Dictionary = {}
## team -> {deck, hand, queue}。主机同时维护双方；客户端只维护自己的本地镜像。
var _authoritative_card_cycles: Dictionary = {}
var _deck_builder: DeckBuilder
var _match_rules := MatchRules.new()
var _timer_label: Label
var _king_player: Tower
var _king_enemy: Tower
var _towers: Array[Tower] = []
var _battle_presentation: BattlePresentation3D
var _audio_manager: GameAudioManager
var _art_dev_mode := false
var _art_dev_selection := "training_dummy"
var _art_dev_team := 1
var _art_dev_spell_active := false
var _art_dev_panel: DevelopmentWorkbench
var _art_dev_last_units: Dictionary = {}
var _workbench_preset_loading := false
var _art_dev_active_skill_choices: Dictionary = {}

# 主菜单
var _menu_layer: CanvasLayer
var _menu_status: Label
var _ip_input: LineEdit
# 主机端：对手（客户端玩家）的金币
var _elixir_p1: ElixirManager
# 主机端：net_id -> Unit
var _net_units := {}
var _next_net_id := 1000
var _snapshot_system: NetworkSnapshotSystem
var _snapshot_timer := 0.0
const SNAPSHOT_INTERVAL := 0.05
# 客户端：net_id -> Unit
var _client_units := {}
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
# 固定 20Hz 模拟累加器：帧率高低都不影响战斗逻辑步数
var _simulation_clock := FixedStepClock.new()
## 客户端由快照提供的最后已知主机 Tick，用于生成 input_tick。
var _authoritative_server_tick := 0
## 客户端只估计服务器时钟，不推进任何战斗状态；快照到达时向前校正，间隔内按本地时间补 Tick。
var _estimated_server_tick := 0
var _estimated_server_tick_fraction := 0.0
var _has_estimated_server_tick := false
var _sim_tick_id := 0

func _ready() -> void:
	_setup_arena_background()
	_simulation_clock.step = _sim_step
	_simulation_clock.running = func(): return not game_over
	_combat = CombatResolver.new()
	_combat.attack_hit.connect(_notify_attack_presentation)
	add_child(_combat)
	_match_rules.overtime_started.connect(_on_overtime_started)
	_movement = MovementSystem.new()
	_movement.terrain_walkable = _is_ground_terrain_walkable
	_movement.structure_gap = _structure_gap_to_circle
	add_child(_movement)
	battle_context = BattleContext.new(self)
	_spell_system = SPELL_SYSTEM_SCRIPT.new(self)
	_active_skill_effect_system = ACTIVE_SKILL_EFFECT_SYSTEM_SCRIPT.new(self)
	_commands.impact = _active_skill_effect_system.apply
	_commands.cast_end = _active_skill_effect_system.apply_cast_end
	_effects_view = BattleEffects2D.new()
	_effects_view.spells = _spell_system
	_effects_view.skills = _active_skill_effect_system
	add_child(_effects_view)
	child_entered_tree.connect(_provide_battle_context)
	_projectile_system = ProjectileSystem.new()
	_projectile_system.setup(battle_context)
	_projectile_system.skill_hit.connect(_on_skill_projectile_hit)
	_projectile_system.launch_audio_started.connect(_on_projectile_launch_audio_started)
	_projectile_system.launch_audio_stopped.connect(_on_projectile_launch_audio_stopped)
	add_child(_projectile_system)
	_projectiles = _projectile_system.projectiles
	_client_projectiles = _projectile_system.client_projectiles
	_snapshot_system = NetworkSnapshotSystem.new(self)
	_audio_manager = AUDIO_MANAGER_SCRIPT.new()
	add_child(_audio_manager)
	_projectile_system.launch_audio_cleared.connect(_audio_manager.clear_projectile_launch_audio)
	randomize()
	var card_errors := CardDB.validate_all()
	if not card_errors.is_empty():
		for error in card_errors:
			push_error("[CardDB] " + error)
		return
	var cli := _parse_cli()
	_auto_test = cli.get("auto_test", false)
	match cli.get("mode", ""):
		"host":
			_start_host()
		"join":
			_start_client(cli.get("ip", "127.0.0.1"))
		"local":
			_start_local()
		"workbench":
			_start_art_dev()
		_:
			_show_menu()

func _provide_battle_context(node: Node) -> void:
	if node is Unit:
		(node as Unit).set_battle_context(battle_context)
	elif node is Tower:
		(node as Tower).set_battle_context(battle_context)

## 解析命令行用户参数（-- 之后的部分），用于无界面联机测试
func _parse_cli() -> Dictionary:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a == "--auto-test":
			args["auto_test"] = true
		elif a.begins_with("--mode="):
			args["mode"] = a.trim_prefix("--mode=")
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
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_layer.add_child(root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)
	var title := Label.new()
	title.text = "Clash Legends"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var btn_solo := _make_menu_button("单机对战 AI")
	btn_solo.pressed.connect(func(): _pick_deck_ui(_start_local))
	vbox.add_child(btn_solo)
	var btn_art_dev := _make_menu_button("卡牌开发工作台")
	btn_art_dev.pressed.connect(_start_art_dev)
	vbox.add_child(btn_art_dev)
	var btn_host := _make_menu_button("创建房间（我做主机）")
	btn_host.pressed.connect(func(): _pick_deck_ui(_start_host))
	vbox.add_child(btn_host)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_ip_input = LineEdit.new()
	_ip_input.text = "127.0.0.1"
	_ip_input.custom_minimum_size = Vector2(220, 0)
	_ip_input.placeholder_text = "对方 IP 地址"
	row.add_child(_ip_input)
	var btn_join := _make_menu_button("加入房间")
	btn_join.pressed.connect(func(): _pick_deck_ui(func(): _start_client(_ip_input.text.strip_edges())))
	row.add_child(btn_join)
	vbox.add_child(row)
	_menu_status = Label.new()
	_menu_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_menu_status)

func _make_menu_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 44)
	return b

func _pick_deck_ui(after_start: Callable) -> void:
	if _deck_builder != null and is_instance_valid(_deck_builder):
		_deck_builder.queue_free()
	_deck_builder = DeckBuilder.new()
	add_child(_deck_builder)
	_deck_builder.open(_deck, _active_skill_choices, _skin_choices, func(selected_deck: Array, active_choices: Dictionary, skin_choices: Dictionary) -> void:
		_deck = selected_deck
		_active_skill_choices = active_choices
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

func _start_local() -> void:
	mode = "local"
	_match_started = true
	queue_redraw()
	_hide_menu()
	_setup_battle_presentation()
	_setup_player_ui()
	_ai = AIOpponent.new()
	add_child(_ai)
	_ai.setup(self, _deck)
	_create_towers()
	_build_nav()
	_create_timer_ui()

## 美术开发模式复用正式模拟与表现，但不创建金币、手牌、AI 和比赛倒计时。
func _start_art_dev() -> void:
	_resources.prepare(CardDB.all().keys())
	mode = "local"
	_match_started = true
	queue_redraw()
	_art_dev_mode = true
	_hide_menu()
	_setup_battle_presentation()
	_create_towers()
	_build_nav()
	_art_dev_panel = WORKBENCH_SCRIPT.new()
	add_child(_art_dev_panel)
	_art_dev_panel.setup(CardDB.all())
	_art_dev_panel.item_selected.connect(_set_art_dev_selection)
	_art_dev_panel.team_changed.connect(_set_art_dev_team)
	_art_dev_panel.active_skill_selected.connect(_on_art_dev_active_skill_selected)
	_art_dev_panel.active_skill_requested.connect(_use_art_dev_active_skill)
	_art_dev_panel.scenario_requested.connect(_run_workbench_scenario)
	_art_dev_panel.spell_active_changed.connect(func(enabled): _art_dev_spell_active = enabled)
	_art_dev_panel.workspace_changed.connect(_set_workbench_battle_active)
	_art_dev_panel.skill_resource_requested.connect(_set_art_dev_skill_resource)
	_art_dev_panel.clear_requested.connect(_clear_art_dev_units)
	_set_art_dev_selection("garen")
	_set_art_dev_team(0)
	_set_workbench_battle_active(false)
	_art_dev_panel.exit_requested.connect(func():
		get_tree().reload_current_scene()
	)

func _start_host() -> void:
	mode = "host"
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(NET_PORT)
	if err != OK:
		if _menu_status != null:
			_menu_status.text = "创建失败：端口 %d 被占用？" % NET_PORT
		return
	multiplayer.multiplayer_peer = peer
	if _menu_status != null:
		_menu_status.text = "房间已创建，等待对手加入…（把你的 IP 告诉对方）"
	print("[联机] 主机：房间已创建，端口 %d" % NET_PORT)
	multiplayer.peer_connected.connect(_on_peer_connected)

func _on_peer_connected(_peer_id: int) -> void:
	print("[联机] 主机：对手已加入，开始比赛")
	# 主机端开局，并通知客户端开局
	_begin_net_match_host()
	_rpc_start.rpc()

func _start_client(ip: String) -> void:
	mode = "client"
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, NET_PORT)
	if err != OK:
		if _menu_status != null:
			_menu_status.text = "连接失败：%s" % ip
		return
	multiplayer.multiplayer_peer = peer
	if _menu_status != null:
		_menu_status.text = "正在连接 %s …" % ip
	print("[联机] 客户端：正在连接 %s:%d" % [ip, NET_PORT])
	multiplayer.connected_to_server.connect(func(): print("[联机] 客户端：已连上主机"))
	multiplayer.connection_failed.connect(func(): print("[联机] 客户端：连接失败"))
	# 之后等主机的 _rpc_start

## 主机端开局：双方金币独立，主机权威模拟
func _begin_net_match_host() -> void:
	_match_started = true
	queue_redraw()
	_hide_menu()
	_setup_battle_presentation()
	_setup_player_ui()
	_elixir_p1 = ElixirManager.new()
	add_child(_elixir_p1)
	_create_towers()
	_build_nav()
	_create_timer_ui()

## 客户端收到主机开局通知
@rpc("authority", "call_remote", "reliable")
func _rpc_start() -> void:
	print("[联机] 客户端：收到开局通知")
	_match_started = true
	queue_redraw()
	_hide_menu()
	_flip_camera()
	_setup_battle_presentation()
	_setup_player_ui()
	_rpc_register_deck.rpc_id(1, _deck, _active_skill_choices)
	_create_towers()
	_build_nav()
	_create_timer_ui()

## 客户端是上方玩家：相机旋转 180°，让自己半场显示在屏幕下方
func _flip_camera() -> void:
	var cam := Camera2D.new()
	# 只旋转 1280px 高的战场；下方额外的 120px 手牌区保持不动。
	var viewport_height := get_viewport_rect().size.y
	cam.position = Vector2(ArenaRules.FIELD_W / 2.0, ArenaRules.FIELD_H - viewport_height / 2.0)
	cam.rotation = PI
	add_child(cam)
	cam.make_current()

func _setup_player_ui() -> void:
	_resources.prepare(CardDB.selectable_ids() if _deck.is_empty() else _deck)
	_resources.prepare(_remote_deck + ["melee_minion", "ranged_minion", "siege_minion", "super_minion"])
	_elixir = ElixirManager.new()
	add_child(_elixir)
	_hand = CardHand.new()
	add_child(_hand)
	_hand.setup(_elixir, _deck)
	_hand.set_active_skill_cards(_deck.slice(0, 2))
	_hand.card_selected.connect(_on_card_selected)
	var local_team := 1 if mode == "client" else 0
	_initialize_authoritative_card_cycle(local_team, _deck)
	if mode == "local":
		_initialize_authoritative_card_cycle(1, _deck)
	_active_skill_bar = ACTIVE_SKILL_BAR_SCRIPT.new()
	add_child(_active_skill_bar)
	_active_skill_bar.skill_pressed.connect(_on_active_skill_pressed)
	_active_skill_bar.set_elixir(_elixir.elixir)
	_elixir.changed.connect(_active_skill_bar.set_elixir)

func _is_local_player_team(p_team: int) -> bool:
	return p_team == (1 if mode == "client" else 0)

func _team_deck(p_team: int) -> Array:
	if mode == "host" and p_team == 1:
		return _remote_deck
	return _deck

func _initialize_authoritative_card_cycle(p_team: int, deck: Array) -> bool:
	if deck.size() != 8:
		_authoritative_card_cycles.erase(p_team)
		return false
	var normalized: Array = []
	for raw_card_id in deck:
		normalized.append(String(raw_card_id))
	var cycle := {
		"deck": normalized.duplicate(),
		"hand": normalized.slice(0, 4),
		"queue": normalized.slice(4, 8),
	}
	_authoritative_card_cycles[p_team] = cycle
	if _hand != null and _is_local_player_team(p_team):
		_hand.set_cycle_state(cycle.hand, cycle.queue)
	return true

func _ensure_authoritative_card_cycle(p_team: int) -> bool:
	var team_deck := _team_deck(p_team)
	if team_deck.size() != 8:
		return false
	var cycle: Dictionary = _authoritative_card_cycles.get(p_team, {})
	var normalized: Array = []
	for raw_card_id in team_deck:
		normalized.append(String(raw_card_id))
	if cycle.is_empty() or cycle.get("deck", []) != normalized:
		return _initialize_authoritative_card_cycle(p_team, normalized)
	return true

func get_authoritative_hand(p_team: int) -> Array:
	if not _ensure_authoritative_card_cycle(p_team):
		return []
	var cycle: Dictionary = _authoritative_card_cycles[p_team]
	return cycle.hand.duplicate()

func get_authoritative_queue(p_team: int) -> Array:
	if not _ensure_authoritative_card_cycle(p_team):
		return []
	var cycle: Dictionary = _authoritative_card_cycles[p_team]
	return cycle.queue.duplicate()

func _authoritative_card_in_hand(p_team: int, card_id: String) -> bool:
	return card_id in get_authoritative_hand(p_team)

func _consume_authoritative_card(p_team: int, card_id: String) -> bool:
	if not _ensure_authoritative_card_cycle(p_team):
		return false
	var cycle: Dictionary = _authoritative_card_cycles[p_team]
	var hand: Array = cycle.hand
	var queue: Array = cycle.queue
	var hand_index := hand.find(card_id)
	if hand_index < 0 or queue.is_empty():
		return false
	hand[hand_index] = queue.pop_front()
	queue.push_back(card_id)
	cycle.hand = hand
	cycle.queue = queue
	_authoritative_card_cycles[p_team] = cycle
	if _hand != null and _is_local_player_team(p_team):
		_hand.set_cycle_state(hand, queue)
	return true

## 客户端只用本地时间估计服务器 Tick；这里不调用 _sim_step，也不触碰任何战斗状态。
func _advance_estimated_server_tick(delta: float) -> void:
	if mode != "client" or not _has_estimated_server_tick or delta <= 0.0:
		return
	_estimated_server_tick_fraction += delta
	while _estimated_server_tick_fraction >= SIM_DT:
		_estimated_server_tick += 1
		_estimated_server_tick_fraction -= SIM_DT

## 接收快照中的权威时钟。乱序快照被拒绝；若本地估计已经领先，则不让旧快照把命令时钟拨回去。
func _accept_authoritative_server_tick(server_tick: int) -> bool:
	if mode != "client" or server_tick < 0 or server_tick < _authoritative_server_tick:
		return false
	_authoritative_server_tick = server_tick
	if not _has_estimated_server_tick or server_tick >= _estimated_server_tick:
		_estimated_server_tick = server_tick
		_estimated_server_tick_fraction = 0.0
	_has_estimated_server_tick = true
	return true

func get_estimated_server_tick() -> int:
	return _estimated_server_tick if _has_estimated_server_tick else _authoritative_server_tick

## Host/单机本地输入发生在当前权威 Tick；客户端请求则携带点击时观察到的 input_tick。
func _input_tick_for_new_command() -> int:
	return _current_authority_tick()

## 仅供 Host/单机本地命令读取其固定的 10 Tick 目标；网络请求不能直接提交 execute_tick。
func _authority_tick_for_new_command() -> int:
	return _input_tick_for_new_command() + COMMAND_DELAY_TICKS

## 所有卡牌与主动技能共用：Command Buffer 从 input_tick 开始计时，网络耗时消耗其中一部分。
## 返回 -1 表示迟到或时钟明显异常；Host 不会把已过期请求重新排到 current + 10。
func _resolve_command_execute_tick(input_tick: int = -1) -> int:
	var current_tick := _current_authority_tick()
	# -1 只表示 Host/单机本地输入；RPC 入口会拒绝缺失的客户端 input_tick。
	if input_tick < 0:
		return current_tick + COMMAND_DELAY_TICKS
	if input_tick < current_tick - COMMAND_MAX_LATENCY_TICKS:
		return -1
	if input_tick > current_tick + COMMAND_CLOCK_FUTURE_TOLERANCE:
		return -1
	var execute_tick := input_tick + COMMAND_DELAY_TICKS
	# 网络延迟已经耗尽整个 Buffer 时，按明确 late policy 拒绝，不再追加一轮 Buffer。
	if execute_tick <= current_tick:
		return -1
	return execute_tick

func _current_authority_tick() -> int:
	return get_estimated_server_tick() if mode == "client" else _sim_tick_id

func get_authoritative_server_tick() -> int:
	return _authoritative_server_tick if mode == "client" else _sim_tick_id

func _team_active_skill_choices(p_team: int) -> Dictionary:
	if mode == "host" and p_team == 1:
		return _remote_active_skill_choices
	return _active_skill_choices

func _active_skill_choice_for_team(p_team: int, card_id: String, skill_count: int) -> int:
	if skill_count <= 0:
		return -1
	return clampi(int(_team_active_skill_choices(p_team).get(card_id, 0)), 0, skill_count - 1)

func _card_has_active_for_team(p_team: int, card_id: String) -> bool:
	return _active_card_slot_for_team(p_team, card_id) >= 0

func _active_card_slot_for_team(p_team: int, card_id: String) -> int:
	var team_deck := _team_deck(p_team)
	if team_deck.size() != 8:
		return -1
	for slot_index in range(2):
		if String(team_deck[slot_index]) == card_id:
			return slot_index
	return -1

## 法术卡位于主动槽时的实际施放费用：基础费用 + active_cost_bonus（强化治疗 +1）。
## 单位卡与不在主动槽的法术卡返回原费用；出牌扣费、客户端预检和 UI 角标共用这一口径。
func card_cost_for_team(p_team: int, card_id: String) -> int:
	var stats := CardDB.get_card(card_id)
	var cost := int(stats.get("cost", 0))
	if StringName(stats.get("type", "")) != &"spell":
		return cost
	var cost_bonus := int(stats.get("active_cost_bonus", 0))
	if cost_bonus > 0 and _active_card_slot_for_team(p_team, card_id) >= 0:
		return cost + cost_bonus
	return cost

func is_net_client() -> bool:
	return mode == "client"

## 固定模拟完成后剩余时间占一个 tick 的比例。所有本地表现共用该值，避免各节点
## 独立累计插值进度，或因 Unit / 3D 代理的 _process 顺序不同而前后跳动。
func get_sim_interpolation_alpha() -> float:
	if mode == "client":
		return 1.0
	return clampf(_simulation_clock.remainder / SIM_DT, 0.0, 1.0)

func _setup_battle_presentation() -> void:
	if _battle_presentation != null:
		return
	_battle_presentation = BattlePresentation3D.new()
	add_child(_battle_presentation)
	_battle_presentation.setup(Vector2(ArenaRules.FIELD_W, ArenaRules.FIELD_H), ArenaRules.TILE_SIZE)
	_battle_presentation.attach_projectile_system(_projectile_system)

## 顶部右侧的比赛计时器
func _create_timer_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 32)
	# CR 计时器位于顶部右侧；避开按官方格位上移后的敌方国王塔血条。
	_timer_label.position = Vector2(ArenaRules.FIELD_W - 132.0, 8.0)
	layer.add_child(_timer_label)
	_update_timer_label()

func _create_towers() -> void:
	# 参考项目格位：公主塔中心 y=6.5/25.5，国王塔 y=3/29。
	for spec in [
		[0, Vector2(ArenaRules.BRIDGE_X_LEFT,  25.5 * ArenaRules.TILE_SIZE)],
		[0, Vector2(ArenaRules.BRIDGE_X_RIGHT, 25.5 * ArenaRules.TILE_SIZE)],
		[1, Vector2(ArenaRules.BRIDGE_X_LEFT,  6.5 * ArenaRules.TILE_SIZE)],
		[1, Vector2(ArenaRules.BRIDGE_X_RIGHT, 6.5 * ArenaRules.TILE_SIZE)],
	]:
		var t := Tower.new()
		t.setup(spec[0], CardDB.PRINCESS_TOWER_STATS, false)
		t.position = spec[1]
		add_child(t)
		t.z_index = 10
		if _battle_presentation != null:
			_battle_presentation.attach_tower(t, CardDB.PRINCESS_TOWER_VISUAL_CONFIG)
		_towers.append(t)
	_king_player = Tower.new()
	_king_player.setup(0, CardDB.NEXUS_STATS, true)
	_king_player.position = Vector2(9.0 * ArenaRules.TILE_SIZE, 29.0 * ArenaRules.TILE_SIZE)
	add_child(_king_player)
	_king_player.z_index = 10
	if _battle_presentation != null:
		_battle_presentation.attach_tower(_king_player, CardDB.NEXUS_VISUAL_CONFIG)
	_towers.append(_king_player)
	_king_enemy = Tower.new()
	_king_enemy.setup(1, CardDB.NEXUS_STATS, true)
	_king_enemy.position = Vector2(9.0 * ArenaRules.TILE_SIZE, 3.0 * ArenaRules.TILE_SIZE)
	add_child(_king_enemy)
	_king_enemy.z_index = 10
	if _battle_presentation != null:
		_battle_presentation.attach_tower(_king_enemy, CardDB.NEXUS_VISUAL_CONFIG)
	_towers.append(_king_enemy)
	for tower in _towers:
		var audio_id := PresentationConfig.world_card_id(tower)
		tower.destroyed.connect(_on_world_building_destroyed.bind(audio_id, weakref(tower)))
		if _audio_manager != null:
			_audio_manager.attach_building_audio(tower, CardDB.NEXUS_VISUAL_CONFIG if tower.is_king else CardDB.PRINCESS_TOWER_VISUAL_CONFIG)

func _on_world_building_destroyed(audio_id: String, tower_ref: WeakRef) -> void:
	var tower = tower_ref.get_ref()
	if is_instance_valid(tower) and _audio_manager != null:
		_audio_manager.stop_building_audio(tower.get_instance_id())
		_audio_manager.play_card_event(audio_id, "death", tower.global_position)

## 构建导航网格：河道（除两座桥）与所有防御塔为障碍
func _build_nav() -> void:
	nav = NavGrid.new()
	var obstacles := []
	for t in _towers:
		# 塔后最后一行是合法出生区；圆形导航占地只按最大单位半径扩张，
		# 不再额外扩大到合法点上，否则 A* 会先让单位后退以离开实心格。
		obstacles.append([t.position, t.body_radius + ArenaRules.NAV_CLEARANCE])
	nav.build(
		Vector2(ArenaRules.FIELD_W, ArenaRules.FIELD_H),
		ArenaRules.RIVER_Y, ArenaRules.RIVER_HALF + ArenaRules.NAV_CLEARANCE,
		[ArenaRules.BRIDGE_X_LEFT, ArenaRules.BRIDGE_X_RIGHT],
		ArenaRules.BRIDGE_HALF - ArenaRules.NAV_CLEARANCE,
		obstacles
	)
	# 记录每个塔的占地格，塔被摧毁时解除阻挡（路径可穿过原塔位）
	for t in _towers:
		t.nav_cells = nav.cells_for_circle(t.position, t.body_radius + ArenaRules.NAV_CLEARANCE)

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
	var my_team := 1 if mode == "client" else 0
	var tile := _world_to_arena_tile(pointer_pos)
	tile.x = clampi(tile.x, 0, ArenaRules.ARENA_COLUMNS - 1)
	tile.y = clampi(tile.y, 0, ArenaRules.ARENA_ROWS - 1)
	_deployment_preview_tile = tile
	_deployment_preview_pos = _snap_card_position(_selected_card, pointer_pos, my_team)
	_deployment_preview_visible = true
	_deployment_preview_valid = is_card_deploy_position_valid(my_team, _selected_card, _deployment_preview_pos)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if _art_dev_mode:
		if _art_dev_panel != null and not _art_dev_panel.accepts_battle_input():
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var art_pos := get_global_mouse_position()
			if art_pos.x >= 0.0 and art_pos.x < ArenaRules.FIELD_W and art_pos.y >= 0.0 and art_pos.y < ArenaRules.FIELD_H:
				_place_art_dev_item(art_pos)
		return
	if game_over or _selected_card == "":
		return
	if event is InputEventMouseMotion:
		_update_deployment_preview(get_global_mouse_position())
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 点击前再刷新一次，确保刚进入目标格时使用的是屏幕上看到的那一格。
		_update_deployment_preview(get_global_mouse_position())
		if not _deployment_preview_visible:
			return
		var my_team := 1 if mode == "client" else 0
		var pos := _deployment_preview_pos
		if not _deployment_preview_valid:
			return
		var used_card := _selected_card
		var accepted := play_card(my_team, used_card, pos, {
			"elixir": _elixir,
			"client_request": mode == "client",
		})
		if not accepted:
			return
		_selected_card = ""
		_clear_deployment_preview()
		_hand.clear_selection()
		queue_redraw()

func _place_art_dev_item(pos: Vector2) -> void:
	if _art_dev_selection == "training_dummy":
		pos = _snap_to_tile_center(pos)
		var stats := CardDB.training_dummy_stats()
		var dummy := Unit.new()
		dummy.position = pos
		dummy.setup(_art_dev_team, stats, stats.name)
		dummy.card_id = "training_dummy"
		add_child(dummy)
		_register_dynamic_building(dummy)
		_art_dev_last_units[_art_dev_unit_key("training_dummy", _art_dev_team)] = weakref(dummy)
		_sync_art_dev_panel_state()
		return
	if not CardDB.has_card(_art_dev_selection):
		return
	pos = _snap_card_position(_art_dev_selection, pos, _art_dev_team)
	if play_card(_art_dev_team, _art_dev_selection, pos, {"immediate": true, "validate_position": false, "preview_active_spell": _art_dev_spell_active}):
		var unit := _latest_unit_for_card(_art_dev_selection, _art_dev_team)
		if unit != null:
			_art_dev_last_units[_art_dev_unit_key(_art_dev_selection, _art_dev_team)] = weakref(unit)
			_configure_art_dev_unit_skill(unit)
			_sync_art_dev_panel_state()

func _latest_unit_for_card(card_id: String, p_team: int) -> Unit:
	var latest: Unit = null
	for combatant in get_tree().get_nodes_in_group("combatants"):
		if combatant is Unit and combatant.card_id == card_id and combatant.team == p_team:
			latest = combatant as Unit
	return latest

func _art_dev_selected_unit() -> Unit:
	var candidate_ref = _art_dev_last_units.get(_art_dev_unit_key(_art_dev_selection, _art_dev_team))
	var candidate = (candidate_ref as WeakRef).get_ref() if candidate_ref is WeakRef else null
	if candidate is Unit and is_instance_valid(candidate) and candidate.hp > 0.0:
		return candidate as Unit
	return null

func _art_dev_unit_key(card_id: String, p_team: int) -> String:
	return "%s:%d" % [card_id, p_team]

func _set_art_dev_selection(item_id: String) -> void:
	_art_dev_selection = item_id
	_art_dev_spell_active = false
	_sync_art_dev_panel_state()

func _set_art_dev_team(team: int) -> void:
	_art_dev_team = team
	_sync_art_dev_panel_state()

func _art_dev_selected_skill(card_id: String = "", requested_index: int = -1) -> Dictionary:
	var resolved_card_id := _art_dev_selection if card_id.is_empty() else card_id
	var skills := CardDB.active_skills_for(resolved_card_id)
	if skills.is_empty():
		return {}
	var selected_index := requested_index
	if selected_index < 0:
		selected_index = int(_art_dev_active_skill_choices.get(resolved_card_id, 0))
	selected_index = clampi(selected_index, 0, skills.size() - 1)
	return skills[selected_index]

func _configure_art_dev_unit_skill(unit: Unit) -> void:
	var skill := _art_dev_selected_skill(unit.card_id)
	if skill.is_empty():
		unit.clear_carried_active_skill_resource()
	else:
		unit.configure_carried_active_skill(skill)

func _on_art_dev_active_skill_selected(item_id: String, skill_index: int) -> void:
	var skills := CardDB.active_skills_for(item_id)
	if skills.is_empty():
		return
	_art_dev_active_skill_choices[item_id] = clampi(skill_index, 0, skills.size() - 1)
	if item_id == _art_dev_selection:
		var unit := _art_dev_selected_unit()
		if unit != null:
			_configure_art_dev_unit_skill(unit)
	_sync_art_dev_panel_state()

## 美术面板不消耗正式主动资格，允许对最后放置的同卡单位反复检查技能演出。
func _use_art_dev_active_skill(skill_index: int = -1) -> void:
	var unit := _art_dev_selected_unit()
	if unit == null or not unit.is_deployed() or unit.is_form_transitioning() or unit.is_active_skill_casting():
		return
	var skill := _art_dev_selected_skill(_art_dev_selection, skill_index)
	if skill.is_empty():
		return
	_art_dev_active_skill_choices[_art_dev_selection] = clampi(skill_index, 0, CardDB.active_skills_for(_art_dev_selection).size() - 1) if skill_index >= 0 else int(_art_dev_active_skill_choices.get(_art_dev_selection, 0))
	unit.configure_carried_active_skill(skill)
	preview_active_skill(unit, skill)
	_sync_art_dev_panel_state()

func _set_art_dev_skill_resource(value: float) -> void:
	var unit := _art_dev_selected_unit()
	if unit == null or not unit.is_skill_resource_visible() or unit.skill_resource_max <= 0.0:
		return
	unit.skill_resource_value = clampf(value, 0.0, unit.skill_resource_max)
	unit.mark_skill_resource_combat_activity()
	unit.queue_redraw()
	_sync_art_dev_panel_state()

## 开发场景操作使用现有单位/出牌接口，不能进入正式比赛。
func _run_workbench_scenario(action: String) -> void:
	if not _art_dev_mode:
		return
	if action.begins_with("preset:"):
		_load_workbench_preset(action.trim_prefix("preset:"))
		return
	var unit := _art_dev_selected_unit()
	match action:
		"spawn":
			_place_art_dev_item(Vector2(300, 780) if _art_dev_team == 0 else Vector2(300, 500))
		"target":
			var old_selection := _art_dev_selection
			var old_team := _art_dev_team
			_art_dev_selection = "training_dummy"
			_art_dev_team = 1 - old_team
			var origin := unit.position if unit != null else Vector2(300, 780 if old_team == 0 else 500)
			_place_art_dev_item(origin + Vector2(0, -100 if old_team == 0 else 100))
			_art_dev_selection = old_selection
			_art_dev_team = old_team
		"freeze":
			if unit != null: unit.freeze(2.0)
		"stun":
			if unit != null: unit.stun(2.0)
		"slow":
			if unit != null: unit.apply_slow(3.0, 0.5)
		"attack_slow":
			if unit != null: unit.apply_attack_speed_slow(3.0, 0.5)
		"death":
			if unit != null: unit.take_damage(unit.max_hp * 100.0)
	_sync_art_dev_panel_state()

func _load_workbench_preset(id: String) -> void:
	if not _art_dev_mode or _workbench_preset_loading:
		return
	var recipe := preload("res://scripts/ui/workbench/battle_scenarios.gd").placements(id, _art_dev_selection, _art_dev_team)
	if recipe.is_empty():
		return
	_workbench_preset_loading = true
	var selection := _art_dev_selection
	var selected_team := _art_dev_team
	var enhanced := _art_dev_spell_active
	_clear_art_dev_units()
	if _audio_manager != null:
		for player in _audio_manager.get_children():
			if player is AudioStreamPlayer2D:
				player.stop()
				player.stream = null
	for tower in _towers:
		tower.queue_free()
	_towers.clear()
	# 清空使用 queue_free；等旧对象退场后再布置，避免部署效果命中旧对象。
	await get_tree().process_frame
	_create_towers()
	_build_nav()
	for entry in recipe:
		_art_dev_selection = entry.card
		_art_dev_team = entry.team
		_place_art_dev_item(entry.pos)
	_art_dev_selection = selection
	_art_dev_team = selected_team
	_art_dev_spell_active = enhanced
	_workbench_preset_loading = false
	_sync_art_dev_panel_state()

func _set_workbench_battle_active(active: bool) -> void:
	# 检查素材时暂停整个实战分支（包括 3D 代理和声音），防止后台攻击干扰试听。
	if not _art_dev_mode:
		return
	for child in get_children():
		if child != _art_dev_panel:
			child.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if _audio_manager != null:
		for player in _audio_manager.get_children():
			if player is AudioStreamPlayer2D:
				player.stream_paused = not active

func _sync_art_dev_panel_state() -> void:
	if _art_dev_panel == null:
		return
	var unit := _art_dev_selected_unit()
	_art_dev_panel.update_selected_unit_state(
		unit != null,
		unit != null and unit.is_deployed(),
		unit != null and (unit.is_form_transitioning() or unit.is_active_skill_casting()),
		unit != null and unit.is_skill_resource_visible(),
		unit.skill_resource_value if unit != null else 0.0,
		unit.skill_resource_max if unit != null else 0.0,
	)
	_art_dev_panel.update_live_details(unit)

func preview_active_skill(unit: Unit, skill: Dictionary) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	# ArtDev 只绕过玩家命令缓冲；普通主动仍必须经过 Cast Start → Impact → Recovery。
	return _start_active_skill_cast(unit, skill)

func _register_dynamic_building(unit: Unit) -> void:
	if nav == null or not unit.is_building:
		return
	# 建筑的格子占地只限制下牌；A* 障碍按实际圆柱碰撞扩张移动单位净空。
	unit.nav_cells = nav.cells_for_circle(unit.global_position, unit.body_radius + ArenaRules.NAV_CLEARANCE)
	nav.set_cells_blocked(unit.nav_cells, true)

func _clear_art_dev_units() -> void:
	_art_dev_last_units.clear()
	_commands.pre_deployments.clear()
	_commands.impacts.clear()
	_commands.card_commands.clear()
	_commands.skill_commands.clear()
	for combatant in get_tree().get_nodes_in_group("combatants"):
		if not combatant is Unit:
			continue
		var unit := combatant as Unit
		if unit.is_building and not unit.nav_cells.is_empty():
			unblock_nav_cells(unit.nav_cells)
			unit.nav_cells = []
		unit.queue_free()
	_projectile_system.clear_all()
	_spell_system.freeze_effects.clear()
	_spell_system.slow_zones.clear()
	_spell_system.slow_effects.clear()
	_spell_system.heal_effects.clear()
	_active_skill_effect_system.clear()
	_sync_art_dev_panel_state()
	queue_redraw()

func _world_to_arena_tile(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / ArenaRules.TILE_SIZE), floori(pos.y / ArenaRules.TILE_SIZE))

func _arena_tile_center(tile: Vector2i) -> Vector2:
	return Vector2(tile) * ArenaRules.TILE_SIZE + Vector2.ONE * ArenaRules.TILE_SIZE * 0.5

func _snap_to_tile_center(pos: Vector2) -> Vector2:
	var tile := _world_to_arena_tile(pos)
	tile.x = clampi(tile.x, 0, ArenaRules.ARENA_COLUMNS - 1)
	tile.y = clampi(tile.y, 0, ArenaRules.ARENA_ROWS - 1)
	return _arena_tile_center(tile)

## 单格单位和奇数格建筑落在格心；偶数格建筑落在格线交点，确保规则占地对齐完整格子。
func _snap_card_position(card_id: String, pos: Vector2, p_team: int = -1) -> Vector2:
	if not CardDB.has_card(card_id):
		return _snap_to_tile_center(pos)
	var stats: Dictionary = CardDB.get_card(card_id)
	var footprint: Vector2i = stats.get("footprint_tiles", Vector2i.ONE)
	if stats.get("type", "unit") != "building" or footprint == Vector2i.ONE:
		# 单位严格落在鼠标所在格的格心。若该格因河岸、塔或边界不合法，
		# 由预览显示红色并拒绝部署，不能通过微调中心偷偷换到别的位置。
		return _snap_to_tile_center(pos)
	var half_size := Vector2(footprint) * ArenaRules.TILE_SIZE * 0.5
	var snapped := Vector2(
		roundf(pos.x / ArenaRules.TILE_SIZE) * ArenaRules.TILE_SIZE if footprint.x % 2 == 0 else floorf(pos.x / ArenaRules.TILE_SIZE) * ArenaRules.TILE_SIZE + ArenaRules.TILE_SIZE * 0.5,
		roundf(pos.y / ArenaRules.TILE_SIZE) * ArenaRules.TILE_SIZE if footprint.y % 2 == 0 else floorf(pos.y / ArenaRules.TILE_SIZE) * ArenaRules.TILE_SIZE + ArenaRules.TILE_SIZE * 0.5
	)
	snapped.x = clampf(snapped.x, half_size.x, ArenaRules.FIELD_W - half_size.x)
	snapped.y = clampf(snapped.y, half_size.y, ArenaRules.FIELD_H - half_size.y)
	return snapped

## 部署区域按 CR 格子掩码判断：法术全场，单位/建筑为己方 15 行及已解锁 pocket。
func _pos_in_deploy_zone(pos: Vector2, p_team: int, is_spell: bool) -> bool:
	if pos.x < 0.0 or pos.x >= ArenaRules.FIELD_W or pos.y < 0.0 or pos.y >= ArenaRules.FIELD_H:
		return false
	if is_spell:
		return true
	return _tile_in_ground_deploy_zone(_world_to_arena_tile(pos), p_team)

## 防御塔、水晶和建筑卡的部署禁区使用规则占地格，而不是物理圆。
## 矩形边界按格子归属取样，避免刚好贴边时误封锁相邻格。
func _arena_tiles_for_rect(rect: Rect2) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var min_tile := _world_to_arena_tile(rect.position + Vector2.ONE * 0.001)
	var max_tile := _world_to_arena_tile(rect.end - Vector2.ONE * 0.001)
	for y in range(min_tile.y, max_tile.y + 1):
		for x in range(min_tile.x, max_tile.x + 1):
			var tile := Vector2i(x, y)
			if tile.x >= 0 and tile.x < ArenaRules.ARENA_COLUMNS and tile.y >= 0 and tile.y < ArenaRules.ARENA_ROWS:
				tiles.append(tile)
	return tiles

func _structure_deployment_rect(structure: Node2D) -> Rect2:
	var footprint := Vector2i.ONE
	if structure is Tower:
		footprint = (structure as Tower).footprint_tiles
	elif structure is Unit and (structure as Unit).is_building:
		footprint = (structure as Unit).footprint_tiles
	var size := Vector2(footprint) * ArenaRules.TILE_SIZE
	return Rect2(structure.global_position - size * 0.5, size)

func _structure_deployment_tiles(structure: Node2D) -> Array[Vector2i]:
	return _arena_tiles_for_rect(_structure_deployment_rect(structure))

## 已毁公主塔仍为太阳圆盘保留 3x3 塔墟语义；国王水晶废墟不属于该被动。
## Tower 的 hp 与 footprint_tiles 是唯一权威来源，3D Rubble 表面不参与判定。
func _destroyed_princess_tower_for_tile(tile: Vector2i) -> Tower:
	for tower in _towers:
		if not is_instance_valid(tower) or tower.is_king or tower.hp > 0.0:
			continue
		if tile in _structure_deployment_tiles(tower):
			return tower
	return null

func _destroyed_princess_tower_at_card_center(pos: Vector2) -> Tower:
	return _destroyed_princess_tower_for_tile(_world_to_arena_tile(pos))

func _is_structure_deployment_tile_blocked(tile: Vector2i) -> bool:
	for c in get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(c) or c.hp <= 0.0:
			continue
		var is_structure: bool = c is Tower or (c is Unit and (c as Unit).is_building)
		if not is_structure:
			continue
		if tile in _structure_deployment_tiles(c):
			return true
	return false

func _tile_in_ground_deploy_zone(tile: Vector2i, p_team: int) -> bool:
	if tile.x < 0 or tile.x >= ArenaRules.ARENA_COLUMNS or tile.y < 0 or tile.y >= ArenaRules.ARENA_ROWS:
		return false
	var local_row := tile.y if p_team == 0 else ArenaRules.ARENA_ROWS - 1 - tile.y
	# 自己半场包含靠河第一行的左右角；最后一行只保留国王塔正后方中央 6 格。
	if local_row >= ArenaRules.TEAM_0_FIRST_ROW and local_row <= ArenaRules.TEAM_0_LAST_ROW:
		if local_row == ArenaRules.TEAM_0_LAST_ROW and (tile.x < ArenaRules.BACK_CENTER_MIN_COLUMN or tile.x > ArenaRules.BACK_CENTER_MAX_COLUMN):
			return false
		return true
	# 摧毁某一路公主塔后，只解锁该路塔后至河岸的 6 行 pocket。
	if local_row < ArenaRules.POCKET_FIRST_ROW or local_row > ArenaRules.POCKET_LAST_ROW:
		return false
	if local_row == ArenaRules.POCKET_LAST_ROW and (tile.x == 0 or tile.x == ArenaRules.ARENA_COLUMNS - 1):
		return false
	var is_left := tile.x < ArenaRules.ARENA_COLUMNS / 2
	return _pocket_unlocked(p_team, is_left)

## 全图卡牌允许落在河道外的地面格 + 两座桥面三格；敌我双方区域都合法，但塔/水晶占地格
## 仍由 is_card_deploy_position_valid() 单独拦截。除桥面外，河道其余两行保持不可部署。
func _tile_in_global_ground_deploy_zone(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.x >= ArenaRules.ARENA_COLUMNS or tile.y < 0 or tile.y >= ArenaRules.ARENA_ROWS:
		return false
	var in_river: bool = tile.y >= ArenaRules.RIVER_TOP_ROW and tile.y < ArenaRules.RIVER_BOTTOM_ROW
	if not in_river:
		return true
	# 河道中：只允许左右桥的三格宽列通过
	var colf: float = float(tile.x)
	var on_left_bridge: bool = abs(colf - ArenaRules.BRIDGE_X_LEFT / ArenaRules.TILE_SIZE) <= 1.5
	var on_right_bridge: bool = abs(colf - ArenaRules.BRIDGE_X_RIGHT / ArenaRules.TILE_SIZE) <= 1.5
	return on_left_bridge or on_right_bridge

func _pocket_unlocked(p_team: int, is_left: bool) -> bool:
	if _towers.size() < 4:
		return false
	var tower_index: int
	if p_team == 0:
		tower_index = 2 if is_left else 3
	else:
		tower_index = 0 if is_left else 1
	return _towers[tower_index].hp <= 0.0

## 占位检查：候选卡的规则占地不得与存活塔/水晶/建筑卡的规则占地重叠。
## 兵种生成后的真实半径只交给移动、碰撞和挤压系统处理；建筑卡即使是 1x1，
## 部署资格也只按 footprint_tiles 与地面格规则判断，不读取圆柱碰撞半径。
func _can_deploy_at(pos: Vector2, radius: float, is_air: bool = false, footprint: Vector2i = Vector2i.ONE, is_building_card: bool = false) -> bool:
	if not is_air and not is_building_card and not is_ground_position_walkable(pos, radius, null, true, true):
		return false
	var deploy_rect := Rect2(pos - Vector2(footprint) * ArenaRules.TILE_SIZE * 0.5, Vector2(footprint) * ArenaRules.TILE_SIZE)
	for c in get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(c) or c.hp <= 0.0:
			continue
		var is_static: bool = c is Tower or (c is Unit and (c as Unit).is_building)
		if not is_static:
			continue
		# 共边不算重叠，相邻部署格必须保持可用。
		if _structure_deployment_rect(c).intersects(deploy_rect, false):
			return false
	return true

## 所有正常卡牌部署入口（玩家、客户端请求、AI）共享同一套区域与占位校验。
func is_card_deploy_position_valid(p_team: int, card_id: String, pos: Vector2) -> bool:
	if not CardDB.has_card(card_id):
		return false
	pos = _snap_card_position(card_id, pos, p_team)
	var stats: Dictionary = CardDB.get_card(card_id)
	var deploy_zone: String = String(stats.get("deploy_zone", "own_side"))
	var ignore_structures: bool = bool(stats.get("deploy_ignore_structures", false))
	var footprint: Vector2i = stats.get("footprint_tiles", Vector2i.ONE)
	var card_type: String = String(stats.get("type", "unit"))
	var uses_tower_ruin_foundation := bool(stats.get("tower_ruin_foundation", false))
	var foundation_tower := _destroyed_princess_tower_at_card_center(pos) if uses_tower_ruin_foundation else null

	# 1. 部署区域：从 CardDB 独立读取 deploy_zone。只有 own_side / global 两态；
	#    「河道非桥面不可下」统一放在下一段占位层里（和塔/水晶/建筑同开关），不重复耦合到区域分类。
	# 塔墟被动允许直接选中敌方已毁公主塔的九格；这些格通常位于普通 pocket
	# 部署区之外。中心未落在塔墟时仍严格执行原部署区域。
	match deploy_zone if foundation_tower == null else "tower_ruin":
		"global":
			if pos.x < 0.0 or pos.x >= ArenaRules.FIELD_W or pos.y < 0.0 or pos.y >= ArenaRules.FIELD_H:
				return false
		"tower_ruin":
			pass
		_:  # own_side
			var first_tile := Vector2i(
				roundi(pos.x / ArenaRules.TILE_SIZE - float(footprint.x) * 0.5),
				roundi(pos.y / ArenaRules.TILE_SIZE - float(footprint.y) * 0.5))
			for y in range(first_tile.y, first_tile.y + footprint.y):
				for x in range(first_tile.x, first_tile.x + footprint.x):
					var tile := Vector2i(x, y)
					if not _tile_in_ground_deploy_zone(tile, p_team):
						return false

	# 2. 占位：独立开关；河流非桥面及塔/水晶/建筑卡占地格统一由 deploy_ignore_structures 控制。
	#    用户语义：河流非桥面占位等同于水晶/防御塔/建筑；桥面可通过。ignore=true 时（如冰冻）全部跳过。
	if not ignore_structures:
		var first_tile := Vector2i(
			roundi(pos.x / ArenaRules.TILE_SIZE - float(footprint.x) * 0.5),
			roundi(pos.y / ArenaRules.TILE_SIZE - float(footprint.y) * 0.5))
		for y in range(first_tile.y, first_tile.y + footprint.y):
			for x in range(first_tile.x, first_tile.x + footprint.x):
				var tile := Vector2i(x, y)
				# 太阳圆盘的 3x3 只要擦到塔墟就被阻挡；唯一例外是建筑中心
				# 本身落在该塔墟九格内，此时只豁免这一个已毁公主塔。
				if uses_tower_ruin_foundation:
					var ruined_tower := _destroyed_princess_tower_for_tile(tile)
					if ruined_tower != null and ruined_tower != foundation_tower:
						return false
				# 河流：非桥面三格的列一律当作占位阻挡
				var tile_in_river: bool = tile.y >= ArenaRules.RIVER_TOP_ROW and tile.y < ArenaRules.RIVER_BOTTOM_ROW
				if tile_in_river:
					var colf: float = float(tile.x)
					var on_left_bridge: bool = abs(colf - ArenaRules.BRIDGE_X_LEFT / ArenaRules.TILE_SIZE) <= 1.5
					var on_right_bridge: bool = abs(colf - ArenaRules.BRIDGE_X_RIGHT / ArenaRules.TILE_SIZE) <= 1.5
					if not on_left_bridge and not on_right_bridge:
						return false
				if _is_structure_deployment_tile_blocked(tile):
					return false
		if card_type != "spell":
			# 单格兵种共用同一套部署位置。不要因为盖伦等大体型兵种的真实半径较大，
			# 把本来属于部署区的格子判成非法；真实体积从生成后才参与战斗碰撞。
			var placement_radius := 0.0
			return _can_deploy_at(pos, placement_radius, stats.get("is_air", false), footprint, card_type == "building")
	return true

func _structure_gap_to_circle(c: Node2D, center: Vector2, radius: float) -> float:
	if c.has_method("surface_gap_to_circle"):
		return c.surface_gap_to_circle(center, radius)
	return maxf(0.0, center.distance_to(c.global_position) - c.body_radius - radius)

## 按当前单位真实半径检查连续空间，而不只检查半格导航格中心。
## 导航格负责全局路线；这里补足塔角/建筑角最多半格的离散误差。
func is_ground_position_walkable(pos: Vector2, mover_radius: float, excluded: Node = null, allow_deploy_edge_center: bool = false, ignore_structures: bool = false) -> bool:
	# 玩家部署允许第一/最后一列、第一/最后一行的格心作为出生点；
	# 单位会从边缘格向场内移动。正常战斗移动仍要求整个圆柱留在场内。
	if allow_deploy_edge_center:
		if pos.x < 0.0 or pos.x > ArenaRules.FIELD_W or pos.y < 0.0 or pos.y > ArenaRules.FIELD_H:
			return false
	else:
		if pos.x < mover_radius or pos.x > ArenaRules.FIELD_W - mover_radius:
			return false
		if pos.y < mover_radius or pos.y > ArenaRules.FIELD_H - mover_radius:
			return false
	if not _is_ground_terrain_walkable(pos, mover_radius):
		return false
	for c in get_tree().get_nodes_in_group("combatants"):
		if c == excluded or not is_instance_valid(c) or c.hp <= 0.0:
			continue
		var is_structure: bool = c is Tower or (c is Unit and (c as Unit).is_building)
		if not is_structure:
			continue
		if ignore_structures:
			continue
		if _structure_gap_to_circle(c, pos, mover_radius) < ArenaRules.STRUCTURE_SEPARATION:
			return false
	return true

## 连续河道碰撞：河岸按单位真实半径扩张，桥面按真实半径收窄。
## 不读取 A* 的离散格，避免合法部署格因格心取样误判为河道。
func _is_ground_terrain_walkable(pos: Vector2, mover_radius: float) -> bool:
	if absf(pos.y - ArenaRules.RIVER_Y) >= ArenaRules.RIVER_HALF + mover_radius:
		return true
	var bridge_clearance := maxf(ArenaRules.BRIDGE_HALF - mover_radius, 0.0)
	return (
		absf(pos.x - ArenaRules.BRIDGE_X_LEFT) <= bridge_clearance
		or absf(pos.x - ArenaRules.BRIDGE_X_RIGHT) <= bridge_clearance
	)

## 推进路线能直达时不调用 A*。按连续空间采样，保证直线不会切进圆形塔或建筑。
func is_ground_segment_walkable(from: Vector2, to: Vector2, mover_radius: float, excluded: Node = null) -> bool:
	var distance := from.distance_to(to)
	var samples := maxi(1, ceili(distance / 4.0))
	for i in range(1, samples + 1):
		if not is_ground_position_walkable(from.lerp(to, float(i) / float(samples)), mover_radius, excluded):
			return false
	return true

## 部署前把落点内的可移动单位挤开（建筑与空军不动）
func _push_units_around(pos: Vector2, radius: float) -> void:
	for c in get_tree().get_nodes_in_group("combatants"):
		var u := c as Unit
		if u == null or u.is_building or u.is_air or not is_instance_valid(u) or u.hp <= 0.0:
			continue
		var min_dist: float = u.body_radius + radius
		var gap: float = pos.distance_to(u.global_position)
		if gap < min_dist:
			var dir := pos.direction_to(u.global_position)
			if dir.length_squared() < 0.001:
				dir = Vector2.RIGHT
			var new_pos: Vector2 = pos + dir * min_dist
			# 推挤结果必须仍在可行走区域，不能把地面单位推进河里
			if u.is_walkable_at(new_pos):
				u.global_position = new_pos

## 墓碑等建筑的召唤入口。召唤偏移可能指向塔/建筑，生成前必须找到最近合法位置。
func spawn_summoned(p_team: int, card_id: String, pos: Vector2, deploy_time_override: float = -1.0, visual_transition: String = "", death_replacement_charges_override: int = -1) -> Unit:
	var stats: Dictionary = CardDB.get_unit_stats(card_id)
	if stats.is_empty():
		push_error("尝试生成不存在的召唤单位：%s" % card_id)
		return null
	if not stats.get("is_air", false):
		pos = _nearest_valid_ground_spawn(pos, stats.get("radius", 14.0), p_team)
	return _spawn_unit(p_team, card_id, pos, deploy_time_override, -1, -1, -1, visual_transition, death_replacement_charges_override)

func _nearest_valid_ground_spawn(desired: Vector2, radius: float, p_team: int) -> Vector2:
	if is_ground_position_walkable(desired, radius):
		return desired
	var forward := Vector2.UP if p_team == 0 else Vector2.DOWN
	for distance in range(4, 165, 4):
		for angle in [0.0, PI / 8.0, -PI / 8.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0, PI]:
			var candidate := desired + forward.rotated(angle) * float(distance)
			if is_ground_position_walkable(candidate, radius):
				return candidate
	push_warning("召唤物找不到合法出生点：team=%d pos=%s" % [p_team, desired])
	return desired

## 形态放大采用权威半径瞬时切换。若当前位置对新半径不合法，确定性地挪到最近安全点，
## 并重置插值/路径，避免桥角、河岸或塔边因为旧体积合法而新体积永久卡住。
func ensure_unit_form_resize_safe(unit: Unit) -> void:
	if unit == null or not is_instance_valid(unit) or unit.is_air or unit.is_building:
		return
	if is_ground_position_walkable(unit.global_position, unit.body_radius, unit):
		return
	var safe_position := _nearest_valid_ground_spawn(unit.global_position, unit.body_radius, unit.team)
	unit.global_position = safe_position
	unit._prev_pos = safe_position
	unit.net_target_pos = safe_position
	unit._path = PackedVector2Array()
	unit._path_index = 0
	unit._repath_cd = 0.0

func _deploy_card(p_team: int, card_id: String, pos: Vector2, input_tick: int = -1) -> int:
	# 玩家、AI 与联机请求统一从 input_tick 进入 10 Tick 权威队列；召唤物不受此延迟影响。
	pos = _snap_card_position(card_id, pos, p_team)
	var resolved_execute_tick := _resolve_command_execute_tick(input_tick)
	if resolved_execute_tick < 0:
		return -1
	_commands.card_commands.append({
		"team": p_team,
		"card_id": card_id,
		"pos": pos,
		"execute_tick": resolved_execute_tick,
	})
	return resolved_execute_tick

## 玩家、AI、联机 RPC 与 DevelopmentWorkbench 共用的出牌命令入口。
## options 只描述请求来源；联机请求携带客户端观察到的 input_tick，Host 计算目标 Tick。
func play_card(p_team: int, card_id: String, pos: Vector2, options: Dictionary = {}) -> bool:
	if game_over or not CardDB.has_card(card_id):
		return false
	var stats := CardDB.get_card(card_id)
	if StringName(stats.get("type", "unit")) == &"spell" and not SPELL_SYSTEM_SCRIPT.supports(StringName(stats.get("spell_kind", ""))):
		return false
	var immediate := bool(options.get("immediate", false))
	if not bool(stats.get("selectable", true)) and not immediate:
		return false
	pos = _snap_card_position(card_id, pos, p_team)
	if bool(options.get("validate_position", true)) and not is_card_deploy_position_valid(p_team, card_id, pos):
		return false
	if bool(options.get("require_team_deck", false)):
		var team_deck := _team_deck(p_team)
		if team_deck.size() != 8 or card_id not in team_deck:
			return false
	if not immediate and not _authoritative_card_in_hand(p_team, card_id):
		return false
	var input_tick := int(options.get("input_tick", -1))
	if not immediate and _resolve_command_execute_tick(input_tick) < 0:
		return false
	var elixir = options.get("elixir")
	if options.has("elixir") and elixir == null:
		return false
	# 强化法术（如主动槽治疗术）的实际费用含 active_cost_bonus；扣费、预检与回滚共用。
	var card_cost := card_cost_for_team(p_team, card_id)
	if bool(options.get("client_request", false)):
		if mode != "client" or immediate or elixir == null or not elixir.can_afford(card_cost):
			return false
		_rpc_deploy_request.rpc_id(1, card_id, pos, _input_tick_for_new_command())
		if _hand != null:
			_hand.set_card_pending(card_id, true)
		return true
	if elixir != null and not elixir.spend(card_cost):
		return false
	if immediate:
		var type := String(stats.get("type", "unit"))
		if type == "spell":
			_cast_spell(p_team, card_id, pos, _art_dev_mode and bool(options.get("preview_active_spell", false)))
		elif float(stats.get("pre_deploy_time", 0.0)) > 0.0:
			_execute_card_deployment(p_team, card_id, pos)
		else:
			if type == "building":
				_push_units_around(pos, float(stats.get("radius", 14.0)))
			_spawn_card_units(p_team, card_id, pos)
		return true
	# 只有命令已完成权威校验、扣费与手牌轮换后才向客户端确认。
	if not _consume_authoritative_card(p_team, card_id):
		# spend 已经成功时理论上不会失败；保留事务式回滚，避免未来扩展插入中间验证后丢费。
		if elixir != null:
			elixir.elixir += float(card_cost)
		return false
	var execute_tick := _deploy_card(p_team, card_id, pos, input_tick)
	if execute_tick < 0:
		# 仅作为未来扩展的兜底；常规异常 Tick 已在扣费/轮换前被拒绝。
		return false
	var requester_peer_id := int(options.get("requester_peer_id", 0))
	if mode == "host" and requester_peer_id > 0:
		_rpc_deploy_accepted.rpc_id(
			requester_peer_id, card_id, execute_tick,
			get_authoritative_hand(p_team), get_authoritative_queue(p_team)
		)
	return true

func _tick_pending_card_deployments(_dt: float) -> void:
	var ready := _commands.take_card_commands(_sim_tick_id)
	for deployment in ready:
		_execute_card_deployment(
			int(deployment.team),
			String(deployment.card_id),
			deployment.pos as Vector2
		)

func _tick_pending_card_pre_deployments(dt: float) -> void:
	var ready := _commands.take_pre_deployments(dt)
	for deployment in ready:
		_spawn_card_units(
			int(deployment.team), String(deployment.card_id), deployment.pos as Vector2,
			-1.0, int(deployment.get("active_slot", -1)), int(deployment.get("id", -1))
		)

func _execute_card_deployment(p_team: int, card_id: String, pos: Vector2) -> void:
	var stats: Dictionary = CardDB.get_card(card_id)
	var type: String = stats.get("type", "unit")
	var active_slot := _active_card_slot_for_team(p_team, card_id)
	var pre_deploy_time := maxf(float(stats.get("pre_deploy_time", 0.0)), 0.0)
	if pre_deploy_time > 0.0 and type != "spell":
		var pre_deploy_id := _commands.next_pre_deploy_id
		_commands.next_pre_deploy_id += 1
		_commands.pre_deployments.append({
			"id": pre_deploy_id,
			"team": p_team,
			"card_id": card_id,
			"pos": pos,
			"active_slot": active_slot,
			"time_left": pre_deploy_time,
			"duration": pre_deploy_time,
		})
		if mode == "host":
			_rpc_card_pre_deploy_started.rpc(pre_deploy_id, card_id, p_team, pos, pre_deploy_time)
		_presentation_event_id += 1
		_play_card_event(_presentation_event_id, card_id, "pre_deploy:start", pos)
		if mode == "host":
			_rpc_card_event.rpc(_presentation_event_id, card_id, "pre_deploy:start", pos)
		return
	match type:
		"spell":
			_cast_spell(p_team, card_id, pos, active_slot >= 0)
		_:
			if type == "building":
				_push_units_around(pos, stats.get("radius", 14.0))
			_spawn_card_units(p_team, card_id, pos, -1.0, active_slot)

func launch_attack(attacker: Node2D, target: Node2D, amount: float, projectile_speed: float, splash_radius: float, knockback: float, projectile_color: Color, effects: Dictionary = {}) -> void:
	_projectile_system.launch(attacker, target, amount, projectile_speed, splash_radius, knockback, projectile_color, effects)
	if attacker is Tower and is_instance_valid(target) and target.hp > 0.0:
		var source := PresentationConfig.attack_source(attacker)
		_on_skill_projectile_hit(source, "attack", attacker.global_position, "cast")
		_on_skill_projectile_hit(source, "attack", attacker.global_position, "launch")

## 弹体命中表现与伤害结算分离；半径只用于绘制对应的权威溅射范围。
func show_projectile_impact(position: Vector2, radius: float, color: Color, visual: StringName) -> void:
	_projectile_system.add_impact_visual(position, radius, color, visual)
	if mode == "host":
		_rpc_projectile_impact_fx.rpc(position, radius, color, String(visual))

## 持续伤害（龙王吐息、审判等）共用的战斗层入口。调用方决定脉冲频率和命中目标，
## 这里统一处理攻击来源、护盾/隐匿、受击表现、击杀以及可选的普攻击中回调。
func apply_damage_pulse(source: Node2D, target: Node2D, amount: float, splash_radius: float = 0.0, origin: Vector2 = Vector2(INF, INF), counts_as_attack: bool = false, source_form_index: int = -1, effects: Dictionary = {}) -> bool:
	if source == null or not is_instance_valid(source) or target == null or not is_instance_valid(target):
		return false
	if target.hp <= 0.0 or amount <= 0.0:
		return false
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
	if mode == "host":
		_rpc_attack_audio_hit.rpc(source, position, first_strike)

## 一次范围脉冲即使命中多个目标也只播放一次；空挥/免疫不产生命中声。
func _on_projectile_launch_audio_started(id: int, source: Dictionary, position: Vector2) -> void:
	if _audio_manager != null:
		_audio_manager.start_projectile_launch(id, source, position)
	if mode == "host":
		_rpc_projectile_launch_audio.rpc(id, source, position, true)

func _on_projectile_launch_audio_stopped(id: int) -> void:
	if _audio_manager != null:
		_audio_manager.stop_projectile_launch(id)
	if mode == "host":
		_rpc_projectile_launch_audio.rpc(id, {}, Vector2.ZERO, false)

@rpc("authority", "call_remote", "reliable")
func _rpc_projectile_launch_audio(id: int, source: Dictionary, position: Vector2, started: bool) -> void:
	if mode != "client" or _audio_manager == null:
		return
	if started:
		_audio_manager.start_projectile_launch(id, source, position)
	else:
		_audio_manager.stop_projectile_launch(id)

func _notify_unit_audio_event(unit: Unit, cue: StringName, position: Vector2) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if cue == &"revival:end" and _audio_manager != null:
		_audio_manager.complete_revival(unit)
	if cue in [&"deploy:hit", &"replacement:start", &"revival:end", &"shield:cast", &"shield:applied"]:
		_on_skill_projectile_hit(PresentationConfig.attack_source(unit), String(cue).get_slice(":", 0), position, String(cue).get_slice(":", 1))
		return
	if _audio_manager != null:
		_audio_manager.play_event(unit, cue, position)
	if mode == "host" and unit.net_id >= 0:
		_rpc_unit_audio_event.rpc(unit.net_id, String(cue), position, unit.presentation_state().attack_serial)

@rpc("authority", "call_remote", "unreliable")
func _rpc_unit_audio_event(net_id: int, cue: String, position: Vector2, attack_serial: int = -1) -> void:
	if mode != "client" or _audio_manager == null:
		return
	var unit: Unit = _client_units.get(net_id)
	if unit != null and is_instance_valid(unit):
		_audio_manager.play_event(unit, StringName(cue), position, attack_serial)

func _cast_spell(p_team: int, card_id: String, pos: Vector2, active_enabled: bool = false) -> bool:
	var cast: bool = _spell_system.cast(p_team, CardDB.get_card(card_id), pos, active_enabled)
	if cast:
		_presentation_event_id += 1
		_play_card_event(_presentation_event_id, card_id, "spell:cast", pos)
		if mode == "host":
			_rpc_card_event.rpc(_presentation_event_id, card_id, "spell:cast", pos)
	return cast

func _apply_freeze(pos: Vector2, radius: float, duration: float, p_team: int, slow_duration: float = 0.0, slow_multiplier: float = 1.0) -> void:
	_spell_system.apply_freeze(pos, radius, duration, p_team, slow_duration, slow_multiplier)

func _tick_slow_zones(dt: float) -> void:
	_spell_system.tick(dt)

func _tick_slow_effect_visuals(delta: float) -> void:
	_spell_system.tick_visuals(delta)

## 手牌单位卡的生成入口。一条部署命令和一个落点提示可以展开为确定性编队；
## 每个成员仍是独立 Unit，碰撞、索敌、快照和死亡都沿用普通单位规则。
func _spawn_card_units(team: int, card_id: String, pos: Vector2, deploy_time_override: float = -1.0, active_slot: int = -1, pre_deploy_id: int = -1) -> Array[Unit]:
	var stats := CardDB.get_unit_stats(card_id)
	var built_on_tower_ruin := (
		bool(stats.get("tower_ruin_foundation", false))
		and _destroyed_princess_tower_at_card_center(pos) != null
	)
	var count := maxi(int(stats.get("deployment_count", 1)), 1)
	var spacing := maxf(float(stats.get("deployment_spacing", 0.0)), 0.0)
	var group_id := -1
	if count > 1:
		group_id = _next_deployment_group_id
		_next_deployment_group_id += 1
	var offsets := _deployment_formation_offsets(count, spacing, team)
	var spawned: Array[Unit] = []
	for index in range(count):
		var member_slot := active_slot if index == 0 else -1
		var member_pos := pos + offsets[index]
		var member_radius := float(stats.get("radius", 14.0))
		member_pos.x = clampf(member_pos.x, member_radius, ArenaRules.FIELD_W - member_radius)
		member_pos.y = clampf(member_pos.y, member_radius, ArenaRules.FIELD_H - member_radius)
		var member := _spawn_unit(team, card_id, member_pos, deploy_time_override, member_slot, pre_deploy_id, group_id, "", -1, built_on_tower_ruin)
		if member != null:
			spawned.append(member)
	return spawned


## 奇数编队保留中心成员，其余成员围绕点击格心均匀排列；队伍方向只旋转阵型，
## 不影响中心和成员间距。部署 UI 仍只显示点击格心的一个读条圈。
func _deployment_formation_offsets(count: int, spacing: float, team: int) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	if count <= 1:
		offsets.append(Vector2.ZERO)
		return offsets
	var ring_count := count
	if count % 2 == 1:
		offsets.append(Vector2.ZERO)
		ring_count -= 1
	var rotation := 0.0 if team == 0 else PI
	for index in range(ring_count):
		var angle := rotation - PI * 0.5 + TAU * float(index) / float(ring_count)
		offsets.append(Vector2.RIGHT.rotated(angle) * spacing)
	return offsets


func _spawn_unit(team: int, card_id: String, pos: Vector2, deploy_time_override: float = -1.0, active_slot: int = -1, pre_deploy_id: int = -1, deployment_group_id: int = -1, visual_transition: String = "", death_replacement_charges_override: int = -1, built_on_tower_ruin: bool = false) -> Unit:
	var stats: Dictionary = CardDB.get_unit_stats(card_id)
	if stats.is_empty():
		push_error("尝试生成不存在的单位：%s" % card_id)
		return null
	if deploy_time_override >= 0.0:
		stats = stats.duplicate()
		stats["deploy_time"] = deploy_time_override
	# 部署资格按网格统一，但真实体积从落地开始生效。若格心与河岸、桥边、塔或水晶重叠，
	# 先把地面移动单位推到最近的完整合法位置，再加入场景，避免第一帧就被静态碰撞锁死。
	if not bool(stats.get("is_air", false)) and not bool(stats.get("is_building", false)):
		pos = _nearest_valid_ground_spawn(pos, float(stats.get("radius", 14.0)), team)
	var u := Unit.new()
	u.card_id = card_id
	u.deployment_group_id = deployment_group_id
	u.visual_spawn_transition = StringName(visual_transition)
	u.built_on_tower_ruin = built_on_tower_ruin
	u.position = pos
	u.setup(team, stats, stats.name)
	if death_replacement_charges_override >= 0:
		u.death_replacement_charges = death_replacement_charges_override
	if deploy_time_override >= 0.0:
		# 自动兵线不经过卡牌部署读条，生成当帧即可行动；仍标记为新落地单位供碰撞分离使用。
		u._just_deployed = true
	add_child(u)
	if _battle_presentation != null:
		_battle_presentation.attach_unit(u, stats)
	if _audio_manager != null:
		_audio_manager.attach_unit(u, stats)
	# 建筑卡：按实际碰撞圆动态注册导航障碍，死亡/到期时由 unit._die 解除。
	if nav != null and u.is_building:
		_register_dynamic_building(u)
	# 主机：分配网络 id 并广播给客户端
	if mode == "host":
		u.net_id = _next_net_id
		_next_net_id += 1
		_net_units[u.net_id] = u
	if active_slot >= 0 and active_slot < 2 and not CardDB.active_skills_for(card_id).is_empty():
		u.active_ability_id = u.net_id if u.net_id >= 0 else _next_active_ability_id
		u.active_ability_slot = active_slot
		if u.net_id < 0:
			_next_active_ability_id += 1
		_register_active_skill(u, card_id, team)
	if mode == "host":
		_rpc_spawn_unit.rpc(card_id, team, pos, u.net_id, deploy_time_override, u.active_ability_id, u.active_ability_slot, pre_deploy_id, deployment_group_id, visual_transition, death_replacement_charges_override, built_on_tower_ruin)
	return u

func _register_active_skill(unit: Unit, card_id: String, p_team: int) -> void:
	if unit.active_ability_id < 0 or unit.active_ability_slot < 0 or unit.active_ability_slot >= 2 or not CardDB.has_card(card_id):
		return
	var stats: Dictionary = CardDB.get_card(card_id)
	var available_skills := CardDB.active_skills_for(card_id)
	if available_skills.is_empty():
		return
	# 备战信息页只允许从候选集合中携带一个；场上实例不会同时获得多个主动技能。
	var chosen_skill_index := _active_skill_choice_for_team(p_team, card_id, available_skills.size())
	var carried_skill: Dictionary = available_skills[chosen_skill_index]
	unit.configure_carried_active_skill(carried_skill)
	var ability_id := unit.active_ability_id
	var active_slot := unit.active_ability_slot
	var max_uses := maxi(int(carried_skill.get("max_uses", 1)), 1)
	# 每个主动槽始终只控制最近部署的实例。新实例落地时，旧实例的未用资格立即作废。
	var replaced_id := -1
	for existing_id in _active_skills:
		var existing: Dictionary = _active_skills[existing_id]
		if int(existing.team) == p_team and int(existing.slot) == active_slot:
			replaced_id = int(existing_id)
			break
	if replaced_id >= 0:
		var replaced: Dictionary = _active_skills[replaced_id]
		var replaced_unit = replaced.get("unit")
		if is_instance_valid(replaced_unit) and replaced_unit is Unit:
			var valid_replaced_unit := replaced_unit as Unit
			valid_replaced_unit.active_ability_id = -1
			valid_replaced_unit.active_ability_slot = -1
			valid_replaced_unit.clear_carried_active_skill_resource()
		_active_skills.erase(replaced_id)
		_cancel_pending_active_skill(replaced_id)
		if _active_skill_bar != null:
			_active_skill_bar.remove_skill(replaced_id)
	_active_skills[ability_id] = {
		"unit": unit,
		"card_id": card_id,
		"team": p_team,
		"slot": active_slot,
		"skill": carried_skill,
		"max_uses": max_uses,
		"uses_remaining": max_uses,
		"cooldown_left": 0.0,
	}
	unit.died.connect(_on_active_skill_unit_died.bind(ability_id), CONNECT_ONE_SHOT)
	if _is_local_player_team(p_team) and _active_skill_bar != null:
		_active_skill_bar.show_skill(
			active_slot, ability_id, String(carried_skill.name), stats.get("color", CardArt.DEFAULT_ACCENT),
			float(carried_skill.get("cost", 0.0)), max_uses, max_uses, float(carried_skill.get("cooldown", 0.0)), unit.is_deployed()
		)
	# 单机 AI 也携带卡组前两槽的技能；占位 AI 同样经过 0.5 秒待释放窗口。
	if mode == "local" and p_team == 1:
		call_deferred("use_active_skill", ability_id, p_team, 0, false)

## 部署期间技能按钮保持不可点击；部署计时归零后只同步可用表现，不改变权威技能判定。
func _sync_active_skill_deployment_readiness() -> void:
	for ability_value in _active_skills.keys():
		var ability_id := int(ability_value)
		var entry: Dictionary = _active_skills[ability_id]
		var unit = entry.get("unit")
		if not is_instance_valid(unit) or not unit is Unit:
			_active_skills.erase(ability_id)
			_cancel_pending_active_skill(ability_id)
			if _active_skill_bar != null:
				_active_skill_bar.remove_skill(ability_id)
			continue
		var valid_unit := unit as Unit
		var deployed := valid_unit.is_deployed()
		if _is_local_player_team(int(entry.team)) and _active_skill_bar != null:
			_active_skill_bar.update_skill_state(
				ability_id,
				int(entry.get("uses_remaining", entry.get("max_uses", 1))),
				float(entry.get("cooldown_left", 0.0)),
				deployed,
				float((entry.get("skill", {}) as Dictionary).get("cost", 0.0)),
				int(entry.get("max_uses", (entry.get("skill", {}) as Dictionary).get("max_uses", 1)))
			)

func _on_active_skill_unit_died(ability_id: int) -> void:
	if _active_skills.has(ability_id):
		var entry: Dictionary = _active_skills[ability_id]
		var dead_unit = entry.get("unit")
		var skill: Dictionary = entry.get("skill", {})
		if dead_unit is Unit and StringName(skill.get("target_scope", "self")) == &"deployment_group":
			var group_id := (dead_unit as Unit).deployment_group_id
			for combatant in get_tree().get_nodes_in_group("combatants"):
				if not combatant is Unit or not is_instance_valid(combatant) or combatant.hp <= 0.0:
					continue
				var replacement := combatant as Unit
				if replacement.deployment_group_id != group_id or replacement.team != int(entry.team):
					continue
				replacement.active_ability_id = ability_id
				replacement.active_ability_slot = int(entry.slot)
				replacement.configure_carried_active_skill(skill)
				entry["unit"] = replacement
				_active_skills[ability_id] = entry
				replacement.died.connect(_on_active_skill_unit_died.bind(ability_id), CONNECT_ONE_SHOT)
				return
	_active_skills.erase(ability_id)
	_cancel_pending_active_skill(ability_id)
	if _active_skill_bar != null:
		_active_skill_bar.remove_skill(ability_id)

func _on_active_skill_pressed(ability_id: int) -> void:
	if not use_active_skill(ability_id, 0, 0, mode == "client") and _active_skill_bar != null:
		_active_skill_bar.set_pending(ability_id, false)

## 玩家、AI 和联机 RPC 共用的主动技能请求入口；客户端提交 input_tick，Host 统一计算 10 Tick 目标。
func use_active_skill(ability_id: int, expected_team: int = -1, requester_peer_id: int = 0, client_request: bool = false, input_tick: int = -1) -> bool:
	if client_request:
		if mode != "client" or not _active_skill_is_legal(ability_id, 1):
			return false
		var client_entry: Dictionary = _active_skills[ability_id]
		var client_skill: Dictionary = client_entry.skill
		var client_elixir := _elixir_for_team(1)
		if client_elixir == null or client_elixir.elixir < maxf(float(client_skill.get("cost", 0.0)), 0.0):
			return false
		_rpc_active_skill_request.rpc_id(1, ability_id, _input_tick_for_new_command())
		return true
	return _queue_active_skill(ability_id, expected_team, requester_peer_id, input_tick)

func _queue_active_skill(ability_id: int, expected_team: int = -1, requester_peer_id: int = 0, input_tick: int = -1) -> bool:
	for pending in _commands.skill_commands:
		if int(pending.ability_id) == ability_id:
			return false
	if not _active_skill_is_legal(ability_id, expected_team):
		return false
	var entry: Dictionary = _active_skills[ability_id]
	var p_team := int(entry.team)
	var execute_tick := _resolve_command_execute_tick(input_tick)
	if execute_tick < 0:
		return false
	var skill: Dictionary = entry.skill
	if not _spend_active_skill_cost(p_team, skill):
		return false
	_commands.skill_commands.append({
		"ability_id": ability_id,
		"team": p_team,
		"requester_peer_id": requester_peer_id,
		"execute_tick": execute_tick,
	})
	return true

func _tick_pending_active_skills(_dt: float) -> void:
	var ready := _commands.take_skill_commands(_sim_tick_id)
	for pending in ready:
		var ability_id := int(pending.ability_id)
		if _activate_active_skill(ability_id, int(pending.team)):
			continue
		var requester_peer_id := int(pending.requester_peer_id)
		if mode == "host" and requester_peer_id > 0:
			_rpc_active_skill_rejected.rpc_id(requester_peer_id, ability_id)
		elif _active_skill_bar != null:
			_active_skill_bar.set_pending(ability_id, false)

func _cancel_pending_active_skill(ability_id: int) -> void:
	_commands.skill_commands = _commands.skill_commands.filter(
		func(pending): return int(pending.ability_id) != ability_id
	)

func _tick_active_skill_cooldowns(dt: float) -> void:
	for ability_value in _active_skills.keys():
		var ability_id := int(ability_value)
		var entry: Dictionary = _active_skills[ability_id]
		entry["cooldown_left"] = maxf(float(entry.get("cooldown_left", 0.0)) - dt, 0.0)
		_active_skills[ability_id] = entry

func _elixir_for_team(p_team: int) -> ElixirManager:
	if _is_local_player_team(p_team):
		return _elixir
	if mode == "host" and p_team == 1:
		return _elixir_p1
	if mode == "local" and p_team == 1 and _ai != null:
		return _ai._elixir
	return null

func _spend_active_skill_cost(p_team: int, skill: Dictionary) -> bool:
	var cost := maxf(float(skill.get("cost", 0.0)), 0.0)
	if cost <= 0.0:
		return true
	var elixir := _elixir_for_team(p_team)
	return elixir != null and elixir.spend(cost)

func get_active_skill_snapshot(ability_id: int) -> Dictionary:
	if not _active_skills.has(ability_id):
		return {}
	var entry: Dictionary = _active_skills[ability_id]
	return {
		"uses_remaining": int(entry.get("uses_remaining", entry.get("max_uses", 1))),
		"cooldown_left": maxf(float(entry.get("cooldown_left", 0.0)), 0.0),
	}

## Cast Start 后的通用 Gameplay Impact 队列。计时在固定 Tick 中推进，
## 并在施法者被冻结/眩晕时与 Unit 的 cast timer 同步暂停。
func _queue_active_skill_impact(source: Unit, skill: Dictionary, impact_delay: float) -> void:
	skill = skill.duplicate(true)
	skill["cast_hit_state"] = ActiveSkillEffectSystem.CastHitState.new()
	var hit_damages = skill.get("prepared_hit_damages", [])
	var hit_delays = skill.get("prepared_hit_delays", [])
	if hit_damages is Array and hit_delays is Array and not (hit_damages as Array).is_empty():
		var hit_count := mini((hit_damages as Array).size(), (hit_delays as Array).size())
		for hit_index in hit_count:
			var hit_skill := skill.duplicate(true)
			hit_skill.erase("prepared_hit_damages")
			hit_skill.erase("prepared_hit_delays")
			hit_skill["hit_audio_phase"] = "first" if hit_index == 0 else ("last" if hit_index == hit_count - 1 else "middle")
			hit_skill["damage"] = maxf(float((hit_damages as Array)[hit_index]), 0.0)
			_queue_single_active_skill_impact(source, hit_skill, maxf(float((hit_delays as Array)[hit_index]), 0.0))
	else:
		_queue_single_active_skill_impact(source, skill, impact_delay)
	var cast_end_heal := maxf(float(skill.get("cast_end_heal", 0.0)), 0.0)
	if cast_end_heal > 0.0:
		_commands.impacts.append({
			"source_ref": weakref(source),
			"skill": {"cast_end_heal": cast_end_heal, "cast_end_heal_requires_hit": bool(skill.get("cast_end_heal_requires_hit", false)), "cast_hit_state": skill.cast_hit_state},
			"time_left": maxf(float(skill.get("cast_duration", 0.0)), 0.0),
			"phase": &"cast_end",
		})

func _queue_single_active_skill_impact(source: Unit, skill: Dictionary, impact_delay: float) -> void:
	if impact_delay <= 0.0:
		_active_skill_effect_system.apply(source, skill)
		return
	_commands.impacts.append({
		"source_ref": weakref(source),
		"skill": skill.duplicate(true),
		"time_left": impact_delay,
		"phase": &"impact",
	})


## 点击只决定请求能否进入 pending；队列到期时必须用同一谓词重新读取权威状态。
## pending 占用检查刻意留在 _queue_active_skill()，否则队列中的请求永远无法落地。
func _active_skill_is_legal(ability_id: int, expected_team: int = -1) -> bool:
	if game_over or not _active_skills.has(ability_id):
		return false
	var entry: Dictionary = _active_skills[ability_id]
	var unit = entry.get("unit")
	var p_team := int(entry.team)
	if not is_instance_valid(unit) or not unit is Unit or unit.hp <= 0.0:
		return false
	if expected_team >= 0 and p_team != expected_team:
		return false
	if int(entry.get("uses_remaining", entry.get("max_uses", 1))) <= 0:
		return false
	if float(entry.get("cooldown_left", 0.0)) > 0.001:
		return false
	if not _card_has_active_for_team(p_team, String(entry.card_id)):
		return false
	var valid_unit := unit as Unit
	if valid_unit.is_frozen() or valid_unit.is_stunned():
		return false
	# deploy/transform/skill 都高于普通攻击；高优先级窗口内拒绝新技能并保留按钮。
	return valid_unit.is_deployed() and not valid_unit.is_form_transitioning() and not valid_unit.is_active_skill_casting()

func _activate_active_skill(ability_id: int, expected_team: int = -1) -> bool:
	if not _active_skill_is_legal(ability_id, expected_team):
		# 正常死亡会由 died 信号立即清理；这里保留对失效引用/直接调用的兜底。
		if _active_skills.has(ability_id):
			var stale_entry: Dictionary = _active_skills[ability_id]
			var stale_unit = stale_entry.get("unit")
			if not is_instance_valid(stale_unit) or not stale_unit is Unit or stale_unit.hp <= 0.0:
				_on_active_skill_unit_died(ability_id)
		return false
	var entry: Dictionary = _active_skills[ability_id]
	var unit: Unit = entry.unit
	var skill: Dictionary = entry.skill
	if not _start_active_skill_cast(unit, skill):
		return false
	entry["uses_remaining"] = maxi(int(entry.get("uses_remaining", entry.get("max_uses", 1))) - 1, 0)
	entry["cooldown_left"] = maxf(float(skill.get("cooldown", 0.0)), 0.0)
	_active_skills[ability_id] = entry
	if _active_skill_bar != null:
		_active_skill_bar.set_pending(ability_id, false)
		_sync_active_skill_deployment_readiness()
	if mode == "host":
		_rpc_active_skill_used.rpc(ability_id, int(entry["uses_remaining"]), float(entry["cooldown_left"]))
	return true

func _start_active_skill_cast(unit: Unit, skill: Dictionary) -> bool:
	var prepared_skill: Dictionary = _active_skill_effect_system.prepare_cast(unit, skill)
	if StringName(prepared_skill.get("kind", "")) == &"dual_form":
		prepared_skill = _active_skill_effect_system.prepare_dual_form_cast(unit, prepared_skill)
	if prepared_skill.is_empty():
		return false
	# 先发布 Cast Start，再按 impact_delay 进入固定 Tick 队列；动画回调不参与结算。
	_active_skill_effect_system.apply_cast_start(unit, prepared_skill)
	_begin_configured_active_skill_cast(unit, prepared_skill)
	_queue_active_skill_impact(unit, prepared_skill, maxf(float(prepared_skill.get("impact_delay", 0.0)), 0.0))
	return true

func _begin_configured_active_skill_cast(unit: Unit, skill: Dictionary) -> void:
	var cast_duration := maxf(float(skill.get("cast_duration", 0.0)), 0.0)
	var action_name := StringName(skill.get("visual_action", ""))
	if cast_duration <= 0.0 and action_name == &"":
		return
	var cast_locks: Array = skill.get("cast_locks", Unit.DEFAULT_CAST_LOCKS)
	var cast_facing: Vector2 = skill.get("cast_forward", unit.get_visual_facing_direction())
	if cast_duration > 0.0:
		unit.begin_active_skill_cast(cast_duration, cast_facing, cast_locks)
	if action_name != &"":
		unit.play_visual_action(action_name, cast_duration)
	if StringName(skill.get("kind", "")) in [&"frontal", &"dual_form"]:
		var cast_forward := unit.active_skill_cast_facing
		if cast_forward.length_squared() < 0.001:
			cast_forward = unit.get_visual_facing_direction()
		_active_skill_effect_system.begin_frontal_visual(unit, skill, cast_forward)
	elif StringName(skill.get("kind", "")) == &"forward_area":
		var cast_forward := unit.active_skill_cast_facing
		if cast_forward.length_squared() < 0.001:
			cast_forward = unit.get_visual_facing_direction()
		_active_skill_effect_system.begin_forward_area_visual(unit, skill, cast_forward)
	elif StringName(skill.get("kind", "")) == &"continuous_area":
		_active_skill_effect_system.begin_continuous_area_visual(unit, skill)

## 水晶兵线入口。只在单机/主机固定模拟调用，最终仍统一走 _spawn_unit 与现有 RPC。
func _tick_minion_waves(dt: float) -> void:
	var waiting: Array[Dictionary] = []
	var ready: Array[Dictionary] = []
	for minion in _pending_lane_minions:
		var time_left := float(minion.time_left) - dt
		if time_left > 0.001:
			minion.time_left = time_left
			waiting.append(minion)
		else:
			ready.append(minion)
	_pending_lane_minions = waiting
	for minion in ready:
		_spawn_lane_minion(int(minion.team), int(minion.lane), String(minion.card_id))

	_battle_elapsed += dt
	while true:
		# 双倍金币阶段是独立的兵线事件：取消普通阶段原本会落在 2:20 的下一波，
		# 在 2:05 立即出炮车线，之后再从 2:05 以 30 秒为周期排程。
		if not _match_rules.overtime and _battle_elapsed + 0.001 >= DOUBLE_ELIXIR_START_TIME \
			and _next_minion_wave_time >= DOUBLE_ELIXIR_START_TIME \
			and _next_minion_wave_time < DOUBLE_ELIXIR_START_TIME + DOUBLE_MINION_WAVE_INTERVAL:
			_spawn_minion_wave(MINION_WAVE_SIEGE)
			_next_minion_wave_time = DOUBLE_ELIXIR_START_TIME + DOUBLE_MINION_WAVE_INTERVAL
			continue
		if _battle_elapsed + 0.001 < _next_minion_wave_time:
			break
		# 正赛结束和加时结束都是硬边界：自动 scheduler 不能生成 3:05/5:05 兵线。
		if not _match_rules.overtime and _next_minion_wave_time >= MATCH_TIME:
			break
		if _match_rules.overtime and _next_minion_wave_time >= MATCH_TIME + OVERTIME_TIME:
			break
		var wave_type := MINION_WAVE_SIEGE if _match_rules.overtime or _next_minion_wave_time >= DOUBLE_ELIXIR_START_TIME else MINION_WAVE_NORMAL
		if is_equal_approx(_next_minion_wave_time, FIRST_MINION_WAVE_TIME):
			_present_match_announcement("minions_spawn")
		_spawn_minion_wave(wave_type)
		_next_minion_wave_time += DOUBLE_MINION_WAVE_INTERVAL if wave_type == MINION_WAVE_SIEGE else NORMAL_MINION_WAVE_INTERVAL

func _spawn_minion_wave(wave_type: String = MINION_WAVE_NORMAL) -> void:
	var second_card := "siege_minion" if wave_type == MINION_WAVE_SIEGE else "ranged_minion"
	# 固定顺序保证相同 tick 的出生与碰撞结果不依赖节点遍历或随机数。
	for team in [0, 1]:
		for lane in [0, 1]:
			var front_card := "super_minion" if _enemy_lane_tower_destroyed(team, lane) else "melee_minion"
			_spawn_lane_minion(team, lane, front_card)
			_pending_lane_minions.append({
				"team": team,
				"lane": lane,
				"card_id": second_card,
				"time_left": MINION_WAVE_STAGGER,
			})

func _spawn_lane_minion(team: int, lane: int, card_id: String) -> Unit:
	var x := ArenaRules.FIELD_W * 0.5 + (-MINION_SPAWN_X_OFFSET if lane == 0 else MINION_SPAWN_X_OFFSET)
	var y := 29.0 * ArenaRules.TILE_SIZE if team == 0 else 3.0 * ArenaRules.TILE_SIZE
	var stats: Dictionary = CardDB.get_card(card_id)
	var pos := _nearest_valid_ground_spawn(Vector2(x, y), float(stats.radius), team)
	return _spawn_unit(team, card_id, pos, 0.0)

func _enemy_lane_tower_destroyed(team: int, lane: int) -> bool:
	# _towers 顺序：蓝左、蓝右、红左、红右。己方对应路只看敌方同侧公主塔。
	var enemy_team := 1 - team
	var tower_index := enemy_team * 2 + lane
	return tower_index >= 0 and tower_index < 4 and _towers[tower_index].hp <= 0.0

func _is_double_elixir_phase() -> bool:
	# 正赛 2:05 起双倍金币；加时全程保持双倍。match_timer 兼容客户端不推进 _battle_elapsed 的情况。
	return _match_rules.overtime or _battle_elapsed + 0.001 >= DOUBLE_ELIXIR_START_TIME or _match_rules.time_left <= DOUBLE_ELIXIR_TIME + 0.001

## 解除导航网格阻挡格（建筑卡死亡 / 塔被摧毁时调用）
func unblock_nav_cells(cells: Array) -> void:
	if nav == null or cells.is_empty():
		return
	nav.set_cells_blocked(cells, false)

## 河道本身是硬障碍，A* 会自然选择总代价最低的桥。
## 不再拼接“桥入口 -> 桥出口”三段路径：单位踏上桥后重算时，旧实现会先把它拉回入口。
func find_ground_path(from: Vector2, goal: Vector2, _target: Node2D, _mover_radius: float = ArenaRules.NAV_CLEARANCE) -> PackedVector2Array:
	if nav == null:
		return PackedVector2Array()
	return nav.find_path(from, goal)

## 单位死亡回调（由 unit._die 调用）：主机可靠广播死亡表现并立即清理映射。
func on_unit_died(id: int, play_death_visual: bool = true) -> void:
	_net_units.erase(id)
	if mode == "host":
		_rpc_unit_died.rpc(id, play_death_visual)

## 单位受击回调：本地模型已由 Unit 信号闪白，主机只负责可靠转发给客户端表现层。
func on_unit_hit(id: int) -> void:
	if mode == "host":
		_rpc_unit_hit.rpc(id)

## 塔受击回调：本地模型已由 Tower 信号闪白，主机按 _towers 下标可靠转发给客户端。
func on_tower_hit(tower: Tower) -> void:
	if mode == "host":
		var index := _towers.find(tower)
		if index >= 0:
			_rpc_tower_hit.rpc(index)

## 固定 20Hz 模拟步：驱动全部战斗单位与塔，处理国王塔激活与障碍移除。
## 帧率高低只影响每帧跑多少步，不改变战斗结果（联机两端行为一致）。
func _sim_step(dt: float) -> void:
	_sim_tick_id += 1
	if _match_started and not _art_dev_mode:
		_update_elixir_rate()
		_elixir.sim_tick(dt)
		if _elixir_p1 != null:
			_elixir_p1.sim_tick(dt)
		if _ai != null:
			_ai._elixir.sim_tick(dt)
			if _ai.enabled:
				_ai.sim_tick(dt)
	# 已存在的施法时间线先推进；本 Tick 新执行的命令从当前 Tick 边界开始计时。
	_tick_active_skill_cooldowns(dt)
	_commands.tick_impacts(dt)
	_active_skill_effect_system.tick_effects(dt)
	_tick_pending_card_deployments(dt)
	_tick_pending_active_skills(dt)
	_tick_slow_zones(dt)
	if not _art_dev_mode and _minion_waves_enabled:
		_tick_minion_waves(dt)
	for c in get_tree().get_nodes_in_group("combatants"):
		if c.has_method("sim_tick"):
			c.sim_tick(dt)
	# 预部署在本 Tick 边界完成；新单位从下一 Tick 推进实际部署，避免两阶段共用一个 Tick。
	_tick_pending_card_pre_deployments(dt)
	_sync_active_skill_deployment_readiness()
	_movement.tick(dt)
	_tick_projectiles(dt)
	# 己方任一公主塔被摧毁 → 国王塔参战。
	for king in [_king_player, _king_enemy]:
		if not king.can_attack or king.activated or king.hp <= 0.0:
			continue
		var side: int = king.team
		if _towers[side * 2].hp <= 0.0 or _towers[side * 2 + 1].hp <= 0.0:
			king.activate()
	# 塔被摧毁 → 解除其导航网格占地，路径可穿过原塔位
	for t in _towers:
		if t.hp <= 0.0 and not t.nav_cells.is_empty():
			unblock_nav_cells(t.nav_cells)
			t.nav_cells = []
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
			_deploy_card(0, "garen", Vector2(360, 1000))
			_deploy_card(0, "ashe", Vector2(300, 700))
			_deploy_card(0, "aurelionsol", Vector2(410, 700))
			_deploy_card(1, "xin", Vector2(300, 580))
			var auto_gnar := _spawn_unit(0, "gnar", Vector2(520, 760), 0.0)
			preview_active_skill(auto_gnar, CardDB.active_skills_for("gnar")[0])
			_auto_gnar_revert_unit = auto_gnar
			_auto_gnar_revert_timer = 2.4

	if _match_started and not _art_dev_mode:
		_tick_match_rules(dt)

func _process(delta: float) -> void:
	if mode == "client":
		_sync_active_skill_deployment_readiness()
	_projectile_system.tick_visuals(delta)
	# 客户端：只更新冰冻视觉与重绘，逻辑状态全靠主机快照
	if mode == "client":
		_advance_estimated_server_tick(delta)
		_projectile_system.tick_client_interpolation(delta)
		_tick_card_pre_deploy_visuals(delta)
		_tick_slow_effect_visuals(delta)
		_active_skill_effect_system.tick_visuals(delta)
		queue_redraw()
		return
	if _art_dev_mode:
		if _art_dev_panel != null and not _art_dev_panel.accepts_battle_input():
			return
		_tick_slow_effect_visuals(delta)
		_active_skill_effect_system.tick_visuals(delta)
		queue_redraw()
		_simulation_clock.advance(delta)
		_sync_art_dev_panel_state()
		return
	if not _match_started or game_over:
		return
	# 更新冰冻视觉效果
	_tick_slow_effect_visuals(delta)
	_active_skill_effect_system.tick_visuals(delta)
	queue_redraw()
	# 主机：定时向客户端发送快照
	if mode == "host":
		_snapshot_timer -= delta
		if _snapshot_timer <= 0.0:
			_snapshot_timer = SNAPSHOT_INTERVAL
			_send_snapshot()
	# 固定 20Hz 战斗模拟：与渲染帧率解耦（auto-test 出兵也在模拟内计时）
	_simulation_clock.advance(delta)
	_update_timer_label()

func _tick_match_rules(dt: float) -> void:
	var outcome := _match_rules.advance(dt, _king_player.hp, _king_enemy.hp, _count_destroyed_towers(0), _count_destroyed_towers(1))
	_update_elixir_rate()
	if not outcome.is_empty():
		_end_game(outcome)

func _on_overtime_started() -> void:
	_battle_elapsed = maxf(_battle_elapsed, MATCH_TIME)
	_next_minion_wave_time = MATCH_TIME + DOUBLE_MINION_WAVE_INTERVAL
	if _minion_waves_enabled and not _art_dev_mode:
		_spawn_minion_wave(MINION_WAVE_SIEGE)
	_update_timer_label()
	_update_elixir_rate()

## 某方被摧毁的塔数量
func _count_destroyed_towers(p_team: int) -> int:
	var count := 0
	for t in _towers:
		if t.team == p_team and t.hp <= 0.0:
			count += 1
	return count

func _update_timer_label() -> void:
	if _timer_label == null:
		return
	var t := maxi(int(_match_rules.time_left), 0)
	var text := "%d:%02d" % [t / 60, t % 60]
	if _match_rules.overtime:
		text += " 加时"
	_timer_label.text = text

## 金币回复倍率：正赛 2:05 起双倍；加时前一分钟双倍，最后一分钟三倍。
func _update_elixir_rate() -> void:
	var mult := 1.0
	if _match_rules.overtime:
		mult = 3.0 if _match_rules.time_left <= OVERTIME_TRIPLE_ELIXIR_TIME else 2.0
	elif _is_double_elixir_phase():
		mult = 2.0
	_elixir.regen_multiplier = mult
	if _elixir_p1 != null:
		_elixir_p1.regen_multiplier = mult
	if _ai != null:
		_ai._elixir.regen_multiplier = mult

## 找玩家单位最密集的位置（敌方法术 AI 用）
func _find_player_cluster() -> Vector2:
	var best_pos := Vector2(360.0, 960.0)
	var best_count := 0
	for c in get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(c) or c.team != 0:
			continue
		var u := c as Unit
		if u == null or u.is_building:
			continue
		var count := 0
		for c2 in get_tree().get_nodes_in_group("combatants"):
			if not is_instance_valid(c2) or c2.team != 0:
				continue
			if c2.global_position.distance_to(c.global_position) < 120.0:
				count += 1
		if count > best_count:
			best_count = count
			best_pos = c.global_position
	return best_pos

func _end_game(text: String) -> void:
	if game_over:
		return
	game_over = true
	if _audio_manager != null:
		if text.begins_with("胜利"): _audio_manager.play_match_event("victory")
		elif text.begins_with("失败"): _audio_manager.play_match_event("defeat")
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 48)
	label.position = Vector2(60, 600)
	add_child(label)
	# 主机：通知客户端比赛结果
	if mode == "host":
		_rpc_end.rpc(text)

# ============================================================
#  联机 RPC
# ============================================================

## 客户端开局后上报完整卡组。主机只接受 8 张互不重复、可选的合法卡牌。
@rpc("any_peer", "call_remote", "reliable")
func _rpc_register_deck(deck: Array, active_skill_choices: Dictionary = {}) -> void:
	if mode != "host" or deck.size() != 8:
		return
	var validated: Array = []
	for raw_id in deck:
		var card_id := String(raw_id)
		if not CardDB.has_card(card_id) or not bool(CardDB.get_card(card_id).get("selectable", true)) or card_id in validated:
			return
		validated.append(card_id)
	_resources.prepare(validated)
	_remote_deck = validated
	_remote_active_skill_choices.clear()
	for card_id in validated:
		var skills := CardDB.active_skills_for(card_id)
		if not skills.is_empty():
			_remote_active_skill_choices[card_id] = clampi(int(active_skill_choices.get(card_id, 0)), 0, skills.size() - 1)
	_initialize_authoritative_card_cycle(1, _remote_deck)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_active_skill_request(ability_id: int, input_tick: int = -1) -> void:
	if mode != "host" or game_over:
		return
	var sender := multiplayer.get_remote_sender_id()
	if input_tick < 0 or not use_active_skill(ability_id, 1, sender, false, input_tick):
		_rpc_active_skill_rejected.rpc_id(sender, ability_id)

func _tick_card_pre_deploy_visuals(delta: float) -> void:
	var alive: Array[Dictionary] = []
	for deployment in _commands.pre_deployments:
		deployment.time_left = maxf(float(deployment.get("time_left", 0.0)) - delta, 0.0)
		if float(deployment.time_left) > 0.001:
			alive.append(deployment)
	_commands.pre_deployments = alive

func _remove_card_pre_deploy_visual(pre_deploy_id: int) -> void:
	if pre_deploy_id < 0:
		return
	var alive: Array[Dictionary] = []
	for deployment in _commands.pre_deployments:
		if int(deployment.get("id", -1)) != pre_deploy_id:
			alive.append(deployment)
	_commands.pre_deployments = alive

@rpc("authority", "call_remote", "reliable")
func _rpc_active_skill_used(ability_id: int, uses_remaining: int = 0, cooldown_left: float = 0.0) -> void:
	if mode != "client":
		return
	if _active_skills.has(ability_id):
		var entry: Dictionary = _active_skills[ability_id]
		entry["uses_remaining"] = maxi(uses_remaining, 0)
		entry["cooldown_left"] = maxf(cooldown_left, 0.0)
		_active_skills[ability_id] = entry
		_sync_active_skill_deployment_readiness()

@rpc("authority", "call_remote", "reliable")
func _rpc_active_skill_rejected(ability_id: int) -> void:
	if mode == "client" and _active_skill_bar != null:
		_active_skill_bar.set_pending(ability_id, false)

## 客户端 → 主机：部署请求。客户端只携带点击时观察到的 input_tick，目标 Tick 由 Host 计算。
@rpc("any_peer", "call_remote", "reliable")
func _rpc_deploy_request(card_id: String, pos: Vector2, input_tick: int = -1) -> void:
	if mode != "host" or game_over:
		return
	var sender := multiplayer.get_remote_sender_id()
	var accepted := input_tick >= 0 and play_card(1, card_id, pos, {
		"elixir": _elixir_p1,
		"require_team_deck": true,
		"requester_peer_id": sender,
		"input_tick": input_tick,
	})
	if not accepted:
		_rpc_deploy_rejected.rpc_id(sender, card_id)

## 主机 → 客户端：仅在权威扣费、轮换手牌并排程成功后确认出牌。
@rpc("authority", "call_remote", "reliable")
func _rpc_deploy_accepted(card_id: String, execute_tick: int, hand: Array, queue: Array) -> void:
	if mode != "client":
		return
	if _hand != null:
		_hand.set_card_pending(card_id, false)
		_hand.set_cycle_state(hand, queue)
	_authoritative_card_cycles[1] = {
		"deck": _deck.duplicate(),
		"hand": hand.duplicate(),
		"queue": queue.duplicate(),
	}

## 主机 → 客户端：拒绝不改变权威手牌；只恢复对应卡牌按钮。
@rpc("authority", "call_remote", "reliable")
func _rpc_deploy_rejected(card_id: String) -> void:
	if mode == "client" and _hand != null:
		_hand.set_card_pending(card_id, false)

## 主机 → 客户端：单位生成
@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_unit(card_id: String, p_team: int, pos: Vector2, net_id: int, deploy_time_override: float = -1.0, active_ability_id: int = -1, active_ability_slot: int = -1, pre_deploy_id: int = -1, deployment_group_id: int = -1, visual_transition: String = "", death_replacement_charges_override: int = -1, built_on_tower_ruin: bool = false) -> void:
	if mode != "client":
		return
	_remove_card_pre_deploy_visual(pre_deploy_id)
	var stats: Dictionary = CardDB.get_unit_stats(card_id)
	if deploy_time_override >= 0.0:
		stats = stats.duplicate()
		stats["deploy_time"] = deploy_time_override
	var u := Unit.new()
	u.card_id = card_id
	u.deployment_group_id = deployment_group_id
	u.visual_spawn_transition = StringName(visual_transition)
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
	if nav != null and u.is_building:
		_register_dynamic_building(u)
	_client_units[net_id] = u
	if active_ability_id >= 0:
		_register_active_skill(u, card_id, p_team)
	if _auto_test:
		print("[测试] 客户端收到单位生成: ", card_id, " net_id=", net_id)

## 主机 → 客户端：两段式部署的第一段落点提示。客户端只计时和绘制标记，
## 真正生成仍以随后到达的 _rpc_spawn_unit 为准。
@rpc("authority", "call_remote", "reliable")
func _rpc_card_pre_deploy_started(pre_deploy_id: int, card_id: String, p_team: int, pos: Vector2, duration: float) -> void:
	if mode != "client":
		return
	_remove_card_pre_deploy_visual(pre_deploy_id)
	_commands.pre_deployments.append({
		"id": pre_deploy_id,
		"card_id": card_id,
		"team": p_team,
		"pos": pos,
		"time_left": maxf(duration, 0.0),
		"duration": maxf(duration, 0.0),
	})
	queue_redraw()

## 主机 → 客户端：可靠触发一次短暂闪白，不依赖不可靠血量快照是否刚好采到该帧。
@rpc("authority", "call_remote", "reliable")
func _rpc_unit_hit(net_id: int) -> void:
	if mode != "client":
		return
	var u: Unit = _client_units.get(net_id)
	if u != null and is_instance_valid(u):
		u.notify_visual_hit()
		if _auto_test:
			print("[测试] 客户端收到受击闪白事件: net_id=", net_id)

## 主机 → 客户端：一次真实普攻命中对应一个短促的纯表现音频事件；允许丢失，绝不阻塞快照。
@rpc("authority", "call_remote", "unreliable")
func _rpc_attack_audio_hit(source: Dictionary, position: Vector2, first_strike: bool = false) -> void:
	if mode != "client":
		return
	if _auto_test and not _auto_audio_source_seen:
		_auto_audio_source_seen = true
		print("[测试] 客户端收到独立攻击来源命中事件：", source)
	if _audio_manager != null:
		_audio_manager.play_attack_source(source, position, first_strike)

@rpc("authority", "call_remote", "reliable")
func _rpc_tower_hit(index: int) -> void:
	if mode != "client":
		return
	if index >= 0 and index < _towers.size():
		_towers[index].notify_visual_hit()

## 主机 → 客户端：可靠播放一次弹体命中表现；伤害结果仍只来自主机快照。
@rpc("authority", "call_remote", "reliable")
func _rpc_projectile_impact_fx(pos: Vector2, radius: float, color: Color, visual: String) -> void:
	if mode != "client":
		return
	_projectile_system.add_impact_visual(pos, radius, color, StringName(visual))

## 主机 → 客户端：可靠触发死亡动作。逻辑单位立即释放，3D 代理独立播完动作。
@rpc("authority", "call_remote", "reliable")
func _rpc_unit_died(net_id: int, play_death_visual: bool = true) -> void:
	if mode != "client":
		return
	var u: Unit = _client_units.get(net_id)
	if u == null or not is_instance_valid(u):
		_client_units.erase(net_id)
		return
	if u.is_building and not u.nav_cells.is_empty():
		unblock_nav_cells(u.nav_cells)
		u.nav_cells = []
	if not play_death_visual and not u.timed_revival_id.is_empty() and _audio_manager != null:
		_audio_manager.complete_revival(u)
	if play_death_visual:
		u.notify_visual_death()
	u.queue_free()
	_client_units.erase(net_id)

## 主机 → 客户端：定期快照（位置/血量/金币/计时）。
## 兵线会稳定增加单位数，直接 RPC 传嵌套 Variant 数组很快超过 ENet MTU；
## 因此先序列化并 DEFLATE 压缩成单个字节载荷，客户端解包后仍只做表现插值。
@rpc("authority", "call_remote", "unreliable")
func _rpc_snapshot(snapshot_bytes: PackedByteArray) -> void:
	_snapshot_system.apply(snapshot_bytes)

## 主机 → 客户端：冰冻法术视觉
@rpc("authority", "call_remote", "reliable")
func _rpc_freeze_fx(pos: Vector2, radius: float, duration: float, slow_duration: float = 0.0, _slow_multiplier: float = 1.0) -> void:
	if mode != "client":
		return
	_spell_system.freeze_effects.append({"pos": pos, "timer": duration, "duration": duration, "radius": radius})
	if slow_duration > 0.0:
		_spell_system.slow_effects.append({"pos": pos, "radius": radius, "delay": duration, "timer": slow_duration, "duration": slow_duration})

## 主机 → 客户端：治疗法术视觉。治疗数值由主机权威结算，客户端只显示淡黄光效。
@rpc("authority", "call_remote", "reliable")
func _rpc_heal_fx(pos: Vector2, radius: float, duration: float, enhanced: bool = false) -> void:
	if mode != "client":
		return
	_spell_system.heal_effects.append({"pos": pos, "radius": radius, "timer": duration, "duration": duration, "enhanced": enhanced})

## 主机 → 客户端：定向技能蓄力范围。客户端只画表现，伤害与状态仍由主机快照体现。
@rpc("authority", "call_remote", "reliable")
func _rpc_frontal_skill_fx(net_id: int, pos: Vector2, forward: Vector2, source_radius: float, length: float, width: float, duration: float, p_team: int, shape: String = "rectangle", near_width: float = 0.0, far_width: float = 0.0, arc_degrees: float = 0.0, projectile_count: int = 0, center_ratio: float = 0.0, center_width: float = 0.0, fan_inner_arc: bool = false, projectile_visual: String = "arrow", projectile_launch_delay: float = 0.0, projectile_flight_duration: float = 0.0, projectile_visual_height: float = 0.0, projectile_visual_forward_offset: float = -1.0, projectile_visual_width: float = 0.0) -> void:
	if mode != "client":
		return
	_active_skill_effect_system.frontal_effects.append({
		"source_ref": null,
		"net_id": net_id,
		"fixed_position": shape in ["target_circle", "shockwave", "frost_storm"],
		"pos": pos,
		"forward": forward.normalized(),
		"source_radius": source_radius,
		"length": length,
		"width": width,
		"shape": shape,
		"near_width": width if near_width <= 0.0 else near_width,
		"far_width": width if far_width <= 0.0 else far_width,
		"arc_degrees": arc_degrees,
		"projectile_count": projectile_count,
		"projectile_visual": projectile_visual,
		"projectile_launch_delay": maxf(projectile_launch_delay, 0.0),
		"projectile_flight_duration": maxf(projectile_flight_duration, 0.0),
		"projectile_visual_height": maxf(projectile_visual_height, 0.0),
		"projectile_visual_forward_offset": source_radius if projectile_visual_forward_offset < 0.0 else projectile_visual_forward_offset,
		"projectile_visual_width": maxf(projectile_visual_width, 0.0),
		"center_ratio": center_ratio,
		"center_width": center_width,
		"fan_inner_arc": fan_inner_arc,
		"timer": duration,
		"duration": duration,
		"team": p_team,
	})
	if _auto_test and not _auto_gnar_skill_fx_seen:
		_auto_gnar_skill_fx_seen = true
		print("[测试] 客户端已收到固定方向技能范围表现")

## 主机 → 客户端：比赛结束
@rpc("authority", "call_remote", "reliable")
func _rpc_end(text: String) -> void:
	if mode != "client":
		return
	# 结果文本来自主机视角；客户端的胜负及播报必须相反。
	var local_text := text
	if text.begins_with("胜利"):
		local_text = "失败" + text.substr(2)
	elif text.begins_with("失败"):
		local_text = "胜利" + text.substr(2)
	local_text = local_text.replace("敌方", "__opponent__").replace("我方", "敌方").replace("__opponent__", "我方")
	_end_game(local_text)

## 主机端：组装并发送快照
func _send_snapshot() -> void:
	_snapshot_system.send()

func _draw() -> void:
	# 完整 720x1400 地图（含手牌区后方场外风景）；3D 表现视口继续透明叠加。
	# 选中卡牌时高亮可部署区域
	if _selected_card != "":
		var sel_stats: Dictionary = CardDB.get_card(_selected_card)
		var deploy_zone: String = String(sel_stats.get("deploy_zone", "own_side"))
		match deploy_zone:
			"global":
				# global 级卡（冰冻、卡牌大师）：整个竞技场提示为范围提示色；
				# 具体水面/塔上等占位不可点的位置，由红/绿圆形落点预览精确反馈。
				draw_rect(Rect2(0, 0, ArenaRules.FIELD_W, ArenaRules.FIELD_H), Color(0.40, 0.70, 1.00, 0.08))
			_:
				# own_side：逐格按己方部署掩码绘制
				var deploy_team := 1 if mode == "client" else 0
				for row in ArenaRules.ARENA_ROWS:
					for column in ArenaRules.ARENA_COLUMNS:
						var tile := Vector2i(column, row)
						if _tile_in_ground_deploy_zone(tile, deploy_team):
							draw_rect(Rect2(Vector2(tile) * ArenaRules.TILE_SIZE, Vector2.ONE * ArenaRules.TILE_SIZE), Color(0.40, 0.70, 1.00, 0.15))
		_draw_deployment_preview(sel_stats)
	# 两段式部署的第一段只显示一个落点卡牌标记，不创建单位或战斗碰撞体。
	for pre_deployment in _commands.pre_deployments:
		_draw_card_pre_deploy_indicator(pre_deployment)

func _setup_arena_background() -> void:
	_arena_background_sprite = Sprite2D.new()
	_arena_background_sprite.name = "ArenaBackground2D"
	_arena_background_sprite.texture = ARENA_BACKGROUND_TEXTURE
	_arena_background_sprite.centered = false
	_arena_background_sprite.position = Vector2.ZERO
	_arena_background_sprite.z_index = -100
	add_child(_arena_background_sprite)
	move_child(_arena_background_sprite, 0)

func _draw_card_pre_deploy_indicator(deployment: Dictionary) -> void:
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
		var unit_radius: float = minf(float(stats.get("radius", ArenaRules.TILE_SIZE * 0.5)), ArenaRules.TILE_SIZE * 0.42)
		draw_circle(_deployment_preview_pos, unit_radius, Color(color.r, color.g, color.b, 0.26))
		draw_arc(_deployment_preview_pos, unit_radius, 0.0, TAU, 32, color, 2.0, true)
	else:
		# 建筑额外画中心十字，明确规则占地中心；奇数格在格心，偶数格在线交点。
		var cross_size := 7.0
		draw_line(_deployment_preview_pos - Vector2(cross_size, 0.0), _deployment_preview_pos + Vector2(cross_size, 0.0), color, 2.0, true)
		draw_line(_deployment_preview_pos - Vector2(0.0, cross_size), _deployment_preview_pos + Vector2(0.0, cross_size), color, 2.0, true)

func _play_card_event(event_id: int, card_id: String, cue: String, pos: Vector2, form: int = 0) -> void:
	if event_id <= _last_card_event_id:
		return
	_last_card_event_id = event_id
	if card_id == "match":
		if not game_over and _audio_manager != null: _audio_manager.play_match_event(cue)
		return
	if cue == "shield:cast":
		_active_skill_effect_system.present_area_shield(card_id, form, pos)
	if _audio_manager != null:
		_audio_manager.play_card_event(card_id, cue, pos, form)

func _on_skill_projectile_hit(source: Dictionary, action: String, pos: Vector2, phase: String = "hit") -> void:
	if action.is_empty():
		return
	_presentation_event_id += 1
	var card_id := String(source.get("card_id", ""))
	var form := int(source.get("form", 0))
	_play_card_event(_presentation_event_id, card_id, action + ":" + phase, pos, form)
	if mode == "host":
		_rpc_card_event.rpc(_presentation_event_id, card_id, action + ":" + phase, pos, form)

func present_zone_audio(source: Unit, action: String, pos: Vector2, duration: float) -> void:
	_presentation_event_id += 1
	if _audio_manager != null:
		_audio_manager.start_zone_audio(_presentation_event_id, source.card_id, source.form_index, action, pos, duration)
	if mode == "host":
		_rpc_zone_audio.rpc(_presentation_event_id, source.card_id, source.form_index, action, pos, duration)

@rpc("authority", "call_remote", "reliable")
func _rpc_zone_audio(event_id: int, card_id: String, form: int, action: String, pos: Vector2, duration: float) -> void:
	if mode == "client" and _audio_manager != null:
		_audio_manager.start_zone_audio(event_id, card_id, form, action, pos, duration)

@rpc("authority", "call_remote", "reliable")
func _rpc_card_event(event_id: int, card_id: String, cue: String, pos: Vector2, form: int = 0) -> void:
	if mode == "client":
		_play_card_event(event_id, card_id, cue, pos, form)


func _present_match_announcement(cue: String) -> void:
	_presentation_event_id += 1
	_play_card_event(_presentation_event_id, "match", cue, Vector2.ZERO)
	if mode == "host":
		_rpc_card_event.rpc(_presentation_event_id, "match", cue, Vector2.ZERO)
