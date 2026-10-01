extends Node2D
## 巴德基础皮肤R纹理适配。纯表现时钟，不施加凝滞。
const WARNING = preload("res://assets/effects/stasis/warning_decal.png")
const NOVA = preload("res://assets/effects/stasis/explo_nova.png")
const GOLD = preload("res://assets/effects/stasis/cosmic_gold.png")
const RING = preload("res://assets/effects/stasis/ring_flare.png")
var spells: RefCounted

var _orb: ImageTexture

func _ready() -> void:
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = blend
	var bitmap := GOLD.get_image()
	bitmap.convert(Image.FORMAT_RGBA8)
	for y in bitmap.get_height():
		for x in bitmap.get_width():
			var uv := Vector2(float(x) / bitmap.get_width(), float(y) / bitmap.get_height())
			var color := bitmap.get_pixel(x, y)
			color.a *= 1.0 - smoothstep(0.15, 0.49, uv.distance_to(Vector2(0.5, 0.5)))
			bitmap.set_pixel(x, y, color)
	_orb = ImageTexture.create_from_image(bitmap)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if spells == null: return
	for effect in spells.stasis_effects:
		var age := float(effect.progress) * float(int(effect.impact_tick) - int(effect.start_tick)) * FixedStepClock.STEP
		var center: Vector2 = effect.pos
		var radius := float(effect.radius)
		var tint := Color(1.0, 0.8, 0.28)
		if not bool(effect.impacted):
			_stamp(WARNING, center, radius, Color(tint, 0.5 + 0.2 * sin(age * 8.0)))
			var t := float(effect.progress)
			for i in range(8, -1, -1):
				var tail := maxf(t - i * 0.014, 0.0)
				var point: Vector2 = effect.origin.lerp(center, tail) + Vector2(0, -sin(tail * PI) * 160.0 - (1.0 - tail) * 60.0)
				_stamp(_orb, point, 22.0 - i * 1.7, Color(tint, 0.8 - i * 0.08))
		else:
			var elapsed := 0.8 - float(effect.timer)
			var fade := 1.0 - smoothstep(0.15, 0.8, elapsed)
			_stamp(NOVA, center, radius * (0.5 + elapsed), Color(tint, fade))
			_stamp(WARNING, center, radius, Color(tint, fade * 0.45))
			_stamp(RING, center, radius * (0.8 + elapsed * 0.7), Color(tint, fade))

func _stamp(texture: Texture2D, point: Vector2, radius: float, color: Color) -> void:
	draw_texture_rect(texture, Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, color)
