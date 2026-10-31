class_name UIMaterials
extends RefCounted
## 位图材质共用入口。九宫格纹理只在首次使用时归一尺寸，边角不随面板拉伸。
const BACKGROUND := preload("res://assets/ui/materials/rune_archive.png")
const RUNE := preload("res://assets/ui/materials/active_rune.png")
const PANEL := preload("res://assets/ui/materials/slate_panel.png")
const SLOT_FRAME := preload("res://assets/ui/materials/active_slot_frame.png")
static var _slot_frame: Texture2D
static var _panel: Texture2D
static var _rune: Texture2D

static func panel(tint: Color = Color.WHITE, content_margin: float = 8.0) -> StyleBoxTexture:
	if _panel == null:
		var source := PANEL.get_image()
		if source.is_compressed(): source.decompress()
		source.resize(256, 256, Image.INTERPOLATE_LANCZOS)
		_panel = ImageTexture.create_from_image(source)
	var style := StyleBoxTexture.new()
	style.texture = _panel
	style.set_texture_margin_all(16.0)
	style.set_content_margin_all(content_margin)
	style.modulate_color = tint
	return style

static func rune() -> Texture2D:
	if _rune == null:
		var source := RUNE.get_image()
		if source.is_compressed(): source.decompress()
		source.resize(128, 128, Image.INTERPOLATE_LANCZOS)
		source.generate_mipmaps()
		_rune = ImageTexture.create_from_image(source)
	return _rune

static func slot_frame() -> Texture2D:
	if _slot_frame == null:
		var source := SLOT_FRAME.get_image()
		if source.is_compressed(): source.decompress()
		# Remove transparent delivery padding without modifying the original asset.
		source = source.get_region(source.get_used_rect())
		source.resize(304, 392, Image.INTERPOLATE_LANCZOS)
		source.generate_mipmaps()
		_slot_frame = ImageTexture.create_from_image(source)
	return _slot_frame
