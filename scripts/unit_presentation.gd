class_name UnitPresentation
extends Node2D
## 可选的单位美术表现层。它只读取模拟层状态播放动画，不参与移动、伤害或碰撞。
## SpriteFrames 统一使用 deploy / idle / move / attack 四个动画名；
## 缺少某个动画时自动回退到 idle，便于先做一个单位的竖切。

const STATE_ANIMATIONS := [&"deploy", &"idle", &"move", &"attack"]

var _sprite := AnimatedSprite2D.new()
var _has_art := false

func setup(frames: SpriteFrames, draw_size: float) -> void:
	# 血条、冰冻和蓄力圈由 Unit 绘制，表现层必须位于这些状态提示之后。
	show_behind_parent = true
	add_child(_sprite)
	if frames == null:
		return
	_sprite.sprite_frames = frames
	_has_art = true
	# 素材可以用任意分辨率导入，这里按第一帧宽度统一缩放到卡牌的视觉直径。
	var fallback_animation: StringName = _fallback_animation()
	if fallback_animation != &"" and frames.get_frame_count(fallback_animation) > 0:
		var texture := frames.get_frame_texture(fallback_animation, 0)
		if texture != null and texture.get_width() > 0:
			var target_width := draw_size * 2.0
			_sprite.scale = Vector2.ONE * (target_width / float(texture.get_width()))
	play_state(1, 1.0, false)

func has_art() -> bool:
	return _has_art

func play_state(state: int, facing_x: float, frozen: bool) -> void:
	if not _has_art:
		return
	var requested: StringName = STATE_ANIMATIONS[clampi(state, 0, STATE_ANIMATIONS.size() - 1)]
	var animation := requested if _sprite.sprite_frames.has_animation(requested) else _fallback_animation()
	if animation != &"" and _sprite.animation != animation:
		_sprite.play(animation)
	if absf(facing_x) > 0.05:
		_sprite.flip_h = facing_x < 0.0
	_sprite.modulate = Color(0.72, 0.88, 1.0) if frozen else Color.WHITE

func _fallback_animation() -> StringName:
	if _sprite.sprite_frames == null:
		return &""
	if _sprite.sprite_frames.has_animation(&"idle"):
		return &"idle"
	var names := _sprite.sprite_frames.get_animation_names()
	return names[0] if not names.is_empty() else &""
