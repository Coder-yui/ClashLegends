class_name RuneSlotFrame
extends MarginContainer
## One crafted slot frame: iron cradle, bronze fittings and an amethyst clasp.
## Decorative only; card identity, costs and active eligibility remain external.
var active := false:
	set(value):
		active = value
		queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for edge in ["left", "right", "top"]:
		add_theme_constant_override("margin_" + edge, 12)
	add_theme_constant_override("margin_bottom", 18)
	resized.connect(queue_redraw)

func _draw() -> void:
	if active:
		draw_texture_rect(UIMaterials.slot_frame(), Rect2(Vector2.ZERO, size), false)
