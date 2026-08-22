extends Node2D
## 主场景：战场搭建、部署输入、敌方占位出兵、胜负判定。

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
const NAV_CLEARANCE := 16.0
const NAV_GRID_PADDING := 8.0
const STRUCTURE_SEPARATION := 1.0
const AVOID_LOOKAHEAD := 34.0
const AVOID_NEIGHBOR_PADDING := 26.0
const AVOID_MIN_FORWARD_RATIO := 0.35
const COLLISION_SLOP := 0.5
const COLLISION_CORRECTION_PERCENT := 0.35
const COLLISION_MAX_CORRECTION := 3.0
const LANDING_CORRECTION_PERCENT := 0.75
const LANDING_MAX_CORRECTION := 8.0
# 双方地面部署区各 15 行；贴河外角与国王塔后方两侧不可部署。
const TEAM_0_FIRST_ROW := RIVER_BOTTOM_ROW
const TEAM_0_LAST_ROW := ARENA_ROWS - 1
const BACK_CENTER_MIN_COLUMN := 6
const BACK_CENTER_MAX_COLUMN := 11
const POCKET_FIRST_ROW := 9
const POCKET_LAST_ROW := RIVER_TOP_ROW - 1

# 视觉占地、部署禁区与移动碰撞分离：塔仍显示为 3x3 / 4x4，
# 但单位绕行使用参考项目的 1.0 / 1.4 格圆形物理半径。
const PRINCESS_STATS := {"hp": 1400.0, "damage": 55.0, "range": 300.0, "interval": 0.8, "radius": 40.0, "visual_radius": 60.0, "deployment_radius": 40.0, "first_hit": 0.2, "projectile_speed": 420.0}
const KING_STATS := {"hp": 2400.0, "damage": 70.0, "range": 280.0, "interval": 1.0, "radius": 56.0, "visual_radius": 80.0, "deployment_radius": 56.0, "first_hit": 0.2, "projectile_speed": 380.0}

# 比赛计时：3 分钟正赛，平局进 60 秒加时（先破塔者胜），再平则平局
const MATCH_TIME := 180.0
const OVERTIME_TIME := 60.0
const SIM_DT := 1.0 / 20.0
const DOUBLE_ELIXIR_TIME := 60.0

# 联机
const NET_PORT := 39152

var game_over := false
var nav: NavGrid
var mode := "local"  # local=单机 / host=主机 / client=客户端
var _match_started := false  # 比赛是否已开始（联机时主机需等对手加入）
var _freeze_effects: Array = []  # [{pos, timer, duration, radius}]
var _projectiles := {}  # 主机/单机：id -> {pos, target, team, damage, speed, ...}
var _client_projectiles := {}  # 客户端仅保存插值表现
var _next_projectile_id := 1

var _elixir: ElixirManager
var _hand: CardHand
var _ai: AIOpponent
var _selected_card := ""
var _match_timer := MATCH_TIME
var _overtime := false
var _timer_label: Label
var _king_player: Tower
var _king_enemy: Tower
var _towers: Array[Tower] = []
var _battle_presentation: BattlePresentation3D

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
# 命令行联机测试钩子（--auto-test：主机 2 秒后生成近战与远程交战样本）
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
	btn_solo.pressed.connect(_start_local)
	vbox.add_child(btn_solo)
	var btn_host := _make_menu_button("创建房间（我做主机）")
	btn_host.pressed.connect(_start_host)
	vbox.add_child(btn_host)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_ip_input = LineEdit.new()
	_ip_input.text = "127.0.0.1"
	_ip_input.custom_minimum_size = Vector2(220, 0)
	_ip_input.placeholder_text = "对方 IP 地址"
	row.add_child(_ip_input)
	var btn_join := _make_menu_button("加入房间")
	btn_join.pressed.connect(func(): _start_client(_ip_input.text.strip_edges()))
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
	_ai.setup(self)
	_create_towers()
	_build_nav()
	_create_timer_ui()

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
	_hand.setup(_elixir)
	_hand.card_selected.connect(_on_card_selected)

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
		_towers.append(t)
	_king_player = Tower.new()
	_king_player.setup(0, KING_STATS, true)
	_king_player.position = Vector2(9.0 * TILE_SIZE, 29.0 * TILE_SIZE)
	add_child(_king_player)
	_towers.append(_king_player)
	_king_enemy = Tower.new()
	_king_enemy.setup(1, KING_STATS, true)
	_king_enemy.position = Vector2(9.0 * TILE_SIZE, 3.0 * TILE_SIZE)
	add_child(_king_enemy)
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
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if game_over or _selected_card == "":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := _snap_card_position(_selected_card, get_global_mouse_position())
		var stats: Dictionary = CardDB.all()[_selected_card]
		if not _elixir.can_afford(stats.cost):
			return
		var my_team := 1 if mode == "client" else 0
		if not is_card_deploy_position_valid(my_team, _selected_card, pos):
			return
		var used_card := _selected_card
		_selected_card = ""
		_hand.clear_selection()
		queue_redraw()
		if mode == "client":
			# 客户端：只发请求，扣费与生成由主机权威处理
			_hand.card_used(used_card)
			_rpc_deploy_request.rpc_id(1, used_card, pos)
			return
		if not _elixir.spend(stats.cost):
			return
		if stats.get("type", "unit") == "building":
			_push_units_around(pos, stats.get("radius", 14.0))
		_deploy_card(0, used_card, pos)
		_hand.card_used(used_card)

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
func _snap_card_position(card_id: String, pos: Vector2) -> Vector2:
	if not CardDB.all().has(card_id):
		return _snap_to_tile_center(pos)
	var stats: Dictionary = CardDB.all()[card_id]
	var footprint: Vector2i = stats.get("footprint_tiles", Vector2i.ONE)
	if stats.get("type", "unit") != "building" or footprint == Vector2i.ONE:
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

## 占位检查：该位置与存活的塔/建筑卡不重叠才允许部署
func _can_deploy_at(pos: Vector2, radius: float, is_air: bool = false, footprint: Vector2i = Vector2i.ONE) -> bool:
	var is_rect := footprint != Vector2i.ONE
	if not is_air and not is_rect and not is_ground_position_walkable(pos, radius):
		return false
	for c in get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(c) or c.hp <= 0.0:
			continue
		var is_static: bool = c is Tower or (c is Unit and (c as Unit).is_building)
		if not is_static:
			continue
		if is_rect:
			var deploy_rect := Rect2(pos - Vector2(footprint) * TILE_SIZE * 0.5, Vector2(footprint) * TILE_SIZE)
			if _structure_intersects_rect(c, deploy_rect):
				return false
		elif _structure_deploy_gap_to_circle(c, pos, radius) < STRUCTURE_SEPARATION:
			return false
	return true

## 所有正常卡牌部署入口（玩家、客户端请求、AI）共享同一套区域与占位校验。
func is_card_deploy_position_valid(p_team: int, card_id: String, pos: Vector2) -> bool:
	if not CardDB.all().has(card_id):
		return false
	pos = _snap_card_position(card_id, pos)
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
				if not _tile_in_ground_deploy_zone(Vector2i(x, y), p_team):
					return false
	if is_spell:
		return true
	return _can_deploy_at(pos, stats.get("radius", 14.0), stats.get("is_air", false), footprint)

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
func is_ground_position_walkable(pos: Vector2, mover_radius: float, excluded: Node = null) -> bool:
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

func _deploy_card(p_team: int, card_id: String, pos: Vector2) -> void:
	# 玩家、AI 与联机请求统一落在同一格中心；召唤物走 _spawn_unit，不受此吸附影响。
	pos = _snap_card_position(card_id, pos)
	var stats: Dictionary = CardDB.all()[card_id]
	var type: String = stats.get("type", "unit")
	match type:
		"spell":
			_cast_spell(p_team, card_id, pos)
		_:
			_spawn_unit(p_team, card_id, pos)

## 单位/塔统一攻击出口：近战即时结算，远程生成主机权威弹道。
func launch_attack(attacker: Node2D, target: Node2D, amount: float, projectile_speed: float, splash_radius: float, knockback: float, projectile_color: Color) -> void:
	if target == null or not is_instance_valid(target) or target.hp <= 0.0:
		return
	if projectile_speed <= 0.0:
		_resolve_attack_hit(attacker.team, attacker.global_position, target, amount, splash_radius, knockback)
		return
	var id := _next_projectile_id
	_next_projectile_id += 1
	_projectiles[id] = {
		"pos": attacker.global_position,
		"target": target,
		"team": attacker.team,
		"damage": amount,
		"speed": projectile_speed,
		"splash": splash_radius,
		"knockback": knockback,
		"color": projectile_color,
		"radius": 4.0,
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
		var target_pos: Vector2 = target.global_position
		var pos: Vector2 = projectile.pos
		var next_pos := pos.move_toward(target_pos, projectile.speed * dt)
		projectile.pos = next_pos
		_projectiles[id] = projectile
		if next_pos.distance_to(target_pos) <= target.body_radius + projectile.radius:
			_resolve_attack_hit(projectile.team, pos, target, projectile.damage, projectile.splash, projectile.knockback)
			finished.append(id)
	for id in finished:
		_projectiles.erase(id)

func _resolve_attack_hit(p_team: int, origin: Vector2, primary: Node2D, amount: float, radius: float, knockback: float) -> void:
	if primary == null or not is_instance_valid(primary) or primary.hp <= 0.0:
		return
	if radius <= 0.0:
		primary.take_damage(amount)
		if knockback > 0.0 and primary is Unit and is_instance_valid(primary) and primary.hp > 0.0:
			(primary as Unit).apply_knockback(origin, knockback)
		return
	var impact_pos := primary.global_position
	for c in get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(c) or c.team == p_team or c.hp <= 0.0:
			continue
		if c is Unit and not (c as Unit).is_deployed():
			continue
		if c.global_position.distance_to(impact_pos) <= radius + c.body_radius:
			c.take_damage(amount)
			if knockback > 0.0 and c is Unit and is_instance_valid(c) and c.hp > 0.0:
				(c as Unit).apply_knockback(origin, knockback)

func _cast_spell(p_team: int, card_id: String, pos: Vector2) -> void:
	match card_id:
		"freeze":
			var stats: Dictionary = CardDB.all()["freeze"]
			var radius: float = stats.radius
			var duration: float = stats.duration
			_apply_freeze(pos, radius, duration, p_team)
			# 主机：同步冰冻视觉效果给客户端
			if mode == "host":
				_rpc_freeze_fx.rpc(pos, radius, duration)

func _apply_freeze(pos: Vector2, radius: float, duration: float, p_team: int) -> void:
	# 记录视觉效果
	_freeze_effects.append({"pos": pos, "timer": duration, "duration": duration, "radius": radius})
	for c in get_tree().get_nodes_in_group("combatants"):
		if not is_instance_valid(c) or c.team == p_team or c.hp <= 0.0:
			continue
		# 法术圆与目标碰撞圆相交即命中，而不是只判断目标中心点。
		if c.global_position.distance_to(pos) <= radius + c.body_radius:
			if c is Unit:
				(c as Unit).freeze(duration)
			elif c is Tower:
				(c as Tower).freeze(duration)

func _spawn_unit(team: int, card_id: String, pos: Vector2) -> Unit:
	var stats: Dictionary = CardDB.imp_stats() if card_id == "imp" else CardDB.all()[card_id]
	var u := Unit.new()
	u.position = pos
	u.setup(team, stats, stats.name)
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
		_rpc_spawn_unit.rpc(card_id, team, pos, u.net_id)
	return u

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

## 固定 20Hz 模拟步：驱动全部战斗单位与塔，处理国王塔激活与障碍移除。
## 帧率高低只影响每帧跑多少步，不改变战斗结果（联机两端行为一致）。
func _sim_step(dt: float) -> void:
	for c in get_tree().get_nodes_in_group("combatants"):
		if c.has_method("sim_tick"):
			c.sim_tick(dt)
	_apply_unit_movement(dt)
	_resolve_unit_collisions(dt)
	_tick_projectiles(dt)
	# 己方任一公主塔被摧毁 → 国王塔参战。
	for king in [_king_player, _king_enemy]:
		if king.activated or king.hp <= 0.0:
			continue
		var side: int = king.team
		if _towers[side * 2].hp <= 0.0 or _towers[side * 2 + 1].hp <= 0.0:
			king.activate()
	# 塔被摧毁 → 解除其导航网格占地，路径可穿过原塔位
	for t in _towers:
		if t.hp <= 0.0 and not t.nav_cells.is_empty():
			unblock_nav_cells(t.nav_cells)
			t.nav_cells = []
	# 联机测试钩子：进入模拟 2 秒后生成近战、远程与弹道样本。
	if _auto_test:
		_auto_timer -= dt
		if _auto_timer <= 0.0:
			_auto_test = false
			_deploy_card(0, "garen", Vector2(360, 1000))
			_deploy_card(0, "ashe", Vector2(300, 700))
			_deploy_card(1, "xin", Vector2(300, 580))

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
	var next_pos := unit.global_position + velocity * dt
	if not unit.is_walkable_at(next_pos):
		return false
	unit.global_position = Vector2(
		clampf(next_pos.x, unit.body_radius, FIELD_W - unit.body_radius),
		clampf(next_pos.y, unit.body_radius, FIELD_H - unit.body_radius)
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
			if unit.hp > 0.0 and not unit.is_building and unit.is_deployed():
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
			_client_projectiles[id] = projectile
		for fe in _freeze_effects:
			fe.timer -= delta
		_freeze_effects = _freeze_effects.filter(func(fe): return fe.timer > 0.0)
		queue_redraw()
		return
	if not _match_started or game_over:
		return
	# 更新冰冻视觉效果
	for fe in _freeze_effects:
		fe.timer -= delta
	_freeze_effects = _freeze_effects.filter(func(fe): return fe.timer > 0.0)
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

## 圣水回复倍率：常规时间最后一分钟双倍、加时三倍（对齐皇室战争节奏）
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

## 客户端 → 主机：部署请求（主机校验区域/占位/费用后生成）
@rpc("any_peer", "call_remote", "reliable")
func _rpc_deploy_request(card_id: String, pos: Vector2) -> void:
	if mode != "host" or game_over:
		return
	if not CardDB.all().has(card_id):
		return
	pos = _snap_card_position(card_id, pos)
	var stats: Dictionary = CardDB.all()[card_id]
	if not is_card_deploy_position_valid(1, card_id, pos):
		return
	if _elixir_p1 == null or not _elixir_p1.spend(stats.cost):
		return
	if stats.get("type", "unit") == "building":
		_push_units_around(pos, stats.get("radius", 14.0))
	_deploy_card(1, card_id, pos)

## 主机 → 客户端：单位生成
@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_unit(card_id: String, p_team: int, pos: Vector2, net_id: int) -> void:
	if mode != "client":
		return
	var stats: Dictionary = CardDB.imp_stats() if card_id == "imp" else CardDB.all()[card_id]
	var u := Unit.new()
	u.position = pos
	u.setup(p_team, stats, stats.name)
	u.net_id = net_id
	u.net_target_pos = pos
	add_child(u)
	if _battle_presentation != null:
		_battle_presentation.attach_unit(u, stats)
	if nav != null and u.is_building:
		u.nav_cells = nav.cells_for_rect(_structure_rect(u).grow(NAV_CLEARANCE + NAV_GRID_PADDING))
		nav.set_cells_blocked(u.nav_cells, true)
	_client_units[net_id] = u
	if _auto_test:
		print("[测试] 客户端收到单位生成: ", card_id, " net_id=", net_id)

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

## 主机 → 客户端：定期快照（位置/血量/金币/计时）
@rpc("authority", "call_remote", "unreliable")
func _rpc_snapshot(units_data: Array, projectiles_data: Array, towers_data: Array, e0: float, e1: float, mt: float, ot: bool) -> void:
	if mode != "client":
		return
	var seen := {}
	for d in units_data:
		seen[d[0]] = true
		var u: Unit = _client_units.get(d[0])
		if u == null or not is_instance_valid(u):
			continue
		u.net_target_pos = Vector2(d[1], d[2])
		u.hp = d[3]
		u.frozen_timer = 0.15 if d[4] == 1 else 0.0
		u._charged = d[5] == 1
		if d.size() >= 8:
			u.net_visual_state = d[6]
			u.net_facing_x = d[7]
		if d.size() >= 9:
			u.net_attack_visual_serial = d[8]
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
		})
		projectile.target_pos = Vector2(d[1], d[2])
		projectile.color = d[3]
		projectile.radius = d[4]
		_client_projectiles[d[0]] = projectile
	var gone_projectiles := []
	for id in _client_projectiles:
		if not seen_projectiles.has(id):
			gone_projectiles.append(id)
	for id in gone_projectiles:
		_client_projectiles.erase(id)
	for i in range(mini(towers_data.size(), _towers.size())):
		_towers[i].hp = towers_data[i][0]
		_towers[i].activated = towers_data[i][1] == 1
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
func _rpc_freeze_fx(pos: Vector2, radius: float, duration: float) -> void:
	if mode != "client":
		return
	_freeze_effects.append({"pos": pos, "timer": duration, "duration": duration, "radius": radius})

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
		units_data.append([id, u.global_position.x, u.global_position.y, u.hp, 1 if u.frozen_timer > 0.0 else 0, 1 if u.is_charged() else 0, u.get_visual_state_code(), u.get_facing_x(), u.get_attack_visual_serial()])
	for id in dead:
		_net_units.erase(id)
	var towers_data := []
	for t in _towers:
		# [血量, 国王塔是否已激活]
		towers_data.append([t.hp, 1 if t.activated else 0])
	var projectiles_data := []
	for id in _projectiles:
		var projectile: Dictionary = _projectiles[id]
		projectiles_data.append([id, projectile.pos.x, projectile.pos.y, projectile.color, projectile.radius])
	_rpc_snapshot.rpc(units_data, projectiles_data, towers_data, _elixir.elixir, _elixir_p1.elixir, _match_timer, _overtime)

func _draw() -> void:
	# 18x32 棋盘草地：格子既是视觉标尺，也是实际部署坐标。
	for row in ARENA_ROWS:
		for column in ARENA_COLUMNS:
			var base := Color(0.29, 0.43, 0.29) if row < RIVER_TOP_ROW else Color(0.26, 0.41, 0.30)
			if (row + column) % 2 == 0:
				base = base.lightened(0.035)
			draw_rect(Rect2(Vector2(column, row) * TILE_SIZE, Vector2.ONE * TILE_SIZE), base)
	# 两行河道（第 15、16 行）与两座 3 格宽桥。
	draw_rect(Rect2(0, RIVER_Y - RIVER_HALF, FIELD_W, RIVER_HALF * 2.0), Color(0.25, 0.45, 0.65))
	var bridge_top := RIVER_Y - RIVER_HALF
	var bridge_h := RIVER_HALF * 2.0
	draw_rect(Rect2(BRIDGE_X_LEFT  - BRIDGE_HALF, bridge_top, BRIDGE_HALF * 2.0, bridge_h), Color(0.52, 0.38, 0.22))
	draw_rect(Rect2(BRIDGE_X_RIGHT - BRIDGE_HALF, bridge_top, BRIDGE_HALF * 2.0, bridge_h), Color(0.52, 0.38, 0.22))
	# 灰盒阶段保留细格线，方便肉眼核对摆位、碰撞与寻路。
	for column in range(ARENA_COLUMNS + 1):
		draw_line(Vector2(column * TILE_SIZE, 0.0), Vector2(column * TILE_SIZE, FIELD_H), Color(0.08, 0.12, 0.08, 0.20), 1.0)
	for row in range(ARENA_ROWS + 1):
		draw_line(Vector2(0.0, row * TILE_SIZE), Vector2(FIELD_W, row * TILE_SIZE), Color(0.08, 0.12, 0.08, 0.20), 1.0)
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
	# 冰冻区域效果
	for fe in _freeze_effects:
		var alpha: float = (fe.timer / fe.duration) * 0.25
		draw_circle(fe.pos, fe.radius, Color(0.40, 0.70, 1.00, alpha))
		draw_circle(fe.pos, fe.radius, Color(0.60, 0.85, 1.00, alpha * 0.5), false, 2.0)
	var visible_projectiles: Dictionary = _client_projectiles if mode == "client" else _projectiles
	for id in visible_projectiles:
		var projectile: Dictionary = visible_projectiles[id]
		draw_circle(projectile.pos, projectile.radius, projectile.color)
