extends RefCounted
## 只调整工作台窗口和显示变换；权威战场仍为 720×1280。
const SIZE := Vector2i(1440, 1000)
const FIELD_RECT := Rect2(656, 20, 768, 960)
const FIELD_SIZE := Vector2(720, 1280)
const FIT_SCALE := 0.75
var zoom := 1.0
var _window: Window
var _old_size: Vector2i
var _old_position: Vector2i
var _old_content_size: Vector2i
var _old_transform: Transform2D
var _old_min_size: Vector2i

func install(window: Window) -> void:
	_window = window
	_old_size = window.size
	_old_position = window.position
	_old_content_size = window.content_scale_size
	_old_transform = window.canvas_transform
	_old_min_size = window.min_size
	window.content_scale_size = SIZE
	center(1.0)
	if DisplayServer.get_name() != "headless":
		var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
		var scale := minf(float(usable.size.x - 24) / SIZE.x, float(usable.size.y - 34) / SIZE.y)
		window.min_size = Vector2i(864, 600)
		window.size = Vector2i(Vector2(SIZE) * scale)
		window.position = usable.position + (usable.size - window.size) / 2

func center(value: float) -> void:
	zoom = clampf(value, 1.0, 3.0)
	var scale := FIT_SCALE * zoom
	_apply(FIELD_RECT.get_center() - FIELD_SIZE * scale / 2.0)

func zoom_at(value: float, screen_position: Vector2) -> void:
	var world_position := _window.canvas_transform.affine_inverse() * screen_position
	zoom = clampf(value, 1.0, 3.0)
	_apply(screen_position - world_position * FIT_SCALE * zoom)

func pan(delta: Vector2) -> void:
	_apply(_window.canvas_transform.origin + delta)

func _apply(origin: Vector2) -> void:
	var scale := FIT_SCALE * zoom
	var displayed := FIELD_SIZE * scale
	for axis in 2:
		if displayed[axis] <= FIELD_RECT.size[axis]:
			origin[axis] = FIELD_RECT.position[axis] + (FIELD_RECT.size[axis] - displayed[axis]) / 2.0
		else:
			origin[axis] = clampf(origin[axis], FIELD_RECT.end[axis] - displayed[axis], FIELD_RECT.position[axis])
	_window.canvas_transform = Transform2D(Vector2(scale, 0), Vector2(0, scale), origin)

func restore() -> void:
	if not is_instance_valid(_window): return
	_window.canvas_transform = _old_transform
	_window.content_scale_size = _old_content_size
	_window.min_size = _old_min_size
	if DisplayServer.get_name() != "headless":
		_window.size = _old_size
		_window.position = _old_position
	_window = null
