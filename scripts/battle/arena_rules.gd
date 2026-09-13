class_name ArenaRules
extends RefCounted
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
const STRUCTURE_SEPARATION := 1.0 * CardDB.CHARACTER_SCALE_MULTIPLIER
## 原生 ContactA：向前查询 256 原生坐标；初始偏转 200/256，
## 每个 50ms Tick 衰减 10/256，应用时重新归一化以保持自主步幅。
const AVOID_QUERY_OFFSET := TILE_SIZE * 0.256
const AVOID_TURN := 200.0 / 256.0
const AVOID_TURN_DECAY := (10.0 / 256.0) * 20.0
## 原生接触算法的长度常量按 1000 原生坐标 = 1 地图格转换。
## 它们是解算步幅/限幅，不是卡牌平衡数值；本项目仍使用浮点权威坐标。
const CONTACT_MIN_STEP := TILE_SIZE / 1000.0
const CONTACT_PAIR_LIMIT := TILE_SIZE * 0.3
const CONTACT_STEP_LIMIT := TILE_SIZE * 0.15
## 几何回归允许的接触容差；不再作为求解器的穿透 dead zone。
const COLLISION_SLOP := 0.5 * CardDB.CHARACTER_SCALE_MULTIPLIER
const BRIDGE_EDGE_MARGIN := 2.0 * CardDB.CHARACTER_SCALE_MULTIPLIER
const DEPLOY_PREVIEW_VALID := Color(0.35, 0.95, 0.58, 0.82)
const DEPLOY_PREVIEW_INVALID := Color(1.0, 0.30, 0.30, 0.88)
# 双方地面部署区各 15 行；贴河外角与国王塔后方两侧不可部署。
const TEAM_0_FIRST_ROW := RIVER_BOTTOM_ROW
const TEAM_0_LAST_ROW := ARENA_ROWS - 1
const BACK_CENTER_MIN_COLUMN := 6
const BACK_CENTER_MAX_COLUMN := 11
const POCKET_FIRST_ROW := 9
const POCKET_LAST_ROW := RIVER_TOP_ROW - 1
