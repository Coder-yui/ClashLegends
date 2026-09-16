extends RefCounted
class_name NavGrid
## 半格导航网格：BattlePathSearch 执行已与 APK 原始指令比对的 A* 核心。
## 下方地形代价生成、目标修正和平滑仍是项目适配层，不是完整原生导航。
## 河道为硬阻挡，桥是唯一的地面跨河通道；
## 塔与建筑卡的实际圆柱碰撞由外部按半径扩张后动态注册；部署格占地不进入寻路。
## 动态阻挡用引用计数：塔被摧毁 / 建筑卡到期或被摧毁时解除对应格子，
## 路径即可穿过原塔位（对齐 CR 摧毁后塔位可通行的规则）。
## 寻路与渲染解耦，不依赖帧率，保证联机两端行为一致。

var revision := 0

const CELL_SIZE := ArenaRules.TILE_SIZE * 0.5
const LANE_HALF_TILE := CELL_SIZE
const ROAD_COST := 5
const DEFAULT_COST := 8
const OFF_LANE_WEIGHT := float(DEFAULT_COST) / ROAD_COST
# 参考项目的 36x64 半格路线场。1/2 都是低成本推进区，点是可走但稍高成本区。
# 左右标记分开保留，便于之后对单路做可视化/调试，当前两者权重相同。
const LANE_MAP := [
	"....................................",
	"....................................",
	"..............11112222..............",
	"..............11112222..............",
	"..............11112222..............",
	".....11111111111112222222222222.....",
	".....11111111111112222222222222.....",
	".....11111111111112222222222222.....",
	".....11111111111112222222222222.....",
	".....11111....11112222....22222.....",
	"....111111................222222....",
	"....111111................222222....",
	"....111111................222222....",
	"....111111................222222....",
	"....111111................222222....",
	"....111111................222222....",
	"....111111................222222....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	"WWWWW1111WWWWWWWWWWWWWWWWWW2222WWWWW",
	"WWWWW.11.WWWWWWWWWWWWWWWWWW.22.WWWWW",
	"WWWWW.11.WWWWWWWWWWWWWWWWWW.22.WWWWW",
	"WWWWW1111WWWWWWWWWWWWWWWWWW2222WWWWW",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	".....1111..................2222.....",
	"....111111................222222....",
	"....111111................222222....",
	"....111111................222222....",
	"....111111................222222....",
	"....111111................222222....",
	"....111111................222222....",
	"....111111................222222....",
	".....11111....11112222....22222.....",
	".....11111111111112222222222222.....",
	".....11111111111112222222222222.....",
	".....11111111111112222222222222.....",
	".....11111111111112222222222222.....",
	"..............11112222..............",
	"..............11112222..............",
	"..............11112222..............",
	"....................................",
	"....................................",
]

var _region := Rect2i()
var _costs := PackedInt32Array()
var _search := preload("res://scripts/battle/battle_path_search.gd").new()
# 永久阻挡（河道），引用计数解除时也不放开
var _base_blocked := {}
# 动态阻挡引用计数（塔 / 建筑卡碰撞圆）
var _block_counts := {}

## 构建网格：河道（除桥）永久阻挡，obstacles = [[pos, radius], ...] 圆形占地阻挡
func build(size: Vector2, river_y: float, river_half: float, bridge_xs: Array, bridge_half: float, obstacles: Array) -> void:
	var cols := int(size.x / CELL_SIZE)
	var rows := int(size.y / CELL_SIZE)
	_region = Rect2i(0, 0, cols, rows)
	_costs.resize(cols * rows)
	_base_blocked = {}
	_block_counts = {}
	for y in rows:
		for x in cols:
			var cell := Vector2i(x, y)
			var world_pos := cell_to_world(cell)
			_costs[cell.x + cell.y * cols] = roundi(get_lane_weight_at(world_pos) * ROAD_COST)
			# 与河岸一样为身体留出边界：最外侧半格中心只有 10px 余量，
			# 不能作为大单位绕水晶的路径点，否则移动层钳制位置后永远到不了。
			var outside_body_bounds := world_pos.x < ArenaRules.NAV_CLEARANCE or world_pos.x > size.x - ArenaRules.NAV_CLEARANCE or world_pos.y < ArenaRules.NAV_CLEARANCE or world_pos.y > size.y - ArenaRules.NAV_CLEARANCE
			if outside_body_bounds or _is_river_blocked(world_pos, river_y, river_half, bridge_xs, bridge_half):
				_base_blocked[cell] = true
				_costs[cell.x + cell.y * cols] = -1
	for o in obstacles:
		set_cells_blocked(cells_for_circle(o[0], o[1]), true)

func _is_river_blocked(pos: Vector2, river_y: float, river_half: float, bridge_xs: Array, bridge_half: float) -> bool:
	# 正好与河岸相切的导航格允许通行；最大单位半径已包含在 river_half 中。
	if absf(pos.y - river_y) >= river_half:
		return false
	for bx in bridge_xs:
		if absf(pos.x - float(bx)) <= bridge_half:
			return false
	return true

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE + CELL_SIZE / 2.0, cell.y * CELL_SIZE + CELL_SIZE / 2.0)

func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL_SIZE), floori(pos.y / CELL_SIZE))

func _is_cell_blocked(cell: Vector2i) -> bool:
	return not _region.has_point(cell) or _costs[cell.x + cell.y * _region.size.x] < 0

func is_walkable(pos: Vector2) -> bool:
	if _costs.is_empty():
		return false
	var cell := world_to_cell(pos)
	if not _region.has_point(cell):
		return false
	return not _is_cell_blocked(cell)

## 只检查河道/场地等永久地形，不包含塔与建筑的扩张导航占地。
## 实际移动用它配合连续形状碰撞，避免单位处在 A* 的保守边缘格时无法离开。
func is_terrain_walkable(pos: Vector2) -> bool:
	if _costs.is_empty():
		return false
	var cell := world_to_cell(pos)
	if not _region.has_point(cell):
		return false
	return not _base_blocked.has(cell)

## 返回推进偏好权重：1.0 是宽松的左右路区，8/5 是仍可通行的非主路区。
## 偏好只负责把单位渐进引向分路，不能强到让右下角单位绕己方右塔左侧。
func get_lane_weight_at(pos: Vector2) -> float:
	var map_x := clampi(floori(pos.x / LANE_HALF_TILE), 0, 35)
	var map_y := clampi(floori(pos.y / LANE_HALF_TILE), 0, 63)
	var row: String = LANE_MAP[map_y]
	var marker: String = row.substr(map_x, 1)
	return 1.0 if marker == "1" or marker == "2" else OFF_LANE_WEIGHT

## 圆形占地覆盖的格子（格中心落在圆内）
func cells_for_circle(center: Vector2, radius: float) -> Array:
	var cells := []
	if _costs.is_empty():
		return cells
	var min_c := world_to_cell(center - Vector2(radius, radius))
	var max_c := world_to_cell(center + Vector2(radius, radius))
	for y in range(min_c.y, max_c.y + 1):
		for x in range(min_c.x, max_c.x + 1):
			var cell := Vector2i(x, y)
			if not _region.has_point(cell):
				continue
			if cell_to_world(cell).distance_to(center) <= radius:
				cells.append(cell)
	return cells

## 矩形覆盖的格子（供通用网格计算与测试使用；建筑寻路障碍不使用部署矩形）。
func cells_for_rect(rect: Rect2) -> Array:
	var cells := []
	if _costs.is_empty():
		return cells
	var min_c := world_to_cell(rect.position)
	var max_c := world_to_cell(rect.end - Vector2.ONE * 0.001)
	for y in range(min_c.y, max_c.y + 1):
		for x in range(min_c.x, max_c.x + 1):
			var cell := Vector2i(x, y)
			if _region.has_point(cell):
				cells.append(cell)
	return cells

## 动态阻挡：引用计数，多个来源重叠占用同一格时不会误解除
func set_cells_blocked(cells: Array, blocked: bool) -> void:
	if not cells.is_empty(): revision += 1
	if _costs.is_empty():
		return
	for cell in cells:
		var key: Vector2i = cell
		if not _region.has_point(key):
			continue
		if blocked:
			_block_counts[key] = _block_counts.get(key, 0) + 1
			_costs[key.x + key.y * _region.size.x] = -1
		else:
			var count: int = _block_counts.get(key, 0) - 1
			if count <= 0:
				_block_counts.erase(key)
				if not _base_blocked.has(key):
					_costs[key.x + key.y * _region.size.x] = roundi(get_lane_weight_at(cell_to_world(key)) * ROAD_COST)
			else:
				_block_counts[key] = count

## A* 寻路：无节点数上限；起终点若落在阻挡格内自动取最近可行走格
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if _costs.is_empty():
		return PackedVector2Array()
	var from_cell := _nearest_walkable_cell(from, world_to_cell(from))
	# 终点受阻时优先选择靠近来路的一侧，而不是按左上角固定扫描顺序取点。
	var to_cell := _nearest_walkable_cell(to, from_cell)
	if from_cell == to_cell:
		return PackedVector2Array()
	var cells := _search.find_cells(_region.size, _costs, from_cell, to_cell, ROAD_COST)
	var raw := PackedVector2Array()
	for cell in cells:
		raw.append(cell_to_world(cell))
	if raw.size() < 2:
		return PackedVector2Array()
	# A* 返回格中心，但单位通常位于格内任意点。把真实起点纳入平滑，
	# 否则 Unit 跳过第 0 个路径点后，真实位置到第 1 点的线段可能擦进塔碰撞圈。
	var anchored := PackedVector2Array()
	anchored.append(from)
	for point in raw:
		if anchored[anchored.size() - 1].distance_to(point) > 0.01:
			anchored.append(point)
	return _smooth_path(anchored)

## 起点/终点落在阻挡格（塔占地、兵贴河沿）时，环形外扩找最近可行走格
func _nearest_walkable_cell(pos: Vector2, reference: Vector2i) -> Vector2i:
	var cell := world_to_cell(pos)
	if _region.has_point(cell) and not _is_cell_blocked(cell):
		return cell
	for r in range(1, 32):
		var best := Vector2i(-1, -1)
		var best_score := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cand := cell + Vector2i(dx, dy)
				if _region.has_point(cand) and not _is_cell_blocked(cand):
					var score := Vector2(cand).distance_squared_to(Vector2(reference))
					if score < best_score:
						best = cand
						best_score = score
		if best.x >= 0:
			return best
	return cell

func _line_walkable(from: Vector2, to: Vector2) -> bool:
	var dist := from.distance_to(to)
	if dist < 1.0:
		return true
	# 四分之一格采样，不能跨过仅几像素宽的桥岸/塔角阻挡格。
	# 半格采样会在斜线恰好跨格时漏掉一个实心格，单位实走到那里就会停住。
	var count := int(dist / (CELL_SIZE * 0.25)) + 1
	# 平滑可以让非路线上的出生点斜向汇入主路，但不能在两个主路点
	# 之间穿过高成本区，否则会把 A* 得到的路线权重再次抹掉。
	var from_cell := world_to_cell(from)
	var to_cell := world_to_cell(to)
	var max_weight := maxf(get_lane_weight_at(cell_to_world(from_cell)), get_lane_weight_at(cell_to_world(to_cell))) + 0.001
	for i in range(1, count + 1):
		var t := float(i) / float(count)
		var cell := world_to_cell(from.lerp(to, t))
		if not _region.has_point(cell) or _is_cell_blocked(cell):
			return false
		if get_lane_weight_at(cell_to_world(cell)) > max_weight:
			return false
	return true

## 路径平滑：去掉可直线通行的中间拐点，走位更接近 CR 的自然曲线
func _smooth_path(path: PackedVector2Array) -> PackedVector2Array:
	if path.size() <= 2:
		return path
	var result := PackedVector2Array()
	result.append(path[0])
	var anchor := 0
	var i := 2
	while i < path.size():
		if _line_walkable(path[anchor], path[i]):
			i += 1
		else:
			result.append(path[i - 1])
			anchor = i - 1
			i += 1
	result.append(path[path.size() - 1])
	return result
