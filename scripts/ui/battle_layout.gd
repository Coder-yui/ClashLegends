extends RefCounted
## 显示构图与整体缩放的唯一来源，不缩放权威 Node2D。
const FIELD_SIZE := Vector2(ArenaRules.FIELD_W, ArenaRules.FIELD_H)
const DESIGN_SIZE := Vector2i(720, 1280)
const HUD_WIDTH := 720.0
const HAND_HEIGHT := 120.0
const SKILL_SIZE := 58.0
const SKILL_GAP := 3.0
## 最后一排可部署格的外边缘，不是格心或水晶中心。
const BLUE_BACK_EDGE := (ArenaRules.TEAM_0_LAST_ROW + 1) * ArenaRules.TILE_SIZE
const RED_BACK_EDGE := (ArenaRules.ARENA_ROWS - 1 - ArenaRules.TEAM_0_LAST_ROW) * ArenaRules.TILE_SIZE
const BACK_MARGIN := ArenaRules.TILE_SIZE
const BASE_TOP := RED_BACK_EDGE - BACK_MARGIN
const BASE_BOTTOM := BLUE_BACK_EDGE + BACK_MARGIN
const BASE_WORLD_HEIGHT := BASE_BOTTOM - BASE_TOP
const BASE_WORLD_SCALE := (DESIGN_SIZE.y - HAND_HEIGHT) / BASE_WORLD_HEIGHT

## 与画面整体大小有关的唯一缩放；长屏保持宽度，不随新增高度放大。
## 正常运行时 Godot canvas_items 已把物理像素归一到逻辑画布，不能再乘一次 DPI。
static func ui_scale(size: Vector2) -> float:
	return minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)

static func canvas(size: Vector2, flipped: bool = false) -> Transform2D:
	var scale := BASE_WORLD_SCALE * ui_scale(size)
	var center := Vector2(size.x * 0.5, (size.y - HAND_HEIGHT * ui_scale(size)) * 0.5)
	var world_center := Vector2(FIELD_SIZE.x * 0.5, (BASE_TOP + BASE_BOTTOM) * 0.5)
	var signed_scale := -scale if flipped else scale
	return Transform2D(Vector2(signed_scale, 0), Vector2(0, signed_scale), center - world_center * signed_scale)

static func visible_world(size: Vector2, transform: Transform2D) -> Rect2:
	var inverse := transform.affine_inverse()
	var a := inverse * Vector2.ZERO
	var b := inverse * size
	# 手机9:16～9:20优先；异常比例只显示有限外围，余下留统一背景。
	var start := a.min(b).max(-FIELD_SIZE * Vector2(1, 0.5)).floor()
	var end := a.max(b).min(FIELD_SIZE * Vector2(2, 1.5)).ceil()
	return Rect2(start, end - start)

static func hand_origin(size: Vector2) -> Vector2:
	var scale := ui_scale(size)
	return Vector2((size.x - HUD_WIDTH * scale) * 0.5, size.y - HAND_HEIGHT * scale)

static func skill_origin(size: Vector2) -> Vector2:
	return hand_origin(size) - Vector2(0, (SKILL_SIZE + SKILL_GAP) * ui_scale(size))

## Godot macOS窗口/屏幕API使用Retina像素；边距先用逻辑点定义。
static func default_client_size(usable_size: Vector2i, decoration_size: Vector2i, screen_scale: float) -> Vector2i:
	var backing_scale := maxf(screen_scale, 1.0)
	# Cocoa会把半逻辑点的窗口宽度取整；先按整逻辑点的9:16单位计算。
	var available_points := Vector2(usable_size - decoration_size) / backing_scale - Vector2.ONE * 8.0
	var point_units := floori(minf(available_points.x / 9.0, available_points.y / 16.0))
	var pixel_units := maxi(1, floori(point_units * backing_scale))
	return Vector2i(9, 16) * pixel_units

static func fit_window(window: Window) -> void:
	if DisplayServer.get_name() == "headless": return
	var screen := window.current_screen
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var decorations := window.get_size_with_decorations() - window.size
	var client_offset := window.position - window.get_position_with_decorations()
	var client_size := default_client_size(usable.size, decorations, DisplayServer.screen_get_scale(screen))
	window.min_size = Vector2i(360, 480)
	window.size = client_size
	# 居中完整外框，客户区位置需加回标题栏偏移；usable已排除菜单栏和Dock。
	window.position = usable.position + (usable.size - client_size - decorations) / 2 + client_offset
