extends Node2D
## 独立加色画布去除原始粒子贴图的黑底；仅消费实际爆炸事件。
var skills: RefCounted
func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
func _process(_delta: float) -> void:
	queue_redraw()
func _draw() -> void:
	if skills == null: return
	for effect in skills.frontal_effects:
		if String(effect.get("shape", "")) != "aftershock": continue
		var center: Vector2 = effect.pos
		var radius := float(effect.length)
		var remaining := clampf(float(effect.timer) / float(effect.duration), 0.0, 1.0)
		var burst := clampf((1.0 - remaining) * 8.0, 0.2, 1.0)
		var extent := Vector2.ONE * radius * 2.0
		draw_texture_rect(load("res://assets/effects/aftershock/aoe_ground_crack.png"), Rect2(center - extent * 0.5, extent), false, Color(0.6, 1.0, 0.35, remaining))
		draw_texture_rect(load("res://assets/effects/aftershock/buff.png"), Rect2(center - extent * burst * 0.5, extent * burst), false, Color(0.65, 1.0, 0.4, remaining))

static func resource_manifest(variant: String) -> Dictionary:
	if variant != "default": return {}
	return {"paths": ["res://assets/effects/aftershock/aoe_ground_crack.png", "res://assets/effects/aftershock/buff.png"]}
