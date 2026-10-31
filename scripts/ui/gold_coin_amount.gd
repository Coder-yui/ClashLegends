extends Label
## Label 保留文字访问接口；仅在费用或币面尺寸变化时重排。
var _last_text := ""
var _last_size := Vector2.ZERO
var _last_font_size := 0

func _process(_delta: float) -> void:
	var parent := get_parent() as Control
	var font_size := get_theme_font_size("font_size")
	if text == _last_text and parent.size == _last_size and font_size == _last_font_size: return
	_last_text = text
	_last_size = parent.size
	_last_font_size = font_size
	GoldCoin.center_amount(self)
