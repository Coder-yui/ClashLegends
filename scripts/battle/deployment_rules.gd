class_name DeploymentRules
extends RefCounted
## 只查询当前结构与地面几何；不保存占位、不扣费、不生成节点。
var combatants: Callable
var towers: Callable
var ground_walkable: Callable

func world_to_arena_tile(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / ArenaRules.TILE_SIZE), floori(pos.y / ArenaRules.TILE_SIZE))

func arena_tile_center(tile: Vector2i) -> Vector2:
	return Vector2(tile) * ArenaRules.TILE_SIZE + Vector2.ONE * ArenaRules.TILE_SIZE * 0.5

func snap_to_tile_center(pos: Vector2) -> Vector2:
	var tile := world_to_arena_tile(pos)
	tile.x = clampi(tile.x, 0, ArenaRules.ARENA_COLUMNS - 1)
	tile.y = clampi(tile.y, 0, ArenaRules.ARENA_ROWS - 1)
	return arena_tile_center(tile)

## 单格单位和奇数格建筑落在格心；偶数格建筑落在格线交点，确保规则占地对齐完整格子。
func snap_card_position(card_id: String, pos: Vector2, p_team: int = -1) -> Vector2:
	if not CardDB.has_card(card_id):
		return snap_to_tile_center(pos)
	var stats: Dictionary = CardDB.get_card(card_id)
	var footprint: Vector2i = stats.get("footprint_tiles", Vector2i.ONE)
	if stats.get("type", "unit") != "building" or footprint == Vector2i.ONE:
		# 单位严格落在鼠标所在格的格心。若该格因河岸、塔或边界不合法，
		# 由预览显示红色并拒绝部署，不能通过微调中心偷偷换到别的位置。
		return snap_to_tile_center(pos)
	var half_size := Vector2(footprint) * ArenaRules.TILE_SIZE * 0.5
	var snapped := Vector2(
		roundf(pos.x / ArenaRules.TILE_SIZE) * ArenaRules.TILE_SIZE if footprint.x % 2 == 0 else floorf(pos.x / ArenaRules.TILE_SIZE) * ArenaRules.TILE_SIZE + ArenaRules.TILE_SIZE * 0.5,
		roundf(pos.y / ArenaRules.TILE_SIZE) * ArenaRules.TILE_SIZE if footprint.y % 2 == 0 else floorf(pos.y / ArenaRules.TILE_SIZE) * ArenaRules.TILE_SIZE + ArenaRules.TILE_SIZE * 0.5
	)
	snapped.x = clampf(snapped.x, half_size.x, ArenaRules.FIELD_W - half_size.x)
	snapped.y = clampf(snapped.y, half_size.y, ArenaRules.FIELD_H - half_size.y)
	return snapped

## 部署区域按 CR 格子掩码判断：法术全场，单位/建筑为己方 15 行及已解锁 pocket。
func pos_in_deploy_zone(pos: Vector2, p_team: int, is_spell: bool) -> bool:
	if pos.x < 0.0 or pos.x >= ArenaRules.FIELD_W or pos.y < 0.0 or pos.y >= ArenaRules.FIELD_H:
		return false
	if is_spell:
		return true
	return tile_in_ground_deploy_zone(world_to_arena_tile(pos), p_team)

## 防御塔、水晶和建筑卡的部署禁区使用规则占地格，而不是物理圆。
## 矩形边界按格子归属取样，避免刚好贴边时误封锁相邻格。
func arena_tiles_for_rect(rect: Rect2) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var min_tile := world_to_arena_tile(rect.position + Vector2.ONE * 0.001)
	var max_tile := world_to_arena_tile(rect.end - Vector2.ONE * 0.001)
	for y in range(min_tile.y, max_tile.y + 1):
		for x in range(min_tile.x, max_tile.x + 1):
			var tile := Vector2i(x, y)
			if tile.x >= 0 and tile.x < ArenaRules.ARENA_COLUMNS and tile.y >= 0 and tile.y < ArenaRules.ARENA_ROWS:
				tiles.append(tile)
	return tiles

func structure_deployment_rect(structure: Node2D) -> Rect2:
	var footprint := Vector2i.ONE
	if structure is Tower:
		footprint = (structure as Tower).footprint_tiles
	elif structure is Unit and (structure as Unit).is_building:
		footprint = (structure as Unit).footprint_tiles
	var size := Vector2(footprint) * ArenaRules.TILE_SIZE
	return Rect2(structure.global_position - size * 0.5, size)

func structure_deployment_tiles(structure: Node2D) -> Array[Vector2i]:
	return arena_tiles_for_rect(structure_deployment_rect(structure))

## 已毁公主塔仍为太阳圆盘保留 3x3 塔墟语义；国王水晶废墟不属于该被动。
## Tower 的 hp 与 footprint_tiles 是唯一权威来源，3D Rubble 表面不参与判定。
func destroyed_princess_tower_for_tile(tile: Vector2i) -> Tower:
	for tower in towers.call():
		if not is_instance_valid(tower) or tower.is_king or tower.hp > 0.0:
			continue
		if tile in structure_deployment_tiles(tower):
			return tower
	return null

func destroyed_princess_tower_at_card_center(pos: Vector2) -> Tower:
	var tower: Tower = destroyed_princess_tower_for_tile(world_to_arena_tile(pos))
	return tower if tower != null and pos.is_equal_approx(tower.global_position) else null

func is_structure_deployment_tile_blocked(tile: Vector2i) -> bool:
	for c in combatants.call():
		if not is_instance_valid(c) or c.hp <= 0.0:
			continue
		var is_structure: bool = c is Tower or (c is Unit and (c as Unit).is_building)
		if not is_structure:
			continue
		if tile in structure_deployment_tiles(c):
			return true
	return false

func tile_in_ground_deploy_zone(tile: Vector2i, p_team: int, require_both_towers: bool = false) -> bool:
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
	if require_both_towers and not (pocket_unlocked(p_team, true) and pocket_unlocked(p_team, false)):
		return false
	var is_left := tile.x < ArenaRules.ARENA_COLUMNS / 2
	return pocket_unlocked(p_team, is_left)

## 全图卡牌允许落在河道外的地面格 + 两座桥面三格；敌我双方区域都合法，但塔/水晶占地格
## 仍由 is_card_deploy_position_valid() 单独拦截。除桥面外，河道其余两行保持不可部署。
func tile_in_global_ground_deploy_zone(tile: Vector2i) -> bool:
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

func pocket_unlocked(p_team: int, is_left: bool) -> bool:
	if towers.call().size() < 4:
		return false
	var tower_index: int
	if p_team == 0:
		tower_index = 2 if is_left else 3
	else:
		tower_index = 0 if is_left else 1
	return towers.call()[tower_index].hp <= 0.0

## 占位检查：候选卡的规则占地不得与存活塔/水晶/建筑卡的规则占地重叠。
## 兵种生成后的真实半径只交给移动、碰撞和挤压系统处理；建筑卡即使是 1x1，
## 部署资格也只按 footprint_tiles 与地面格规则判断，不读取圆柱碰撞半径。
func can_deploy_at(pos: Vector2, radius: float, is_air: bool = false, footprint: Vector2i = Vector2i.ONE, is_building_card: bool = false) -> bool:
	if not is_air and not is_building_card and not bool(ground_walkable.call(pos, radius, null, true, true)):
		return false
	var deploy_rect := Rect2(pos - Vector2(footprint) * ArenaRules.TILE_SIZE * 0.5, Vector2(footprint) * ArenaRules.TILE_SIZE)
	for c in combatants.call():
		if not is_instance_valid(c) or c.hp <= 0.0:
			continue
		var is_static: bool = c is Tower or (c is Unit and (c as Unit).is_building)
		if not is_static:
			continue
		# 共边不算重叠，相邻部署格必须保持可用。
		if structure_deployment_rect(c).intersects(deploy_rect, false):
			return false
	return true

## 所有正常卡牌部署入口（玩家、客户端请求、AI）共享同一套区域与占位校验。
func is_card_deploy_position_valid(p_team: int, card_id: String, pos: Vector2) -> bool:
	if not CardDB.has_card(card_id):
		return false
	pos = snap_card_position(card_id, pos, p_team)
	var stats: Dictionary = CardDB.get_card(card_id)
	# 横排中心跨度须留在场内；边缘身体在生成时逐兵挤回合法位置。
	if String(stats.get("deployment_formation", "ring")) == "line":
		var margin := (int(stats.get("deployment_count", 1)) - 1) * float(stats.get("deployment_spacing", 0.0)) * 0.5
		if pos.x < margin or pos.x > ArenaRules.FIELD_W - margin:
			return false
	var deploy_zone: String = String(stats.get("deploy_zone", "own_side"))
	var ignore_structures: bool = bool(stats.get("deploy_ignore_structures", false))
	var footprint: Vector2i = stats.get("footprint_tiles", Vector2i.ONE)
	var card_type: String = String(stats.get("type", "unit"))
	var uses_tower_ruin_foundation := bool(stats.get("tower_ruin_foundation", false))
	var foundation_tower := destroyed_princess_tower_at_card_center(pos) if uses_tower_ruin_foundation else null

	# 1. 部署区域：从 CardDB 独立读取 deploy_zone。只有 own_side / global 两态；
	#    「河道非桥面不可下」统一放在下一段占位层里（和塔/水晶/建筑同开关），不重复耦合到区域分类。
	# 塔墟被动仅允许在已毁公主塔的精确中心重建；该位置可能在普通 pocket
	# 部署区之外。中心未对齐塔墟时仍严格执行原部署区域。
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
					if not tile_in_ground_deploy_zone(tile, p_team, bool(stats.get("deploy_pocket_requires_both_towers", false))):
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
				# 本身对齐该塔墟中心，此时只豁免这一个已毁公主塔。
				if uses_tower_ruin_foundation:
					var ruined_tower := destroyed_princess_tower_for_tile(tile)
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
				if is_structure_deployment_tile_blocked(tile):
					return false
		if card_type != "spell":
			# 单格兵种共用同一套部署位置。不要因为盖伦等大体型兵种的真实半径较大，
			# 把本来属于部署区的格子判成非法；真实体积从生成后才参与战斗碰撞。
			var placement_radius := 0.0
			return can_deploy_at(pos, placement_radius, stats.get("is_air", false), footprint, card_type == "building")
	return true

func nearest_valid_building_spawn(team: int, card_id: String, requested: Vector2) -> Vector2:
	var origin := snap_card_position(card_id, requested, team)
	if is_card_deploy_position_valid(team, card_id, origin):
		return origin
	var best := Vector2.INF
	var best_distance := INF
	for row in ArenaRules.ARENA_ROWS:
		for column in ArenaRules.ARENA_COLUMNS:
			var tile := Vector2i(column, row) if team == 0 else Vector2i(ArenaRules.ARENA_COLUMNS - 1 - column, ArenaRules.ARENA_ROWS - 1 - row)
			var candidate := snap_card_position(card_id, arena_tile_center(tile), team)
			var distance := candidate.distance_squared_to(origin)
			if distance < best_distance and is_card_deploy_position_valid(team, card_id, candidate):
				best = candidate
				best_distance = distance
	return best
