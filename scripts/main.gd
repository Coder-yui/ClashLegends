extends Node2D
## 主场景：战场搭建、部署输入、敌方占位出兵、胜负判定。

const ART_DEV_PANEL_SCRIPT := preload("res://scripts/art_dev_panel.gd")
const ACTIVE_SKILL_BAR_SCRIPT := preload("res://scripts/active_skill_bar.gd")
const SPELL_SYSTEM_SCRIPT := preload("res://scripts/battle/spell_system.gd")
const ACTIVE_SKILL_EFFECT_SYSTEM_SCRIPT := preload("res://scripts/battle/active_skill_effect_system.gd")
const ARENA_BACKGROUND_TEXTURE := preload("res://assets/arena/arena_rift_v4.png")

## CR 标准 1v1 场地：18 列 x 32 行。项目分辨率正好对应每格 40px。
## 后续地图、部署、塔位和导航只能从这组格子常量派生，避免再次出现比例漂移。
const ARENA_COLUMNS := 18
const ARENA_ROWS := 32
const TILE_SIZE := 40.0
const FIELD_W := ARENA_COLUMNS * TILE_SIZE
const FIELD_H := ARENA_ROWS * TILE_SIZE
const RIVER_TOP_ROW := 15
const RIVER_BOTTOM_ROW := 17
const RIVER_Y := 16.0 * TILE_SIZE
const RIVER_HALF := TILE_SIZE
# 参考竞技场的两座桥均为 3 格宽，中心与对应公主塔同轴。
const BRIDGE_HALF := TILE_SIZE * 1.5
const BRIDGE_X_LEFT := 3.5 * TILE_SIZE
const BRIDGE_X_RIGHT := 14.5 * TILE_SIZE
## A* 用当前最大人物圆柱半径统一收窄桥面、扩张河岸与静态障碍；
## 连续碰撞仍按每个单位自己的档位半径精确判定。
const NAV_CLEARANCE := CardDB.RADIUS_EXTREMELY_LARGE
const NAV_GRID_PADDING := 8.0
const STRUCTURE_SEPARATION := 1.0 * CardDB.CHARACTER_SCALE_MULTIPLIER
const AVOID_LOOKAHEAD := 34.0 * CardDB.CHARACTER_SCALE_MULTIPLIER
const AVOID_NEIGHBOR_PADDING := 26.0 * CardDB.CHARACTER_SCALE_MULTIPLIER
const AVOID_MIN_FORWARD_RATIO := 0.35
const COLLISION_SLOP := 0.5 * CardDB.CHARACTER_SCALE_MULTIPLIER
const COLLISION_CORRECTION_PERCENT := 0.35
const COLLISION_MAX_CORRECTION := 3.0 * CardDB.CHARACTER_SCALE_MULTIPLIER
const LANDING_CORRECTION_PERCENT := 0.75
const LANDING_MAX_CORRECTION := 8.0 * CardDB.CHARACTER_SCALE_MULTIPLIER
const BRIDGE_EDGE_MARGIN := 2.0 * CardDB.CHARACTER_SCALE_MULTIPLIER
const DEPLOY_PREVIEW_VALID := Color(0.35, 0.95, 0.58, 0.82)
const DEPLOY_PREVIEW_INVALID := Color(1.0, 0.30, 0.30, 0.88)
# 公主塔的权杖晶石相对 2D 塔心的屏幕偏移，只用于弹体绘制，不参与射程、碰撞或命中。
# 蓝方/红方塔模型在表现层相差 180°，Tower.setup() 会镜像 X。
const PRINCESS_PROJECTILE_VISUAL_OFFSET := Vector2(12.0, -205.0)
const TOWER_RANGE_REDUCTION := 1.5 * TILE_SIZE
# 双方地面部署区各 15 行；贴河外角与国王塔后方两侧不可部署。
const TEAM_0_FIRST_ROW := RIVER_BOTTOM_ROW
const TEAM_0_LAST_ROW := ARENA_ROWS - 1
const BACK_CENTER_MIN_COLUMN := 6
const BACK_CENTER_MAX_COLUMN := 11
const POCKET_FIRST_ROW := 9
const POCKET_LAST_ROW := RIVER_TOP_ROW - 1

# 视觉占地、部署禁区与移动碰撞分离：塔仍显示为 3x3 / 4x4，物理与部署圆稍微内收，
# 给放大后的人物在公主塔侧面和水晶底部留下稳定的绕行空间。
const PRINCESS_STATS := {"hp": 2100.0, "damage": 55.0, "range": 300.0 - TOWER_RANGE_REDUCTION, "interval": 0.8, "radius": 54.0, "visual_radius": 60.0, "deployment_radius": 54.0, "first_hit": 0.2, "projectile_speed": 420.0, "projectile_visual_offset": PRINCESS_PROJECTILE_VISUAL_OFFSET}
# 基地水晶只承担被保护/被摧毁的胜负目标，不再索敌或攻击；兵线由主机固定模拟生成。
const KING_STATS := {"hp": 3600.0, "damage": 0.0, "range": 0.0, "interval": 1.0, "radius": 72.0, "visual_radius": 80.0, "deployment_radius": 72.0, "first_hit": 0.2, "projectile_speed": 0.0, "can_attack": false}
# 公主塔阶段模式：满血显示 Base；血量破 2/3 换 Stage1 并播 Broken1 坠落，
# 破 1/3 换 Stage2 并播 Broken2；被摧毁换 Stage3 并播 Broken3，演完定格 Rubble。
# 掉到哪个阶段就直接播该阶段的碎块动画（跨阶段跳播、打断旧的）。
# 素材轨迹是组装向（地下→附着位），窗口 [落定时刻, 附着时刻] 反转烘焙成
# 正放坠毁（原动画倒放压缩到 2 秒）。
const PRINCESS_VISUAL_CONFIG := {
	"scene_paths": [
		"res://assets/towers/princess/princess_tower_blue_view.tscn",
		"res://assets/towers/princess/princess_tower_red_view.tscn",
	],
	"ground_cutoff": 0.0,
	"animations": {
		"destroy": "Destroyed",
		"stage_surfaces": ["Base", "Stage1", "Stage2"],
		"final_stage_surface": "Stage3",
		"ruin_surface": "Rubble",
		"debris": [
			{"bones": "Break1", "surface": "Broken1", "window": [10.0, 15.0]},
			{"bones": "Break2", "surface": "Broken2", "window": [8.0, 15.0]},
			{"bones": "Break3", "surface": "Broken3", "window": [8.0, 15.0]},
		],
		"debris_duration": 2.0,
	},
}
const NEXUS_VISUAL_CONFIG := {
	"scene_paths": [
		"res://assets/towers/nexus/nexus_blue_view.tscn",
		"res://assets/towers/nexus/nexus_red_view.tscn",
	],
	"ground_cutoff": 0.0,
	"animations": {
		"spawn": "Nexus_spawn_anm", "idle": "Idle1_Base", "destroy": "Death",
		"spawn_duration": 2.5, "destroy_duration": 4.0,
		"alive_materials": ["SRUAP_OrderNexus_Mat"], "destroyed_materials": ["Destroyed"],
	},
}

# 比赛计时：3 分钟正赛，平局进 60 秒加时（先破塔者胜），再平则平局
const MATCH_TIME := 180.0
const OVERTIME_TIME := 60.0
const SIM_DT := 1.0 / 20.0
const DOUBLE_ELIXIR_TIME := 60.0
## 所有玩家命令使用 20Hz 权威 Tick 排程，0.5 秒对应 10 个模拟 Tick。
const COMMAND_DELAY_TICKS := 10
## 网络请求的 input_tick 最多允许落后两个 Buffer；更早的输入直接视为异常。
const COMMAND_MAX_LATENCY_TICKS := COMMAND_DELAY_TICKS * 2
## 允许少量客户端时钟领先 Host；这只是校验窗口，不是客户端执行权。
const COMMAND_CLOCK_FUTURE_TOLERANCE := 2
## 水晶兵线由主机固定 tick 驱动：开局 5 秒首波，之后每 30 秒一波，第二只延迟 0.5 秒。
const FIRST_MINION_WAVE_TIME := 5.0
const MINION_WAVE_INTERVAL := 30.0
const MINION_WAVE_STAGGER := 0.5
const MINION_SPAWN_X_OFFSET := 3.0 * TILE_SIZE

# 联机
const NET_PORT := 39152

var game_over := false
var nav: NavGrid
var battle_context: BattleContext
var mode := "local"  # local=单机 / host=主机 / client=客户端
var _match_started := false  # 比赛是否已开始（联机时主机需等对手加入）
var _freeze_effects: Array = []  # [{pos, timer, duration, radius}]
## 强化冰冻结束后的权威减速区域与客户端纯视觉区域分开保存。
var _slow_zones: Array[Dictionary] = []
var _slow_effects: Array[Dictionary] = []
var _spell_system: RefCounted
## 纳尔 Spell2：固定模拟延迟到手掌触地才结算；范围框是独立纯表现数据。
var _active_skill_effect_system: RefCounted
var _projectile_system: ProjectileSystem
var _projectiles := {}  # 主机/单机：id -> {pos, target, team, damage, speed, ...}
var _client_projectiles := {}  # 客户端仅保存插值表现

var _elixir: ElixirManager
var _hand: CardHand
var _active_skill_bar: ActiveSkillBar
## ability_id -> {unit, card_id, team, skill, uses_remaining, cooldown_left}；按钮只是这份权威状态的视图。
var _active_skills: Dictionary = {}
var _next_active_ability_id := 1
## 主动请求确认后按 Host 由 input_tick 计算出的 execute_tick 等待；同一 ability_id 只能存在一次。
var _pending_active_skill_activations: Array[Dictionary] = []
## Cast Start 后的通用 Gameplay Impact 队列；与 dual_form 的旧专用前方技能队列分开。
var _pending_active_skill_impacts: Array[Dictionary] = []
var _ai: AIOpponent
var _selected_card := ""
## 选卡后的落点预览：单位以单格格心为目标，点击时使用当前预览而不是重新猜测落点。
var _deployment_preview_pos := Vector2.ZERO
var _deployment_preview_tile := Vector2i(-1, -1)
var _deployment_preview_valid := false
var _deployment_preview_visible := false
## 主机/单机权威卡牌队列：单位、建筑和法术都在 Host 计算的 execute_tick 才真正生效。
var _pending_card_deployments: Array[Dictionary] = []
## 兵线第二只单位的权威延迟队列；不经过手牌 0.5 秒部署队列，也不扣金币。
var _pending_lane_minions: Array[Dictionary] = []
var _battle_elapsed := 0.0
var _next_minion_wave_time := FIRST_MINION_WAVE_TIME
var _minion_waves_enabled := true
# 本次对战选定的 8 张卡组（空表示未指定，随机取）
var _deck: Array = []
## card_id -> active_skills 候选下标。当前每张卡只有一项，界面与联机协议先保留选择能力。
var _active_skill_choices: Dictionary = {}
var _skin_choices: Dictionary = {}
## 主机收到的客户端卡组；用于校验出牌归属及前两槽主动资格。
var _remote_deck: Array = []
var _remote_active_skill_choices: Dictionary = {}
## team -> {deck, hand, queue}。主机同时维护双方；客户端只维护自己的本地镜像。
var _authoritative_card_cycles: Dictionary = {}
var _deck_builder: DeckBuilder
var _match_timer := MATCH_TIME
var _overtime := false
var _timer_label: Label
var _king_player: Tower
var _king_enemy: Tower
var _towers: Array[Tower] = []
var _battle_presentation: BattlePresentation3D
var _art_dev_mode := false
var _art_dev_selection := "training_dummy"
var _art_dev_team := 1
var _art_dev_panel: CanvasLayer
var _art_dev_last_units: Dictionary = {}

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
var _sim_acc := 0.0
## 客户端由快照提供的最后已知主机 Tick，用于生成 input_tick。
var _authoritative_server_tick := 0
## 客户端只估计服务器时钟，不推进任何战斗状态；快照到达时向前校正，间隔内按本地时间补 Tick。
var _estimated_server_tick := 0
var _estimated_server_tick_fraction := 0.0
var _has_estimated_server_tick := false
var _sim_tick_id := 0

func _ready() -> void:
	battle_context = BattleContext.new(self)
	_spell_system = SPELL_SYSTEM_SCRIPT.new(self)
	_freeze_effects = _spell_system.freeze_effects
	_slow_zones = _spell_system.slow_zones
	_slow_effects = _spell_system.slow_effects
	_active_skill_effect_system = ACTIVE_SKILL_EFFECT_SYSTEM_SCRIPT.new(self)
	child_entered_tree.connect(_provide_battle_context)
	_projectile_system = ProjectileSystem.new()
	_projectile_system.setup(battle_context)
	add_child(_projectile_system)
	_projectiles = _projectile_system.projectiles
	_client_projectiles = _projectile_system.client_projectiles
	_snapshot_system = NetworkSnapshotSystem.new(self)
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
	var btn_art_dev := _make_menu_button("美术开发面板")
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
	mode = "local"
	_match_started = true
	_art_dev_mode = true
	_hide_menu()
	_setup_battle_presentation()
	_create_towers()
	_build_nav()
	_art_dev_panel = ART_DEV_PANEL_SCRIPT.new()
	add_child(_art_dev_panel)
	_art_dev_panel.setup(CardDB.all())
	_art_dev_panel.item_selected.connect(func(item_id: String): _art_dev_selection = item_id)
	_art_dev_panel.team_changed.connect(func(team: int): _art_dev_team = team)
	_art_dev_panel.active_skill_requested.connect(_use_art_dev_active_skill)
	_art_dev_panel.clear_requested.connect(_clear_art_dev_units)
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
	cam.position = Vector2(FIELD_W / 2.0, FIELD_H - viewport_height / 2.0)
	cam.rotation = PI
	add_child(cam)
	cam.make_current()

func _setup_player_ui() -> void:
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

func is_net_client() -> bool:
	return mode == "client"

## 固定模拟完成后剩余时间占一个 tick 的比例。所有本地表现共用该值，避免各节点
## 独立累计插值进度，或因 Unit / 3D 代理的 _process 顺序不同而前后跳动。
func get_sim_interpolation_alpha() -> float:
	if mode == "client":
		return 1.0
	return clampf(_sim_acc / SIM_DT, 0.0, 1.0)

func _setup_battle_presentation() -> void:
	if _battle_presentation != null:
		return
	_battle_presentation = BattlePresentation3D.new()
	add_child(_battle_presentation)
	_battle_presentation.setup(Vector2(FIELD_W, FIELD_H), TILE_SIZE)

## 顶部右侧的比赛计时器
func _create_timer_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 32)
	# CR 计时器位于顶部右侧；避开按官方格位上移后的敌方国王塔血条。
	_timer_label.position = Vector2(FIELD_W - 132.0, 8.0)
	layer.add_child(_timer_label)
	_update_timer_label()

func _create_towers() -> void:
	# 参考项目格位：公主塔中心 y=6.5/25.5，国王塔 y=3/29。
	for spec in [
		[0, Vector2(BRIDGE_X_LEFT,  25.5 * TILE_SIZE)],
		[0, Vector2(BRIDGE_X_RIGHT, 25.5 * TILE_SIZE)],
		[1, Vector2(BRIDGE_X_LEFT,  6.5 * TILE_SIZE)],
		[1, Vector2(BRIDGE_X_RIGHT, 6.5 * TILE_SIZE)],
	]:
		var t := Tower.new()
		t.setup(spec[0], PRINCESS_STATS, false)
		t.position = spec[1]
		add_child(t)
		t.z_index = 10
		if _battle_presentation != null:
			_battle_presentation.attach_tower(t, PRINCESS_VISUAL_CONFIG)
		_towers.append(t)
	_king_player = Tower.new()
	_king_player.setup(0, KING_STATS, true)
	_king_player.position = Vector2(9.0 * TILE_SIZE, 29.0 * TILE_SIZE)
	add_child(_king_player)
	_king_player.z_index = 10
	if _battle_presentation != null:
		_battle_presentation.attach_tower(_king_player, NEXUS_VISUAL_CONFIG)
	_towers.append(_king_player)
	_king_enemy = Tower.new()
	_king_enemy.setup(1, KING_STATS, true)
	_king_enemy.position = Vector2(9.0 * TILE_SIZE, 3.0 * TILE_SIZE)
	add_child(_king_enemy)
	_king_enemy.z_index = 10
	if _battle_presentation != null:
		_battle_presentation.attach_tower(_king_enemy, NEXUS_VISUAL_CONFIG)
	_towers.append(_king_enemy)

## 构建导航网格：河道（除两座桥）与所有防御塔为障碍
func _build_nav() -> void:
	nav = NavGrid.new()
	var obstacles := []
	for t in _towers:
		# 塔后最后一行是合法出生区；圆形导航占地只按最大单位半径扩张，
		# 不再额外扩大到合法点上，否则 A* 会先让单位后退以离开实心格。
		obstacles.append([t.position, t.body_radius + NAV_CLEARANCE])
	nav.build(
		Vector2(FIELD_W, FIELD_H),
		RIVER_Y, RIVER_HALF + NAV_CLEARANCE,
		[BRIDGE_X_LEFT, BRIDGE_X_RIGHT],
		BRIDGE_HALF - NAV_CLEARANCE,
		obstacles
	)
	# 记录每个塔的占地格，塔被摧毁时解除阻挡（路径可穿过原塔位）
	for t in _towers:
		t.nav_cells = nav.cells_for_circle(t.position, t.body_radius + NAV_CLEARANCE)

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
	if pointer_pos.x < 0.0 or pointer_pos.x >= FIELD_W or pointer_pos.y < 0.0 or pointer_pos.y >= FIELD_H:
		queue_redraw()
		return
	var my_team := 1 if mode == "client" else 0
	var tile := _world_to_arena_tile(pointer_pos)
	tile.x = clampi(tile.x, 0, ARENA_COLUMNS - 1)
	tile.y = clampi(tile.y, 0, ARENA_ROWS - 1)
	_deployment_preview_tile = tile
	_deployment_preview_pos = _snap_card_position(_selected_card, pointer_pos, my_team)
	_deployment_preview_visible = true
	_deployment_preview_valid = is_card_deploy_position_valid(my_team, _selected_card, _deployment_preview_pos)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if _art_dev_mode:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var art_pos := get_global_mouse_position()
			if art_pos.x >= 0.0 and art_pos.x < FIELD_W and art_pos.y >= 0.0 and art_pos.y < FIELD_H:
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
		add_child(dummy)
		_register_dynamic_building(dummy)
		return
	if not CardDB.has_card(_art_dev_selection):
		return
	pos = _snap_card_position(_art_dev_selection, pos, _art_dev_team)
	if play_card(_art_dev_team, _art_dev_selection, pos, {"immediate": true, "validate_position": false}):
		var unit := _latest_unit_for_card(_art_dev_selection, _art_dev_team)
		if unit != null:
			_art_dev_last_units[_art_dev_selection] = weakref(unit)

func _latest_unit_for_card(card_id: String, p_team: int) -> Unit:
	var latest: Unit = null
	for combatant in get_tree().get_nodes_in_group("combatants"):
		if combatant is Unit and combatant.card_id == card_id and combatant.team == p_team:
			latest = combatant as Unit
	return latest

func _art_dev_selected_unit() -> Unit:
	var candidate_ref = _art_dev_last_units.get(_art_dev_selection)
	var candidate = (candidate_ref as WeakRef).get_ref() if candidate_ref is WeakRef else null
	if candidate is Unit and is_instance_valid(candidate) and candidate.hp > 0.0:
		return candidate as Unit
	return null

## 美术面板不消耗正式主动资格，允许对最后放置的同卡单位反复检查技能演出。
func _use_art_dev_active_skill() -> void:
	var unit := _art_dev_selected_unit()
	if unit == null or not unit.is_deployed() or unit.is_form_transitioning() or unit.is_active_skill_casting():
		return
	var skills := CardDB.active_skills_for(_art_dev_selection)
	if skills.is_empty():
		return
	preview_active_skill(unit, skills[0])

func preview_active_skill(unit: Unit, skill: Dictionary) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	# ArtDev 只绕过玩家命令缓冲；普通主动仍必须经过 Cast Start → Impact → Recovery。
	# dual_form 自己包含变形/前方技能的完整特殊时间轴，不能在这里重复启动一次。
	if String(skill.get("kind", "")) == "dual_form":
		return _active_skill_effect_system.apply(unit, skill)
	var prepared_skill: Dictionary = _active_skill_effect_system.prepare_cast(unit, skill)
	_active_skill_effect_system.apply_cast_start(unit, prepared_skill)
	_begin_configured_active_skill_cast(unit, prepared_skill)
	_queue_active_skill_impact(unit, prepared_skill, maxf(float(prepared_skill.get("impact_delay", 0.0)), 0.0))
	return true

func _register_dynamic_building(unit: Unit) -> void:
	if nav == null or not unit.is_building:
		return
	unit.nav_cells = nav.cells_for_rect(_structure_rect(unit).grow(NAV_CLEARANCE + NAV_GRID_PADDING))
	nav.set_cells_blocked(unit.nav_cells, true)

func _clear_art_dev_units() -> void:
	_art_dev_last_units.clear()
	for combatant in get_tree().get_nodes_in_group("combatants"):
		if not combatant is Unit:
			continue
		var unit := combatant as Unit
		if unit.is_building and not unit.nav_cells.is_empty():
			unblock_nav_cells(unit.nav_cells)
			unit.nav_cells = []
		unit.queue_free()
	_projectile_system.clear_all()
	_freeze_effects.clear()
	_slow_zones.clear()
	_slow_effects.clear()
	_active_skill_effect_system.pending_frontal_stuns.clear()
	_active_skill_effect_system.frontal_effects.clear()
	queue_redraw()

func _world_to_arena_tile(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE_SIZE), floori(pos.y / TILE_SIZE))

func _arena_tile_center(tile: Vector2i) -> Vector2:
	return Vector2(tile) * TILE_SIZE + Vector2.ONE * TILE_SIZE * 0.5

func _snap_to_tile_center(pos: Vector2) -> Vector2:
	var tile := _world_to_arena_tile(pos)
	tile.x = clampi(tile.x, 0, ARENA_COLUMNS - 1)
	tile.y = clampi(tile.y, 0, ARENA_ROWS - 1)
	return _arena_tile_center(tile)

## 单格单位落在格心；偶数格建筑落在格线交点，确保实际覆盖完整的 2x2 格。
func _snap_card_position(card_id: String, pos: Vector2, p_team: int = -1) -> Vector2:
	if not CardDB.has_card(card_id):
		return _snap_to_tile_center(pos)
	var stats: Dictionary = CardDB.get_card(card_id)
	var footprint: Vector2i = stats.get("footprint_tiles", Vector2i.ONE)
	if stats.get("type", "unit") != "building" or footprint == Vector2i.ONE:
		# 单位严格落在鼠标所在格的格心。若该格因河岸、塔或边界不合法，
		# 由预览显示红色并拒绝部署，不能通过微调中心偷偷换到别的位置。
		return _snap_to_tile_center(pos)
	var half_size := Vector2(footprint) * TILE_SIZE * 0.5
	var snapped := Vector2(
		roundf(pos.x / TILE_SIZE) * TILE_SIZE if footprint.x % 2 == 0 else floorf(pos.x / TILE_SIZE) * TILE_SIZE + TILE_SIZE * 0.5,
		roundf(pos.y / TILE_SIZE) * TILE_SIZE if footprint.y % 2 == 0 else floorf(pos.y / TILE_SIZE) * TILE_SIZE + TILE_SIZE * 0.5
	)
	snapped.x = clampf(snapped.x, half_size.x, FIELD_W - half_size.x)
	snapped.y = clampf(snapped.y, half_size.y, FIELD_H - half_size.y)
	return snapped

## 部署区域按 CR 格子掩码判断：法术全场，单位/建筑为己方 15 行及已解锁 pocket。
func _pos_in_deploy_zone(pos: Vector2, p_team: int, is_spell: bool) -> bool:
	if pos.x < 0.0 or pos.x >= FIELD_W or pos.y < 0.0 or pos.y >= FIELD_H:
		return false
	if is_spell:
		return true
	return _tile_in_ground_deploy_zone(_world_to_arena_tile(pos), p_team)

## 防御塔/水晶的部署禁区使用规则占地格，而不是物理圆：公主塔 3x3，水晶 4x4。
## 矩形边界按格子归属取样，避免刚好贴边时误封锁相邻格。
func _arena_tiles_for_rect(rect: Rect2) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var min_tile := _world_to_arena_tile(rect.position + Vector2.ONE * 0.001)
	var max_tile := _world_to_arena_tile(rect.end - Vector2.ONE * 0.001)
	for y in range(min_tile.y, max_tile.y + 1):
		for x in range(min_tile.x, max_tile.x + 1):
			var tile := Vector2i(x, y)
			if tile.x >= 0 and tile.x < ARENA_COLUMNS and tile.y >= 0 and tile.y < ARENA_ROWS:
				tiles.append(tile)
	return tiles

func _tower_deployment_tiles(tower: Tower) -> Array[Vector2i]:
	var footprint := Vector2i(4, 4) if tower.is_king else Vector2i(3, 3)
	var size := Vector2(footprint) * TILE_SIZE
	return _arena_tiles_for_rect(Rect2(tower.global_position - size * 0.5, size))

func _is_tower_deployment_tile_blocked(tile: Vector2i) -> bool:
	for c in get_tree().get_nodes_in_group("combatants"):
		if not c is Tower or not is_instance_valid(c) or c.hp <= 0.0:
			continue
		if tile in _tower_deployment_tiles(c as Tower):
			return true
	return false

func _tile_in_ground_deploy_zone(tile: Vector2i, p_team: int) -> bool:
	if tile.x < 0 or tile.x >= ARENA_COLUMNS or tile.y < 0 or tile.y >= ARENA_ROWS:
		return false
	var local_row := tile.y if p_team == 0 else ARENA_ROWS - 1 - tile.y
	# 自己半场包含靠河第一行的左右角；最后一行只保留国王塔正后方中央 6 格。
	if local_row >= TEAM_0_FIRST_ROW and local_row <= TEAM_0_LAST_ROW:
		if local_row == TEAM_0_LAST_ROW and (tile.x < BACK_CENTER_MIN_COLUMN or tile.x > BACK_CENTER_MAX_COLUMN):
			return false
		return true
	# 摧毁某一路公主塔后，只解锁该路塔后至河岸的 6 行 pocket。
	if local_row < POCKET_FIRST_ROW or local_row > POCKET_LAST_ROW:
		return false
	if local_row == POCKET_LAST_ROW and (tile.x == 0 or tile.x == ARENA_COLUMNS - 1):
		return false
	var is_left := tile.x < ARENA_COLUMNS / 2
	return _pocket_unlocked(p_team, is_left)

func _pocket_unlocked(p_team: int, is_left: bool) -> bool:
	if _towers.size() < 4:
		return false
	var tower_index: int
	if p_team == 0:
		tower_index = 2 if is_left else 3
	else:
		tower_index = 0 if is_left else 1
	return _towers[tower_index].hp <= 0.0

## 占位检查：该位置与存活的塔/建筑卡不重叠才允许部署。
## 兵种调用时使用统一的格心占位半径 0，体型不参与“能否落这格”的判断；
## 兵种生成后的真实半径只交给移动、碰撞和挤压系统处理。
func _can_deploy_at(pos: Vector2, radius: float, is_air: bool = false, footprint: Vector2i = Vector2i.ONE) -> bool:
	var is_rect := footprint != Vector2i.ONE
	if not is_air and not is_rect and not is_ground_position_walkable(pos, radius, null, true, true):
		return false
	for c in get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(c) or c.hp <= 0.0:
			continue
		var is_static: bool = c is Tower or (c is Unit and (c as Unit).is_building)
		if not is_static:
			continue
		if is_rect:
			var deploy_rect := Rect2(pos - Vector2(footprint) * TILE_SIZE * 0.5, Vector2(footprint) * TILE_SIZE)
			if c is Tower:
				# 防御塔/水晶的精确 3x3/4x4 禁区已由格子掩码统一判断。
				continue
			if _structure_intersects_rect(c, deploy_rect):
				return false
		elif c is Tower:
			# 防御塔/水晶的精确禁区已由 _is_tower_deployment_tile_blocked 判断；
			# 这里不能再用圆形半径扩大或缩小部署禁区。
			continue
		elif _structure_deploy_gap_to_circle(c, pos, radius) < STRUCTURE_SEPARATION:
			return false
	return true

## 所有正常卡牌部署入口（玩家、客户端请求、AI）共享同一套区域与占位校验。
func is_card_deploy_position_valid(p_team: int, card_id: String, pos: Vector2) -> bool:
	if not CardDB.has_card(card_id):
		return false
	pos = _snap_card_position(card_id, pos, p_team)
	var stats: Dictionary = CardDB.get_card(card_id)
	var is_spell: bool = stats.get("type", "unit") == "spell"
	var footprint: Vector2i = stats.get("footprint_tiles", Vector2i.ONE)
	if is_spell:
		if not _pos_in_deploy_zone(pos, p_team, true):
			return false
	else:
		var first_tile := Vector2i(roundi(pos.x / TILE_SIZE - float(footprint.x) * 0.5), roundi(pos.y / TILE_SIZE - float(footprint.y) * 0.5))
		for y in range(first_tile.y, first_tile.y + footprint.y):
			for x in range(first_tile.x, first_tile.x + footprint.x):
				var tile := Vector2i(x, y)
				if not _tile_in_ground_deploy_zone(tile, p_team):
					return false
				if _is_tower_deployment_tile_blocked(tile):
					return false
	if is_spell:
		return true
	# 单格兵种共用同一套部署位置。不要因为盖伦等大体型兵种的真实半径较大，
	# 把本来属于部署区的格子判成非法；真实体积从生成后才参与战斗碰撞。
	var placement_radius: float = 0.0 if stats.get("type", "unit") == "unit" else stats.get("radius", 14.0)
	return _can_deploy_at(pos, placement_radius, stats.get("is_air", false), footprint)

func _structure_rect(c: Node2D) -> Rect2:
	return Rect2(c.global_position - Vector2.ONE * c.body_radius, Vector2.ONE * c.body_radius * 2.0)

func _structure_gap_to_circle(c: Node2D, center: Vector2, radius: float) -> float:
	if c.has_method("surface_gap_to_circle"):
		return c.surface_gap_to_circle(center, radius)
	return maxf(0.0, center.distance_to(c.global_position) - c.body_radius - radius)

## 部署禁区与视觉尺寸分离：新单位不能与存活塔的物理圆重叠，
## 但可以放在精灵图透明/外缘区域，才能在塔前近战单位后方落地并参与挤压。
func _structure_deploy_gap_to_circle(c: Node2D, center: Vector2, radius: float) -> float:
	if c.has_method("deployment_gap_to_circle"):
		return c.deployment_gap_to_circle(center, radius)
	return _structure_gap_to_circle(c, center, radius)

func _structure_intersects_rect(c: Node2D, rect: Rect2) -> bool:
	if c is Unit and (c as Unit).is_building:
		return _structure_rect(c).intersects(rect, true)
	var closest := Vector2(
		clampf(c.global_position.x, rect.position.x, rect.end.x),
		clampf(c.global_position.y, rect.position.y, rect.end.y)
	)
	var structure_radius: float = c.deployment_radius if c is Tower else c.body_radius
	return closest.distance_squared_to(c.global_position) < structure_radius * structure_radius

## 按当前单位真实半径检查连续空间，而不只检查 16px 导航格中心。
## 导航格负责全局路线；这里补足塔角/建筑角最多半格的离散误差。
func is_ground_position_walkable(pos: Vector2, mover_radius: float, excluded: Node = null, allow_deploy_edge_center: bool = false, ignore_structures: bool = false) -> bool:
	# 玩家部署允许第一/最后一列、第一/最后一行的格心作为出生点；
	# 单位会从边缘格向场内移动。正常战斗移动仍要求整个圆柱留在场内。
	if allow_deploy_edge_center:
		if pos.x < 0.0 or pos.x > FIELD_W or pos.y < 0.0 or pos.y > FIELD_H:
			return false
	else:
		if pos.x < mover_radius or pos.x > FIELD_W - mover_radius:
			return false
		if pos.y < mover_radius or pos.y > FIELD_H - mover_radius:
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
		if _structure_gap_to_circle(c, pos, mover_radius) < STRUCTURE_SEPARATION:
			return false
	return true

## 连续河道碰撞：河岸按单位真实半径扩张，桥面按真实半径收窄。
## 不读取 A* 的离散格，避免合法部署格因格心取样误判为河道。
func _is_ground_terrain_walkable(pos: Vector2, mover_radius: float) -> bool:
	if absf(pos.y - RIVER_Y) >= RIVER_HALF + mover_radius:
		return true
	var bridge_clearance := maxf(BRIDGE_HALF - mover_radius, 0.0)
	return (
		absf(pos.x - BRIDGE_X_LEFT) <= bridge_clearance
		or absf(pos.x - BRIDGE_X_RIGHT) <= bridge_clearance
	)

## 推进路线能直达时不调用 A*。按连续空间采样，保证直线不会切进圆形塔或建筑。
func is_ground_segment_walkable(from: Vector2, to: Vector2, mover_radius: float, excluded: Node = null) -> bool:
	var distance := from.distance_to(to)
	var samples := maxi(1, ceili(distance / 4.0))
	for i in range(1, samples + 1):
		if not is_ground_position_walkable(from.lerp(to, float(i) / float(samples)), mover_radius, excluded):
			return false
	return true

## 部署前把落点内的可移动单位挤开（建筑不动）
func _push_units_around(pos: Vector2, radius: float) -> void:
	for c in get_tree().get_nodes_in_group("combatants"):
		var u := c as Unit
		if u == null or u.is_building or not is_instance_valid(u) or u.hp <= 0.0:
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
func spawn_summoned(p_team: int, card_id: String, pos: Vector2) -> Unit:
	var stats: Dictionary = CardDB.get_unit_stats(card_id)
	if stats.is_empty():
		push_error("尝试生成不存在的召唤单位：%s" % card_id)
		return null
	if not stats.get("is_air", false):
		pos = _nearest_valid_ground_spawn(pos, stats.get("radius", 14.0), p_team)
	return _spawn_unit(p_team, card_id, pos)

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
	_pending_card_deployments.append({
		"team": p_team,
		"card_id": card_id,
		"pos": pos,
		"execute_tick": resolved_execute_tick,
	})
	return resolved_execute_tick

## 玩家、AI、联机 RPC 与 ArtDevPanel 共用的出牌命令入口。
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
	if bool(options.get("client_request", false)):
		if mode != "client" or immediate or elixir == null or not elixir.can_afford(stats.cost):
			return false
		_rpc_deploy_request.rpc_id(1, card_id, pos, _input_tick_for_new_command())
		if _hand != null:
			_hand.set_card_pending(card_id, true)
		return true
	if elixir != null and not elixir.spend(stats.cost):
		return false
	if immediate:
		var type := String(stats.get("type", "unit"))
		if type == "spell":
			_cast_spell(p_team, card_id, pos)
		else:
			if type == "building":
				_push_units_around(pos, float(stats.get("radius", 14.0)))
			_spawn_unit(p_team, card_id, pos)
		return true
	# 只有命令已完成权威校验、扣费与手牌轮换后才向客户端确认。
	if not _consume_authoritative_card(p_team, card_id):
		# spend 已经成功时理论上不会失败；保留事务式回滚，避免未来扩展插入中间验证后丢费。
		if elixir != null:
			elixir.elixir += float(stats.cost)
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
	var waiting: Array[Dictionary] = []
	var ready: Array[Dictionary] = []
	for deployment in _pending_card_deployments:
		if int(deployment.execute_tick) > _sim_tick_id:
			waiting.append(deployment)
		else:
			ready.append(deployment)
	_pending_card_deployments = waiting
	# 同一个 tick 到期时保持出牌顺序，避免主机结果依赖数组反向删除顺序。
	for deployment in ready:
		_execute_card_deployment(
			int(deployment.team),
			String(deployment.card_id),
			deployment.pos as Vector2
		)

func _execute_card_deployment(p_team: int, card_id: String, pos: Vector2) -> void:
	var stats: Dictionary = CardDB.get_card(card_id)
	var type: String = stats.get("type", "unit")
	var active_slot := _active_card_slot_for_team(p_team, card_id)
	match type:
		"spell":
			_cast_spell(p_team, card_id, pos, active_slot >= 0)
		_:
			if type == "building":
				_push_units_around(pos, stats.get("radius", 14.0))
			_spawn_unit(p_team, card_id, pos, -1.0, active_slot)

func launch_attack(attacker: Node2D, target: Node2D, amount: float, projectile_speed: float, splash_radius: float, knockback: float, projectile_color: Color, effects: Dictionary = {}) -> void:
	_projectile_system.launch(attacker, target, amount, projectile_speed, splash_radius, knockback, projectile_color, effects)

func _tick_projectiles(dt: float) -> void:
	_projectile_system.tick(dt)

func resolve_attack_hit(p_team: int, origin: Vector2, primary: Node2D, amount: float, radius: float, knockback: float, from: Node2D = null, source_position: Vector2 = Vector2(INF, INF), source_form_index: int = -1, effects: Dictionary = {}) -> void:
	if primary == null or not is_instance_valid(primary) or primary.hp <= 0.0:
		return
	if radius <= 0.0:
		var was_alive: bool = primary.hp > 0.0
		var landed: bool = primary.take_damage(amount, from, p_team, source_position)
		if landed:
			_apply_attack_hit_effects(primary, effects)
		if landed and from is Unit and is_instance_valid(from):
			(from as Unit).on_attack_landed(source_form_index)
			if was_alive and primary.hp <= 0.0:
				(from as Unit).on_enemy_killed(primary)
		if landed and knockback > 0.0 and primary is Unit and is_instance_valid(primary) and primary.hp > 0.0:
			(primary as Unit).apply_knockback(origin, knockback)
		return
	var impact_pos := primary.global_position
	var any_landed := false
	for c in get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(c) or c.team == p_team or c.hp <= 0.0:
			continue
		if c.global_position.distance_to(impact_pos) <= radius + c.body_radius:
			var was_alive: bool = c.hp > 0.0
			var landed: bool = c.take_damage(amount, from, p_team, source_position)
			if landed:
				_apply_attack_hit_effects(c, effects)
			any_landed = landed or any_landed
			if landed and was_alive and c.hp <= 0.0 and from is Unit and is_instance_valid(from):
				(from as Unit).on_enemy_killed(c)
			if landed and knockback > 0.0 and c is Unit and is_instance_valid(c) and c.hp > 0.0:
				(c as Unit).apply_knockback(origin, knockback)
	if any_landed and from is Unit and is_instance_valid(from):
		(from as Unit).on_attack_landed(source_form_index)

func _apply_attack_hit_effects(target: Node2D, effects: Dictionary) -> void:
	if target is Unit and is_instance_valid(target) and target.hp > 0.0:
		var blind_charges := maxi(int(effects.get("blind_charges", 0)), 0)
		if blind_charges > 0:
			(target as Unit).apply_blind(blind_charges)

func _cast_spell(p_team: int, card_id: String, pos: Vector2, active_enabled: bool = false) -> bool:
	return _spell_system.cast(p_team, CardDB.get_card(card_id), pos, active_enabled)

func _apply_freeze(pos: Vector2, radius: float, duration: float, p_team: int, slow_duration: float = 0.0, slow_multiplier: float = 1.0) -> void:
	_spell_system.apply_freeze(pos, radius, duration, p_team, slow_duration, slow_multiplier)

func _tick_slow_zones(dt: float) -> void:
	_spell_system.tick(dt)

func _tick_slow_effect_visuals(delta: float) -> void:
	_spell_system.tick_visuals(delta)

func _spawn_unit(team: int, card_id: String, pos: Vector2, deploy_time_override: float = -1.0, active_slot: int = -1) -> Unit:
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
	u.position = pos
	u.setup(team, stats, stats.name)
	if deploy_time_override >= 0.0:
		# 自动兵线不经过卡牌部署读条，生成当帧即可行动；仍标记为新落地单位供碰撞分离使用。
		u._just_deployed = true
	add_child(u)
	if _battle_presentation != null:
		_battle_presentation.attach_unit(u, stats)
	# 建筑卡：把占地格动态注册进导航网格，死亡/到期时由 unit._die 解除
	if nav != null and u.is_building:
		u.nav_cells = nav.cells_for_rect(_structure_rect(u).grow(NAV_CLEARANCE + NAV_GRID_PADDING))
		nav.set_cells_blocked(u.nav_cells, true)
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
		_rpc_spawn_unit.rpc(card_id, team, pos, u.net_id, deploy_time_override, u.active_ability_id, u.active_ability_slot)
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
	for pending in _pending_active_skill_activations:
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
	_pending_active_skill_activations.append({
		"ability_id": ability_id,
		"team": p_team,
		"requester_peer_id": requester_peer_id,
		"execute_tick": execute_tick,
	})
	return true

func _tick_pending_active_skills(_dt: float) -> void:
	var waiting: Array[Dictionary] = []
	var ready: Array[Dictionary] = []
	for pending in _pending_active_skill_activations:
		if int(pending.execute_tick) > _sim_tick_id:
			waiting.append(pending)
		else:
			ready.append(pending)
	_pending_active_skill_activations = waiting
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
	_pending_active_skill_activations = _pending_active_skill_activations.filter(
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
	if source == null or not is_instance_valid(source):
		return
	var hit_damages = skill.get("prepared_hit_damages", [])
	var hit_delays = skill.get("prepared_hit_delays", [])
	if hit_damages is Array and hit_delays is Array and not (hit_damages as Array).is_empty():
		var hit_count := mini((hit_damages as Array).size(), (hit_delays as Array).size())
		for hit_index in hit_count:
			var hit_skill := skill.duplicate(true)
			hit_skill.erase("prepared_hit_damages")
			hit_skill.erase("prepared_hit_delays")
			hit_skill["damage"] = maxf(float((hit_damages as Array)[hit_index]), 0.0)
			_queue_single_active_skill_impact(source, hit_skill, maxf(float((hit_delays as Array)[hit_index]), 0.0))
	else:
		_queue_single_active_skill_impact(source, skill, impact_delay)
	var cast_end_heal := maxf(float(skill.get("cast_end_heal", 0.0)), 0.0)
	if cast_end_heal > 0.0:
		_pending_active_skill_impacts.append({
			"source_ref": weakref(source),
			"skill": {"cast_end_heal": cast_end_heal},
			"time_left": maxf(float(skill.get("cast_duration", 0.0)), 0.0),
			"phase": &"cast_end",
		})

func _queue_single_active_skill_impact(source: Unit, skill: Dictionary, impact_delay: float) -> void:
	if impact_delay <= 0.0:
		_active_skill_effect_system.apply(source, skill)
		return
	_pending_active_skill_impacts.append({
		"source_ref": weakref(source),
		"skill": skill.duplicate(true),
		"time_left": impact_delay,
		"phase": &"impact",
	})

func _tick_pending_active_skill_impacts(dt: float) -> void:
	var waiting: Array[Dictionary] = []
	for pending in _pending_active_skill_impacts:
		var source = (pending.source_ref as WeakRef).get_ref()
		if not source is Unit or not is_instance_valid(source) or source.hp <= 0.0:
			continue
		var unit := source as Unit
		if unit.is_frozen() or unit.is_stunned():
			waiting.append(pending)
			continue
		pending.time_left = maxf(0.0, float(pending.time_left) - dt)
		if float(pending.time_left) > 0.001:
			waiting.append(pending)
			continue
		if StringName(pending.get("phase", &"impact")) == &"cast_end":
			_active_skill_effect_system.apply_cast_end(unit, pending.skill)
		else:
			_active_skill_effect_system.apply(unit, pending.skill)
	_pending_active_skill_impacts = waiting

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
	entry["uses_remaining"] = maxi(int(entry.get("uses_remaining", entry.get("max_uses", 1))) - 1, 0)
	entry["cooldown_left"] = maxf(float(skill.get("cooldown", 0.0)), 0.0)
	_active_skills[ability_id] = entry
	# 先发布 Cast Start，再按 impact_delay 结算效果；AnimationPlayer 完成事件不参与这里。
	var skill_kind := String(skill.get("kind", ""))
	var prepared_skill: Dictionary = skill
	if skill_kind == "dual_form":
		_active_skill_effect_system.apply_cast_start(unit, prepared_skill)
		_active_skill_effect_system.activate_dual_form(unit, prepared_skill)
	else:
		prepared_skill = _active_skill_effect_system.prepare_cast(unit, skill)
		_active_skill_effect_system.apply_cast_start(unit, prepared_skill)
		_begin_configured_active_skill_cast(unit, prepared_skill)
		_queue_active_skill_impact(unit, prepared_skill, maxf(float(prepared_skill.get("impact_delay", 0.0)), 0.0))
	if _active_skill_bar != null:
		_active_skill_bar.set_pending(ability_id, false)
		_sync_active_skill_deployment_readiness()
	if mode == "host":
		_rpc_active_skill_used.rpc(ability_id, int(entry["uses_remaining"]), float(entry["cooldown_left"]))
	return true

func _begin_configured_active_skill_cast(unit: Unit, skill: Dictionary) -> void:
	var cast_duration := maxf(float(skill.get("cast_duration", 0.0)), 0.0)
	var action_name := StringName(skill.get("visual_action", ""))
	if cast_duration <= 0.0 and action_name == &"":
		return
	var cast_locks: Array = skill.get("cast_locks", Unit.DEFAULT_CAST_LOCKS)
	if cast_duration > 0.0:
		unit.begin_active_skill_cast(cast_duration, unit.get_visual_facing_direction(), cast_locks)
	if action_name != &"":
		unit.play_visual_action(action_name, cast_duration)
	if StringName(skill.get("kind", "")) == &"frontal":
		var cast_forward := unit.active_skill_cast_facing
		if cast_forward.length_squared() < 0.001:
			cast_forward = unit.get_visual_facing_direction()
		_active_skill_effect_system.begin_frontal_visual(unit, skill, cast_forward)
	elif StringName(skill.get("kind", "")) == &"forward_area":
		var cast_forward := unit.active_skill_cast_facing
		if cast_forward.length_squared() < 0.001:
			cast_forward = unit.get_visual_facing_direction()
		_active_skill_effect_system.begin_forward_area_visual(unit, skill, cast_forward)

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
	while _battle_elapsed + 0.001 >= _next_minion_wave_time:
		_spawn_minion_wave()
		_next_minion_wave_time += MINION_WAVE_INTERVAL

func _spawn_minion_wave() -> void:
	var second_card := "siege_minion" if _is_double_elixir_phase() else "ranged_minion"
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
	var x := FIELD_W * 0.5 + (-MINION_SPAWN_X_OFFSET if lane == 0 else MINION_SPAWN_X_OFFSET)
	var y := 29.0 * TILE_SIZE if team == 0 else 3.0 * TILE_SIZE
	var stats: Dictionary = CardDB.get_card(card_id)
	var pos := _nearest_valid_ground_spawn(Vector2(x, y), float(stats.radius), team)
	return _spawn_unit(team, card_id, pos, 0.0)

func _enemy_lane_tower_destroyed(team: int, lane: int) -> bool:
	# _towers 顺序：蓝左、蓝右、红左、红右。己方对应路只看敌方同侧公主塔。
	var enemy_team := 1 - team
	var tower_index := enemy_team * 2 + lane
	return tower_index >= 0 and tower_index < 4 and _towers[tower_index].hp <= 0.0

func _is_double_elixir_phase() -> bool:
	# 第 120 秒起即为双倍金币；加时仍沿用炮车编成。
	return _battle_elapsed + 0.001 >= MATCH_TIME - DOUBLE_ELIXIR_TIME

## 解除导航网格阻挡格（建筑卡死亡 / 塔被摧毁时调用）
func unblock_nav_cells(cells: Array) -> void:
	if nav == null or cells.is_empty():
		return
	nav.set_cells_blocked(cells, false)

## 河道本身是硬障碍，A* 会自然选择总代价最低的桥。
## 不再拼接“桥入口 -> 桥出口”三段路径：单位踏上桥后重算时，旧实现会先把它拉回入口。
func find_ground_path(from: Vector2, goal: Vector2, _target: Node2D, _mover_radius: float = NAV_CLEARANCE) -> PackedVector2Array:
	if nav == null:
		return PackedVector2Array()
	return nav.find_path(from, goal)

## 单位死亡回调（由 unit._die 调用）：主机可靠广播死亡表现并立即清理映射。
func on_unit_died(id: int) -> void:
	_net_units.erase(id)
	if mode == "host":
		_rpc_unit_died.rpc(id)

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
	# 已存在的施法时间线先推进；本 Tick 新执行的命令从当前 Tick 边界开始计时。
	_tick_active_skill_cooldowns(dt)
	_tick_pending_active_skill_impacts(dt)
	_active_skill_effect_system.tick_pending(dt)
	_tick_pending_card_deployments(dt)
	_tick_pending_active_skills(dt)
	_tick_slow_zones(dt)
	if not _art_dev_mode and _minion_waves_enabled:
		_tick_minion_waves(dt)
	for c in get_tree().get_nodes_in_group("combatants"):
		if c.has_method("sim_tick"):
			c.sim_tick(dt)
	_sync_active_skill_deployment_readiness()
	_apply_unit_movement(dt)
	_resolve_unit_collisions(dt)
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
			_active_skill_effect_system.activate_dual_form(auto_gnar, CardDB.get_card("gnar").active_skill)
			_auto_gnar_revert_unit = auto_gnar
			_auto_gnar_revert_timer = 2.4

## 所有单位先计算移动意图，再统一做局部避让并应用，避免节点遍历顺序影响结果。
func _apply_unit_movement(dt: float) -> void:
	var units := _active_mobile_units()
	var velocities := {}
	for unit in units:
		velocities[_unit_order_key(unit)] = _adjust_unit_velocity(unit, units, dt)
	for unit in units:
		var velocity: Vector2 = velocities[_unit_order_key(unit)]
		if velocity.length_squared() < 0.001:
			unit.on_movement_applied(0.0, dt)
			continue
		var old_pos := unit.global_position
		var applied := _try_apply_velocity(unit, velocity, dt)
		if not applied and not velocity.is_equal_approx(unit._move_intent):
			# 先去掉局部避让分量，尝试原始路径速度。
			applied = _try_apply_velocity(unit, unit._move_intent, dt)
		if not applied:
			# 桥角/塔角的斜向步进可能同时跨入障碍。沿障碍切线尝试单轴分量，
			# 让单位先滑到桥口再向前，而不是在角点原地踏步。
			applied = _try_slide_velocity(unit, velocity, dt)
		if applied:
			unit.on_movement_applied(unit.global_position.distance_to(old_pos), dt)
		else:
			unit.cancel_charge()
			unit.on_movement_applied(0.0, dt)

func _try_apply_velocity(unit: Unit, velocity: Vector2, dt: float) -> bool:
	if velocity.length_squared() < 0.001:
		return false
	# 部署允许单位从边缘格心出生；先把候选位置收回完整圆柱可活动的场内，
	# 再做塔/河岸碰撞检查，避免边缘格心因为半径超出几像素而永远无法向内移动。
	var raw_next_pos := unit.global_position + velocity * dt
	var next_pos := Vector2(
			clampf(raw_next_pos.x, unit.body_radius, FIELD_W - unit.body_radius),
			clampf(raw_next_pos.y, unit.body_radius, FIELD_H - unit.body_radius)
		)
	if not unit.is_walkable_at(next_pos):
		if _try_leave_deployment_river_overlap(unit, next_pos):
			unit.global_position = next_pos
			return true
		return _try_bridge_corner_tangent(unit, velocity, dt)
	unit.global_position = Vector2(
		clampf(next_pos.x, unit.body_radius, FIELD_W - unit.body_radius),
		clampf(next_pos.y, unit.body_radius, FIELD_H - unit.body_radius)
	)
	return true

## 大体型单位允许在靠河第一部署排的格心出生，落点可能暂时压过河岸几像素。
## 若这一步正沿远离河道的方向移动，允许它先退出这段部署重叠，再恢复标准地形碰撞。
func _try_leave_deployment_river_overlap(unit: Unit, candidate: Vector2) -> bool:
	if unit.is_air:
		return false
	var clearance := RIVER_HALF + unit.body_radius
	var current_gap := absf(unit.global_position.y - RIVER_Y)
	var candidate_gap := absf(candidate.y - RIVER_Y)
	if current_gap >= clearance or candidate_gap <= current_gap + 0.001:
		return false
	if _is_ground_terrain_walkable(candidate, unit.body_radius):
		return false
	for c in get_tree().get_nodes_in_group("combatants"):
		if c == unit or not is_instance_valid(c) or c.hp <= 0.0:
			continue
		var is_structure: bool = c is Tower or (c is Unit and (c as Unit).is_building)
		if is_structure and _structure_gap_to_circle(c, candidate, unit.body_radius) < STRUCTURE_SEPARATION:
			return false
	return true

## 圆柱碰到桥面与河岸的直角交界时，把剩余速度投影到河岸切线。
## 这样单位会以原速度横向对准桥口，再连续进入桥面，不会先原地停一帧才缓慢挪动。
func _try_bridge_corner_tangent(unit: Unit, velocity: Vector2, dt: float) -> bool:
	if unit.is_air or velocity.length_squared() < 0.001:
		return false
	var shore_clearance := RIVER_HALF + unit.body_radius
	var distance_to_river := absf(unit.global_position.y - RIVER_Y)
	var movement_step := velocity.length() * dt
	if distance_to_river > shore_clearance + movement_step + BRIDGE_EDGE_MARGIN:
		return false
	var moving_toward_river := (
		(unit.global_position.y > RIVER_Y and velocity.y < 0.0)
		or (unit.global_position.y < RIVER_Y and velocity.y > 0.0)
	)
	if not moving_toward_river and distance_to_river >= shore_clearance:
		return false
	var bridge_x := BRIDGE_X_LEFT
	if absf(unit.global_position.x - BRIDGE_X_RIGHT) < absf(unit.global_position.x - BRIDGE_X_LEFT):
		bridge_x = BRIDGE_X_RIGHT
	var safe_half := maxf(BRIDGE_HALF - unit.body_radius - BRIDGE_EDGE_MARGIN, 0.0)
	var safe_min_x := bridge_x - safe_half
	var safe_max_x := bridge_x + safe_half
	var candidate := unit.global_position + velocity * dt
	if unit.global_position.x < safe_min_x:
		candidate = Vector2(minf(unit.global_position.x + movement_step, safe_min_x), unit.global_position.y)
	elif unit.global_position.x > safe_max_x:
		candidate = Vector2(maxf(unit.global_position.x - movement_step, safe_max_x), unit.global_position.y)
	else:
		candidate.x = clampf(candidate.x, safe_min_x, safe_max_x)
	if not unit.is_walkable_at(candidate):
		return false
	unit.global_position = Vector2(
		clampf(candidate.x, unit.body_radius, FIELD_W - unit.body_radius),
		clampf(candidate.y, unit.body_radius, FIELD_H - unit.body_radius)
	)
	return true

func _try_slide_velocity(unit: Unit, velocity: Vector2, dt: float) -> bool:
	var primary := Vector2(velocity.x, 0.0)
	var secondary := Vector2(0.0, velocity.y)
	if absf(velocity.y) > absf(velocity.x):
		primary = Vector2(0.0, velocity.y)
		secondary = Vector2(velocity.x, 0.0)
	return _try_apply_velocity(unit, primary, dt) or _try_apply_velocity(unit, secondary, dt)

func _active_mobile_units() -> Array[Unit]:
	var units: Array[Unit] = []
	for c in get_tree().get_nodes_in_group("combatants"):
		if c is Unit:
			var unit := c as Unit
			if unit.hp > 0.0 and not unit.is_building:
				units.append(unit)
	units.sort_custom(func(a: Unit, b: Unit): return _unit_order_key(a) < _unit_order_key(b))
	return units

func _adjust_unit_velocity(unit: Unit, units: Array[Unit], dt: float) -> Vector2:
	var desired: Vector2 = unit._move_intent
	if desired.length_squared() < 0.001:
		unit._steering_velocity = Vector2.ZERO
		return Vector2.ZERO
	if unit._forced_movement:
		return desired
	var direction := desired.normalized()
	var desired_speed := desired.length()
	var forward_speed := desired_speed
	var side := Vector2(-direction.y, direction.x)
	var steering := Vector2.ZERO
	for other in units:
		if other == unit or other.is_air != unit.is_air or other.team != unit.team:
			continue
		var relative := other.global_position - unit.global_position
		var distance := relative.length()
		var clearance := unit.body_radius + other.body_radius + 2.0
		var neighbor_range := clearance + AVOID_NEIGHBOR_PADDING
		if distance >= neighbor_range:
			continue
		var proximity := 1.0 - distance / neighbor_range
		var away: Vector2
		if distance > 0.01:
			away = -relative / distance
		else:
			away = side * (-1.0 if _unit_order_key(unit) < _unit_order_key(other) else 1.0)
		# 分离力从邻域边缘平滑增大，不等到真正穿透才处理。
		steering += away * desired_speed * 0.55 * proximity
		var forward := relative.dot(direction)
		if forward <= 0.0 or forward > AVOID_LOOKAHEAD + clearance:
			continue
		var signed_side := relative.dot(side)
		var side_distance := absf(signed_side)
		if side_distance >= clearance + 8.0:
			continue
		# 预测到前方走廊被占用时，双方按稳定 id 选择相反侧，形成互惠避让；
		# 已有侧向偏移时沿当前空隙继续，不会左右反复切换。
		var side_sign := signf(-signed_side)
		if side_distance < 1.0:
			side_sign = -1.0 if _unit_order_key(unit) < _unit_order_key(other) else 1.0
		var corridor := 1.0 - side_distance / (clearance + 8.0)
		var ahead_weight := 1.0 - forward / (AVOID_LOOKAHEAD + clearance)
		var avoid_weight := maxf(corridor * ahead_weight, 0.0)
		steering += side * side_sign * desired_speed * 0.45 * avoid_weight
		forward_speed = minf(forward_speed, lerpf(desired_speed, desired_speed * AVOID_MIN_FORWARD_RATIO, avoid_weight))
	var target_velocity := direction * maxf(forward_speed, desired_speed * AVOID_MIN_FORWARD_RATIO) + steering
	# 避让不能把单位推成倒车；总速度也不超过卡牌本身速度。
	var forward_component := target_velocity.dot(direction)
	var min_forward := desired_speed * AVOID_MIN_FORWARD_RATIO
	if forward_component < min_forward:
		target_velocity += direction * (min_forward - forward_component)
	target_velocity = target_velocity.limit_length(desired_speed)
	# 对避让速度做低通滤波，侧移表现为弧线而不是突然折线。
	if unit._steering_velocity.length_squared() < 0.001:
		unit._steering_velocity = target_velocity
	else:
		unit._steering_velocity = unit._steering_velocity.lerp(target_velocity, minf(dt * 8.0, 1.0))
	return unit._steering_velocity

## 穿透修正采用常见的 slop + 百分比校正：轻微接触不处理，明显重叠逐步
## 消除且单 tick 有上限。它只修复几何穿透，不承担移动避让或击退玩法。
func _resolve_unit_collisions(_dt: float) -> void:
	var units := _active_mobile_units()
	for i in range(units.size()):
		var a := units[i]
		if not is_instance_valid(a) or a.hp <= 0.0:
			continue
		for j in range(i + 1, units.size()):
			var b := units[j]
			if not is_instance_valid(b) or b.hp <= 0.0 or a.is_air != b.is_air:
				continue
			_resolve_unit_pair(a, b, a._just_deployed or b._just_deployed)
	for unit in units:
		unit._just_deployed = false

func _unit_order_key(unit: Unit) -> int:
	return unit.net_id if unit.net_id >= 0 else unit.get_instance_id()

func _resolve_unit_pair(a: Unit, b: Unit, landing_contact: bool = false) -> void:
	var delta_pos := a.global_position - b.global_position
	var distance := delta_pos.length()
	var min_distance := a.body_radius + b.body_radius
	if distance >= min_distance:
		return
	var direction: Vector2
	if distance <= 0.01:
		if landing_contact:
			direction = _landing_overlap_direction(a, b)
		else:
			# 完全重叠时使用稳定方向拆分；桥区优先纵向，避免被挤进河道。
			direction = Vector2.UP if absf(a.global_position.y - RIVER_Y) < 70.0 else Vector2.RIGHT
	else:
		direction = delta_pos / distance
	if absf((a.global_position.y + b.global_position.y) * 0.5 - RIVER_Y) < 70.0:
		direction.x *= 0.15
	var penetration := maxf(min_distance - distance - COLLISION_SLOP, 0.0)
	if penetration <= 0.0:
		return
	var correction_percent := LANDING_CORRECTION_PERCENT if landing_contact else COLLISION_CORRECTION_PERCENT
	var max_correction := LANDING_MAX_CORRECTION if landing_contact else COLLISION_MAX_CORRECTION
	var overlap := minf(penetration * correction_percent, max_correction)
	var mass_a := a.mass
	var mass_b := b.mass
	var move_a := direction * overlap * (mass_b / (mass_a + mass_b))
	var move_b := -direction * overlap * (mass_a / (mass_a + mass_b))
	var next_a := a.global_position + move_a
	var next_b := b.global_position + move_b
	var can_move_a := a.is_walkable_at(next_a)
	var can_move_b := b.is_walkable_at(next_b)
	if can_move_a and can_move_b:
		a.global_position = Vector2(
			clampf(next_a.x, a.body_radius, FIELD_W - a.body_radius),
			clampf(next_a.y, a.body_radius, FIELD_H - a.body_radius)
		)
		b.global_position = Vector2(
			clampf(next_b.x, b.body_radius, FIELD_W - b.body_radius),
			clampf(next_b.y, b.body_radius, FIELD_H - b.body_radius)
		)
	elif can_move_a:
		var full_next_a := a.global_position + direction * overlap
		if a.is_walkable_at(full_next_a):
			a.global_position = full_next_a
	elif can_move_b:
		var full_next_b := b.global_position - direction * overlap
		if b.is_walkable_at(full_next_b):
			b.global_position = full_next_b

## 两个单位完全重合落地时没有几何法线。如果附近有塔/建筑，优先把原有单位
## 沿远离该结构的方向挤开，支持“在塔和近战单位之间下兵”的细节交互。
func _landing_overlap_direction(a: Unit, b: Unit) -> Vector2:
	var landing := a if a._just_deployed else b
	var existing := b if landing == a else a
	var nearest_structure: Node2D = null
	var nearest_distance := INF
	for c in get_tree().get_nodes_in_group("combatants"):
		if c == a or c == b or not is_instance_valid(c) or c.hp <= 0.0:
			continue
		if not (c is Tower or (c is Unit and (c as Unit).is_building)):
			continue
		var dist: float = c.global_position.distance_squared_to(landing.global_position)
		if dist < nearest_distance:
			nearest_distance = dist
			nearest_structure = c
	var existing_direction := Vector2.ZERO
	if nearest_structure != null:
		existing_direction = nearest_structure.global_position.direction_to(landing.global_position)
	if existing_direction.length_squared() < 0.001:
		existing_direction = Vector2.UP if existing.team == 1 else Vector2.DOWN
	# direction 是 b -> a：若 a 是原有单位则直接返回其应移动方向。
	return existing_direction if existing == a else -existing_direction

func _process(delta: float) -> void:
	_sync_active_skill_deployment_readiness()
	# 客户端：只更新冰冻视觉与重绘，逻辑状态全靠主机快照
	if mode == "client":
		_advance_estimated_server_tick(delta)
		_projectile_system.tick_client_interpolation(delta)
		for fe in _freeze_effects:
			fe.timer -= delta
		_freeze_effects = _freeze_effects.filter(func(fe): return fe.timer > 0.0)
		_tick_slow_effect_visuals(delta)
		_active_skill_effect_system.tick_visuals(delta)
		queue_redraw()
		return
	if _art_dev_mode:
		for fe in _freeze_effects:
			fe.timer -= delta
		_freeze_effects = _freeze_effects.filter(func(fe): return fe.timer > 0.0)
		_tick_slow_effect_visuals(delta)
		_active_skill_effect_system.tick_visuals(delta)
		queue_redraw()
		_sim_acc += delta
		while _sim_acc >= SIM_DT:
			_sim_acc -= SIM_DT
			_sim_step(SIM_DT)
		return
	if not _match_started or game_over:
		return
	# 更新冰冻视觉效果
	for fe in _freeze_effects:
		fe.timer -= delta
	_freeze_effects = _freeze_effects.filter(func(fe): return fe.timer > 0.0)
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
	_sim_acc += delta
	while _sim_acc >= SIM_DT:
		_sim_acc -= SIM_DT
		_sim_step(SIM_DT)
	# 比赛计时与胜负判断
	_match_timer -= delta
	_update_timer_label()
	_update_elixir_rate()
	# 国王塔被毁立即结束
	if _king_enemy.hp <= 0.0:
		_end_game("胜利！敌方国王塔已被摧毁")
		return
	if _king_player.hp <= 0.0:
		_end_game("失败……我方国王塔被摧毁")
		return
	var my_lost := _count_destroyed_towers(0)
	var enemy_lost := _count_destroyed_towers(1)
	# 加时赛：任何一方破塔数领先立即获胜
	if _overtime and my_lost != enemy_lost:
		_end_game_by_towers(my_lost, enemy_lost)
		return
	if _match_timer <= 0.0:
		if not _overtime:
			if my_lost != enemy_lost:
				# 正赛结束，破塔多者胜
				_end_game_by_towers(my_lost, enemy_lost)
			else:
				# 战平进入加时
				_overtime = true
				_match_timer = OVERTIME_TIME
				_update_timer_label()
		else:
			# 加时结束仍平 → 平局
			if my_lost != enemy_lost:
				_end_game_by_towers(my_lost, enemy_lost)
			else:
				_end_game("平局！双方战成 %d:%d" % [enemy_lost, my_lost])

## 某方被摧毁的塔数量
func _count_destroyed_towers(p_team: int) -> int:
	var count := 0
	for t in _towers:
		if t.team == p_team and t.hp <= 0.0:
			count += 1
	return count

## 按破塔数结算（enemy_lost 多 = 玩家胜）
func _end_game_by_towers(my_lost: int, enemy_lost: int) -> void:
	if enemy_lost > my_lost:
		_end_game("胜利！破塔 %d:%d" % [enemy_lost, my_lost])
	else:
		_end_game("失败……破塔 %d:%d" % [enemy_lost, my_lost])

func _update_timer_label() -> void:
	if _timer_label == null:
		return
	var t := maxi(int(_match_timer), 0)
	var text := "%d:%02d" % [t / 60, t % 60]
	if _overtime:
		text += " 加时"
	_timer_label.text = text

## 金币回复倍率：常规时间最后一分钟双倍、加时三倍（对齐皇室战争节奏）
func _update_elixir_rate() -> void:
	var mult := 3.0 if _overtime else (2.0 if _match_timer <= DOUBLE_ELIXIR_TIME else 1.0)
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
func _rpc_spawn_unit(card_id: String, p_team: int, pos: Vector2, net_id: int, deploy_time_override: float = -1.0, active_ability_id: int = -1, active_ability_slot: int = -1) -> void:
	if mode != "client":
		return
	var stats: Dictionary = CardDB.get_unit_stats(card_id)
	if deploy_time_override >= 0.0:
		stats = stats.duplicate()
		stats["deploy_time"] = deploy_time_override
	var u := Unit.new()
	u.card_id = card_id
	u.position = pos
	u.setup(p_team, stats, stats.name)
	if deploy_time_override >= 0.0:
		u._just_deployed = true
	u.net_id = net_id
	u.active_ability_id = active_ability_id
	u.active_ability_slot = active_ability_slot
	u.net_target_pos = pos
	add_child(u)
	if _battle_presentation != null:
		_battle_presentation.attach_unit(u, stats)
	if nav != null and u.is_building:
		u.nav_cells = nav.cells_for_rect(_structure_rect(u).grow(NAV_CLEARANCE + NAV_GRID_PADDING))
		nav.set_cells_blocked(u.nav_cells, true)
	_client_units[net_id] = u
	if active_ability_id >= 0:
		_register_active_skill(u, card_id, p_team)
	if _auto_test:
		print("[测试] 客户端收到单位生成: ", card_id, " net_id=", net_id)

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

## 主机 → 客户端：可靠触发一次塔/水晶受击闪白。
@rpc("authority", "call_remote", "reliable")
func _rpc_tower_hit(index: int) -> void:
	if mode != "client":
		return
	if index >= 0 and index < _towers.size():
		_towers[index].notify_visual_hit()

## 主机 → 客户端：可靠触发死亡动作。逻辑单位立即释放，3D 代理独立播完动作。
@rpc("authority", "call_remote", "reliable")
func _rpc_unit_died(net_id: int) -> void:
	if mode != "client":
		return
	var u: Unit = _client_units.get(net_id)
	if u == null or not is_instance_valid(u):
		_client_units.erase(net_id)
		return
	if u.is_building and not u.nav_cells.is_empty():
		unblock_nav_cells(u.nav_cells)
		u.nav_cells = []
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
	_freeze_effects.append({"pos": pos, "timer": duration, "duration": duration, "radius": radius})
	if slow_duration > 0.0:
		_slow_effects.append({"pos": pos, "radius": radius, "delay": duration, "timer": slow_duration, "duration": slow_duration})

## 主机 → 客户端：定向技能蓄力范围。客户端只画表现，伤害与状态仍由主机快照体现。
@rpc("authority", "call_remote", "reliable")
func _rpc_frontal_skill_fx(net_id: int, pos: Vector2, forward: Vector2, source_radius: float, length: float, width: float, duration: float, p_team: int, shape: String = "rectangle", near_width: float = 0.0, far_width: float = 0.0, arc_degrees: float = 0.0, projectile_count: int = 0, center_ratio: float = 0.0, center_width: float = 0.0, fan_inner_arc: bool = false) -> void:
	if mode != "client":
		return
	_active_skill_effect_system.frontal_effects.append({
		"source_ref": null,
		"net_id": net_id,
		"fixed_position": shape in ["target_circle", "shockwave"],
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
	_end_game(text)

## 主机端：组装并发送快照
func _send_snapshot() -> void:
	_snapshot_system.send()

func _draw() -> void:
	# 完整 720x1400 地图（含手牌区后方场外风景）；3D 表现视口继续透明叠加。
	draw_texture(ARENA_BACKGROUND_TEXTURE, Vector2.ZERO)
	# 选中卡牌时高亮可部署区域
	if _selected_card != "":
		var sel_stats: Dictionary = CardDB.get_card(_selected_card)
		var is_spell_sel: bool = sel_stats.get("type", "unit") == "spell"
		if is_spell_sel:
			# 法术：高亮全场
			draw_rect(Rect2(0, 0, FIELD_W, FIELD_H), Color(0.40, 0.70, 1.00, 0.08))
		else:
			var deploy_team := 1 if mode == "client" else 0
			for row in ARENA_ROWS:
				for column in ARENA_COLUMNS:
					var tile := Vector2i(column, row)
					if _tile_in_ground_deploy_zone(tile, deploy_team):
						draw_rect(Rect2(Vector2(tile) * TILE_SIZE, Vector2.ONE * TILE_SIZE), Color(0.40, 0.70, 1.00, 0.15))
		_draw_deployment_preview(sel_stats)
	# 冰冻区域效果
	for fe in _freeze_effects:
		var alpha: float = (fe.timer / fe.duration) * 0.25
		draw_circle(fe.pos, fe.radius, Color(0.40, 0.70, 1.00, alpha))
		draw_circle(fe.pos, fe.radius, Color(0.60, 0.85, 1.00, alpha * 0.5), false, 2.0)
	# 强化冰冻的减速阶段在冻结结束后才显示，和权威区域使用相同半径与时长。
	for effect in _slow_effects:
		if float(effect.delay) > 0.0:
			continue
		var slow_alpha: float = clampf(float(effect.timer) / maxf(float(effect.duration), 0.001), 0.0, 1.0)
		draw_circle(effect.pos, effect.radius, Color(0.20, 0.48, 0.92, 0.12 * slow_alpha))
		draw_arc(effect.pos, effect.radius, 0.0, TAU, 48, Color(0.38, 0.70, 1.0, 0.72 * slow_alpha), 3.0, true)
	# 纳尔 Spell2 使用三边矩形：两条侧边加远端宽边，靠纳尔的近端宽边刻意留空。
	for effect in _active_skill_effect_system.frontal_effects:
		_draw_frontal_skill_effect(effect)

func _draw_frontal_skill_effect(effect: Dictionary) -> void:
	var source = _active_skill_effect_system.effect_source(effect)
	var center: Vector2 = effect.get("pos", Vector2.ZERO)
	var forward: Vector2 = effect.get("forward", Vector2.UP)
	var source_radius := float(effect.get("source_radius", 0.0))
	if not bool(effect.get("fixed_position", false)) and source is Unit and is_instance_valid(source):
		center = (source as Unit).get_visual_screen_position()
		source_radius = (source as Unit).body_radius
	if forward.length_squared() < 0.001:
		return
	forward = forward.normalized()
	var side := Vector2(-forward.y, forward.x)
	var near_center := center + forward * source_radius
	var length := maxf(float(effect.get("length", 0.0)), 0.0)
	var far_center := near_center + forward * length
	var remaining_ratio := clampf(float(effect.get("timer", 0.0)) / maxf(float(effect.get("duration", 0.0)), 0.001), 0.0, 1.0)
	var progress := 1.0 - remaining_ratio
	var line_color := Color(0.28, 0.68, 1.0, 0.9) if int(effect.get("team", 0)) == 0 else Color(1.0, 0.34, 0.24, 0.9)
	var fill_color := Color(line_color.r, line_color.g, line_color.b, 0.10 + 0.06 * remaining_ratio)
	var shape := StringName(effect.get("shape", "rectangle"))
	if shape == &"target_circle":
		var radius := length
		# 星落/天瀑的落点需要清晰可辨，但不能用大面积色块遮住圈内人物。
		# 填充最高仅 6% 不透明度，边缘单独保留适中的亮度用于读范围。
		var area_fill_alpha := 0.025 + 0.035 * remaining_ratio
		var area_line_color := Color(line_color.r, line_color.g, line_color.b, 0.52)
		draw_circle(center, radius, Color(line_color.r, line_color.g, line_color.b, area_fill_alpha))
		draw_arc(center, radius, 0.0, TAU, 64, area_line_color, 3.0, true)
		var star_height := radius * lerpf(2.2, 0.0, progress)
		var star_pos := center + Vector2(0.0, -star_height)
		draw_circle(star_pos, 9.0 + 5.0 * progress, Color(1.0, 0.90, 0.48, 0.96))
		draw_line(star_pos + Vector2(0.0, -34.0), star_pos, Color(0.72, 0.90, 1.0, 0.65), 5.0, true)
		return
	if shape == &"shockwave":
		var wave_radius := lerpf(maxf(float(effect.get("width", 0.0)), 0.0), length, progress)
		var wave_alpha := 0.92 * remaining_ratio
		draw_arc(center, wave_radius, 0.0, TAU, 96, Color(0.72, 0.90, 1.0, wave_alpha), 7.0, true)
		draw_arc(center, wave_radius + 7.0, 0.0, TAU, 96, Color(1.0, 0.84, 0.42, wave_alpha * 0.65), 3.0, true)
		return
	if shape == &"fan":
		var half_angle := deg_to_rad(float(effect.get("arc_degrees", 0.0)) * 0.5)
		var center_angle := forward.angle()
		var fan_inner_arc := bool(effect.get("fan_inner_arc", false))
		if fan_inner_arc:
			var inner_radius := source_radius
			var outer_radius := inner_radius + length
			var inner_left := center - side * inner_radius
			var inner_right := center + side * inner_radius
			var outer_left := center + Vector2.from_angle(center_angle - half_angle) * outer_radius
			var outer_right := center + Vector2.from_angle(center_angle + half_angle) * outer_radius
			var ring_points := PackedVector2Array([inner_left])
			for index in range(17):
				var outer_angle := lerpf(center_angle - half_angle, center_angle + half_angle, float(index) / 16.0)
				ring_points.append(center + Vector2.from_angle(outer_angle) * outer_radius)
			ring_points.append(inner_right)
			for index in range(16, -1, -1):
				var inner_angle := lerpf(center_angle - PI * 0.5, center_angle + PI * 0.5, float(index) / 16.0)
				ring_points.append(center + Vector2.from_angle(inner_angle) * inner_radius)
			draw_colored_polygon(ring_points, fill_color)
			draw_arc(center, outer_radius, center_angle - half_angle, center_angle + half_angle, 32, line_color, 3.0, true)
			draw_line(inner_left, outer_left, line_color, 2.0, true)
			draw_line(inner_right, outer_right, line_color, 2.0, true)
			draw_arc(center, inner_radius, center_angle - PI * 0.5, center_angle + PI * 0.5, 24, line_color, 2.0, true)
			var arrow_count := maxi(int(effect.get("projectile_count", 0)), 0)
			var arrow_distance := length * clampf(progress * 1.25, 0.0, 1.0)
			for index in range(arrow_count):
				var ratio := 0.5 if arrow_count == 1 else float(index) / float(arrow_count - 1)
				var arrow_angle := lerpf(center_angle - half_angle * 0.92, center_angle + half_angle * 0.92, ratio)
				var arrow_direction := Vector2.from_angle(arrow_angle)
				var arrow_pos := center + arrow_direction * (inner_radius + arrow_distance)
				draw_line(arrow_pos - arrow_direction * 10.0, arrow_pos + arrow_direction * 5.0, Color(0.78, 0.94, 1.0, 0.95), 2.0, true)
			return
		var center_width := maxf(float(effect.get("center_width", 0.0)), 0.0)
		var center_half_width := center_width * 0.5
		var sector_near_left := near_center - side * center_half_width if center_width > 0.0 else near_center
		var sector_near_right := near_center + side * center_half_width if center_width > 0.0 else near_center
		var left_arc := near_center + Vector2.from_angle(center_angle - half_angle) * length
		var right_arc := near_center + Vector2.from_angle(center_angle + half_angle) * length
		var points := PackedVector2Array([sector_near_left])
		for index in range(17):
			var angle := lerpf(center_angle - half_angle, center_angle + half_angle, float(index) / 16.0)
			points.append(near_center + Vector2.from_angle(angle) * length)
		points.append(sector_near_right)
		draw_colored_polygon(points, fill_color)
		draw_arc(near_center, length, center_angle - half_angle, center_angle + half_angle, 32, line_color, 3.0, true)
		draw_line(sector_near_left, left_arc, line_color, 2.0, true)
		draw_line(sector_near_right, right_arc, line_color, 2.0, true)
		var center_ratio := clampf(float(effect.get("center_ratio", 0.0)), 0.0, 1.0)
		if center_width > 0.0:
			var center_points := PackedVector2Array([
				sector_near_left,
				far_center - side * center_half_width,
				far_center + side * center_half_width,
				sector_near_right,
			])
			var center_fill := Color(0.54, 0.94, 1.0, 0.22 + 0.12 * progress)
			draw_colored_polygon(center_points, center_fill)
			draw_line(center_points[0], center_points[1], Color(line_color.r, line_color.g, line_color.b, 0.72), 1.5, true)
			draw_line(center_points[3], center_points[2], Color(line_color.r, line_color.g, line_color.b, 0.72), 1.5, true)
		elif center_ratio > 0.0:
			var center_half_angle := half_angle * center_ratio
			var center_points := PackedVector2Array([near_center])
			for index in range(9):
				var angle := lerpf(center_angle - center_half_angle, center_angle + center_half_angle, float(index) / 8.0)
				center_points.append(near_center + Vector2.from_angle(angle) * length)
			var center_fill := Color(1.0, 0.96, 0.76, 0.16 + 0.10 * progress)
			draw_colored_polygon(center_points, center_fill)
		var arrow_count := maxi(int(effect.get("projectile_count", 0)), 0)
		var arrow_distance := length * clampf(progress * 1.25, 0.0, 1.0)
		for index in range(arrow_count):
			var ratio := 0.5 if arrow_count == 1 else float(index) / float(arrow_count - 1)
			var arrow_angle := lerpf(center_angle - half_angle * 0.92, center_angle + half_angle * 0.92, ratio)
			var arrow_direction := Vector2.from_angle(arrow_angle)
			var arrow_pos := near_center + arrow_direction * arrow_distance
			draw_line(arrow_pos - arrow_direction * 10.0, arrow_pos + arrow_direction * 5.0, Color(0.78, 0.94, 1.0, 0.95), 2.0, true)
		return
	var near_half := maxf(float(effect.get("near_width", effect.get("width", 0.0))) * 0.5, 0.0)
	var far_half := maxf(float(effect.get("far_width", effect.get("width", 0.0))) * 0.5, 0.0)
	var near_left := near_center - side * near_half
	var near_right := near_center + side * near_half
	var far_left := far_center - side * far_half
	var far_right := far_center + side * far_half
	draw_colored_polygon(PackedVector2Array([near_left, far_left, far_right, near_right]), fill_color)
	draw_line(near_left, far_left, line_color, 3.0, true)
	draw_line(far_left, far_right, line_color, 3.0, true)
	draw_line(far_right, near_right, line_color, 3.0, true)
	if shape == &"trapezoid":
		draw_line(near_left, near_right, line_color, 3.0, true)
	var center_ratio := clampf(float(effect.get("center_ratio", 0.0)), 0.0, 1.0)
	if center_ratio > 0.0:
		var center_fill := Color(1.0, 0.96, 0.76, 0.16 + 0.10 * progress)
		draw_colored_polygon(PackedVector2Array([
			near_center - side * near_half * center_ratio,
			far_center - side * far_half * center_ratio,
			far_center + side * far_half * center_ratio,
			near_center + side * near_half * center_ratio,
		]), center_fill)

## 绘制当前卡牌的落点：格子边框用于确认“哪一格”，半透明占位用于确认卡牌大小。
## 这是纯表现层，不会修改部署坐标或战斗状态。
func _draw_deployment_preview(stats: Dictionary) -> void:
	if not _deployment_preview_visible:
		return
	var color := DEPLOY_PREVIEW_VALID if _deployment_preview_valid else DEPLOY_PREVIEW_INVALID
	var footprint: Vector2i = stats.get("footprint_tiles", Vector2i.ONE)
	var type: String = stats.get("type", "unit")
	var preview_rect: Rect2
	if type == "building" and footprint != Vector2i.ONE:
		preview_rect = Rect2(
			_deployment_preview_pos - Vector2(footprint) * TILE_SIZE * 0.5,
			Vector2(footprint) * TILE_SIZE
		)
	else:
		preview_rect = Rect2(Vector2(_deployment_preview_tile) * TILE_SIZE, Vector2.ONE * TILE_SIZE)
	draw_rect(preview_rect, Color(color.r, color.g, color.b, 0.18), true)
	draw_rect(preview_rect, color, false, 3.0)

	if type == "spell":
		var spell_radius: float = stats.get("radius", TILE_SIZE * 0.5)
		draw_circle(_deployment_preview_pos, spell_radius, Color(color.r, color.g, color.b, 0.12))
		draw_arc(_deployment_preview_pos, spell_radius, 0.0, TAU, 48, color, 2.0, true)
	elif type == "unit":
		var unit_radius: float = minf(float(stats.get("radius", TILE_SIZE * 0.5)), TILE_SIZE * 0.42)
		draw_circle(_deployment_preview_pos, unit_radius, Color(color.r, color.g, color.b, 0.26))
		draw_arc(_deployment_preview_pos, unit_radius, 0.0, TAU, 32, color, 2.0, true)
	else:
		# 建筑中心在格线交点，额外画一个中心十字，避免 2x2 预览看起来像单格落点。
		var cross_size := 7.0
		draw_line(_deployment_preview_pos - Vector2(cross_size, 0.0), _deployment_preview_pos + Vector2(cross_size, 0.0), color, 2.0, true)
		draw_line(_deployment_preview_pos - Vector2(0.0, cross_size), _deployment_preview_pos + Vector2(0.0, cross_size), color, 2.0, true)
