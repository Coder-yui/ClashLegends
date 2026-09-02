extends RefCounted
class_name NavGrid
## 导航网格：全网格 A* 寻路，参考皇室战争竞技场布局。
## 河道为硬阻挡，桥是唯一的地面跨河通道；
## 塔的占地在 build() 时写入，建筑卡的占地由外部动态注册。
## 动态阻挡用引用计数：塔被摧毁 / 建筑卡到期或被摧毁时解除对应格子，
## 路径即可穿过原塔位（对齐 CR 摧毁后塔位可通行的规则）。
## 寻路与渲染解耦，不依赖帧率，保证联机两端行为一致。

const CELL_SIZE := 16.0
const LANE_HALF_TILE := 20.0
const OFF_LANE_WEIGHT := 1.25
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

var _astar: AStarGrid2D
# 永久阻挡（河道），引用计数解除时也不放开
var _base_blocked := {}
# 动态阻挡引用计数（塔 / 建筑卡占地）
var _block_counts := {}

## 构建网格：河道（除桥）永久阻挡，obstacles = [[pos, radius], ...] 圆形占地阻挡
func build(size: Vector2, river_y: float, river_half: float, bridge_xs: Array, bridge_half: float, obstacles: Array) -> void:
	_astar = AStarGrid2D.new()
	var cols := int(size.x / CELL_SIZE)
	var rows := int(size.y / CELL_SIZE)
	_astar.region = Rect2i(0, 0, cols, rows)
	_astar.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	# AStarGrid2D 默认把路径点放在格子左上角，而阻挡判定使用格子中心。
	# 两者错开半格会让平滑路径看似可走、单位实际前进时却撞上相邻阻挡格。
	_astar.offset = Vector2.ONE * CELL_SIZE * 0.5
	# 禁止沿两个障碍格的夹角斜穿，避免单位从塔角/河岸角“切过去”。
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	_base_blocked = {}
	_block_counts = {}
	for y in rows:
		for x in cols:
			var cell := Vector2i(x, y)
			var world_pos := cell_to_world(cell)
			_astar.set_point_weight_scale(cell, get_lane_weight_at(world_pos))
			if _is_river_blocked(world_pos, river_y, river_half, bridge_xs, bridge_half):
				_base_blocked[cell] = true
				_astar.set_point_solid(cell)
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

func is_walkable(pos: Vector2) -> bool:
	if _astar == null:
		return false
	var cell := world_to_cell(pos)
	if not _astar.region.has_point(cell):
		return false
	return not _astar.is_point_solid(cell)

## 只检查河道/场地等永久地形，不包含塔与建筑的扩张导航占地。
## 实际移动用它配合连续形状碰撞，避免单位处在 A* 的保守边缘格时无法离开。
func is_terrain_walkable(pos: Vector2) -> bool:
	if _astar == null:
		return false
	var cell := world_to_cell(pos)
	if not _astar.region.has_point(cell):
		return false
	return not _base_blocked.has(cell)

## 返回推进偏好权重：1.0 是宽松的左右路区，1.25 是仍可通行的非主路区。
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
	if _astar == null:
		return cells
	var min_c := world_to_cell(center - Vector2(radius, radius))
	var max_c := world_to_cell(center + Vector2(radius, radius))
	for y in range(min_c.y, max_c.y + 1):
		for x in range(min_c.x, max_c.x + 1):
			var cell := Vector2i(x, y)
			if not _astar.region.has_point(cell):
				continue
			if cell_to_world(cell).distance_to(center) <= radius:
				cells.append(cell)
	return cells

## 矩形占地覆盖的格子（用于方形塔与建筑卡）。
func cells_for_rect(rect: Rect2) -> Array:
	var cells := []
	if _astar == null:
		return cells
	var min_c := world_to_cell(rect.position)
	var max_c := world_to_cell(rect.end - Vector2.ONE * 0.001)
	for y in range(min_c.y, max_c.y + 1):
		for x in range(min_c.x, max_c.x + 1):
			var cell := Vector2i(x, y)
			if _astar.region.has_point(cell):
				cells.append(cell)
	return cells

## 动态阻挡：引用计数，多个来源重叠占用同一格时不会误解除
func set_cells_blocked(cells: Array, blocked: bool) -> void:
	if _astar == null:
		return
	for cell in cells:
		var key: Vector2i = cell
		if not _astar.region.has_point(key):
			continue
		if blocked:
			_block_counts[key] = _block_counts.get(key, 0) + 1
			_astar.set_point_solid(key)
		else:
			var count: int = _block_counts.get(key, 0) - 1
			if count <= 0:
				_block_counts.erase(key)
				if not _base_blocked.has(key):
					_astar.set_point_solid(key, false)
			else:
				_block_counts[key] = count

## A* 寻路：无节点数上限；起终点若落在阻挡格内自动取最近可行走格
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if _astar == null:
		return PackedVector2Array()
	var from_cell := _nearest_walkable_cell(from, world_to_cell(from))
	# 终点受阻时优先选择靠近来路的一侧，而不是按左上角固定扫描顺序取点。
	var to_cell := _nearest_walkable_cell(to, from_cell)
	if from_cell == to_cell:
		return PackedVector2Array()
	var raw := _astar.get_point_path(from_cell, to_cell)
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
	if _astar.region.has_point(cell) and not _astar.is_point_solid(cell):
		return cell
	for r in range(1, 32):
		var best := Vector2i(-1, -1)
		var best_score := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cand := cell + Vector2i(dx, dy)
				if _astar.region.has_point(cand) and not _astar.is_point_solid(cand):
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
	var max_weight := maxf(_astar.get_point_weight_scale(from_cell), _astar.get_point_weight_scale(to_cell)) + 0.001
	for i in range(1, count + 1):
		var t := float(i) / float(count)
		var cell := world_to_cell(from.lerp(to, t))
		if not _astar.region.has_point(cell) or _astar.is_point_solid(cell):
			return false
		if _astar.get_point_weight_scale(cell) > max_weight:
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
