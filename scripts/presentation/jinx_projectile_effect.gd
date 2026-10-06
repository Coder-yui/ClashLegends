extends Node2D
## 原版火箭网格/UV和爆炸图集的投影；只消费权威弹体与命中事件。
const ROCKET = preload("res://assets/effects/jinx/jinx_q_rocket.png")
const BULLET = preload("res://assets/effects/jinx/jinx_basic_bullet.png")
const FLAME = preload("res://assets/effects/jinx/jinx_explosion_flat.png")
const SMOKE = preload("res://assets/effects/jinx/jinx_explosion_smoke.png")
const TRAIL = preload("res://assets/effects/jinx/jinx_base_q_trail01.png")
const GEOMETRY = preload("res://assets/effects/jinx/rocket_geometry.gd")
var _system: Node2D
const BLAST_MASK := """shader_type canvas_item;
render_mode blend_mix;
void fragment() {
	vec2 cell_uv = fract(UV * 2.0);
	float edge = 1.0 - smoothstep(0.78, 1.0, length(cell_uv * 2.0 - 1.0));
	COLOR.a *= edge;
}
"""
var _smoke: Node2D
var _blast: Node2D
var _glow: Node2D
func setup(system: Node2D) -> void:
	_system = system
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_smoke = Node2D.new()
	_smoke.material = _blast_material(false)
	add_child(_smoke)
	_smoke.draw.connect(_draw_blast.bind(_smoke, true))
	_blast = Node2D.new()
	_blast.material = _blast_material(true)
	add_child(_blast)
	_blast.draw.connect(_draw_blast.bind(_blast, false))
	_glow = Node2D.new()
	_glow.material = additive
	add_child(_glow)
	_glow.draw.connect(_draw_glow)
func _draw() -> void:
	_glow.queue_redraw()
	_smoke.queue_redraw()
	_blast.queue_redraw()
	for projectile in _system.visible_snapshot().values():
		var kind := StringName(projectile.get("visual", ""))
		if kind not in [&"jinx_rocket", &"jinx_bullet"]: continue
		var direction: Vector2 = _system._direction(projectile)
		draw_set_transform(_system._visual_position(projectile), direction.angle())
		if kind == &"jinx_rocket":
			for face in GEOMETRY.FACES:
				var points := PackedVector2Array()
				var uvs := PackedVector2Array()
				for i in 3:
					var v: Array = face.v[i]
					points.append(Vector2(-float(v[0]), float(v[2]) * 0.85 - float(v[1]) * 0.53) * 0.25)
					uvs.append(Vector2(float(face.uv[i][0]), float(face.uv[i][1])))
				draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, ROCKET)
		draw_set_transform(Vector2.ZERO)
func _draw_glow() -> void:
	for projectile in _system.visible_snapshot().values():
		var kind := StringName(projectile.get("visual", ""))
		if kind not in [&"jinx_rocket", &"jinx_bullet"]: continue
		var direction: Vector2 = _system._direction(projectile)
		if kind == &"jinx_bullet":
			_glow.draw_set_transform(_system._visual_position(projectile), direction.angle() + PI * 0.5)
			_glow.draw_texture_rect(BULLET, Rect2(-2, -14, 4, 28), false)
		else:
			_glow.draw_set_transform(_system._visual_position(projectile), direction.angle())
			_glow.draw_texture_rect(TRAIL, Rect2(-32, -4, 28, 8), false, Color(1, 0.55, 0.18, 0.8))
		_glow.draw_set_transform(Vector2.ZERO)

func _blast_material(additive: bool) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = BLAST_MASK.replace("blend_mix", "blend_add") if additive else BLAST_MASK
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

## 外沿最大恰好到权威溅射半径；内部火焰与烟雾随生长曲线展开。
static func blast_radius(radius: float, progress: float, smoke: bool) -> float:
	var growth := clampf(progress / 0.25, 0.0, 1.0)
	return maxf(radius, 0.0) * (lerpf(0.75, 1.0, clampf(progress, 0.0, 1.0)) if smoke else lerpf(0.65, 1.0, 1.0 - pow(1.0 - growth, 2.0)))

func _draw_blast(canvas: Node2D, smoke: bool) -> void:
	for effect in _system.impact_effects:
		if StringName(effect.get("visual", "")) != &"jinx_explosion": continue
		var progress := 1.0 - clampf(float(effect.timer) / float(effect.duration), 0.0, 1.0)
		var frame := mini(int(progress * 4.0), 3)
		var texture: Texture2D = SMOKE if smoke else FLAME
		var cell := Vector2(texture.get_size()) / 2.0
		var origin := Vector2(frame % 2, frame / 2)
		var size := Vector2.ONE * blast_radius(float(effect.radius), progress, smoke) * 2.0
		var alpha := 0.55 * (1.0 - progress) if smoke else 1.0 - smoothstep(0.4, 1.0, progress)
		canvas.draw_texture_rect_region(texture, Rect2(effect.pos - size * 0.5, size), Rect2(origin * cell, cell), Color(1, 1, 1, alpha))
