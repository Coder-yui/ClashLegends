class_name GoldCoin
extends RefCounted
## 唯一金币母版；卡费、技能、钱包与战场收益共享同一纹理。
const TEXTURE := preload("res://assets/ui/gold_coin.svg")
static var _font: SystemFont

static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Arial", "Helvetica", "Liberation Sans"])
		_font.font_weight = 700
	return _font

static func style() -> StyleBoxTexture:
	var result := StyleBoxTexture.new()
	result.texture = TEXTURE
	result.set_content_margin_all(0)
	return result

static func amount(font_size: int) -> Label:
	var label := preload("res://scripts/ui/gold_coin_amount.gd").new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("352514"))
	label.add_theme_color_override("font_outline_color", Color("ffe9a8"))
	label.add_theme_constant_override("outline_size", 1)
	return label

static func icon(diameter: float) -> Control:
	var control := Control.new()
	control.custom_minimum_size = Vector2.ONE * diameter
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.draw.connect(func(): draw_icon(control, Rect2(Vector2.ZERO, control.size)))
	control.resized.connect(control.queue_redraw)
	return control

static func draw_icon(canvas: CanvasItem, rect: Rect2, alpha: float = 1.0) -> void:
	canvas.draw_texture_rect(TEXTURE, rect, false, Color(1, 1, 1, alpha))
	var center := rect.position + rect.size * Vector2(0.5, 46.0 / 96.0)
	var radius := rect.size * 0.18
	var points := PackedVector2Array([center + Vector2(0, -radius.y), center + Vector2(radius.x * 0.72, 0), center + Vector2(0, radius.y), center + Vector2(-radius.x * 0.72, 0), center + Vector2(0, -radius.y)])
	canvas.draw_polyline(points, Color(0.43, 0.27, 0.10, alpha), maxf(1.2, rect.size.x * 0.045), true)
	canvas.draw_line(center - Vector2(0, radius.y * 0.45), center + Vector2(0, radius.y * 0.45), Color(1.0, 0.91, 0.60, alpha), maxf(1.0, rect.size.x * 0.035), true)

## 按字形墨迹居中，避免 1、0、? 和双位数受字体行高影响。
static func center_amount(label: Label) -> void:
	var current_font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var server := TextServerManager.get_primary_interface()
	var rid: RID = current_font.get_rids()[0]
	var pen := 0.0
	var ink := Rect2()
	var first := true
	for character in label.text:
		var glyph := server.font_get_glyph_index(rid, font_size, character.unicode_at(0), 0)
		var contours := server.font_get_glyph_contours(rid, font_size, glyph)
		var points: PackedVector3Array = contours.get("points", PackedVector3Array())
		for point in points:
			var pos := Vector2(pen + point.x, point.y)
			ink = Rect2(pos, Vector2.ZERO) if first else ink.expand(pos)
			first = false
		pen += current_font.get_char_size(character.unicode_at(0), font_size).x
	if first: return
	var parent := label.get_parent() as Control
	label.position = parent.size * Vector2(0.5, 46.0 / 96.0) - ink.get_center() - Vector2(0, current_font.get_ascent(font_size))
