class_name UIPalette
extends RefCounted
## 海克斯铸金：共享展示色；不参与阵营、费用或交互判断。
const INK := Color("09151e")
const PANEL := Color("102833")
const PANEL_LIGHT := Color("193b46")
const LINE := Color("52656a")
const GOLD := Color("d5b777")
const GOLD_LIGHT := Color("f4dfaa")
const TEAL := Color("66d3d4")
const TEXT := Color("f2eee3")
const MUTED := Color("9db7bd")

## 卡框保留原卡色相，但收敛为七组重复使用的矿物色；不表示稀有度或玩法分类。
const CARD_AZURE := Color("719cda")
const CARD_CYAN := Color("69c5ce")
const CARD_JADE := Color("76b996")
const CARD_AMBER := Color("d4ad65")
const CARD_EMBER := Color("cf7e77")
const CARD_AMETHYST := Color("ab89cf")
const CARD_SILVER := Color("a4b4bf")

static func card_border(source: Color) -> Color:
	if source.s < 0.16: return CARD_SILVER
	var hue := source.h
	if hue < 0.055 or hue >= 0.90: return CARD_EMBER
	if hue < 0.18: return CARD_AMBER
	if hue < 0.44: return CARD_JADE
	if hue < 0.55: return CARD_CYAN
	if hue < 0.69: return CARD_AZURE
	return CARD_AMETHYST

static func panel(background: Color = PANEL, border: Color = LINE, width: int = 1, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.02, 0.03, 0.35)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 3)
	style.set_content_margin_all(4)
	return style
