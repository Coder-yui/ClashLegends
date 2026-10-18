extends RefCounted
## 战场实体与空间的唯一所有者。节点仍直接挂在场景根，组快照保持场景树顺序。
## 不保存命令、账户、会话或表现状态，不回调 Main 的空间/登记方法。
var _root: Node2D
var _towers: Array[Tower] = []
var _kings: Array[Tower] = []
var _authority_units: Dictionary = {}
var _replica_units: Dictionary = {}
var _next_net_id := 1000
var nav: NavGrid
var _river_nav: NavGrid
var _river_nav_source: NavGrid
var _river_nav_revision := -1

func _init(scene_root: Node2D) -> void:
	_root = scene_root

## child_entered_tree时绑定，保留原 combat_source_id 分配时机与节点顺序。
func bind_entity(node: Node, context: BattleContext, combat: CombatResolver) -> void:
	if not (node is Unit or node is Tower): return
	combat.register_source(node)
	node.set_battle_context(context)
	if node is Unit:
		node.tree_exiting.connect(_on_unit_exiting.bind(node), CONNECT_ONE_SHOT)

func combatants() -> Array[Node]:
	return _root.get_tree().get_nodes_in_group("combatants")

func structures() -> Array[Node]:
	return _root.get_tree().get_nodes_in_group("combat_structures")

## 隔离容器，允许消费者改变实体本身，不能增删World索引。
func towers_snapshot() -> Array[Tower]:
	var result := _towers.duplicate()
	result.make_read_only()
	return result

func king(team: int) -> Tower:
	return _kings[team] if team >= 0 and team < _kings.size() else null

func create_towers() -> void:
	assert(_towers.is_empty())
	for spec in [
		[0, Vector2(ArenaRules.BRIDGE_X_LEFT, 25.5 * ArenaRules.TILE_SIZE)],
		[0, Vector2(ArenaRules.BRIDGE_X_RIGHT, 25.5 * ArenaRules.TILE_SIZE)],
		[1, Vector2(ArenaRules.BRIDGE_X_LEFT, 6.5 * ArenaRules.TILE_SIZE)],
		[1, Vector2(ArenaRules.BRIDGE_X_RIGHT, 6.5 * ArenaRules.TILE_SIZE)],
		[0, Vector2(9.0 * ArenaRules.TILE_SIZE, 29.0 * ArenaRules.TILE_SIZE)],
		[1, Vector2(9.0 * ArenaRules.TILE_SIZE, 3.0 * ArenaRules.TILE_SIZE)],
	]:
		var tower := Tower.new()
		var is_king := _towers.size() >= 4
		tower.setup(spec[0], CardDB.NEXUS_STATS if is_king else CardDB.PRINCESS_TOWER_STATS, is_king)
		tower.position = spec[1]
		_root.add_child(tower)
		tower.z_index = 10
		_towers.append(tower)
		if is_king: _kings.append(tower)

func clear_towers() -> void:
	for tower in _towers:
		release_structure_footprint(tower)
		tower.queue_free()
	_towers.clear()
	_kings.clear()

## 只在完整Tick的原有塔收尾阶段调用，保持激活/释放顺序。
func finish_tower_step() -> void:
	for nexus in _kings:
		if not nexus.can_attack or nexus.activated or nexus.hp <= 0.0: continue
		var side := nexus.team
		if _towers[side * 2].hp <= 0.0 or _towers[side * 2 + 1].hp <= 0.0:
			nexus.activate()
	for tower in _towers:
		if tower.hp <= 0.0: release_structure_footprint(tower)

## 表现挂接之后调用，与既有出生流程的ID/占位时序相同。
func register_authority_unit(unit: Unit, networked: bool) -> void:
	register_dynamic_building(unit)
	if networked:
		unit.net_id = _next_net_id
		_next_net_id += 1
		_authority_units[unit.net_id] = unit

func register_replica_unit(unit: Unit) -> void:
	register_dynamic_building(unit)
	_replica_units[unit.net_id] = unit

func forget_authority_unit(id: int) -> void:
	_authority_units.erase(id)

func find_replica_unit(id: int) -> Unit:
	var unit = _replica_units.get(id)
	return unit if is_instance_valid(unit) else null

func forget_replica_unit(id: int) -> void:
	_replica_units.erase(id)

func replica_unit_ids() -> Array:
	return _replica_units.keys()

func replica_units_snapshot() -> Dictionary:
	var result := _replica_units.duplicate()
	result.make_read_only()
	return result

func authoritative_units_snapshot() -> Dictionary:
	for id in _authority_units.keys():
		if not is_instance_valid(_authority_units[id]): _authority_units.erase(id)
	# 不根据HP猜测死亡；等待复生/同批死亡由正式生命周期决定何时移除。
	var result := _authority_units.duplicate()
	result.make_read_only()
	return result

func release_structure_footprint(structure: Node2D) -> void:
	if structure.nav_cells.is_empty(): return
	unblock_nav_cells(structure.nav_cells)
	structure.nav_cells = []

func _on_unit_exiting(unit: Unit) -> void:
	release_structure_footprint(unit)
	if _authority_units.get(unit.net_id) == unit: _authority_units.erase(unit.net_id)
	if _replica_units.get(unit.net_id) == unit: _replica_units.erase(unit.net_id)

func remove_unit(unit: Unit) -> void:
	_on_unit_exiting(unit)
	if unit.is_in_group("combatants"): unit.remove_from_group("combatants")
	if unit.is_in_group("combat_structures"): unit.remove_from_group("combat_structures")
	unit.queue_free()

func clear_units() -> void:
	for actor in combatants():
		actor.bleeding.clear()
		if actor is Unit: remove_unit(actor)

func find_unit_landing(unit: Unit, desired: Vector2, allow_terrain: bool) -> Vector2:
	return UnitLandingQuery.find_position(unit, desired, allow_terrain)

func build_navigation() -> void:
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

func register_dynamic_building(unit: Unit) -> void:
	if nav == null or not unit.is_building or not unit.nav_cells.is_empty():
		return
	# 建筑的格子占地只限制下牌；A* 障碍按实际圆柱碰撞扩张移动单位净空。
	unit.nav_cells = nav.cells_for_circle(unit.global_position, unit.body_radius + ArenaRules.NAV_CLEARANCE)
	nav.set_cells_blocked(unit.nav_cells, true)

func structure_gap_to_circle(c: Node2D, center: Vector2, radius: float) -> float:
	return c.surface_gap_to_circle(center, radius)

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
	var crosses_river: bool = is_instance_valid(excluded) and excluded is Unit and excluded.river_traversal
	if not crosses_river and not is_ground_terrain_walkable(pos, mover_radius):
		return false
	if ignore_structures: return true
	for c in structures():
		if c == excluded or not is_instance_valid(c) or c.hp <= 0.0:
			continue
		if structure_gap_to_circle(c, pos, mover_radius) < ArenaRules.STRUCTURE_SEPARATION:
			return false
	return true

## 连续河道碰撞：河岸按单位真实半径扩张，桥面按真实半径收窄。
## 不读取 A* 的离散格，避免合法部署格因格心取样误判为河道。

func is_ground_terrain_walkable(pos: Vector2, mover_radius: float) -> bool:
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

func push_units_around(pos: Vector2, radius: float) -> void:
	for c in combatants():
		if not is_instance_valid(c): continue
		var u := c as Unit
		if u == null or u.is_building or u.is_air or u.hp <= 0.0 or u.skill_dash_active or CombatInteraction.in_stasis(u):
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
				u.apply_deployment_push_position(new_pos)

## 召唤、成长和换形共用的最近合法地面落点。

func nearest_valid_ground_spawn(desired: Vector2, radius: float, p_team: int, excluded: Node = null) -> Vector2:
	if is_ground_position_walkable(desired, radius, excluded):
		return desired
	var forward := Vector2.UP if p_team == 0 else Vector2.DOWN
	for distance in range(4, 165, 4):
		for angle in [0.0, PI / 8.0, -PI / 8.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0, PI]:
			var candidate := desired + forward.rotated(angle) * float(distance)
			if is_ground_position_walkable(candidate, radius, excluded):
				return candidate
	# 无解是查询失败，不能把已知非法的请求点伪装成成功落点。
	return Vector2.INF

## 形态放大采用权威半径瞬时切换。若当前位置对新半径不合法，确定性地挪到最近安全点，
## 并重置插值/路径，避免桥角、河岸或塔边因为旧体积合法而新体积永久卡住。

func ensure_unit_form_resize_safe(unit: Unit) -> void:
	if is_instance_valid(unit) and unit._in_client_mode(): return
	if is_instance_valid(unit) and unit.knockback.in_transit: return # 外力途中不提前落地，抵达按新体型修正。
	if unit == null or not is_instance_valid(unit) or unit.is_air or unit.is_building or unit.terrain_traversal.enabled:
		return
	if is_ground_position_walkable(unit.global_position, unit.body_radius, unit):
		return
	var safe_position := nearest_valid_ground_spawn(unit.global_position, unit.body_radius, unit.team, unit)
	if not safe_position.is_finite():
		_root._fail_contract("体型交接没有合法落点：card=%s pos=%s radius=%s" % [unit.card_id, unit.global_position, unit.body_radius])
		return
	unit.apply_body_resize_position(safe_position)

## 动态占地按NavGrid引用计数释放。

func unblock_nav_cells(cells: Array) -> void:
	if nav == null or cells.is_empty():
		return
	nav.set_cells_blocked(cells, false)

func navigation_for_river() -> NavGrid:
	if nav == null: return null
	if _river_nav == null or _river_nav_source != nav or _river_nav_revision != nav.revision:
		_river_nav = NavGrid.new()
		_river_nav_source = nav
		_river_nav_revision = nav.revision
		var obstacles: Array = []
		for structure in structures():
			if is_instance_valid(structure) and structure.hp > 0.0:
				obstacles.append([structure.global_position, structure.body_radius + ArenaRules.NAV_CLEARANCE])
		_river_nav.build(Vector2(ArenaRules.FIELD_W, ArenaRules.FIELD_H), -1000.0, 0.0, [], 0.0, obstacles)
	return _river_nav

func find_ground_path(from: Vector2, goal: Vector2, _target: Node2D, _mover_radius: float = ArenaRules.NAV_CLEARANCE, crosses_river: bool = false) -> PackedVector2Array:
	if nav == null:
		return PackedVector2Array()
	return navigation_for_river().find_path(from, goal) if crosses_river else nav.find_path(from, goal)
