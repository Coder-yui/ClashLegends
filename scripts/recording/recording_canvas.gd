extends SubViewport
## 重用同一份2D绘制与HUD canvas；没有复制战斗节点、模拟时钟或输入。
const LAYOUT := preload("res://scripts/ui/battle_layout.gd")
const DESIGN := Vector2(720, 1280)
var _source: Node2D
var _canvases: Array[RID] = []
var _density := 1.0

func setup(source: Node2D, output_size: Vector2i) -> void:
	_source = source
	size = output_size
	_density = output_size.x / DESIGN.x
	disable_3d = true
	gui_disable_input = true
	world_2d = source.get_world_2d()
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	refresh()

func refresh() -> void:
	var scale_transform := Transform2D.IDENTITY.scaled(Vector2.ONE * _density)
	canvas_transform = scale_transform * LAYOUT.canvas(DESIGN, _source.runtime.local_team == 1)
	_attach(_source._hand, scale_transform * Transform2D(0.0, LAYOUT.hand_origin(DESIGN)))
	_attach(_source._active_skill_bar, scale_transform * Transform2D(0.0, LAYOUT.skill_origin(DESIGN)))
	var source_size: Vector2 = _source.get_viewport_rect().size
	var ui_scale: float = LAYOUT.ui_scale(source_size)
	if is_instance_valid(_source._timer_label):
		var timer_transform := Transform2D.IDENTITY.scaled(Vector2.ONE / ui_scale)
		timer_transform.origin.x = (DESIGN.x - source_size.x / ui_scale) * 0.5
		_attach(_source._timer_label.get_parent(), scale_transform * timer_transform)
	if is_instance_valid(_source._cast_notice):
		_attach(_source._cast_notice.get_parent(), canvas_transform * _source.get_viewport().canvas_transform.affine_inverse())
	for node_name in ["MatchResult", "ContractFailure", "StartupFailure"]:
		var overlay := _source.get_node_or_null(NodePath(node_name)) as CanvasLayer
		_attach(overlay, scale_transform * Transform2D(0.0, (DESIGN - source_size) * 0.5))

func _attach(layer: CanvasLayer, transform: Transform2D) -> void:
	if not is_instance_valid(layer): return
	var canvas := layer.get_canvas()
	var viewport := get_viewport_rid()
	if canvas not in _canvases:
		RenderingServer.viewport_attach_canvas(viewport, canvas)
		_canvases.append(canvas)
	RenderingServer.viewport_set_canvas_stacking(viewport, canvas, layer.layer, layer.get_index())
	RenderingServer.viewport_set_canvas_transform(viewport, canvas, transform)

func _exit_tree() -> void:
	for canvas in _canvases:
		RenderingServer.viewport_remove_canvas(get_viewport_rid(), canvas)
	_canvases.clear()
