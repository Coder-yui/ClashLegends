class_name LightningSpellEffect
extends Node2D
## 原版电刑/风暴狂涌纹理的轻量表现适配；不执行目标查询或伤害。
const ZAP_BEAM = preload("res://assets/effects/lightning_spells/perks_electrocute_beams.png")
const ZAP_FLASH = preload("res://assets/effects/lightning_spells/perks_electrocute_beams_flash.png")
const ZAP_ARCS = preload("res://assets/effects/lightning_spells/perks_electrocute_arcs_4x4.png")
const ZAP_GROUND = preload("res://assets/effects/lightning_spells/perks_electrocute_scorch.png")
const STORM_BEAM = preload("res://assets/effects/lightning_spells/leesin_skin31_e_lightning03.png")
const STORM_GROUND = preload("res://assets/effects/lightning_spells/leesin_skin31_e_groundlightning_01.png")
const STORM_RING = preload("res://assets/effects/lightning_spells/leesin_skin31_e_shockring.png")
var spells: RefCounted
var _zap_flash_mask: ImageTexture

func _ready() -> void:
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = blend
	# 闪光沿同一条闪电的透明轮廓叠加，避免独立的发光矩形。
	var beam_image := ZAP_BEAM.get_image()
	var flash_image := ZAP_FLASH.get_image()
	beam_image.convert(Image.FORMAT_RGBA8)
	for y in beam_image.get_height():
		for x in beam_image.get_width():
			var beam_pixel := beam_image.get_pixel(x, y)
			var glow := flash_image.get_pixel(x * flash_image.get_width() / beam_image.get_width(), y * flash_image.get_height() / beam_image.get_height()).r
			beam_image.set_pixel(x, y, Color(1, 1, 1, beam_pixel.a * maxf(beam_pixel.r, maxf(beam_pixel.g, beam_pixel.b)) * glow))
	_zap_flash_mask = ImageTexture.create_from_image(beam_image)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if spells == null: return
	for effect in spells.lightning_effects:
		var elapsed := float(effect.duration) - float(effect.timer)
		var fade := 1.0 - smoothstep(0.12, 0.6, elapsed)
		var bolt_fade := 1.0 - smoothstep(0.08, 0.30, elapsed)
		var center: Vector2 = effect.pos
		var zap := String(effect.kind) == "zap"
		var tint := Color.WHITE if zap else Color(0.35, 0.75, 1.0)
		var reach := float(effect.radius) if zap else 58.0
		var ground: Texture2D = ZAP_GROUND if zap else STORM_GROUND
		draw_texture_rect(ground, Rect2(center - Vector2(reach, reach * 0.55), Vector2(reach * 2.0, reach * 1.1)), false, Color(tint, fade * 0.8))
		if zap:
			var cell := Vector2(ZAP_ARCS.get_size()) / 4.0
			# 每格出生点约在(0.5, 0.94)。各支路从中心出发，错开帧与长度。
			var lengths := [0.91, 0.68, 0.84, 0.73, 0.94, 0.77]
			var angles := [-0.12, 1.02, 2.18, 3.04, 4.31, 5.27]
			for branch in lengths.size():
				var age := elapsed - float(branch % 3) * 0.018
				if age < 0.0 or age >= 0.54: continue
				var frame := mini(int(age / 0.54 * 16.0), 15)
				var length := reach * float(lengths[branch])
				var arc_width := length * 0.48
				var arc_fade := 1.0 - smoothstep(0.20, 0.54, age)
				draw_set_transform(center, float(angles[branch]))
				draw_texture_rect_region(ZAP_ARCS, Rect2(Vector2(-arc_width * 0.5, -length * 0.94), Vector2(arc_width, length)), Rect2(Vector2(frame % 4, frame / 4) * cell, cell), Color(1, 1, 1, arc_fade * 0.85))
			draw_set_transform(Vector2.ZERO)
		else:
			var ring_radius := reach * (0.6 + elapsed * 1.6)
			draw_texture_rect(STORM_RING, Rect2(center - Vector2(ring_radius, ring_radius * 0.5), Vector2(ring_radius * 2, ring_radius)), false, Color(tint, fade * 0.65))
		if bolt_fade <= 0: continue
		var beam: Texture2D = ZAP_BEAM if zap else STORM_BEAM
		var columns := 3 if zap else 2
		var cell_width := float(beam.get_width()) / columns
		# 电击整次固定中间一列，禁止快速轮换三种形状形成多条残像。
		var column := 1 if zap else mini(int(elapsed * 25.0) % columns, columns - 1)
		var width := 46.0 if zap else 78.0
		var height := 275.0 if zap else 340.0
		var rect := Rect2(center - Vector2(width * 0.5, height), Vector2(width, height + 8.0))
		draw_texture_rect_region(beam, rect, Rect2(column * cell_width, 0, cell_width, beam.get_height()), Color(tint, bolt_fade))
		if zap and elapsed < 0.1:
			draw_texture_rect_region(_zap_flash_mask, rect, Rect2(column * cell_width, 0, cell_width, beam.get_height()), Color(1, 1, 1, (1.0 - elapsed / 0.1) * 0.85))
