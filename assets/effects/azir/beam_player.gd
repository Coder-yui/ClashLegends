extends Node2D
## 单一原版beamflow发射器，解析来源曲线后直接求值；不生成权威命中。
const ROOT := "res://assets/effects/azir/"
static var _cached_data: Dictionary = {}
var _data: Dictionary = {}
var _pools: Array = []
var _beam: Polygon2D
var _material: ShaderMaterial
var _start := Vector2.ZERO
var _end := Vector2(0, -140)
var _scale := 0.011 * 40.0
var _emitter: Dictionary

static func resource_manifest(variant: String) -> Dictionary:
	if variant != "basic_attack": return {}
	return {"paths": [ROOT + "beam.gdshader"], "json": [ROOT + "beam.json"],
		"sample": {"player": ROOT + "beam_player.gd", "kind": variant, "setup": "2d"}}

func setup(_kind: String, seed_value: int = 0) -> void:
	if _cached_data.is_empty(): _cached_data = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "beam.json"))
	_data = _cached_data
	_emitter = _data.emitters[0]
	_beam = Polygon2D.new()
	_beam.name = "beamflow"
	_beam.texture = load(_emitter.texture)
	_beam.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_material = ShaderMaterial.new()
	_material.shader = load(ROOT + "beam.gdshader")
	_material.set_shader_parameter("atlas_div", Vector2(_emitter.tex_div[0], _emitter.tex_div[1]))
	_material.set_shader_parameter("uv_scroll", Vector2(_emitter.scroll[0], _emitter.scroll[1]))
	_material.set_shader_parameter("alpha_ref", float(_emitter.alpha_ref))
	# 稳定视觉种子不消费游戏随机源；六个原生图集起始帧与U偏移。
	var frame := posmod(seed_value * 17 + 3, 6) if _emitter.random_start_frame else 0
	_material.set_shader_parameter("frame_cell", Vector2(frame % 3, frame / 3))
	_material.set_shader_parameter("birth_u", float(posmod(seed_value * 37, 101)) / 101.0 if _emitter.random_birth_uv_x else 0.0)
	_beam.material = _material
	add_child(_beam)
	_pools = [[_beam]]

func set_segment(start: Vector2, end: Vector2) -> void:
	_start = start
	_end = end

func sample(age: float, strength: float) -> void:
	var phase := clampf(age / float(_emitter.lifetime), 0.0, 1.0)
	var width_scale := _curve(phase, _emitter.scale_times, _emitter.scale_x)
	var alpha := _curve(phase, _emitter.color_times, _emitter.color_alpha) * strength
	var direction := (_end - _start).normalized()
	if direction == Vector2.ZERO: direction = Vector2.UP
	var side := direction.orthogonal() * float(_emitter.width) * _scale * width_scale * 0.5
	_beam.polygon = PackedVector2Array([_start - side, _start + side, _end + side, _end - side])
	var tiling := _start.distance_to(_end) / maxf(float(_emitter.tiling_length) * _scale, 0.001)
	var size := _beam.texture.get_size()
	_beam.uv = PackedVector2Array([Vector2(0,size.y*tiling), Vector2(size.x,size.y*tiling), Vector2(size.x,0), Vector2(0,0)])
	_material.set_shader_parameter("source_age", age)
	_material.set_shader_parameter("opacity", alpha)
	visible = alpha > 0.0

static func _curve(phase: float, times: Array, values: Array) -> float:
	if phase <= float(times[0]): return float(values[0])
	for index in range(1,times.size()):
		if phase <= float(times[index]):
			return lerpf(float(values[index-1]),float(values[index]),inverse_lerp(float(times[index-1]),float(times[index]),phase))
	return float(values.back())
