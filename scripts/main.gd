extends Node2D
## 主场景：战场搭建、部署输入、敌方占位出兵、胜负判定。

const ART_DEV_PANEL_SCRIPT := preload("res://scripts/art_dev_panel.gd")
const ACTIVE_SKILL_BAR_SCRIPT := preload("res://scripts/active_skill_bar.gd")
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
const PROJECTILE_MUZZLE_FORWARD_GAP := 5.0 * CardDB.CHARACTER_SCALE_MULTIPLIER
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
## 所有手牌在主机确认并扣费后统一延迟执行，给联网指令留出稳定的表现窗口。
const CARD_DEPLOY_DELAY := 0.5
## 主动技能点击后同样进入主机权威等待窗口，再由固定 tick 结算。
const ACTIVE_SKILL_CAST_DELAY := 0.5
## 水晶兵线由主机固定 tick 驱动：开局 5 秒首波，之后每 30 秒一波，第二只延迟 0.5 秒。
const FIRST_MINION_WAVE_TIME := 5.0
const MINION_WAVE_INTERVAL := 30.0
const MINION_WAVE_STAGGER := 0.5
const MINION_SPAWN_X_OFFSET := 3.0 * TILE_SIZE

# 联机
const NET_PORT := 39152

var game_over := false
var nav: NavGrid
var mode := "local"  # local=单机 / host=主机 / client=客户端
var _match_started := false  # 比赛是否已开始（联机时主机需等对手加入）
var _freeze_effects: Array = []  # [{pos, timer, duration, radius}]
## 强化冰冻结束后的权威减速区域与客户端纯视觉区域分开保存。
var _slow_zones: Array[Dictionary] = []
var _slow_effects: Array[Dictionary] = []
## 纳尔 Spell2：固定模拟延迟到手掌触地才结算；范围框是独立纯表现数据。
var _pending_frontal_stun_skills: Array[Dictionary] = []
var _frontal_skill_effects: Array[Dictionary] = []
var _projectiles := {}  # 主机/单机：id -> {pos, target, team, damage, speed, ...}
var _client_projectiles := {}  # 客户端仅保存插值表现
var _next_projectile_id := 1

var _elixir: ElixirManager
var _hand: CardHand
var _active_skill_bar: ActiveSkillBar
## ability_id -> {unit, card_id, team}；按钮只是这份权威状态的视图。
var _active_skills: Dictionary = {}
var _next_active_ability_id := 1
## 主动请求确认后等待 0.5 秒；同一 ability_id 在队列中只能存在一次。
var _pending_active_skill_activations: Array[Dictionary] = []
var _ai: AIOpponent
var _selected_card := ""
## 选卡后的落点预览：单位以单格格心为目标，点击时使用当前预览而不是重新猜测落点。
var _deployment_preview_pos := Vector2.ZERO
var _deployment_preview_tile := Vector2i(-1, -1)
var _deployment_preview_valid := false
var _deployment_preview_visible := false
## 主机/单机权威卡牌队列：单位、建筑和法术都在倒计时结束后才真正生效。
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
## 主机收到的客户端卡组；用于校验出牌归属及前两槽主动资格。
var _remote_deck: Array = []
var _remote_active_skill_choices: Dictionary = {}
var _deck_layer: CanvasLayer
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

func _ready() -> void:
	randomize()
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

# ============================================================
#  选卡组界面
# ============================================================

var _deck_toggles := {}       # card_id -> 下方卡牌库按钮
var _deck_slot_buttons: Array[Button] = []
var _deck_selected: Array = []  # 当前卡组，顺序就是上方 8 个卡位的顺序
var _deck_confirm: Button
var _deck_status: Label
var _deck_average_label: Label
var _deck_ui_root: Control
var _deck_pool_grid: GridContainer
var _deck_filter_option: OptionButton
var _deck_sort_option: OptionButton
var _deck_pool_filter := "all"
var _deck_pool_sort := "name"
var _deck_pending_slot := -1
var _deck_context_popup: PanelContainer
var _deck_context_info: Button
var _deck_context_action: Button
var _deck_context_card_id := ""
var _deck_context_slot := -1
var _deck_context_from_pool := false
var _deck_context_anchor: Control
var _deck_info_overlay: Control
var _deck_info_active_option: OptionButton
var _deck_info_active_description: Label
var _deck_info_skin_option: OptionButton
var _skin_choices: Dictionary = {}

func _deck_style(background: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
	return CardArt.frame_style(background, border, border_width)

func _make_deck_card_button(card_id: String, is_slot: bool) -> Button:
	var button := Button.new()
	button.toggle_mode = false
	button.focus_mode = Control.FOCUS_NONE
	button.set_meta("card_id", card_id)
	CardArt.apply_frame(button, 165.0 if is_slot else 172.0)
	if card_id.is_empty():
		CardArt.show_empty_slot(button, 1)
		button.disabled = false
	else:
		var stats: Dictionary = CardDB.all()[card_id]
		var accent: Color = stats.get("color", CardArt.DEFAULT_ACCENT)
		CardArt.apply_to_button(button, card_id, stats.name, stats.cost, false, accent)
	return button

func _set_active_slot_badge(button: Button, enabled: bool) -> void:
	var badge := button.get_node_or_null("ActiveSlotBadge") as Label
	if badge == null:
		badge = Label.new()
		badge.name = "ActiveSlotBadge"
		badge.position = Vector2(4.0, 42.0)
		badge.custom_minimum_size = Vector2(72.0, 24.0)
		badge.text = "主动位"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_override("font", CardArt.ui_font())
		badge.add_theme_font_size_override("font_size", 14)
		badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
		badge.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.08))
		badge.add_theme_constant_override("outline_size", 4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(badge)
	badge.visible = enabled
	button.move_child(badge, button.get_child_count() - 1)

## 在对战开始前弹出选卡组界面；上方固定 8 个卡位，下方滚动卡池。
func _pick_deck_ui(after_start: Callable) -> void:
	_deck_selected = _deck.duplicate() if _deck.size() == 8 else []
	_deck_pool_filter = "all"
	_deck_pool_sort = "name"
	_deck_pending_slot = -1
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_deck_layer = layer
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	_deck_ui_root = root
	var background_art := TextureRect.new()
	background_art.texture = ARENA_BACKGROUND_TEXTURE
	background_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_art.modulate = Color(0.18, 0.32, 0.52, 0.28)
	background_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background_art)
	var background_tint := ColorRect.new()
	background_tint.color = Color(0.018, 0.055, 0.12, 0.93)
	background_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background_tint)
	var top_glow := ColorRect.new()
	top_glow.color = Color(0.04, 0.42, 0.78, 0.20)
	top_glow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_glow.offset_bottom = 150.0
	top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_glow)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	root.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	margin.add_child(vbox)
	var header_panel := PanelContainer.new()
	header_panel.custom_minimum_size = Vector2(0.0, 78.0)
	header_panel.add_theme_stylebox_override("panel", _deck_style(Color(0.025, 0.16, 0.30, 0.96), Color(0.08, 0.55, 0.94), 2))
	vbox.add_child(header_panel)
	var header_box := VBoxContainer.new()
	header_box.alignment = BoxContainer.ALIGNMENT_CENTER
	header_box.add_theme_constant_override("separation", -2)
	header_panel.add_child(header_box)
	var title := Label.new()
	title.text = "备战卡组"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08))
	title.add_theme_constant_override("outline_size", 5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "选择 8 张卡牌；前两个卡位会把主动技能带进对局"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.68, 0.84, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_box.add_child(subtitle)
	var deck_header := HBoxContainer.new()
	deck_header.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(deck_header)
	var deck_header_title := Label.new()
	deck_header_title.text = "我的卡组"
	deck_header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_header_title.add_theme_font_size_override("font_size", 20)
	deck_header_title.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0))
	deck_header.add_child(deck_header_title)
	_deck_average_label = Label.new()
	_deck_average_label.add_theme_font_size_override("font_size", 16)
	_deck_average_label.add_theme_color_override("font_color", Color(0.94, 0.48, 1.0))
	deck_header.add_child(_deck_average_label)
	var deck_panel := PanelContainer.new()
	deck_panel.custom_minimum_size = Vector2(0.0, 352.0)
	deck_panel.add_theme_stylebox_override("panel", _deck_style(Color(0.025, 0.09, 0.17, 0.97), Color(0.10, 0.42, 0.70), 2))
	vbox.add_child(deck_panel)
	var deck_margin := MarginContainer.new()
	deck_margin.add_theme_constant_override("margin_left", 12)
	deck_margin.add_theme_constant_override("margin_right", 12)
	deck_margin.add_theme_constant_override("margin_top", 6)
	deck_margin.add_theme_constant_override("margin_bottom", 6)
	deck_panel.add_child(deck_margin)
	var deck_center := CenterContainer.new()
	deck_margin.add_child(deck_center)
	var deck_grid := GridContainer.new()
	deck_grid.columns = 4
	deck_grid.add_theme_constant_override("h_separation", 14)
	deck_grid.add_theme_constant_override("v_separation", 10)
	deck_center.add_child(deck_grid)
	_deck_slot_buttons.clear()
	for i in range(8):
		var slot := _make_deck_card_button("", true)
		CardArt.show_empty_slot(slot, i + 1)
		_set_active_slot_badge(slot, i < 2)
		slot.tooltip_text = "主动技能位" if i < 2 else "普通卡位"
		slot.pressed.connect(_on_deck_slot_pressed.bind(i))
		deck_grid.add_child(slot)
		_deck_slot_buttons.append(slot)
	_deck_status = Label.new()
	_deck_status.add_theme_font_size_override("font_size", 16)
	_deck_status.add_theme_color_override("font_color", Color(0.67, 0.82, 0.96))
	_deck_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_deck_status)
	var pool_header := Label.new()
	pool_header.text = "卡牌库"
	pool_header.add_theme_font_size_override("font_size", 20)
	pool_header.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	vbox.add_child(pool_header)
	var pool_controls := HBoxContainer.new()
	pool_controls.add_theme_constant_override("separation", 8)
	vbox.add_child(pool_controls)
	var filter_label := Label.new()
	filter_label.text = "类型"
	filter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	filter_label.add_theme_font_size_override("font_size", 15)
	filter_label.add_theme_color_override("font_color", Color(0.68, 0.84, 1.0))
	pool_controls.add_child(filter_label)
	_deck_filter_option = OptionButton.new()
	_deck_filter_option.custom_minimum_size = Vector2(150.0, 38.0)
	_deck_filter_option.add_theme_font_override("font", CardArt.ui_font())
	_deck_filter_option.add_theme_font_size_override("font_size", 15)
	for filter_name in ["全部", "地面", "空军", "建筑", "法术"]:
		_deck_filter_option.add_item(filter_name)
	_deck_filter_option.select(0)
	_deck_filter_option.item_selected.connect(_on_deck_filter_selected)
	pool_controls.add_child(_deck_filter_option)
	var sort_label := Label.new()
	sort_label.text = "排序"
	sort_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sort_label.add_theme_font_size_override("font_size", 15)
	sort_label.add_theme_color_override("font_color", Color(0.68, 0.84, 1.0))
	pool_controls.add_child(sort_label)
	_deck_sort_option = OptionButton.new()
	_deck_sort_option.custom_minimum_size = Vector2(190.0, 38.0)
	_deck_sort_option.add_theme_font_override("font", CardArt.ui_font())
	_deck_sort_option.add_theme_font_size_override("font_size", 15)
	for sort_name in ["名称排序", "金币消耗递增", "金币消耗递减"]:
		_deck_sort_option.add_item(sort_name)
	_deck_sort_option.select(0)
	_deck_sort_option.item_selected.connect(_on_deck_sort_selected)
	pool_controls.add_child(_deck_sort_option)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, 560.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var grid := GridContainer.new()
	_deck_pool_grid = grid
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	var grid_center := CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid_center.add_child(grid)
	scroll.add_child(grid_center)
	_refresh_deck_pool()
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)
	var back := _make_menu_button("返回")
	back.custom_minimum_size = Vector2(150, 52)
	back.add_theme_stylebox_override("normal", _deck_style(Color(0.08, 0.15, 0.24), Color(0.30, 0.46, 0.64), 2))
	back.pressed.connect(_clear_deck_ui)
	btn_row.add_child(back)
	_deck_confirm = _make_menu_button("开始对战")
	_deck_confirm.custom_minimum_size = Vector2(230, 52)
	_deck_confirm.add_theme_font_size_override("font_size", 20)
	_deck_confirm.add_theme_stylebox_override("normal", _deck_style(Color(0.05, 0.42, 0.74), Color(0.34, 0.78, 1.0), 3))
	_deck_confirm.add_theme_stylebox_override("hover", _deck_style(Color(0.08, 0.54, 0.88), Color(0.60, 0.90, 1.0), 3))
	_deck_confirm.add_theme_stylebox_override("pressed", _deck_style(Color(0.04, 0.32, 0.60), Color(1.0, 0.84, 0.32), 3))
	_deck_confirm.pressed.connect(func(): _confirm_deck(after_start))
	btn_row.add_child(_deck_confirm)
	_create_deck_context_popup(root)
	_update_deck_ui()

func _create_deck_context_popup(root: Control) -> void:
	_deck_context_popup = PanelContainer.new()
	_deck_context_popup.custom_minimum_size = Vector2(132.0, 96.0)
	_deck_context_popup.size = Vector2(132.0, 96.0)
	_deck_context_popup.z_index = 50
	_deck_context_popup.add_theme_stylebox_override("panel", _deck_style(Color(0.025, 0.12, 0.22, 0.99), Color(0.28, 0.72, 1.0), 3))
	root.add_child(_deck_context_popup)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_deck_context_popup.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	_deck_context_info = _make_deck_action_button("信息", Color(0.08, 0.43, 0.72), Color(0.36, 0.78, 1.0))
	_deck_context_info.pressed.connect(_open_selected_card_info)
	box.add_child(_deck_context_info)
	_deck_context_action = _make_deck_action_button("添加", Color(0.08, 0.55, 0.30), Color(0.38, 0.95, 0.58))
	_deck_context_action.pressed.connect(_perform_deck_context_action)
	box.add_child(_deck_context_action)
	_deck_context_popup.visible = false

func _make_deck_action_button(text: String, background: Color, border: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(116.0, 38.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", CardArt.ui_font())
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", _deck_style(background, border, 2))
	button.add_theme_stylebox_override("hover", _deck_style(background.lightened(0.12), border.lightened(0.12), 3))
	button.add_theme_stylebox_override("pressed", _deck_style(background.darkened(0.12), Color(1.0, 0.84, 0.30), 3))
	button.add_theme_stylebox_override("disabled", _deck_style(Color(0.08, 0.10, 0.14), Color(0.28, 0.32, 0.38), 2))
	return button

func _on_deck_pool_card_pressed(card_id: String) -> void:
	if not _deck_toggles.has(card_id):
		return
	if _deck_pending_slot >= 0:
		_add_card_to_pending_slot(card_id)
		return
	_show_deck_context(card_id, -1, true, _deck_toggles[card_id])

func _on_deck_slot_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= 8:
		return
	var slot_card_id := String(_deck_selected[slot_index]) if slot_index < _deck_selected.size() else ""
	if slot_card_id.is_empty():
		_deck_pending_slot = -1 if _deck_pending_slot == slot_index else slot_index
		_hide_deck_context()
		_update_deck_ui()
		return
	_deck_pending_slot = -1
	_show_deck_context(slot_card_id, slot_index, false, _deck_slot_buttons[slot_index])

func _show_deck_context(card_id: String, slot_index: int, from_pool: bool, anchor: Control) -> void:
	if not CardDB.all().has(card_id) or _deck_context_popup == null:
		return
	if _deck_context_popup.visible and _deck_context_card_id == card_id and _deck_context_slot == slot_index and _deck_context_from_pool == from_pool:
		_hide_deck_context()
		_update_deck_ui()
		return
	_deck_pending_slot = -1
	_deck_context_card_id = card_id
	_deck_context_slot = slot_index
	_deck_context_from_pool = from_pool
	_deck_context_anchor = anchor
	_deck_context_action.text = "添加" if from_pool else "移除"
	if from_pool:
		_deck_context_action.disabled = _deck_selected.has(card_id) or _selected_card_count() >= 8
		_deck_context_action.tooltip_text = "已在卡组中" if _deck_selected.has(card_id) else ("卡组已满" if _selected_card_count() >= 8 else "添加到下一个空卡位")
		_deck_context_action.add_theme_stylebox_override("normal", _deck_style(Color(0.08, 0.55, 0.30), Color(0.38, 0.95, 0.58), 2))
	else:
		_deck_context_action.disabled = false
		_deck_context_action.tooltip_text = "从卡组移除"
		_deck_context_action.add_theme_stylebox_override("normal", _deck_style(Color(0.70, 0.16, 0.18), Color(1.0, 0.43, 0.43), 2))
	_deck_context_popup.visible = true
	_deck_context_popup.move_to_front()
	_update_deck_ui()
	_position_deck_context_popup.call_deferred()

func _add_card_to_pending_slot(card_id: String) -> void:
	if _deck_pending_slot < 0 or not _add_card_to_slot(card_id, _deck_pending_slot):
		return
	_deck_pending_slot = -1
	_hide_deck_context()
	_refresh_deck_pool()
	_update_deck_ui()

func _selected_card_count() -> int:
	var count := 0
	for card_id in _deck_selected:
		if not String(card_id).is_empty():
			count += 1
	return count

func _first_empty_deck_slot() -> int:
	for slot_index in range(8):
		if slot_index >= _deck_selected.size() or String(_deck_selected[slot_index]).is_empty():
			return slot_index
	return -1

func _add_card_to_slot(card_id: String, slot_index: int) -> bool:
	if not CardDB.all().has(card_id) or slot_index < 0 or slot_index >= 8:
		return false
	if _selected_card_count() >= 8 or _deck_selected.has(card_id):
		return false
	while _deck_selected.size() <= slot_index:
		_deck_selected.append("")
	_deck_selected[slot_index] = card_id
	return true

func _trim_trailing_empty_slots() -> void:
	while not _deck_selected.is_empty() and String(_deck_selected.back()).is_empty():
		_deck_selected.pop_back()

func _on_deck_filter_selected(index: int) -> void:
	var filters := ["all", "ground", "air", "building", "spell"]
	if index < 0 or index >= filters.size():
		return
	_deck_pool_filter = filters[index]
	_hide_deck_context()
	_refresh_deck_pool()

func _on_deck_sort_selected(index: int) -> void:
	var sort_modes := ["name", "cost_asc", "cost_desc"]
	if index < 0 or index >= sort_modes.size():
		return
	_deck_pool_sort = sort_modes[index]
	_hide_deck_context()
	_refresh_deck_pool()

func _deck_card_matches_filter(card_id: String) -> bool:
	if _deck_pool_filter == "all":
		return true
	var stats: Dictionary = CardDB.all()[card_id]
	match _deck_pool_filter:
		"ground": return String(stats.get("type", "unit")) == "unit" and not bool(stats.get("is_air", false))
		"air": return String(stats.get("type", "unit")) == "unit" and bool(stats.get("is_air", false))
		"building": return String(stats.get("type", "unit")) == "building"
		"spell": return String(stats.get("type", "unit")) == "spell"
	return false

func _sort_deck_card_ids(first_id: String, second_id: String) -> bool:
	var cards := CardDB.all()
	var first_stats: Dictionary = cards[first_id]
	var second_stats: Dictionary = cards[second_id]
	if _deck_pool_sort == "cost_asc" or _deck_pool_sort == "cost_desc":
		var first_cost := int(first_stats.get("cost", 0))
		var second_cost := int(second_stats.get("cost", 0))
		if first_cost != second_cost:
			return first_cost < second_cost if _deck_pool_sort == "cost_asc" else first_cost > second_cost
	var first_name := String(first_stats.get("name", first_id))
	var second_name := String(second_stats.get("name", second_id))
	return first_name < second_name if first_name != second_name else first_id < second_id

func _refresh_deck_pool() -> void:
	if _deck_pool_grid == null:
		return
	for child in _deck_pool_grid.get_children():
		child.queue_free()
	_deck_toggles.clear()
	var card_ids: Array = []
	for configured_id in CardDB.selectable_ids():
		var card_id := String(configured_id)
		if _deck_selected.has(card_id) or not _deck_card_matches_filter(card_id):
			continue
		card_ids.append(card_id)
	card_ids.sort_custom(Callable(self, "_sort_deck_card_ids"))
	for card_id in card_ids:
		var card_button := _make_deck_card_button(card_id, false)
		card_button.pressed.connect(_on_deck_pool_card_pressed.bind(card_id))
		_deck_pool_grid.add_child(card_button)
		_deck_toggles[card_id] = card_button

func _position_deck_context_popup() -> void:
	if _deck_context_popup == null or not _deck_context_popup.visible or _deck_context_anchor == null or not is_instance_valid(_deck_context_anchor) or _deck_ui_root == null:
		return
	var anchor_rect := _deck_context_anchor.get_global_rect()
	var root_rect := _deck_ui_root.get_global_rect()
	var popup_size := _deck_context_popup.size
	var x := anchor_rect.position.x - root_rect.position.x + (anchor_rect.size.x - popup_size.x) * 0.5
	var y := anchor_rect.end.y - root_rect.position.y + 5.0
	x = clampf(x, 8.0, maxf(8.0, root_rect.size.x - popup_size.x - 8.0))
	if y + popup_size.y > root_rect.size.y - 76.0:
		y = anchor_rect.position.y - root_rect.position.y - popup_size.y - 5.0
	_deck_context_popup.position = Vector2(x, maxf(y, 8.0))

func _perform_deck_context_action() -> void:
	if _deck_context_card_id.is_empty():
		return
	if _deck_context_from_pool:
		var empty_slot := _first_empty_deck_slot()
		if empty_slot < 0 or not _add_card_to_slot(_deck_context_card_id, empty_slot):
			return
	else:
		if _deck_context_slot < 0 or _deck_context_slot >= _deck_selected.size() or String(_deck_selected[_deck_context_slot]).is_empty():
			return
		_deck_selected[_deck_context_slot] = ""
		_trim_trailing_empty_slots()
	_deck_pending_slot = -1
	_hide_deck_context()
	_refresh_deck_pool()
	_update_deck_ui()

func _hide_deck_context() -> void:
	_deck_context_card_id = ""
	_deck_context_slot = -1
	_deck_context_from_pool = false
	_deck_context_anchor = null
	if _deck_context_popup != null:
		_deck_context_popup.visible = false

func _open_selected_card_info() -> void:
	if _deck_context_card_id.is_empty() or not CardDB.all().has(_deck_context_card_id):
		return
	_open_card_info(_deck_context_card_id)

func _open_card_info(card_id: String) -> void:
	_close_card_info()
	_hide_deck_context()
	if _deck_ui_root == null or not CardDB.all().has(card_id):
		return
	var stats: Dictionary = CardDB.all()[card_id]
	var accent: Color = stats.get("color", CardArt.DEFAULT_ACCENT)
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.005, 0.015, 0.035, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 80
	_deck_ui_root.add_child(overlay)
	_deck_info_overlay = overlay
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	# 信息页按内容自然收缩，避免固定大面板在内容较少时把下半部分留空。
	panel.custom_minimum_size = Vector2(650.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _deck_style(Color(0.025, 0.075, 0.14, 0.995), accent.lightened(0.22), 3))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	layout.add_child(header)
	var preview := _make_deck_card_button(card_id, false)
	CardArt.apply_frame(preview, 224.0)
	CardArt.apply_to_button(preview, card_id, stats.name, stats.cost, false, accent)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(preview)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 8)
	header.add_child(identity)
	var name_label := Label.new()
	name_label.text = String(stats.name)
	name_label.add_theme_font_override("font", CardArt.ui_font())
	name_label.add_theme_font_size_override("font_size", 34)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.06))
	name_label.add_theme_constant_override("outline_size", 5)
	identity.add_child(name_label)
	var identity_line := Label.new()
	identity_line.text = "%s　·　%d 费" % [_card_type_name(String(stats.get("type", "unit")), stats), int(stats.cost)]
	identity_line.add_theme_font_override("font", CardArt.ui_font())
	identity_line.add_theme_font_size_override("font_size", 19)
	identity_line.add_theme_color_override("font_color", Color(0.68, 0.86, 1.0))
	identity.add_child(identity_line)
	# 皮肤入口固定在信息面板右上角，默认选择原皮；未来只需在卡牌数据中
	# 增加 skins 数组即可出现更多选项，皮肤选择不参与战斗数值。
	var skin_box := VBoxContainer.new()
	skin_box.custom_minimum_size = Vector2(124.0, 0.0)
	skin_box.alignment = BoxContainer.ALIGNMENT_CENTER
	skin_box.add_theme_constant_override("separation", 4)
	header.add_child(skin_box)
	_deck_info_skin_option = _make_card_skin_option(card_id, stats)
	skin_box.add_child(_deck_info_skin_option)
	var separator := HSeparator.new()
	layout.add_child(separator)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 7)
	# 详情内容控制弹窗自身高度；当前属性量可完整放下，不再用会被压成零高的滚动容器。
	layout.add_child(details)
	details.add_child(_make_card_info_heading("简介"))
	details.add_child(_make_card_info_body(_card_brief_description(stats)))
	details.add_child(_make_card_info_heading("属性"))
	details.add_child(_make_card_attribute_grid(stats))
	if card_id == "tombstone":
		details.add_child(_make_card_info_subheading("召唤物：小鬼（每批 %d 只）" % int(stats.get("spawn_count", 1))))
		var imp_stats := CardDB.imp_stats()
		details.add_child(_make_card_attribute_grid(imp_stats, "%d /批" % int(stats.get("spawn_count", 1))))
	var passives := _card_passives(stats)
	if not passives.is_empty():
		details.add_child(_make_card_info_heading("被动"))
		for passive in passives:
			details.add_child(_make_card_passive_row(String(passive.get("name", "被动")), String(passive.get("description", ""))))
	details.add_child(_make_card_info_heading("主动"))
	var skills := CardDB.active_skills_for(card_id)
	_deck_info_active_option = OptionButton.new()
	_deck_info_active_option.custom_minimum_size = Vector2(0.0, 46.0)
	_deck_info_active_option.add_theme_font_override("font", CardArt.ui_font())
	_deck_info_active_option.add_theme_font_size_override("font_size", 17)
	if skills.is_empty():
		if String(stats.get("type", "unit")) == "spell":
			_deck_info_active_option.add_item(String(stats.get("active_name", "强化" + String(stats.get("name", "法术")))))
		else:
			_deck_info_active_option.add_item("无主动技能")
		_deck_info_active_option.disabled = true
	else:
		for skill in skills:
			_deck_info_active_option.add_item(String(skill.get("name", "未命名技能")))
		var selected_skill := clampi(int(_active_skill_choices.get(card_id, 0)), 0, skills.size() - 1)
		_active_skill_choices[card_id] = selected_skill
		_deck_info_active_option.select(selected_skill)
		_deck_info_active_option.disabled = skills.size() <= 1
		_deck_info_active_option.item_selected.connect(_on_info_active_skill_selected.bind(card_id))
	details.add_child(_deck_info_active_option)
	_deck_info_active_description = _make_card_info_body(_active_choice_description(card_id))
	details.add_child(_deck_info_active_description)
	var close := _make_deck_action_button("返回备战", Color(0.08, 0.38, 0.68), Color(0.38, 0.80, 1.0))
	close.custom_minimum_size = Vector2(220.0, 48.0)
	close.pressed.connect(_close_card_info)
	var close_center := CenterContainer.new()
	close_center.add_child(close)
	layout.add_child(close_center)
	overlay.move_to_front()

func _make_card_skin_option(card_id: String, stats: Dictionary) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(124.0, 42.0)
	option.add_theme_font_override("font", CardArt.ui_font())
	option.add_theme_font_size_override("font_size", 15)
	option.tooltip_text = "选择外观；皮肤不改变战斗数值"
	var skins := _card_skin_entries(stats)
	var selected_id := String(_skin_choices.get(card_id, "default"))
	var selected_index := 0
	for i in range(skins.size()):
		var skin: Dictionary = skins[i]
		option.add_item(String(skin.get("name", "原皮")))
		if String(skin.get("id", "default")) == selected_id:
			selected_index = i
	_skin_choices[card_id] = String(skins[selected_index].get("id", "default"))
	option.select(selected_index)
	option.item_selected.connect(_on_info_skin_selected.bind(card_id, skins))
	return option

func _card_skin_entries(stats: Dictionary) -> Array:
	var skins: Array = [{"id": "default", "name": "原皮"}]
	for configured in stats.get("skins", []):
		if configured is Dictionary:
			var skin_id := String(configured.get("id", ""))
			if not skin_id.is_empty() and skin_id != "default":
				skins.append((configured as Dictionary).duplicate(true))
		elif configured is String and not String(configured).is_empty() and String(configured) != "default":
			skins.append({"id": String(configured), "name": String(configured)})
	return skins

func _make_card_info_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", CardArt.ui_font())
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32))
	return label

func _make_card_info_body(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", CardArt.ui_font())
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.84, 0.91, 0.98))
	label.add_theme_constant_override("line_spacing", 4)
	return label

func _card_type_name(card_type: String, stats: Dictionary = {}) -> String:
	match card_type:
		"spell": return "法术"
		"building": return "建筑"
		_:
			return "空军" if bool(stats.get("is_air", false)) else "地面"

func _format_card_number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.2f" % value

func _card_brief_description(stats: Dictionary) -> String:
	var description := String(stats.get("description", ""))
	return description if not description.is_empty() else "这张卡可以通过合理的部署位置和出牌时机发挥作用。"

func _make_card_info_subheading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", CardArt.ui_font())
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.64, 0.82, 1.0))
	return label

func _make_card_attribute_grid(stats: Dictionary, quantity_override: String = "") -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	for attribute in _card_attributes(stats, quantity_override):
		var attribute_value := String(attribute.get("value", ""))
		if attribute_value.is_empty():
			continue
		var item := PanelContainer.new()
		item.custom_minimum_size = Vector2(0.0, 32.0)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_theme_stylebox_override("panel", _deck_style(Color(0.035, 0.12, 0.21, 0.88), Color(0.10, 0.30, 0.48, 0.75), 1))
		var label := Label.new()
		label.text = "%s：%s" % [String(attribute.get("name", "")), attribute_value]
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", CardArt.ui_font())
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.03, 0.08, 0.70))
		label.add_theme_constant_override("outline_size", 2)
		item.add_child(label)
		grid.add_child(item)
	return grid

func _card_attributes(stats: Dictionary, quantity_override: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var card_type := String(stats.get("type", "unit"))
	if card_type == "spell":
		result.append({"name": "类型", "value": _card_type_name(card_type, stats)})
		result.append({"name": "目标", "value": "敌方单位"})
		result.append({"name": "作用范围", "value": "%s（%.1f格）" % [_format_card_number(float(stats.get("radius", 0.0))), float(stats.get("radius", 0.0)) / TILE_SIZE]})
		result.append({"name": "持续时间", "value": "%s秒" % _format_card_number(float(stats.get("duration", 0.0)))})
		return result

	var quantity := quantity_override if not quantity_override.is_empty() else "1"
	result.append({"name": "生命", "value": _format_card_number(float(stats.get("hp", 0.0)))})
	result.append({"name": "类型", "value": _card_type_name(card_type, stats)})
	if card_type == "building":
		result.append({"name": "数量", "value": quantity})
		if stats.has("footprint_tiles") or stats.has("radius"):
			result.append({"name": "体积", "value": _card_volume_name(stats)})
		if stats.has("lifespan"):
			result.append({"name": "存活时间", "value": "%s秒" % _format_card_number(float(stats.get("lifespan", 0.0)))})
		return result

	result.append({"name": "目标", "value": _card_target_name(stats)})
	if stats.has("sight") and float(stats.get("sight", 0.0)) > 0.0:
		result.append({"name": "视野", "value": _format_card_number(float(stats.get("sight", 0.0)))})
	var speed := float(stats.get("speed", 0.0))
	if stats.has("speed"):
		result.append({"name": "移速", "value": "%s/秒（%s）" % [_format_card_number(speed), CardDB.speed_tier_name(speed)]})
	# 数量占据原视野所在的位序，视野统一放到属性列表最后。
	result.append({"name": "数量", "value": quantity})
	var damage := float(stats.get("damage", 0.0))
	var continuous := bool(stats.get("is_continuous_attack", false))
	var damage_multipliers: Array = stats.get("attack_damage_multipliers", [])
	if not continuous and damage > 0.0:
		if damage_multipliers.is_empty():
			result.append({"name": "单次伤害", "value": _format_card_number(damage)})
		else:
			var fist_names := ["左拳", "右拳", "左拳", "右拳"]
			var fist_values: Array[String] = []
			for index in range(mini(damage_multipliers.size(), 2)):
				var fist_name: String = fist_names[index % fist_names.size()]
				var fist_damage := damage * float(damage_multipliers[index])
				fist_values.append("%s（%s）" % [_format_card_number(fist_damage), fist_name])
			result.append({"name": "单次伤害", "value": "，".join(fist_values)})
	var interval := float(stats.get("interval", 0.0))
	var dps: float = damage if continuous else (damage / interval if interval > 0.0 and damage > 0.0 else 0.0)
	if not continuous and not damage_multipliers.is_empty():
		var combo_pattern: Array = stats.get("attack_pattern", [])
		if combo_pattern.size() > 1:
			var combo_damage := damage * (float(damage_multipliers[0]) + float(damage_multipliers[1]))
			var combo_interval := float(stats.get("attack_interval_display", combo_pattern[1])) + float(combo_pattern[0])
			if combo_interval > 0.0:
				dps = combo_damage / combo_interval
	if damage > 0.0:
		result.append({"name": "每秒伤害", "value": _format_card_number(dps)})
	if not continuous and interval > 0.0:
		var display_interval := float(stats.get("attack_interval_display", interval))
		result.append({"name": "攻击间隔", "value": "%s秒" % _format_card_number(display_interval)})
	if damage > 0.0 and stats.has("range"):
		result.append({"name": "攻击距离", "value": "%s（%.1f格）" % [_format_card_number(float(stats.get("range", 0.0))), float(stats.get("range", 0.0)) / TILE_SIZE]})
	if stats.has("radius"):
		result.append({"name": "体积", "value": _card_volume_name(stats)})
	if stats.has("mass"):
		result.append({"name": "质量", "value": _format_card_number(float(stats.get("mass", 0.0)))})
	return result

func _card_target_name(stats: Dictionary) -> String:
	if String(stats.get("type", "unit")) == "spell":
		return "敌方单位"
	if String(stats.get("type", "unit")) == "building" or float(stats.get("damage", 0.0)) <= 0.0:
		return "无"
	if bool(stats.get("building_only", false)):
		return "建筑"
	return "空中和地面" if bool(stats.get("can_attack_air", false)) else "地面"

func _card_volume_name(stats: Dictionary) -> String:
	if stats.has("footprint_tiles"):
		var footprint: Vector2i = stats.footprint_tiles
		return "%d×%d格（半径%s）" % [footprint.x, footprint.y, _format_card_number(float(stats.get("radius", 0.0)))]
	var tier := String(stats.get("size_tier", ""))
	var tier_name := CardDB.size_tier_name(StringName(tier)) if not tier.is_empty() else ""
	return "%s（半径%s）" % [tier_name, _format_card_number(float(stats.get("radius", 0.0)))] if not tier_name.is_empty() else _format_card_number(float(stats.get("radius", 0.0)))

func _card_passives(stats: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if bool(stats.get("is_continuous_attack", false)):
		result.append({"name": "龙息", "description": "持续造成每秒%s伤害，并对目标周围%s范围造成伤害。" % [_format_card_number(float(stats.get("damage", 0.0))), _format_card_number(float(stats.get("splash_radius", 0.0)))]})
	if stats.has("deploy_sweep_radius"):
		result.append({"name": "横扫千军", "description": "部署时击退%s半径内的地面敌人。" % _format_card_number(float(stats.get("deploy_sweep_radius", 0.0)))})
	if stats.has("heal_every_hits"):
		result.append({"name": "无畏战吼", "description": "每第%d次普通攻击命中回复%s点生命。" % [int(stats.get("heal_every_hits", 0)), _format_card_number(float(stats.get("heal_amount", 0.0))) ]})
	if stats.has("shroud_radius"):
		result.append({"name": "丝缕缠流", "description": "首次普攻命中后，%s半径外的敌人无法看见或锁定她。" % _format_card_number(float(stats.get("shroud_radius", 0.0)))})
	if int(stats.get("transform_after_hits", 0)) > 0:
		var transformed: Dictionary = stats.get("transformed_stats", {})
		result.append({
			"name": "狂怒基因",
			"description": "小纳尔完成%d次普攻后变大，大纳尔完成%d次普攻后变小；大形态生命上限为%s、体型为%s且只能近战地面目标。" % [
				int(stats.transform_after_hits),
				int(stats.get("revert_after_hits", 0)),
				_format_card_number(float(transformed.get("hp", 0.0))),
				CardDB.size_tier_name(StringName(transformed.get("size_tier", ""))),
			],
		})
	if stats.has("attack_pattern"):
		var combo_damage := float(stats.get("damage", 0.0))
		var combo_multipliers: Array = stats.get("attack_damage_multipliers", [])
		var left_damage := combo_damage
		var right_damage := combo_damage * 1.5
		if not combo_multipliers.is_empty():
			left_damage = combo_damage * float(combo_multipliers[0])
			if combo_multipliers.size() > 1:
				right_damage = combo_damage * float(combo_multipliers[1])
		var combo_pattern: Array = stats.get("attack_pattern", [])
		var punch_gap := float(combo_pattern[0]) if not combo_pattern.is_empty() else 0.0
		var pair_gap := float(stats.get("attack_interval_display", combo_pattern[1] if combo_pattern.size() > 1 else stats.get("interval", 0.0)))
		result.append({"name": "拳锋连击", "description": "左拳造成%s点伤害，右拳造成%s点伤害；两拳之间间隔%s秒，打完两拳后间隔%s秒，循环进行。" % [_format_card_number(left_damage), _format_card_number(right_damage), _format_card_number(punch_gap), _format_card_number(pair_gap)]})
	if String(stats.get("type", "unit")) == "building" and float(stats.get("spawn_interval", 0.0)) > 0.0:
		result.append({"name": "亡者召唤", "description": "部署完成生成%d只小鬼，之后每%s秒再次生成。" % [int(stats.get("spawn_count", 0)), _format_card_number(float(stats.get("spawn_interval", 0.0)))]})
	if int(stats.get("death_spawn_count", 0)) > 0 and not String(stats.get("death_spawn_id", "")).is_empty():
		var death_spawn_name := "小鬼" if String(stats.get("death_spawn_id", "")) == "imp" else String(stats.get("death_spawn_id", ""))
		result.append({"name": "亡语", "description": "被摧毁时产生%d只%s。" % [int(stats.get("death_spawn_count", 0)), death_spawn_name]})
	return result

func _make_card_passive_row(name: String, description: String) -> Label:
	var label := _make_card_info_body("%s：%s" % [name, description])
	label.custom_minimum_size = Vector2(0.0, 28.0)
	return label

func _active_choice_description(card_id: String) -> String:
	var skills := CardDB.active_skills_for(card_id)
	if skills.is_empty():
		var stats: Dictionary = CardDB.all()[card_id]
		if String(stats.get("type", "unit")) == "spell":
			var radius := float(stats.get("radius", 0.0))
			var duration := float(stats.get("duration", 0.0))
			var slow_duration := float(stats.get("active_slow_duration", 0.0))
			if slow_duration > 0.0:
				var slow_percent := roundi(float(stats.get("active_slow_multiplier", 1.0)) * 100.0)
				return "冻结半径%s（%.1f格）内的敌方单位，持续%s秒；冰冻结束后，范围内的敌军继续减速至%d%%，持续%s秒。" % [_format_card_number(radius), radius / TILE_SIZE, _format_card_number(duration), slow_percent, _format_card_number(slow_duration)]
			return "冻结半径%s（%.1f格）内的敌方单位，持续%s秒。" % [_format_card_number(radius), radius / TILE_SIZE, _format_card_number(duration)]
		return "该卡没有可携带的主动技能。"
	var selected := clampi(int(_active_skill_choices.get(card_id, 0)), 0, skills.size() - 1)
	return _active_skill_description(skills[selected])

func _active_skill_description(skill: Dictionary) -> String:
	var parts: Array[String] = []
	match String(skill.get("kind", "")):
		"nova":
			parts.append("以自身为中心，影响 %s 半径" % _format_card_number(float(skill.get("radius", 0.0))))
			if float(skill.get("damage", 0.0)) > 0.0:
				parts.append("造成 %s 伤害" % _format_card_number(float(skill.damage)))
			if float(skill.get("knockback", 0.0)) > 0.0:
				parts.append("击退 %s" % _format_card_number(float(skill.knockback)))
			if float(skill.get("slow_duration", 0.0)) > 0.0:
				parts.append("减速至 %d%%，持续 %s 秒" % [roundi(float(skill.get("slow_multiplier", 1.0)) * 100.0), _format_card_number(float(skill.slow_duration))])
		"buff":
			parts.append("持续 %s 秒" % _format_card_number(float(skill.get("duration", 0.0))))
			if float(skill.get("speed_multiplier", 1.0)) != 1.0:
				parts.append("移速 ×%.2f" % float(skill.speed_multiplier))
			if float(skill.get("damage_multiplier", 1.0)) != 1.0:
				parts.append("伤害 ×%.2f" % float(skill.damage_multiplier))
			if float(skill.get("attack_speed_multiplier", 1.0)) != 1.0:
				parts.append("攻速 ×%.2f" % float(skill.attack_speed_multiplier))
		"summon":
			parts.append("在自身周围立即召唤 %d 个单位" % int(skill.get("spawn_count", 1)))
		"dual_form":
			parts.append("小纳尔状态立即变大并释放 Spell2")
			parts.append("手掌触地时朝前方 %s×%s 区域造成 %s 伤害，并眩晕 %s 秒" % [
				_format_card_number(float(skill.get("width", 0.0))),
				_format_card_number(float(skill.get("length", 0.0))),
				_format_card_number(float(skill.get("damage", 0.0))),
				_format_card_number(float(skill.get("stun_duration", 0.0))),
			])
	if float(skill.get("shield", 0.0)) > 0.0:
		parts.append("获得 %s 点护盾，持续 %s 秒" % [_format_card_number(float(skill.shield)), _format_card_number(float(skill.get("shield_duration", 0.0)))])
	return "%s：%s。" % [String(skill.get("name", "主动技能")), "；".join(parts)]

func _on_info_active_skill_selected(skill_index: int, card_id: String) -> void:
	var skills := CardDB.active_skills_for(card_id)
	if skills.is_empty():
		return
	_active_skill_choices[card_id] = clampi(skill_index, 0, skills.size() - 1)
	if _deck_info_active_description != null:
		_deck_info_active_description.text = _active_choice_description(card_id)

func _on_info_skin_selected(skin_index: int, card_id: String, skins: Array) -> void:
	if skin_index < 0 or skin_index >= skins.size():
		return
	var skin: Dictionary = skins[skin_index]
	_skin_choices[card_id] = String(skin.get("id", "default"))

func _close_card_info() -> void:
	if _deck_info_overlay != null:
		_deck_info_overlay.queue_free()
		_deck_info_overlay = null
		_deck_info_active_option = null
		_deck_info_active_description = null
		_deck_info_skin_option = null

func _update_deck_ui() -> void:
	if _deck_status == null:
		return
	var selected_count := _selected_card_count()
	if _deck_pending_slot >= 0:
		_deck_status.text = "已选择 %d / 8　·　已选中第%d个卡槽，请点击下方卡牌　·　1、2 号为主动技能位" % [selected_count, _deck_pending_slot + 1]
	else:
		_deck_status.text = "已选择 %d / 8　·　点卡牌后选择信息或添加/移除　·　1、2 号为主动技能位" % selected_count
	var total_cost := 0.0
	for selected_id in _deck_selected:
		if not String(selected_id).is_empty():
			total_cost += float(CardDB.all()[selected_id].cost)
	if _deck_average_label != null:
		_deck_average_label.text = "平均金币  --" if selected_count == 0 else "平均金币  %.1f" % (total_cost / selected_count)
	for i in range(_deck_slot_buttons.size()):
		var slot: Button = _deck_slot_buttons[i]
		var card_id := String(_deck_selected[i]) if i < _deck_selected.size() else ""
		if not card_id.is_empty():
			var stats: Dictionary = CardDB.all()[card_id]
			slot.disabled = false
			var accent: Color = stats.get("color", CardArt.DEFAULT_ACCENT)
			CardArt.apply_to_button(slot, card_id, stats.name, stats.cost, false, accent)
			CardArt.set_selected(slot, not _deck_context_from_pool and _deck_context_slot == i and _deck_context_card_id == card_id)
			_set_active_slot_badge(slot, i < 2)
			slot.tooltip_text = ("主动技能位：点击查看信息或移除" if i < 2 else "普通卡位：点击查看信息或移除")
		else:
			slot.disabled = false
			CardArt.show_empty_slot(slot, i + 1)
			CardArt.set_selected(slot, _deck_pending_slot == i)
			_set_active_slot_badge(slot, i < 2)
	for id in _deck_toggles:
		var button: Button = _deck_toggles[id]
		button.disabled = false
		CardArt.set_selected(button, _deck_context_from_pool and _deck_context_card_id == id)
		button.tooltip_text = "%s · %d 金币 · 点击查看信息" % [CardDB.all()[id].name, int(CardDB.all()[id].cost)]
	var ready := selected_count == 8
	if _deck_confirm != null:
		_deck_confirm.disabled = not ready
		_deck_confirm.text = "开始对战" if ready else "请选择 8 张卡"

func _set_card_in_deck_badge(button: Button, in_deck: bool) -> void:
	var badge := button.get_node_or_null("InDeckBadge") as Label
	if badge == null:
		badge = Label.new()
		badge.name = "InDeckBadge"
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -54.0
		badge.offset_top = 5.0
		badge.offset_right = -4.0
		badge.offset_bottom = 29.0
		badge.text = "已加入"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_override("font", CardArt.ui_font())
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", Color(0.48, 1.0, 0.61))
		badge.add_theme_color_override("font_outline_color", Color(0.0, 0.08, 0.02))
		badge.add_theme_constant_override("outline_size", 4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(badge)
	badge.visible = in_deck
	button.move_child(badge, button.get_child_count() - 1)

func _confirm_deck(after_start: Callable) -> void:
	if _selected_card_count() != 8:
		return
	_deck = []
	for card_id in _deck_selected:
		if not String(card_id).is_empty():
			_deck.append(card_id)
	_clear_deck_ui()
	after_start.call()

func _clear_deck_ui() -> void:
	_close_card_info()
	if _deck_layer != null:
		_deck_layer.queue_free()
		_deck_layer = null
	_deck_toggles.clear()
	_deck_slot_buttons.clear()
	_deck_status = null
	_deck_confirm = null
	_deck_average_label = null
	_deck_ui_root = null
	_deck_pool_grid = null
	_deck_filter_option = null
	_deck_sort_option = null
	_deck_pending_slot = -1
	_deck_context_popup = null
	_deck_context_info = null
	_deck_context_action = null
	_deck_context_card_id = ""
	_deck_context_slot = -1
	_deck_context_from_pool = false
	_deck_context_anchor = null

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
	_hand.card_selected.connect(_on_card_selected)
	_active_skill_bar = ACTIVE_SKILL_BAR_SCRIPT.new()
	add_child(_active_skill_bar)
	_active_skill_bar.skill_pressed.connect(_on_active_skill_pressed)

func _is_local_player_team(p_team: int) -> bool:
	return p_team == (1 if mode == "client" else 0)

func _team_deck(p_team: int) -> Array:
	if mode == "host" and p_team == 1:
		return _remote_deck
	return _deck

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
	if _selected_card.is_empty() or not CardDB.all().has(_selected_card):
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
		var stats: Dictionary = CardDB.all()[_selected_card]
		if not _elixir.can_afford(stats.cost):
			return
		if not _deployment_preview_valid:
			return
		var used_card := _selected_card
		_selected_card = ""
		_clear_deployment_preview()
		_hand.clear_selection()
		queue_redraw()
		if mode == "client":
			# 客户端：只发请求，扣费与生成由主机权威处理
			_hand.card_used(used_card)
			_rpc_deploy_request.rpc_id(1, used_card, pos)
			return
		if not _elixir.spend(stats.cost):
			return
		_deploy_card(0, used_card, pos)
		_hand.card_used(used_card)

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
	if not CardDB.all().has(_art_dev_selection):
		return
	var stats: Dictionary = CardDB.all()[_art_dev_selection]
	pos = _snap_card_position(_art_dev_selection, pos, _art_dev_team)
	if stats.get("type", "unit") == "spell":
		_cast_spell(_art_dev_team, _art_dev_selection, pos)
	else:
		var unit := _spawn_unit(_art_dev_team, _art_dev_selection, pos)
		_art_dev_last_units[_art_dev_selection] = weakref(unit)

func _art_dev_selected_unit() -> Unit:
	var candidate_ref = _art_dev_last_units.get(_art_dev_selection)
	var candidate = (candidate_ref as WeakRef).get_ref() if candidate_ref is WeakRef else null
	if candidate is Unit and is_instance_valid(candidate) and candidate.hp > 0.0:
		return candidate as Unit
	return null

## 美术面板不消耗正式主动资格，允许对最后放置的同卡单位反复检查技能演出。
func _use_art_dev_active_skill() -> void:
	var unit := _art_dev_selected_unit()
	if unit == null or unit.is_form_transitioning() or unit.is_active_skill_casting():
		return
	var skills := CardDB.active_skills_for(_art_dev_selection)
	if skills.is_empty():
		return
	_apply_active_skill_effect(unit, skills[0])

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
	_projectiles.clear()
	_client_projectiles.clear()
	_freeze_effects.clear()
	_slow_zones.clear()
	_slow_effects.clear()
	_pending_frontal_stun_skills.clear()
	_frontal_skill_effects.clear()
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
	if not CardDB.all().has(card_id):
		return _snap_to_tile_center(pos)
	var stats: Dictionary = CardDB.all()[card_id]
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
	if not CardDB.all().has(card_id):
		return false
	pos = _snap_card_position(card_id, pos, p_team)
	var stats: Dictionary = CardDB.all()[card_id]
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
	var stats: Dictionary = CardDB.imp_stats() if card_id == "imp" else CardDB.all()[card_id]
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

func _deploy_card(p_team: int, card_id: String, pos: Vector2) -> void:
	# 玩家、AI 与联机请求统一进入 0.5 秒权威队列；召唤物走 _spawn_unit，不受此延迟影响。
	pos = _snap_card_position(card_id, pos, p_team)
	_pending_card_deployments.append({
		"team": p_team,
		"card_id": card_id,
		"pos": pos,
		"time_left": CARD_DEPLOY_DELAY,
	})

func _tick_pending_card_deployments(dt: float) -> void:
	var waiting: Array[Dictionary] = []
	var ready: Array[Dictionary] = []
	for deployment in _pending_card_deployments:
		var time_left := float(deployment.time_left) - dt
		if time_left > 0.001:
			deployment.time_left = time_left
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
	var stats: Dictionary = CardDB.all()[card_id]
	var type: String = stats.get("type", "unit")
	var active_slot := _active_card_slot_for_team(p_team, card_id)
	match type:
		"spell":
			_cast_spell(p_team, card_id, pos, active_slot >= 0)
		_:
			if type == "building":
				_push_units_around(pos, stats.get("radius", 14.0))
			_spawn_unit(p_team, card_id, pos, -1.0, active_slot)

## 单位/塔统一攻击出口：近战即时结算，远程生成主机权威弹道。
func launch_attack(attacker: Node2D, target: Node2D, amount: float, projectile_speed: float, splash_radius: float, knockback: float, projectile_color: Color) -> void:
	if target == null or not is_instance_valid(target) or target.hp <= 0.0:
		return
	# 丝缕缠流开启后，圈外攻击者连目标都看不到；这个出口再做一次竞态兜底。
	if target is Unit and (target as Unit).is_hidden_from(attacker):
		return
	var source_form_index := (attacker as Unit).form_index if attacker is Unit else -1
	if projectile_speed <= 0.0:
		_resolve_attack_hit(attacker.team, attacker.global_position, target, amount, splash_radius, knockback, attacker, attacker.global_position, source_form_index)
		return
	var direction := attacker.global_position.direction_to(target.global_position)
	var projectile_visual := &"orb"
	var projectile_visual_height := 0.0
	var visual_offset := Vector2.ZERO
	var visual_offset_follows_trajectory := false
	if attacker is Unit:
		projectile_visual = StringName((attacker as Unit).projectile_visual)
		projectile_visual_height = (attacker as Unit).projectile_visual_height
		var forward_offset := (attacker as Unit).projectile_visual_forward_offset
		if forward_offset > 0.0:
			# 只把第一帧画在权杖/炮口前方，随后沿航程平滑收敛到权威弹道。
			visual_offset = direction * forward_offset
			visual_offset_follows_trajectory = true
	elif attacker is Tower:
		# 塔的权威发射点仍是塔心；只把屏幕表现从权杖晶石处起步。
		projectile_visual = &"tower_orb"
		visual_offset = (attacker as Tower).projectile_visual_offset
		visual_offset_follows_trajectory = visual_offset.length_squared() > 0.001
	var start_position := attacker.global_position
	if projectile_visual == &"arrow" or projectile_visual == &"needle" or projectile_visual == &"boomerang":
		start_position += direction * (attacker.body_radius + PROJECTILE_MUZZLE_FORWARD_GAP)
	var id := _next_projectile_id
	_next_projectile_id += 1
	_projectiles[id] = {
		"pos": start_position,
		"target": target,
		"attacker": attacker,
		"source_form_index": source_form_index,
		"source_pos": attacker.global_position,
		"team": attacker.team,
		"damage": amount,
		"speed": projectile_speed,
		"splash": splash_radius,
		"knockback": knockback,
		"color": projectile_color,
		"radius": 7.0 if projectile_visual == &"tower_orb" else (3.0 if projectile_visual == &"arrow" else 4.0),
		"visual": projectile_visual,
		"visual_height": projectile_visual_height,
		"visual_offset": visual_offset,
		"visual_origin_offset": visual_offset,
		"visual_offset_follows_trajectory": visual_offset_follows_trajectory,
		"visual_launch_pos": start_position,
		"direction": direction,
	}

func _tick_projectiles(dt: float) -> void:
	var finished := []
	for id in _projectiles:
		var projectile: Dictionary = _projectiles[id]
		# 已释放对象不能先赋给类型化变量；先用 Variant 检查，再读取其属性。
		var target = projectile.get("target")
		if target == null or not is_instance_valid(target) or target.hp <= 0.0:
			finished.append(id)
			continue
		var attacker = projectile.get("attacker")
		if attacker != null and is_instance_valid(attacker):
			projectile.source_pos = attacker.global_position
		# 弹体在飞行途中遇到格温开启缠流：圈外来源立即失去目标，弹体消散且不结算伤害。
		if target is Unit and (target as Unit).is_hidden_from_position(projectile.team, projectile.source_pos):
			finished.append(id)
			continue
		var target_pos: Vector2 = target.global_position
		var pos: Vector2 = projectile.pos
		projectile.direction = pos.direction_to(target_pos)
		var next_pos := pos.move_toward(target_pos, projectile.speed * dt)
		projectile.pos = next_pos
		if projectile.get("visual_offset_follows_trajectory", false):
			var visual_launch_pos: Vector2 = projectile.get("visual_launch_pos", pos)
			var travel_distance := visual_launch_pos.distance_to(next_pos)
			var total_distance := maxf(visual_launch_pos.distance_to(target_pos), 1.0)
			var travel_ratio := clampf(travel_distance / total_distance, 0.0, 1.0)
			var visual_origin_offset: Vector2 = projectile.get("visual_origin_offset", Vector2.ZERO)
			projectile.visual_offset = visual_origin_offset * (1.0 - travel_ratio)
		_projectiles[id] = projectile
		if next_pos.distance_to(target_pos) <= target.body_radius + projectile.radius:
			# 攻击者可能已在弹体飞行途中被释放，命中仍结算，但以无来源处理，
			# 避免把已释放对象传入类型化函数参数。
			var hit_from: Node2D = projectile.attacker if (projectile.attacker != null and is_instance_valid(projectile.attacker)) else null
			_resolve_attack_hit(projectile.team, pos, target, projectile.damage, projectile.splash, projectile.knockback, hit_from, projectile.source_pos, int(projectile.get("source_form_index", -1)))
			finished.append(id)
	for id in finished:
		_projectiles.erase(id)

func _resolve_attack_hit(p_team: int, origin: Vector2, primary: Node2D, amount: float, radius: float, knockback: float, from: Node2D = null, source_position: Vector2 = Vector2(INF, INF), source_form_index: int = -1) -> void:
	if primary == null or not is_instance_valid(primary) or primary.hp <= 0.0:
		return
	if radius <= 0.0:
		var landed: bool = primary.take_damage(amount, from, p_team, source_position)
		if landed and from is Unit and is_instance_valid(from):
			(from as Unit).on_attack_landed(source_form_index)
		if landed and knockback > 0.0 and primary is Unit and is_instance_valid(primary) and primary.hp > 0.0:
			(primary as Unit).apply_knockback(origin, knockback)
		return
	var impact_pos := primary.global_position
	var any_landed := false
	for c in get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(c) or c.team == p_team or c.hp <= 0.0:
			continue
		if c.global_position.distance_to(impact_pos) <= radius + c.body_radius:
			var landed: bool = c.take_damage(amount, from, p_team, source_position)
			any_landed = landed or any_landed
			if landed and knockback > 0.0 and c is Unit and is_instance_valid(c) and c.hp > 0.0:
				(c as Unit).apply_knockback(origin, knockback)
	if any_landed and from is Unit and is_instance_valid(from):
		(from as Unit).on_attack_landed(source_form_index)

func _cast_spell(p_team: int, card_id: String, pos: Vector2, active_enabled: bool = false) -> void:
	match card_id:
		"freeze":
			var stats: Dictionary = CardDB.all()["freeze"]
			var radius: float = stats.radius
			var duration: float = stats.duration
			var slow_duration: float = stats.active_slow_duration if active_enabled else 0.0
			var slow_multiplier: float = stats.active_slow_multiplier
			_apply_freeze(pos, radius, duration, p_team, slow_duration, slow_multiplier)
			# 主机：同步冰冻视觉效果给客户端
			if mode == "host":
				_rpc_freeze_fx.rpc(pos, radius, duration, slow_duration, slow_multiplier)

func _apply_freeze(pos: Vector2, radius: float, duration: float, p_team: int, slow_duration: float = 0.0, slow_multiplier: float = 1.0) -> void:
	# 记录视觉效果
	_freeze_effects.append({"pos": pos, "timer": duration, "duration": duration, "radius": radius})
	if slow_duration > 0.0:
		_slow_zones.append({"pos": pos, "radius": radius, "delay": duration, "timer": slow_duration, "team": p_team, "multiplier": slow_multiplier})
		_slow_effects.append({"pos": pos, "radius": radius, "delay": duration, "timer": slow_duration, "duration": slow_duration})
	for c in get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(c) or c.team == p_team or c.hp <= 0.0:
			continue
		# 法术圆与目标碰撞圆相交即命中，而不是只判断目标中心点。
		if c.global_position.distance_to(pos) <= radius + c.body_radius:
			if c is Unit:
				(c as Unit).freeze(duration)
			elif c is Tower:
				(c as Tower).freeze(duration)

func _tick_slow_zones(dt: float) -> void:
	var alive: Array[Dictionary] = []
	for zone in _slow_zones:
		if float(zone.delay) > 0.0:
			zone.delay = maxf(0.0, float(zone.delay) - dt)
			alive.append(zone)
			continue
		zone.timer = maxf(0.0, float(zone.timer) - dt)
		for c in get_tree().get_nodes_in_group("combatants"):
			if not c is Unit or not is_instance_valid(c) or c.team == int(zone.team) or c.hp <= 0.0:
				continue
			if c.global_position.distance_to(zone.pos) <= float(zone.radius) + c.body_radius:
				(c as Unit).apply_slow(dt + SIM_DT, float(zone.multiplier))
		if float(zone.timer) > 0.0:
			alive.append(zone)
	_slow_zones = alive

func _tick_slow_effect_visuals(delta: float) -> void:
	for effect in _slow_effects:
		if float(effect.delay) > 0.0:
			effect.delay = maxf(0.0, float(effect.delay) - delta)
		else:
			effect.timer = maxf(0.0, float(effect.timer) - delta)
	_slow_effects = _slow_effects.filter(func(effect): return float(effect.delay) > 0.0 or float(effect.timer) > 0.0)

func _spawn_unit(team: int, card_id: String, pos: Vector2, deploy_time_override: float = -1.0, active_slot: int = -1) -> Unit:
	var stats: Dictionary = CardDB.imp_stats() if card_id == "imp" else CardDB.all()[card_id]
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
	if unit.active_ability_id < 0 or unit.active_ability_slot < 0 or unit.active_ability_slot >= 2 or not CardDB.all().has(card_id):
		return
	var stats: Dictionary = CardDB.all()[card_id]
	var available_skills := CardDB.active_skills_for(card_id)
	if available_skills.is_empty():
		return
	# 备战信息页只允许从候选集合中携带一个；场上实例不会同时获得多个主动技能。
	var chosen_skill_index := _active_skill_choice_for_team(p_team, card_id, available_skills.size())
	var carried_skill: Dictionary = available_skills[chosen_skill_index]
	var ability_id := unit.active_ability_id
	var active_slot := unit.active_ability_slot
	# 每个主动槽始终只控制最近部署的实例。新实例落地时，旧实例的未用资格立即作废。
	var replaced_id := -1
	for existing_id in _active_skills:
		var existing: Dictionary = _active_skills[existing_id]
		if int(existing.team) == p_team and int(existing.slot) == active_slot:
			replaced_id = int(existing_id)
			break
	if replaced_id >= 0:
		var replaced: Dictionary = _active_skills[replaced_id]
		var replaced_unit: Unit = replaced.unit
		if replaced_unit != null and is_instance_valid(replaced_unit):
			replaced_unit.active_ability_id = -1
			replaced_unit.active_ability_slot = -1
		_active_skills.erase(replaced_id)
		_cancel_pending_active_skill(replaced_id)
		if _active_skill_bar != null:
			_active_skill_bar.remove_skill(replaced_id)
	_active_skills[ability_id] = {"unit": unit, "card_id": card_id, "team": p_team, "slot": active_slot, "skill": carried_skill}
	unit.died.connect(_on_active_skill_unit_died.bind(ability_id), CONNECT_ONE_SHOT)
	if _is_local_player_team(p_team) and _active_skill_bar != null:
		_active_skill_bar.show_skill(active_slot, ability_id, String(stats.name), String(carried_skill.name), stats.get("color", CardArt.DEFAULT_ACCENT))
	# 单机 AI 也携带卡组前两槽的技能；占位 AI 同样经过 0.5 秒待释放窗口。
	if mode == "local" and p_team == 1:
		call_deferred("_queue_active_skill", ability_id, p_team, 0)

func _on_active_skill_unit_died(ability_id: int) -> void:
	_active_skills.erase(ability_id)
	_cancel_pending_active_skill(ability_id)
	if _active_skill_bar != null:
		_active_skill_bar.remove_skill(ability_id)

func _on_active_skill_pressed(ability_id: int) -> void:
	if mode == "client":
		_rpc_active_skill_request.rpc_id(1, ability_id)
		return
	if not _queue_active_skill(ability_id, 0, 0) and _active_skill_bar != null:
		_active_skill_bar.set_pending(ability_id, false)

func _queue_active_skill(ability_id: int, expected_team: int = -1, requester_peer_id: int = 0) -> bool:
	if game_over or not _active_skills.has(ability_id):
		return false
	for pending in _pending_active_skill_activations:
		if int(pending.ability_id) == ability_id:
			return false
	var entry: Dictionary = _active_skills[ability_id]
	var unit: Unit = entry.unit
	var p_team := int(entry.team)
	var card_id := String(entry.card_id)
	if unit == null or not is_instance_valid(unit) or unit.hp <= 0.0:
		return false
	if expected_team >= 0 and p_team != expected_team:
		return false
	if not _card_has_active_for_team(p_team, card_id):
		return false
	# 变形演出期间主动技能也视作攻击类动作，拒绝并保留按钮，避免打断形态序列。
	if unit.is_form_transitioning() or unit.is_active_skill_casting():
		return false
	_pending_active_skill_activations.append({
		"ability_id": ability_id,
		"team": p_team,
		"requester_peer_id": requester_peer_id,
		"time_left": ACTIVE_SKILL_CAST_DELAY,
	})
	return true

func _tick_pending_active_skills(dt: float) -> void:
	var waiting: Array[Dictionary] = []
	var ready: Array[Dictionary] = []
	for pending in _pending_active_skill_activations:
		pending.time_left = float(pending.time_left) - dt
		if float(pending.time_left) > 0.001:
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

func _activate_active_skill(ability_id: int, expected_team: int = -1) -> bool:
	if not _active_skills.has(ability_id):
		return false
	var entry: Dictionary = _active_skills[ability_id]
	var unit: Unit = entry.unit
	var p_team := int(entry.team)
	var card_id := String(entry.card_id)
	if unit == null or not is_instance_valid(unit) or unit.hp <= 0.0:
		_on_active_skill_unit_died(ability_id)
		return false
	if expected_team >= 0 and p_team != expected_team:
		return false
	if not _card_has_active_for_team(p_team, card_id):
		return false
	var skill: Dictionary = entry.skill
	if not _apply_active_skill_effect(unit, skill):
		return false
	unit.active_ability_id = -1
	unit.active_ability_slot = -1
	_active_skills.erase(ability_id)
	if _active_skill_bar != null:
		_active_skill_bar.remove_skill(ability_id)
	if mode == "host":
		_rpc_active_skill_used.rpc(ability_id)
	return true

func _apply_active_skill_effect(unit: Unit, skill: Dictionary) -> bool:
	match String(skill.kind):
		"buff":
			unit.apply_active_buff(
				float(skill.get("duration", 0.0)),
				float(skill.get("speed_multiplier", 1.0)),
				float(skill.get("damage_multiplier", 1.0)),
				float(skill.get("attack_speed_multiplier", 1.0))
			)
			unit.add_shield(float(skill.get("shield", 0.0)), float(skill.get("shield_duration", skill.get("duration", 0.0))))
		"nova":
			_activate_nova_skill(unit, skill)
		"summon":
			_activate_summon_skill(unit, skill)
		"dual_form":
			_activate_dual_form_skill(unit, skill)
		_:
			return false
	return true

func _activate_nova_skill(source: Unit, skill: Dictionary) -> void:
	var radius := float(skill.get("radius", 0.0))
	var amount := float(skill.get("damage", 0.0))
	var knockback := float(skill.get("knockback", 0.0))
	var slow_duration := float(skill.get("slow_duration", 0.0))
	var skill_slow_multiplier := float(skill.get("slow_multiplier", 1.0))
	for c in get_tree().get_nodes_in_group("combatants"):
		if c == source or not is_instance_valid(c) or c.team == source.team or c.hp <= 0.0:
			continue
		if c.global_position.distance_to(source.global_position) > radius + c.body_radius:
			continue
		if amount > 0.0:
			c.take_damage(amount, source, source.team, source.global_position)
		if c is Unit and is_instance_valid(c) and c.hp > 0.0:
			if knockback > 0.0:
				(c as Unit).apply_knockback(source.global_position, knockback)
			if slow_duration > 0.0:
				(c as Unit).apply_slow(slow_duration, skill_slow_multiplier)
	source.add_shield(float(skill.get("shield", 0.0)), float(skill.get("shield_duration", 0.0)))

func _activate_summon_skill(source: Unit, skill: Dictionary) -> void:
	var spawn_id := String(skill.get("spawn_id", "imp"))
	var count := maxi(int(skill.get("spawn_count", 1)), 1)
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		var offset := Vector2.RIGHT.rotated(angle) * (source.body_radius + 18.0)
		spawn_summoned(source.team, spawn_id, source.global_position + offset)

func _activate_dual_form_skill(source: Unit, skill: Dictionary) -> void:
	var cast_forward := _frontal_skill_forward(source)
	if source.form_index == 0:
		source.transform_to_mega(true)
		_activate_frontal_stun_skill(
			source, skill, false,
			float(skill.get("transform_impact_delay", 0.9)),
			float(skill.get("transform_cast_duration", 1.3)),
			cast_forward
		)
		return
	_activate_frontal_stun_skill(
		source, skill, true,
		float(skill.get("impact_delay", 0.8)),
		float(skill.get("cast_duration", 1.2)),
		cast_forward
	)

## Spell2 先启动动画和无近端边线的矩形预警；固定模拟到手掌触地时才结算伤害/眩晕。
func _activate_frontal_stun_skill(source: Unit, skill: Dictionary, play_action: bool = true, impact_delay: float = -1.0, cast_duration: float = -1.0, cast_forward: Vector2 = Vector2.ZERO) -> void:
	if impact_delay < 0.0:
		impact_delay = maxf(float(skill.get("impact_delay", 0.8)), 0.0)
	else:
		impact_delay = maxf(impact_delay, 0.0)
	if cast_duration < 0.0:
		cast_duration = maxf(float(skill.get("cast_duration", 1.2)), 0.0)
	else:
		cast_duration = maxf(cast_duration, 0.0)
	if cast_forward.length_squared() < 0.001:
		cast_forward = _frontal_skill_forward(source)
	else:
		cast_forward = cast_forward.normalized()
	source.begin_active_skill_cast(cast_duration, cast_forward)
	if play_action:
		source.play_visual_action(&"active")
	_pending_frontal_stun_skills.append({
		"source_ref": weakref(source),
		"skill": skill.duplicate(true),
		"forward": cast_forward,
		"time_left": impact_delay,
	})
	_add_frontal_skill_effect(source, skill, impact_delay, cast_forward)
	if mode == "host":
		_rpc_frontal_skill_fx.rpc(
			source.net_id,
			source.global_position,
			cast_forward,
			source.body_radius,
			float(skill.get("length", 0.0)),
			float(skill.get("width", 0.0)),
			impact_delay,
			source.team,
		)

func _tick_pending_frontal_stun_skills(dt: float) -> void:
	var waiting: Array[Dictionary] = []
	for pending in _pending_frontal_stun_skills:
		var source = (pending.source_ref as WeakRef).get_ref()
		if not source is Unit or not is_instance_valid(source) or source.hp <= 0.0:
			continue
		if source.frozen_timer > 0.0 or source.stun_timer > 0.0:
			waiting.append(pending)
			continue
		pending.time_left = maxf(0.0, float(pending.time_left) - dt)
		if float(pending.time_left) > 0.001:
			waiting.append(pending)
			continue
		_apply_frontal_stun_impact(source as Unit, pending.skill, pending.forward)
	_pending_frontal_stun_skills = waiting

func _apply_frontal_stun_impact(source: Unit, skill: Dictionary, forward: Vector2) -> void:
	forward = forward.normalized()
	var side := Vector2(-forward.y, forward.x)
	var length := maxf(float(skill.get("length", 0.0)), 0.0)
	var half_width := maxf(float(skill.get("width", 0.0)) * 0.5, 0.0)
	var amount := maxf(float(skill.get("damage", 0.0)), 0.0)
	var stun_duration := maxf(float(skill.get("stun_duration", 0.0)), 0.0)
	var ground_only := bool(skill.get("ground_only", true))
	for c in get_tree().get_nodes_in_group("combatants"):
		if c == source or not is_instance_valid(c) or c.team == source.team or c.hp <= 0.0:
			continue
		if ground_only and c is Unit and (c as Unit).is_air:
			continue
		var local_offset: Vector2 = c.global_position - source.global_position
		var forward_distance := local_offset.dot(forward) - source.body_radius
		var lateral_distance := absf(local_offset.dot(side))
		if forward_distance < -c.body_radius or forward_distance > length + c.body_radius:
			continue
		if lateral_distance > half_width + c.body_radius:
			continue
		if amount > 0.0:
			c.take_damage(amount, source, source.team, source.global_position)
		if is_instance_valid(c) and c.hp > 0.0 and stun_duration > 0.0 and c.has_method("stun"):
			c.stun(stun_duration)

func _frontal_skill_forward(source: Unit) -> Vector2:
	var forward := source.get_visual_facing_direction()
	if forward.length_squared() < 0.001:
		forward = Vector2.UP if source.team == 0 else Vector2.DOWN
	return forward.normalized()

func _add_frontal_skill_effect(source: Unit, skill: Dictionary, duration: float, cast_forward: Vector2) -> void:
	_frontal_skill_effects.append({
		"source_ref": weakref(source),
		"net_id": source.net_id,
		"pos": source.global_position,
		"forward": cast_forward,
		"source_radius": source.body_radius,
		"length": maxf(float(skill.get("length", 0.0)), 0.0),
		"width": maxf(float(skill.get("width", 0.0)), 0.0),
		"timer": duration,
		"duration": duration,
		"team": source.team,
	})

func _tick_frontal_skill_effect_visuals(delta: float) -> void:
	for effect in _frontal_skill_effects:
		var source = _frontal_skill_effect_source(effect)
		if source is Unit and (source.frozen_timer > 0.0 or source.stun_timer > 0.0):
			continue
		effect.timer = maxf(0.0, float(effect.timer) - delta)
	_frontal_skill_effects = _frontal_skill_effects.filter(func(effect): return float(effect.timer) > 0.001)

func _frontal_skill_effect_source(effect: Dictionary):
	var source = null
	var source_ref = effect.get("source_ref")
	if source_ref is WeakRef:
		source = (source_ref as WeakRef).get_ref()
	if (source == null or not is_instance_valid(source)) and mode == "client":
		source = _client_units.get(int(effect.get("net_id", -1)))
	return source

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
	var stats: Dictionary = CardDB.all()[card_id]
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
	_tick_pending_card_deployments(dt)
	_tick_pending_active_skills(dt)
	_tick_pending_frontal_stun_skills(dt)
	_tick_slow_zones(dt)
	if not _art_dev_mode and _minion_waves_enabled:
		_tick_minion_waves(dt)
	for c in get_tree().get_nodes_in_group("combatants"):
		if c.has_method("sim_tick"):
			c.sim_tick(dt)
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
			_activate_dual_form_skill(auto_gnar, CardDB.all()["gnar"].active_skill)
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
	# 客户端：只更新冰冻视觉与重绘，逻辑状态全靠主机快照
	if mode == "client":
		for id in _client_projectiles:
			var projectile: Dictionary = _client_projectiles[id]
			projectile.pos = (projectile.pos as Vector2).lerp(projectile.target_pos, minf(delta * 14.0, 1.0))
			var visual_offset: Vector2 = projectile.get("visual_offset", Vector2.ZERO)
			var target_visual_offset: Vector2 = projectile.get("target_visual_offset", Vector2.ZERO)
			projectile.visual_offset = visual_offset.lerp(target_visual_offset, minf(delta * 14.0, 1.0))
			_client_projectiles[id] = projectile
		for fe in _freeze_effects:
			fe.timer -= delta
		_freeze_effects = _freeze_effects.filter(func(fe): return fe.timer > 0.0)
		_tick_slow_effect_visuals(delta)
		_tick_frontal_skill_effect_visuals(delta)
		queue_redraw()
		return
	if _art_dev_mode:
		for fe in _freeze_effects:
			fe.timer -= delta
		_freeze_effects = _freeze_effects.filter(func(fe): return fe.timer > 0.0)
		_tick_slow_effect_visuals(delta)
		_tick_frontal_skill_effect_visuals(delta)
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
	_tick_frontal_skill_effect_visuals(delta)
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
		if not CardDB.all().has(card_id) or not bool(CardDB.all()[card_id].get("selectable", true)) or card_id in validated:
			return
		validated.append(card_id)
	_remote_deck = validated
	_remote_active_skill_choices.clear()
	for card_id in validated:
		var skills := CardDB.active_skills_for(card_id)
		if not skills.is_empty():
			_remote_active_skill_choices[card_id] = clampi(int(active_skill_choices.get(card_id, 0)), 0, skills.size() - 1)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_active_skill_request(ability_id: int) -> void:
	if mode != "host" or game_over:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _queue_active_skill(ability_id, 1, sender):
		_rpc_active_skill_rejected.rpc_id(sender, ability_id)

@rpc("authority", "call_remote", "reliable")
func _rpc_active_skill_used(ability_id: int) -> void:
	if mode != "client":
		return
	if _active_skills.has(ability_id):
		var entry: Dictionary = _active_skills[ability_id]
		var unit: Unit = entry.unit
		if unit != null and is_instance_valid(unit):
			unit.active_ability_id = -1
			unit.active_ability_slot = -1
	_active_skills.erase(ability_id)
	if _active_skill_bar != null:
		_active_skill_bar.remove_skill(ability_id)

@rpc("authority", "call_remote", "reliable")
func _rpc_active_skill_rejected(ability_id: int) -> void:
	if mode == "client" and _active_skill_bar != null:
		_active_skill_bar.set_pending(ability_id, false)

## 客户端 → 主机：部署请求（主机校验区域/占位/费用后进入 0.5 秒权威队列）
@rpc("any_peer", "call_remote", "reliable")
func _rpc_deploy_request(card_id: String, pos: Vector2) -> void:
	if mode != "host" or game_over:
		return
	if not CardDB.all().has(card_id):
		return
	pos = _snap_card_position(card_id, pos, 1)
	var stats: Dictionary = CardDB.all()[card_id]
	# 未来若加入纯系统单位，客户端不能绕过卡池伪造部署请求。
	if not bool(stats.get("selectable", true)):
		return
	if _remote_deck.size() != 8 or card_id not in _remote_deck:
		return
	if not is_card_deploy_position_valid(1, card_id, pos):
		return
	if _elixir_p1 == null or not _elixir_p1.spend(stats.cost):
		return
	_deploy_card(1, card_id, pos)

## 主机 → 客户端：单位生成
@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_unit(card_id: String, p_team: int, pos: Vector2, net_id: int, deploy_time_override: float = -1.0, active_ability_id: int = -1, active_ability_slot: int = -1) -> void:
	if mode != "client":
		return
	var stats: Dictionary = CardDB.imp_stats() if card_id == "imp" else CardDB.all()[card_id]
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
	if mode != "client":
		return
	var raw_bytes := snapshot_bytes.decompress_dynamic(1024 * 1024, FileAccess.COMPRESSION_DEFLATE)
	if raw_bytes.is_empty():
		return
	var decoded = bytes_to_var(raw_bytes)
	if not decoded is Array or decoded.size() < 7:
		return
	var units_data: Array = decoded[0]
	var projectiles_data: Array = decoded[1]
	var towers_data: Array = decoded[2]
	var _e0 := float(decoded[3])
	var e1 := float(decoded[4])
	var mt := float(decoded[5])
	var ot := bool(decoded[6])
	var seen := {}
	for d in units_data:
		seen[d[0]] = true
		var u: Unit = _client_units.get(d[0])
		if u == null or not is_instance_valid(u):
			continue
		u.net_target_pos = Vector2(d[1], d[2])
		if d.size() >= 23:
			u.sync_network_form(int(d[15]), int(d[22]))
		elif d.size() >= 16:
			u.sync_network_form(int(d[15]))
		u.hp = d[3]
		u.frozen_timer = 0.15 if d[4] == 1 else 0.0
		u._charged = d[5] == 1
		if d.size() >= 8:
			u.net_visual_state = d[6]
			u.net_facing_x = d[7]
		if d.size() >= 9:
			u.net_attack_visual_serial = d[8]
		if d.size() >= 10:
			u.net_shroud_active = d[9] == 1
		if d.size() >= 13:
			u.net_has_continuous_target = d[10] == 1
			u.net_continuous_target_pos = Vector2(d[11], d[12])
			if _auto_test and not _auto_continuous_target_seen and u.net_has_continuous_target:
				_auto_continuous_target_seen = true
				print("[测试] 客户端已收到持续吐息目标端点")
		if d.size() >= 15:
			u.net_shield_active = d[13] == 1
			u.net_slow_active = d[14] == 1
		if d.size() >= 19:
			u.net_stun_active = d[16] == 1
			u.stun_timer = 0.15 if u.net_stun_active else 0.0
			var action_serial := int(d[17])
			if action_serial >= u.net_visual_action_serial:
				u.net_visual_action_serial = action_serial
				u.net_visual_action_name = StringName(d[18])
		if d.size() >= 21:
			u.net_facing_direction = Vector2(d[19], d[20])
		if d.size() >= 22:
			u.net_attacking_structure = d[21] == 1
		if (
			_auto_test and not _auto_gnar_form_seen and u.card_id == "gnar"
			and u.form_index == 1 and u.net_visual_action_name == &"transform_active"
			and u.net_facing_direction.length_squared() > 0.001
		):
			_auto_gnar_form_seen = true
			print("[测试] 客户端已收到纳尔大形态、主动变形动作与完整朝向快照")
		if (
			_auto_test and not _auto_gnar_revert_seen and u.card_id == "gnar"
			and u.form_index == 0 and u.net_form_change_serial >= 2
			and u.net_visual_action_name == &"revert"
		):
			_auto_gnar_revert_seen = true
			print("[测试] 客户端已收到纳尔回到小形态的递增序号与变小动作快照")
		u.queue_redraw()
	# 快照中消失的单位 = 已死亡
	var gone := []
	for id in _client_units:
		if not seen.has(id):
			gone.append(id)
	for id in gone:
		var u: Unit = _client_units[id]
		if is_instance_valid(u):
			if u.is_building and not u.nav_cells.is_empty():
				unblock_nav_cells(u.nav_cells)
				u.nav_cells = []
			u.notify_visual_death()
			u.queue_free()
		_client_units.erase(id)
	var seen_projectiles := {}
	if _auto_test and not _auto_projectile_seen and not projectiles_data.is_empty():
		_auto_projectile_seen = true
		print("[测试] 客户端已收到弹道快照")
	for d in projectiles_data:
		seen_projectiles[d[0]] = true
		var projectile: Dictionary = _client_projectiles.get(d[0], {
			"pos": Vector2(d[1], d[2]),
			"target_pos": Vector2(d[1], d[2]),
			"color": d[3],
			"radius": d[4],
			"visual": StringName(d[5]) if d.size() >= 6 else &"orb",
			"direction": Vector2(d[6], d[7]) if d.size() >= 8 else Vector2.UP,
			"visual_height": float(d[8]) if d.size() >= 9 else 0.0,
			"visual_offset": Vector2(d[9], d[10]) if d.size() >= 11 else Vector2.ZERO,
			"target_visual_offset": Vector2(d[9], d[10]) if d.size() >= 11 else Vector2.ZERO,
		})
		projectile.target_pos = Vector2(d[1], d[2])
		projectile.color = d[3]
		projectile.radius = d[4]
		if d.size() >= 6:
			projectile.visual = StringName(d[5])
		if d.size() >= 8:
			projectile.direction = Vector2(d[6], d[7])
		if d.size() >= 9:
			projectile.visual_height = float(d[8])
		if d.size() >= 11:
			projectile.target_visual_offset = Vector2(d[9], d[10])
		_client_projectiles[d[0]] = projectile
	var gone_projectiles := []
	for id in _client_projectiles:
		if not seen_projectiles.has(id):
			gone_projectiles.append(id)
	for id in gone_projectiles:
		_client_projectiles.erase(id)
	for i in range(mini(towers_data.size(), _towers.size())):
		var tower_was_alive := _towers[i].hp > 0.0
		_towers[i].hp = towers_data[i][0]
		_towers[i].activated = towers_data[i][1] == 1
		if towers_data[i].size() >= 3:
			_towers[i].stun_timer = 0.15 if towers_data[i][2] == 1 else 0.0
		if tower_was_alive and _towers[i].hp <= 0.0:
			_towers[i].notify_visual_destroyed()
		if _towers[i].hp <= 0.0 and not _towers[i].nav_cells.is_empty():
			unblock_nav_cells(_towers[i].nav_cells)
			_towers[i].nav_cells = []
		_towers[i].queue_redraw()
	# 客户端玩家是 team1，金币显示 e1
	_elixir.elixir = e1
	_match_timer = mt
	_overtime = ot
	_update_timer_label()
	_update_elixir_rate()
	_snapshots_received += 1
	if _auto_test and _snapshots_received % 40 == 0:
		print("[测试] 客户端已收快照 ", _snapshots_received, " 份，单位数=", _client_units.size(), " 弹道数=", _client_projectiles.size())

## 主机 → 客户端：冰冻法术视觉
@rpc("authority", "call_remote", "reliable")
func _rpc_freeze_fx(pos: Vector2, radius: float, duration: float, slow_duration: float = 0.0, _slow_multiplier: float = 1.0) -> void:
	if mode != "client":
		return
	_freeze_effects.append({"pos": pos, "timer": duration, "duration": duration, "radius": radius})
	if slow_duration > 0.0:
		_slow_effects.append({"pos": pos, "radius": radius, "delay": duration, "timer": slow_duration, "duration": slow_duration})

## 主机 → 客户端：纳尔 Spell2 蓄力范围。客户端只画框，伤害和眩晕仍由主机快照体现。
@rpc("authority", "call_remote", "reliable")
func _rpc_frontal_skill_fx(net_id: int, pos: Vector2, forward: Vector2, source_radius: float, length: float, width: float, duration: float, p_team: int) -> void:
	if mode != "client":
		return
	_frontal_skill_effects.append({
		"source_ref": null,
		"net_id": net_id,
		"pos": pos,
		"forward": forward.normalized(),
		"source_radius": source_radius,
		"length": length,
		"width": width,
		"timer": duration,
		"duration": duration,
		"team": p_team,
	})
	if _auto_test and not _auto_gnar_skill_fx_seen:
		_auto_gnar_skill_fx_seen = true
		print("[测试] 客户端已收到纳尔固定方向 Spell2 三边范围框")

## 主机 → 客户端：比赛结束
@rpc("authority", "call_remote", "reliable")
func _rpc_end(text: String) -> void:
	if mode != "client":
		return
	_end_game(text)

## 主机端：组装并发送快照
func _send_snapshot() -> void:
	var units_data := []
	var dead := []
	for id in _net_units:
		# 非类型化读取：单位可能已 queue_free，类型化赋值会先于有效性检查报错
		var u = _net_units.get(id)
		if u == null or not is_instance_valid(u) or u.hp <= 0.0:
			dead.append(id)
			continue
		var has_continuous_target: bool = u.has_continuous_visual_target()
		var continuous_target_pos: Vector2 = u.get_continuous_visual_target_position()
		var facing_direction: Vector2 = u.get_visual_facing_direction()
		units_data.append([
			id, u.global_position.x, u.global_position.y, u.hp,
			1 if u.frozen_timer > 0.0 else 0, 1 if u.is_charged() else 0,
			u.get_visual_state_code(), u.get_facing_x(), u.get_attack_visual_serial(),
			1 if u._shroud_active else 0,
			1 if has_continuous_target else 0, continuous_target_pos.x, continuous_target_pos.y,
			1 if u.shield_hp > 0.0 else 0, 1 if u.slow_timer > 0.0 else 0,
			u.form_index, 1 if u.stun_timer > 0.0 else 0,
			u.get_visual_action_serial(), String(u.get_visual_action_name()),
			facing_direction.x, facing_direction.y,
			1 if u.is_attacking_structure_visual() else 0,
			u.form_change_serial,
		])
	for id in dead:
		_net_units.erase(id)
	var towers_data := []
	for t in _towers:
		# [血量, 国王塔是否已激活, 是否眩晕]
		towers_data.append([t.hp, 1 if t.activated else 0, 1 if t.stun_timer > 0.0 else 0])
	var projectiles_data := []
	for id in _projectiles:
		var projectile: Dictionary = _projectiles[id]
		var visual_offset: Vector2 = projectile.get("visual_offset", Vector2.ZERO)
		projectiles_data.append([
			id, projectile.pos.x, projectile.pos.y, projectile.color, projectile.radius,
			String(projectile.visual), projectile.direction.x, projectile.direction.y,
			projectile.get("visual_height", 0.0), visual_offset.x, visual_offset.y,
		])
	var snapshot_bytes := var_to_bytes([
		units_data, projectiles_data, towers_data,
		_elixir.elixir, _elixir_p1.elixir, _match_timer, _overtime,
	]).compress(FileAccess.COMPRESSION_DEFLATE)
	_rpc_snapshot.rpc(snapshot_bytes)

func _draw() -> void:
	# 完整 720x1400 地图（含手牌区后方场外风景）；3D 表现视口继续透明叠加。
	draw_texture(ARENA_BACKGROUND_TEXTURE, Vector2.ZERO)
	# 选中卡牌时高亮可部署区域
	if _selected_card != "":
		var sel_stats: Dictionary = CardDB.all()[_selected_card]
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
	for effect in _frontal_skill_effects:
		_draw_frontal_skill_effect(effect)
	var visible_projectiles: Dictionary = _client_projectiles if mode == "client" else _projectiles
	for id in visible_projectiles:
		var projectile: Dictionary = visible_projectiles[id]
		match StringName(projectile.get("visual", &"orb")):
			&"tower_orb":
				_draw_tower_orb_projectile(projectile)
			&"arrow":
				_draw_arrow_projectile(projectile)
			&"needle":
				_draw_needle_projectile(projectile)
			&"boomerang":
				_draw_boomerang_projectile(projectile)
			_:
				draw_circle(projectile.pos, projectile.radius, projectile.color)

func _draw_frontal_skill_effect(effect: Dictionary) -> void:
	var source = _frontal_skill_effect_source(effect)
	var center: Vector2 = effect.get("pos", Vector2.ZERO)
	var forward: Vector2 = effect.get("forward", Vector2.UP)
	var source_radius := float(effect.get("source_radius", 0.0))
	if source is Unit and is_instance_valid(source):
		center = (source as Unit).get_visual_screen_position()
		source_radius = (source as Unit).body_radius
	if forward.length_squared() < 0.001:
		return
	forward = forward.normalized()
	var side := Vector2(-forward.y, forward.x)
	var half_width := maxf(float(effect.get("width", 0.0)) * 0.5, 0.0)
	var near_center := center + forward * source_radius
	var far_center := near_center + forward * maxf(float(effect.get("length", 0.0)), 0.0)
	var near_left := near_center - side * half_width
	var near_right := near_center + side * half_width
	var far_left := far_center - side * half_width
	var far_right := far_center + side * half_width
	var remaining_ratio := clampf(float(effect.get("timer", 0.0)) / maxf(float(effect.get("duration", 0.0)), 0.001), 0.0, 1.0)
	var line_color := Color(0.28, 0.68, 1.0, 0.9) if int(effect.get("team", 0)) == 0 else Color(1.0, 0.34, 0.24, 0.9)
	var fill_color := Color(line_color.r, line_color.g, line_color.b, 0.10 + 0.06 * remaining_ratio)
	draw_colored_polygon(PackedVector2Array([near_left, far_left, far_right, near_right]), fill_color)
	draw_line(near_left, far_left, line_color, 3.0, true)
	draw_line(far_left, far_right, line_color, 3.0, true)
	draw_line(far_right, near_right, line_color, 3.0, true)

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

func _draw_needle_projectile(projectile: Dictionary) -> void:
	# 提莫毒针：很短短小的直线，无箭头，颜色沿用单位色（提莫为绿色）。
	var pos := _projectile_visual_position(projectile)
	var direction: Vector2 = projectile.get("direction", Vector2.UP)
	if direction.length_squared() < 0.001:
		direction = Vector2.UP
	direction = direction.normalized()
	var head := pos + direction * 8.0
	var tail := pos - direction * 8.0
	draw_line(tail, head, projectile.color, 2.0, true)

func _draw_boomerang_projectile(projectile: Dictionary) -> void:
	# 小纳尔回旋镖的代码占位：双臂 V 形随飞行方向旋转，权威碰撞仍是圆形弹体。
	var pos := _projectile_visual_position(projectile)
	var direction: Vector2 = projectile.get("direction", Vector2.UP)
	if direction.length_squared() < 0.001:
		direction = Vector2.UP
	direction = direction.normalized()
	var side := Vector2(-direction.y, direction.x)
	var color: Color = projectile.color
	var joint := pos + direction * 3.0
	draw_line(joint, pos - direction * 7.0 + side * 8.0, color, 3.0, true)
	draw_line(joint, pos - direction * 7.0 - side * 8.0, color, 3.0, true)

func _draw_arrow_projectile(projectile: Dictionary) -> void:
	var pos := _projectile_visual_position(projectile)
	var direction: Vector2 = projectile.get("direction", Vector2.UP)
	if direction.length_squared() < 0.001:
		direction = Vector2.UP
	direction = direction.normalized()
	var side := Vector2(-direction.y, direction.x)
	var color: Color = projectile.color
	var tip := pos + direction * 10.0
	var neck := pos + direction * 4.0
	var tail := pos - direction * 8.0
	draw_line(tail, neck, color, 3.0, true)
	draw_colored_polygon(PackedVector2Array([tip, neck + side * 4.0, neck - side * 4.0]), color)

func _draw_tower_orb_projectile(projectile: Dictionary) -> void:
	# 防御塔弹体：阵营色能量球+短拖尾，视觉点从权杖晶石起步后回到真实命中点。
	var pos := _projectile_visual_position(projectile)
	var direction: Vector2 = projectile.get("direction", Vector2.UP)
	if direction.length_squared() < 0.001:
		direction = Vector2.UP
	direction = direction.normalized()
	var color: Color = projectile.color
	var radius: float = projectile.radius
	var glow := Color(color.r, color.g, color.b, 0.22)
	var highlight := Color(1.0, 1.0, 1.0, 0.82)
	draw_line(pos - direction * 14.0, pos - direction * 3.0, glow, 5.0, true)
	draw_circle(pos, radius + 5.0, glow)
	draw_circle(pos, radius, color)
	draw_circle(pos - direction * radius * 0.25, radius * 0.34, highlight)

## 弹体仍在 2D 地面坐标中做权威碰撞；这里只适配武器/晶石的表现位置。
func _projectile_visual_position(projectile: Dictionary) -> Vector2:
	var visual_offset: Vector2 = projectile.get("visual_offset", Vector2.ZERO)
	return projectile.pos + visual_offset + Vector2(0.0, -float(projectile.get("visual_height", 0.0)))
