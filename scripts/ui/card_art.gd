class_name CardArt
extends RefCounted
## 卡牌 UI 表现层。卡面、费用角标和名称条只负责显示，不参与卡牌数值或战斗逻辑。

const CARD_ART_DIR := "res://assets/cards/"
const CARD_ART_EXTENSIONS := ["jpg", "png", "webp"]
## 卡面会裁切 Loading Screen，因此 UI 使用更接近实体卡牌的宽比例，而不是原图比例。
const CARD_FRAME_ASPECT := 0.72
const DEFAULT_ACCENT := Color(0.30, 0.62, 0.94)
const ELIXIR_PURPLE := Color(0.83, 0.16, 0.93)
static var _card_ui_font: SystemFont
static var _textures: Dictionary = {}

## 默认字体对少数字（例如“远”“程”）可能没有回退字形，卡牌文字统一走中文系统字体链。
static func ui_font() -> SystemFont:
	if _card_ui_font == null:
		_card_ui_font = SystemFont.new()
		_card_ui_font.font_names = PackedStringArray([
			"Hiragino Sans GB", "STHeiti", "Microsoft YaHei", "Noto Sans CJK SC", "WenQuanYi Micro Hei", "Arial Unicode MS"
		])
	return _card_ui_font

static func texture_for(card_id: String) -> Texture2D:
	if _textures.has(card_id):
		return _textures[card_id]
	var configured := String(CardDB.get_card(card_id).get("card_art", {}).get("path", ""))
	var candidates: Array[String] = []
	if not configured.is_empty():
		candidates.append(configured)
	else:
		for extension in CARD_ART_EXTENSIONS:
			candidates.append("%s%s_loading.%s" % [CARD_ART_DIR, card_id, extension])
	for path in candidates:
		if ResourceLoader.exists(path):
			_textures[card_id] = load(path) as Texture2D
			return _textures[card_id]
	_textures[card_id] = null
	return null

## 缺省图标返回 null，由 UI 保留既有文字占位。
static func skill_icon(skill: Dictionary) -> Texture2D:
	var path := String(skill.get("icon_path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

static func frame_size_for_height(height: float) -> Vector2:
	return Vector2(roundf(height * CARD_FRAME_ASPECT), height)

static func frame_style(background: Color, border: Color, border_width: int = 2, radius: int = 9) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style

static func _badge_style(color: Color, border: Color = Color(1.0, 0.72, 1.0, 0.9)) -> StyleBoxFlat:
	var style := frame_style(color, border, 2, 99)
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style

static func _name_bar_style(accent: Color, selected: bool) -> StyleBoxFlat:
	var background := Color(0.025, 0.055, 0.10, 0.94)
	var border := Color(1.0, 0.82, 0.28, 0.95) if selected else accent.lightened(0.18)
	var style := frame_style(background, border, 1, 5)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.content_margin_left = 2.0
	style.content_margin_right = 2.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style

## 给备战页和战斗手牌统一设置卡框。width > 0 时允许战斗栏使用更易点按的宽卡。
static func apply_frame(button: Button, height: float, compact: bool = false, width: float = 0.0) -> void:
	var frame_size := frame_size_for_height(height)
	if width > 0.0:
		frame_size.x = width
	button.custom_minimum_size = frame_size
	button.clip_contents = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12 if compact else 15)
	button.add_theme_font_override("font", ui_font())
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.set_meta("card_compact", compact)
	button.set_meta("card_accent", DEFAULT_ACCENT)
	button.set_meta("card_selected", false)
	button.set_meta("card_affordable", true)
	button.set_meta("active_skill_card", false)
	_apply_button_styles(button)

static func _apply_button_styles(button: Button) -> void:
	var accent: Color = button.get_meta("card_accent", DEFAULT_ACCENT)
	var selected := bool(button.get_meta("card_selected", false))
	var affordable := bool(button.get_meta("card_affordable", true))
	var active_skill_card := bool(button.get_meta("active_skill_card", false))
	var border_width := 4 if selected else (3 if active_skill_card else 2)
	var normal_border := Color(1.0, 0.82, 0.25) if selected else (Color(1.0, 0.76, 0.28, 0.96) if active_skill_card else accent.lightened(0.18))
	button.add_theme_stylebox_override("normal", frame_style(Color(0.045, 0.08, 0.14), normal_border, border_width))
	var hover_border := Color(1.0, 0.91, 0.54, 1.0) if active_skill_card else accent.lightened(0.38)
	button.add_theme_stylebox_override("hover", frame_style(Color(0.08, 0.16, 0.26), hover_border, 3))
	button.add_theme_stylebox_override("pressed", frame_style(Color(0.07, 0.22, 0.36), Color(1.0, 0.84, 0.28), 4))
	var disabled_border := normal_border.darkened(0.48) if affordable else Color(0.20, 0.24, 0.31)
	button.add_theme_stylebox_override("disabled", frame_style(Color(0.035, 0.045, 0.065), disabled_border, 2))

## 将 Loading Screen 以 cover 方式放进卡框。没有图片的牌使用数据色占位卡面。
## 名称和费用始终由独立控件显示，避免长文本互相覆盖形成“乱码”。
static func apply_to_button(
	button: Button,
	card_id: String,
	title: String,
	cost: int,
	compact: bool = false,
	accent: Color = DEFAULT_ACCENT
) -> bool:
	var texture := texture_for(card_id)
	button.text = ""
	button.tooltip_text = "%s · %d 费" % [title, cost]
	button.set_meta("card_compact", compact)
	button.set_meta("card_accent", accent)

	var artwork := button.get_node_or_null("CardArtwork") as TextureRect
	if artwork == null:
		artwork = TextureRect.new()
		artwork.name = "CardArtwork"
		artwork.set_anchors_preset(Control.PRESET_FULL_RECT)
		artwork.offset_left = 4.0
		artwork.offset_top = 4.0
		artwork.offset_right = -4.0
		artwork.offset_bottom = -4.0
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		artwork.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(artwork)
	artwork.texture = texture
	artwork.visible = texture != null

	var placeholder := button.get_node_or_null("CardPlaceholder") as ColorRect
	var glyph := button.get_node_or_null("CardPlaceholderGlyph") as Label
	if placeholder == null:
		placeholder = ColorRect.new()
		placeholder.name = "CardPlaceholder"
		placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
		placeholder.offset_left = 4.0
		placeholder.offset_top = 4.0
		placeholder.offset_right = -4.0
		placeholder.offset_bottom = -4.0
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(placeholder)
		glyph = Label.new()
		glyph.name = "CardPlaceholderGlyph"
		glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.78))
		glyph.add_theme_font_override("font", ui_font())
		glyph.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
		glyph.add_theme_constant_override("outline_size", 4)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(glyph)
	placeholder.color = Color(accent.r * 0.42, accent.g * 0.42, accent.b * 0.42, 1.0)
	placeholder.visible = texture == null
	glyph.visible = texture == null
	glyph.text = title.left(1)
	glyph.add_theme_font_size_override("font_size", 28 if compact else 46)

	var unavailable_tint := button.get_node_or_null("CardUnavailableTint") as ColorRect
	if unavailable_tint == null:
		unavailable_tint = ColorRect.new()
		unavailable_tint.name = "CardUnavailableTint"
		unavailable_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		unavailable_tint.offset_left = 3.0
		unavailable_tint.offset_top = 3.0
		unavailable_tint.offset_right = -3.0
		unavailable_tint.offset_bottom = -3.0
		unavailable_tint.color = Color(0.02, 0.025, 0.05, 0.58)
		unavailable_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(unavailable_tint)

	var name_bar := button.get_node_or_null("CardNameBar") as PanelContainer
	var name_label := button.get_node_or_null("CardNameBar/CardName") as Label
	if name_bar == null:
		name_bar = PanelContainer.new()
		name_bar.name = "CardNameBar"
		name_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		name_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(name_bar)
		name_label = Label.new()
		name_label.name = "CardName"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.add_theme_font_override("font", ui_font())
		name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_bar.add_child(name_label)
	var name_height := 25.0 if compact else 34.0
	name_bar.visible = true
	name_bar.offset_top = -name_height
	name_bar.offset_bottom = -4.0
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 13 if compact else 18)
	name_label.add_theme_constant_override("outline_size", 3 if compact else 4)

	var cost_badge := button.get_node_or_null("CardCostBadge") as PanelContainer
	var cost_label := button.get_node_or_null("CardCostBadge/CardCost") as Label
	if cost_badge == null:
		cost_badge = PanelContainer.new()
		cost_badge.name = "CardCostBadge"
		cost_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
		cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(cost_badge)
		cost_label = Label.new()
		cost_label.name = "CardCost"
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_label.add_theme_color_override("font_color", Color.WHITE)
		cost_label.add_theme_font_override("font", ui_font())
		cost_label.add_theme_color_override("font_outline_color", Color(0.16, 0.01, 0.20, 0.95))
		cost_label.add_theme_constant_override("outline_size", 3)
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_badge.add_child(cost_label)
	var badge_size := 29.0 if compact else 37.0
	cost_badge.visible = true
	cost_badge.offset_left = 1.0
	cost_badge.offset_top = 1.0
	cost_badge.offset_right = 1.0 + badge_size
	cost_badge.offset_bottom = 1.0 + badge_size
	cost_label.text = "?" if CardPlayHistory.is_mirror(card_id) else str(cost)
	cost_label.add_theme_font_size_override("font_size", 17 if compact else 22)

	_apply_button_styles(button)
	set_affordable(button, bool(button.get_meta("card_affordable", true)))
	set_selected(button, bool(button.get_meta("card_selected", false)))
	return texture != null

static func show_empty_slot(button: Button, slot_number: int) -> void:
	button.text = "+"
	button.tooltip_text = "点击卡槽，再从下方卡牌库选择一张卡牌"
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_color_override("font_color", Color(0.58, 0.70, 0.84))
	for child_name in ["CardArtwork", "CardPlaceholder", "CardPlaceholderGlyph", "CardUnavailableTint", "CardNameBar", "CardCostBadge", "CardSelectedMark", "ActiveSkillMarker"]:
		var child := button.get_node_or_null(child_name)
		if child != null:
			child.visible = false
	button.set_meta("card_accent", Color(0.23, 0.34, 0.48))
	button.set_meta("card_selected", false)
	button.set_meta("card_affordable", true)
	button.set_meta("active_skill_card", false)
	_apply_button_styles(button)

static func set_affordable(button: Button, affordable: bool) -> void:
	button.set_meta("card_affordable", affordable)
	var tint := button.get_node_or_null("CardUnavailableTint") as ColorRect
	if tint != null:
		tint.visible = not affordable
	var cost_badge := button.get_node_or_null("CardCostBadge") as PanelContainer
	if cost_badge != null:
		var badge_color := ELIXIR_PURPLE if affordable else Color(0.34, 0.28, 0.38)
		cost_badge.add_theme_stylebox_override("panel", _badge_style(badge_color))
	_apply_button_styles(button)

## 主动卡的非文字识别标记：细金边 + 角落符印，跟随卡牌而不是跟随手牌位置。
static func set_active_skill_card(button: Button, active: bool) -> void:
	button.set_meta("active_skill_card", active)
	var marker := button.get_node_or_null("ActiveSkillMarker") as Control
	if marker == null:
		marker = Control.new()
		marker.name = "ActiveSkillMarker"
		marker.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		marker.offset_left = -31.0
		marker.offset_top = 5.0
		marker.offset_right = -5.0
		marker.offset_bottom = 31.0
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(marker)

		var halo := Panel.new()
		halo.name = "Halo"
		halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		halo.add_theme_stylebox_override("panel", frame_style(Color(0.36, 0.20, 0.04, 0.48), Color(1.0, 0.86, 0.48, 0.88), 1, 99))
		marker.add_child(halo)

		var gem := Panel.new()
		gem.name = "Gem"
		gem.position = Vector2(8.0, 8.0)
		gem.size = Vector2(10.0, 10.0)
		gem.pivot_offset = Vector2(5.0, 5.0)
		gem.rotation = PI * 0.25
		gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gem.add_theme_stylebox_override("panel", frame_style(Color(1.0, 0.76, 0.22, 0.98), Color(1.0, 0.97, 0.72, 1.0), 1, 3))
		marker.add_child(gem)

		var core := Panel.new()
		core.name = "Core"
		core.position = Vector2(11.0, 11.0)
		core.size = Vector2(4.0, 4.0)
		core.mouse_filter = Control.MOUSE_FILTER_IGNORE
		core.add_theme_stylebox_override("panel", _badge_style(Color(0.12, 0.08, 0.02, 0.95), Color(1.0, 0.93, 0.62, 1.0)))
		marker.add_child(core)
	marker.move_to_front()
	marker.visible = active
	_apply_button_styles(button)

static func set_selected(button: Button, selected: bool, show_mark: bool = false) -> void:
	button.set_meta("card_selected", selected)
	var accent: Color = button.get_meta("card_accent", DEFAULT_ACCENT)
	var name_bar := button.get_node_or_null("CardNameBar") as PanelContainer
	if name_bar != null:
		name_bar.add_theme_stylebox_override("panel", _name_bar_style(accent, selected))
	var mark := button.get_node_or_null("CardSelectedMark") as Label
	if show_mark and mark == null:
		mark = Label.new()
		mark.name = "CardSelectedMark"
		mark.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		mark.offset_left = -30.0
		mark.offset_top = 5.0
		mark.offset_right = -4.0
		mark.offset_bottom = 31.0
		mark.text = "✓"
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.add_theme_font_size_override("font_size", 19)
		mark.add_theme_font_override("font", ui_font())
		mark.add_theme_color_override("font_color", Color(0.45, 1.0, 0.58))
		mark.add_theme_color_override("font_outline_color", Color(0.0, 0.1, 0.02))
		mark.add_theme_constant_override("outline_size", 4)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(mark)
	if mark != null:
		mark.visible = show_mark and selected
	_apply_button_styles(button)

## 运行期玻璃纹与双框覆盖原画，不生成/缓存每个英雄的图片副本。
static func set_mirror_overlay(button: Button, enabled: bool) -> void:
	var glass := button.get_node_or_null("MirrorGlass") as ColorRect
	if glass == null:
		glass = ColorRect.new()
		glass.name = "MirrorGlass"
		glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader := preload("res://scripts/ui/mirror_card.gdshader")
		var material := ShaderMaterial.new()
		material.shader = shader
		glass.material = material
		button.add_child(glass)
		# 卡名与费用仍覆盖在玻璃上方。
		button.move_child(glass, mini(3, button.get_child_count() - 1))
	glass.visible = enabled
