class_name CardGrowthBars
extends Control
## Read-only, recessed crystal counters. Gameplay owns all thresholds and progress.

class Crystal extends Control:
	var color := Color.WHITE:
		set(value):
			color = value
			queue_redraw()

	func _draw() -> void:
		var face := color.lerp(Color("b2c3c5"), 0.14)
		var points := PackedVector2Array([Vector2(0, 2), Vector2(2, 0), Vector2(size.x - 2, 0), Vector2(size.x, 2), Vector2(size.x, size.y - 2), Vector2(size.x - 2, size.y), Vector2(2, size.y), Vector2(0, size.y - 2), Vector2(0, 2)])
		draw_colored_polygon(points, face.darkened(0.18))
		draw_polyline(points, face.lightened(0.18), 0.7, true)
		draw_line(Vector2(2, 1.5), Vector2(size.x - 2, 1.5), face.lightened(0.35), 1.0, true)
		draw_line(Vector2(size.x * 0.5, 2), Vector2(size.x * 0.5, size.y - 1), face, 1.0, true)

var counts := Vector2i.ZERO

func configure(ranged: int, melee: int) -> void:
	counts = Vector2i(ranged, melee)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in 2:
		for index in counts[side]:
			var cell := Crystal.new()
			cell.name = ("ranged" if side == 0 else "melee") + str(index)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(cell)
	resized.connect(_layout_cells)
	_layout_cells()

func _rail(side: int) -> Rect2:
	return Rect2(3.0 if side == 0 else size.x - 15.0, 33.0, 12.0, maxf(24.0, size.y - 59.0))

func _layout_cells() -> void:
	for side in 2:
		var rail := _rail(side)
		var step := (rail.size.y - 4.0) / maxi(1, counts[side])
		for index in counts[side]:
			var cell := get_node(("ranged" if side == 0 else "melee") + str(index)) as Control
			cell.position = Vector2(rail.position.x + 3.0, rail.end.y - 2.0 - step * (index + 1))
			cell.size = Vector2(6.0, step - 2.0)
			cell.queue_redraw()
	queue_redraw()

func _draw() -> void:
	for side in 2:
		var rail := _rail(side)
		draw_style_box(UIMaterials.panel(Color(0.48, 0.61, 0.72), 0), rail)
		draw_rect(rail.grow(-2), Color("09151e"))
