extends Node2D
## 只消费真实格挡事件；短时间连击刷新同一处文字，避免身体上堆字。
const DURATION := 0.48
var elapsed := DURATION
var source: Unit

func _ready() -> void:
	source = get_parent() as Unit
	z_index = 20
	source.presentation_cue.connect(_on_cue)

func _on_cue(cue: StringName) -> void:
	if cue == &"counter_strike:dodge":
		elapsed = 0.0
		queue_redraw()

func _process(delta: float) -> void:
	if elapsed >= DURATION: return
	elapsed = minf(elapsed + delta, DURATION)
	queue_redraw()

func _draw() -> void:
	if elapsed >= DURATION or source.hp <= 0.0 or not source.visible_to_local_player(): return
	var screen_transform := get_global_transform_with_canvas()
	var feet := screen_transform * source.status_effect_origin()
	var center := feet.lerp(source.get_visual_head_screen_position(), 0.5)
	var progress := elapsed / DURATION
	center.y -= 5.0 * progress * screen_transform.y.length()
	draw_set_transform(screen_transform.affine_inverse() * center, -screen_transform.get_rotation())
	var alpha := smoothstep(0.0, 0.045, elapsed) * (1.0 - smoothstep(0.16, DURATION, elapsed))
	var font := CardArt.ui_font()
	var text := "免疫"
	var baseline := Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x * 0.5, (font.get_ascent(20) - font.get_descent(20)) * 0.5)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Color(0.10, 0.07, 0.03, alpha))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.94, 0.68, alpha))
