extends Node2D
## 原版普攻与R纹理的2D投影表现；绝不参与弹体推进或伤害。
const BULLET := "res://assets/effects/corki/corki_base_ba_bullet.png"
const MISSILE := "res://assets/effects/corki/cork_basei_r_mis.png"
const BIG := "res://assets/effects/corki/cork_base_r_big_mis.png"
const RING := "res://assets/effects/corki/corki_base_r_tar_shockwave.png"
const FLAME := "res://assets/effects/corki/common_flames03.png"

var _system: Node2D
func setup(system: Node2D) -> void:
	_system = system
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
func _draw() -> void:
	for projectile in _system.visible_view().values():
		if StringName(projectile.get("visual", "")) != &"corki_bullet": continue
		draw_set_transform(_system._visual_position(projectile), _system._direction(projectile).angle() + PI * 0.5)
		# 原版贴图亮端为弹头，拖尾沿飞行反方向延伸。
		draw_texture_rect(effect_texture(BULLET), Rect2(-4, -8, 8, 48), false)
		draw_set_transform(Vector2.ZERO)
	for effect in _system.impact_effects:
		if StringName(effect.get("visual", "")) in [&"corki_explosion", &"corki_explosion_big"]: draw_impact(self, effect)

static func draw_flight(canvas: Node2D, position: Vector2, direction: Vector2, big: bool) -> void:
	canvas.draw_set_transform(position)
	# SCB原版网格投影到画布，保留逐面UV；纹理图集不能直接当精灵。
	var texture := effect_texture(BIG) if big else effect_texture(MISSILE)
	for face in _projected_faces():
		canvas.draw_polygon(BattleGroundProjection.native_canvas_face(face.vertices, direction.angle() + PI * 0.5, 0.25 if big else 0.20), _white_colors, face.uvs, texture)
	canvas.draw_set_transform(Vector2.ZERO)

static func draw_impact(canvas: Node2D, effect: Dictionary) -> void:
	var big := StringName(effect.get("visual", "")) == &"corki_explosion_big"
	var remaining := clampf(float(effect.timer) / float(effect.duration), 0.0, 1.0)
	var size := Vector2.ONE * float(effect.radius) * 2.0 * (1.0 - remaining * 0.3)
	canvas.draw_texture_rect(effect_texture(RING), Rect2(effect.pos - size * 0.5, size), false, Color(1.8, 0.12, 0.06, remaining) if big else Color(1, 0.65, 0.25, remaining))
	var cell := Vector2(effect_texture(FLAME).get_size()) / Vector2(4, 4)
	var frame := mini(int((1.0 - remaining) * 12.0), 11)
	var flame_size := size * (0.9 if big else 0.6)
	var flame_color := Color(2.8, 0.22, 0.1, remaining) if big else Color(1, 0.8, 0.5, remaining)
	canvas.draw_texture_rect_region(effect_texture(FLAME), Rect2(effect.pos - flame_size * 0.5, flame_size), Rect2(Vector2(frame % 4, frame / 4) * cell, cell), flame_color)

static var _textures: Dictionary = {}

static func effect_texture(path: String) -> Texture2D:
	if not _textures.has(path): _textures[path] = load(path)
	return _textures[path]

static func resource_manifest(variant: String) -> Dictionary:
	if variant == "bullet": return {"paths": [BULLET]}
	if variant == "missile":
		_projected_faces()
		return {"paths": [MISSILE, BIG, RING, FLAME]}
	return {}

# 两种尺寸按原表达式各投影一次，避免改用Canvas缩放产生不同的浮点舍入。
static var _projected_cache: Array[Dictionary] = []
static var _white_colors := PackedColorArray([Color.WHITE])

static func _projected_faces() -> Array[Dictionary]:
	if not _projected_cache.is_empty(): return _projected_cache
	for source in preload("res://assets/effects/corki/missile_geometry.gd").FACES:
		var points := PackedVector2Array()
		var big_points := PackedVector2Array()
		var vertices := PackedVector3Array()
		var uvs := PackedVector2Array()
		for index in 3:
			var vertex: Array = source.v[index]
			var native := Vector3(vertex[0], vertex[1], vertex[2])
			vertices.append(native)
			var projected := BattleGroundProjection.native_canvas_point(native)
			points.append(projected * 0.20)
			big_points.append(projected * 0.25)
			uvs.append(Vector2(float(source.uv[index][0]), float(source.uv[index][1])))
		var face := {"points": points, "big_points": big_points, "uvs": uvs, "vertices": vertices}
		face.make_read_only()
		_projected_cache.append(face)
	_projected_cache.make_read_only()
	return _projected_cache
