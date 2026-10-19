extends ActiveBuffVisual3D
## 原版 R：独立粒子 + 五个原生附着层。只消费表现状态。
const PARTICLES := preload("res://assets/units/pantheon/arrival/particle_player.gd")
const SOURCE := "res://assets/effects/tryndamere/native/systems.json"
# Source model 0.0085 × wrapper 3.1 ÷ LoL skinScale 2.
const WORLD_SCALE := 0.013175
var _player: Node3D
var _definitions: Array = []
var _attached: Array = []
var _layers: Array[Dictionary] = []
var _age := 0.0
var _tail := 0.0

func configure(_visual_radius: float, _team: int = 0) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	_definitions = data.R
	_attached = data.attached
	visible = false

func make_overlay(original: Material) -> Material:
	var chain := original
	for index in range(_attached.size() - 1, -1, -1):
		var definition: Dictionary = _attached[index]
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/effects/tryndamere/attached_add.gdshader") if int(definition.blend) == 4 else preload("res://assets/effects/tryndamere/undying_rage.gdshader")
		material.render_priority = 10 + index
		material.set_shader_parameter("source_texture", load(definition.texture))
		material.set_shader_parameter("surface_offset", 0.001 * (index + 1))
		material.set_shader_parameter("uv_rate", PARTICLES.vec2(PARTICLES.sample(definition.uv_rate, 0.0)))
		material.set_shader_parameter("fresnel", float(definition.fresnel))
		var reflection: Array = definition.reflection_color
		material.set_shader_parameter("reflection_color", Color(reflection[0], reflection[1], reflection[2], reflection[3]))
		if not String(definition.mult).is_empty():
			material.set_shader_parameter("has_mult", true)
			material.set_shader_parameter("mult_texture", load(definition.mult))
			material.set_shader_parameter("mult_rate", PARTICLES.vec2(PARTICLES.sample(definition.mult_rate, 0.0)))
		if not String(definition.erosion).is_empty():
			material.set_shader_parameter("has_erosion", true)
			material.set_shader_parameter("erosion_map", load(definition.erosion))
		_layers.append({"material": material, "definition": definition})
		material.next_pass = chain
		chain = material
	return chain

func advance(enabled: bool, delta: float) -> void:
	if enabled and not active:
		if is_instance_valid(_player): _player.free()
		_player = PARTICLES.new()
		add_child(_player)
		_player.setup("R", WORLD_SCALE, false, "", false, false, _definitions)
		_age = 0.0
		_tail = 0.0
	if not enabled and active:
		_tail = 0.3
		if is_instance_valid(_player): _player.stop_emitting()
	active = enabled
	_age += delta
	_tail = maxf(_tail - delta, 0.0)
	for layer in _layers:
		var definition: Dictionary = layer.definition
		var age := _age - float(definition.delay)
		var t := clampf(age / float(definition.life), 0.0, 1.0)
		var birth: Array = PARTICLES.sample(definition.birthColor, 0.0)
		var rgba: Array = PARTICLES.sample(definition.Color, t)
		var material: ShaderMaterial = layer.material
		var opacity := 1.0 if age >= 0.0 and age < float(definition.life) and (active or _tail > 0.0) else 0.0
		if not active: opacity *= _tail / 0.3
		material.set_shader_parameter("strength", opacity)
		material.set_shader_parameter("elapsed", maxf(age, 0.0))
		material.set_shader_parameter("tint", Color(birth[0] * rgba[0], birth[1] * rgba[1], birth[2] * rgba[2], birth[3] * rgba[3]))
		material.set_shader_parameter("erosion_drive", float(PARTICLES.sample(definition.erosion_drive, t)))
	if is_instance_valid(_player):
		_player.advance(delta)
		if not active and _tail <= 0.0:
			_player.free()
			_player = null
	visible = active or _tail > 0.0

static func resource_manifest(variant: String) -> Dictionary:
	if variant != "default": return {}
	return {"json": [SOURCE], "shader_providers": ["res://assets/units/pantheon/arrival/particle_player.gd"], "paths": ["res://assets/effects/tryndamere/attached_add.gdshader", "res://assets/effects/tryndamere/undying_rage.gdshader"]}
