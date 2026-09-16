class_name LolParticleEffect3D
extends Node3D
## 仅播放已归档 Troy 粒子；发射/寿命/曲线与实际战斗完全分离。
const SCALE_PROBABILITY := ["p-scaleX", "p-scaleY", "p-scaleZ"]
const ROTATION_PROBABILITY := ["p-quadrotX", "p-quadrotY", "p-quadrotZ"]
const ROOT := "res://assets/effects/baron_minion/"
static var _systems: Dictionary = {}
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
static var _quad: QuadMesh
var _camera: Camera3D
var _emitter_transform := Transform3D.IDENTITY
var _camera_basis := Basis.IDENTITY
var _emitters: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _factor := 0.0072
var _loop := false
var _stopped := false

static func system_names() -> Array:
	if _systems.is_empty():
		_load_systems()
	return _systems.keys()

static func dependency_paths(names: Variant = null) -> Array:
	system_names()
	if names == null: names = system_names()
	var paths := {ROOT + "particle_add.gdshader": true, ROOT + "particle_mix.gdshader": true}
	for name in names:
		for config in _systems[name].values():
			if not config is Dictionary: continue
			for key in ["p-mesh", "p-meshtex", "p-texture", "p-meshtex-mult", "p-rgba"]:
				if config.has(key): paths[_asset(config[key], "glb" if key == "p-mesh" else "png")] = true
	return paths.keys()

func setup(system_name: String, factor: float = 0.0072, looping: bool = false) -> void:
	if _systems.is_empty():
		_load_systems()
	_factor = factor
	_loop = looping
	_rng.seed = get_instance_id()
	var sections: Dictionary = _systems.get(system_name, {})
	var system: Dictionary = sections.get("System", {})
	for key in system:
		if not String(key).begins_with("GroupPart") or not String(key).trim_prefix("GroupPart").is_valid_int(): continue
		var label := String(system[key]).trim_prefix('"').trim_suffix('"')
		var c: Dictionary = sections.get(label, {})
		if c.is_empty() or int(_number(c, "p-type", 1)) == 11: continue
		_prepare_emitter(c)
		_emitters.append({"config": c, "next": 0.0, "count": 0})

func stop_emitting() -> void:
	_stopped = true

func finished() -> bool:
	if not _particles.is_empty(): return false
	if _stopped: return true
	for e in _emitters:
		var c: Dictionary = e.config
		if _loop or _number(c, "e-life", 1.0) < 0.0 or _time < _number(c, "e-life", 1.0): return false
	return true

func advance(delta: float) -> void:
	_camera = get_viewport().get_camera_3d()
	_emitter_transform = global_transform
	if _camera != null: _camera_basis = _camera.global_basis
	_time += delta
	if not _stopped:
		for e in _emitters:
			var c: Dictionary = e.config
			var rate := maxf(_number(c, "e-rate", 1.0), 0.01)
			var lifetime := _number(c, "e-life", 1.0)
			var end := _time if _loop or lifetime < 0 else minf(_time, lifetime)
			while float(e.next) <= end:
				if _number(c, "single-particle", 0) == 1 and int(e.count) > 0: break
				_spawn(c, float(e.next))
				e.count += 1
				e.next += 1.0 / rate
	for i in range(_particles.size() - 1, -1, -1):
		var p := _particles[i]
		var age := _time - float(p.birth)
		if age >= float(p.life):
			p.node.free()
			_particles.remove_at(i)
			continue
		_update_particle(p, age)

func _spawn(c: Dictionary, birth: float) -> void:
	var life := maxf(_number(c, "p-life", 1.0), 0.01) * _probability(c, "p-life", 1.0)
	if _time - birth >= life: return
	var node := MeshInstance3D.new()
	node.add_to_group("presentation_fx")
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var is_mesh := c.has("p-mesh")
	node.mesh = c._mesh_resource
	var material := (c._material as ShaderMaterial).duplicate() as ShaderMaterial
	node.material_override = material
	add_child(node)
	var base_scale := _vec3(c, "p-scale", Vector3.ONE)
	var rotation_degrees := _vec3(c, "p-quadrot", Vector3.ZERO)
	for axis in range(3):
		base_scale[axis] *= _probability(c, SCALE_PROBABILITY[axis], 1.0)
		rotation_degrees[axis] *= _probability(c, ROTATION_PROBABILITY[axis], 1.0)
	var offset := _vec3(c, "p-offset", Vector3.ZERO)
	var origin := _emitter_transform
	_particles.append({"node": node, "config": c, "material": material, "birth": birth, "life": life,
		"scale": base_scale, "rotation": rotation_degrees, "offset": offset, "origin": origin,
		"mesh": is_mesh, "frame": _rng.randi_range(0, maxi(int(_number(c, "p-numframes", 1)) - 1, 0))})

static func _material_template(c: Dictionary) -> ShaderMaterial:
	var key := hash(c)
	if _materials.has(key): return _materials[key]
	var material := ShaderMaterial.new()
	material.shader = load(ROOT + ("particle_add.gdshader" if int(_number(c, "rendermode", 0)) in [0, 4] else "particle_mix.gdshader"))
	material.render_priority = clampi(int(_number(c, "pass", 0)), -10, 10)
	material.set_shader_parameter("source_texture", load(_asset(c.get("p-meshtex", c.get("p-texture", '"DATA/Particles/ball32_02.dds"')), "png")))
	material.set_shader_parameter("uv_speed", _vec2(c, "p-uvscroll-rgb", Vector2.ZERO))
	material.set_shader_parameter("uv_div", _vec2(c, "p-texdiv", Vector2.ONE))
	material.set_shader_parameter("scroll_rgb_only", _number(c, "p-uvscroll-no-alpha", 0) == 1)
	if c.has("p-meshtex-mult"):
		material.set_shader_parameter("has_mult", true)
		material.set_shader_parameter("mult_texture", load(_asset(c["p-meshtex-mult"], "png")))
		material.set_shader_parameter("mult_speed", _vec2(c, "p-uvscroll-rgb-mult", Vector2.ZERO))
	if c.has("p-rgba"):
		material.set_shader_parameter("has_ramp", true)
		material.set_shader_parameter("ramp_texture", load(_asset(c["p-rgba"], "png")))
	_materials[key] = material
	return material

func _update_particle(p: Dictionary, age: float) -> void:
	var c: Dictionary = p.config
	var t := age / float(p.life)
	var node: MeshInstance3D = p.node
	var size := (p.scale as Vector3) * _curve3(c, "p-xscale", t, Vector3.ONE)
	var offset: Vector3 = p.offset + _vec3(c, "p-vel", Vector3.ZERO) * age + _vec3(c, "p-accel", Vector3.ZERO) * age * age * 0.5
	var bound := clampf(_number(c, "p-bindtoemitter", 0), 0, 1)
	node.global_position = (p.origin as Transform3D).origin.lerp(_emitter_transform.origin, bound) + _emitter_transform.basis * (offset * _factor)
	var angles: Vector3 = p.rotation + _vec3(c, "p-rotvel", Vector3.ZERO) * age
	if bool(p.mesh) or int(_number(c, "p-type", 1)) == 2:
		node.basis = Basis.from_euler(angles * PI / 180.0)
	else:
		var camera := _camera
		if camera != null:
			node.global_basis = _camera_basis.rotated(_camera_basis.z, deg_to_rad(angles.x))
	# 缩放只属于粒子 mesh，绝不写回单位。
	node.scale = Vector3(maxf(absf(size.x), 0.0001), maxf(absf(size.y), 0.0001), maxf(absf(size.z), 0.0001)) * _factor
	var color := _curve4(c, "p-xrgba", t, Vector4.ONE) * _value4(c, "e-color-modulate", Vector4.ONE)
	p.material.set_shader_parameter("tint", Color(color.x, color.y, color.z, color.w))
	p.material.set_shader_parameter("elapsed", age)
	p.material.set_shader_parameter("age_ratio", t)
	p.material.set_shader_parameter("frame", int(p.frame))

static func _asset(raw: Variant, extension: String) -> String:
	return ROOT + String(raw).replace('"', '').get_file().get_basename().to_lower() + "." + extension

static func _values(raw: Variant) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	for token in String(raw).split(" ", false): values.append(float(token))
	return values

static func _number(c: Dictionary, key: String, fallback: float) -> float:
	return float(c._numbers.get(key, fallback))

static func _vec3(c: Dictionary, key: String, fallback: Vector3) -> Vector3:
	return c._vectors.get(key, fallback)

static func _vec2(c: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var v := _vec3(c, key, Vector3(fallback.x, fallback.y, 0))
	return Vector2(v.x, v.y)

static func _value4(c: Dictionary, key: String, fallback: Vector4) -> Vector4:
	return c._colors.get(key, fallback)

static func _curve4(c: Dictionary, key: String, t: float, fallback: Vector4) -> Vector4:
	var previous := _value4(c, key, fallback)
	var previous_time := 0.0
	for a in c._curves.get(key, []):
		if a.size() < 5: continue
		var value := Vector4(a[1], a[2], a[3], a[4])
		if t <= a[0]: return previous.lerp(value, clampf((t - previous_time) / maxf(a[0] - previous_time, 0.001), 0, 1))
		previous = value
		previous_time = a[0]
	return previous

static func _curve3(c: Dictionary, key: String, t: float, fallback: Vector3) -> Vector3:
	var previous := fallback
	var previous_time := 0.0
	for a in c._curves.get(key, []):
		if a.size() < 4: continue
		var value := Vector3(a[1], a[2], a[3])
		if t <= a[0]: return previous.lerp(value, clampf((t - previous_time) / maxf(a[0] - previous_time, 0.001), 0, 1))
		previous = value
		previous_time = a[0]
	return previous

func _probability(c: Dictionary, key: String, fallback: float) -> float:
	var entries: Array = c._probabilities.get(key, [])
	if entries.is_empty(): return fallback
	var t := _rng.randf()
	var previous: float = entries[0][1] if entries[0].size() > 1 else fallback
	var previous_t: float = entries[0][0]
	for a in entries:
		if a.size() < 2: continue
		if t <= a[0]: return lerpf(previous, a[1], clampf((t - previous_t) / maxf(a[0] - previous_t, 0.001), 0, 1))
		previous = a[1]
		previous_t = a[0]
	return previous

## 原字符串仅在资源准备时解析。运行中的配置只读，材质参数仍逐粒子独立。
static func _load_systems() -> void:
	_systems = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "systems.json"))
	for sections in _systems.values():
		for c in sections.values():
			if c is Dictionary: _compile(c)

static func _compile(c: Dictionary) -> void:
	var numeric_fields := ["p-type", "e-life", "e-rate", "single-particle", "p-life", "p-scale", "p-quadrot", "p-offset", "p-numframes", "rendermode", "pass", "p-uvscroll-rgb", "p-texdiv", "p-uvscroll-no-alpha", "p-uvscroll-rgb-mult", "p-vel", "p-accel", "p-bindtoemitter", "p-rotvel", "e-color-modulate", "p-xrgba"]
	var errors := PackedStringArray()
	for key in c:
		if key in numeric_fields or String(key).begins_with("p-xscale") or String(key).begins_with("p-xrgba") or String(key).contains("P") and String(key).begins_with("p-"):
			for token in String(c[key]).split(" ", false):
				if not token.is_valid_float(): errors.append("%s: 无效粒子数值 %s" % [key, token])
	c["_parse_errors"] = errors
	for message in errors: push_warning(message)
	var numbers := {}
	var vectors := {}
	var colors := {}
	for key in c:
		if String(key).begins_with("_"): continue
		var raw := String(c[key])
		var tokens := raw.split(" ", false)
		if tokens.is_empty() or not tokens[0].is_valid_float(): continue
		var values := _values(raw)
		numbers[key] = float(tokens[0])
		vectors[key] = Vector3(values[0], values[1] if values.size() > 1 else values[0], values[2] if values.size() > 2 else values[0])
		if values.size() == 4: colors[key] = Vector4(values[0], values[1], values[2], values[3])
	var curves := {}
	for key in ["p-xscale", "p-xrgba"]:
		var entries := []
		for index in range(1, 12):
			if not c.has(key + str(index)): break
			entries.append(_values(c[key + str(index)]))
		curves[key] = entries
	var probabilities := {}
	for key in ["p-life", "p-scaleX", "p-scaleY", "p-scaleZ", "p-quadrotX", "p-quadrotY", "p-quadrotZ"]:
		var entries := []
		for index in range(1, 12):
			if c.has(key + "P" + str(index)): entries.append(_values(c[key + "P" + str(index)]))
		probabilities[key] = entries
	c._numbers = numbers
	c._vectors = vectors
	c._colors = colors
	c._curves = curves
	c._probabilities = probabilities

static func _prepare_emitter(c: Dictionary) -> void:
	if c.has("_material"): return
	c._material = _material_template(c)
	if c.has("p-mesh"):
		var path := _asset(c["p-mesh"], "glb")
		if not _meshes.has(path):
			var instance := (load(path) as PackedScene).instantiate()
			var found := instance.find_children("*", "MeshInstance3D", true, false)
			_meshes[path] = (found[0] as MeshInstance3D).mesh
			instance.free()
		c._mesh_resource = _meshes[path]
	else:
		if _quad == null:
			_quad = QuadMesh.new()
			_quad.size = Vector2.ONE * 2.0
		c._mesh_resource = _quad

static func dependencies_for(cards: Dictionary) -> Array:
	# 男爵强化可由全局机制施加；存在对应表现即保守保留整个已接入粒子族。
	# 普通对局含系统兵线，因此仍完整覆盖；纯英雄预览无需无条件扫所有系统。
	for id in cards:
		var base := CardDB.get_card(String(id))
		for form in range(2 if base.has("transformed_stats") else 1):
			var stats := PresentationConfig.for_form(base, form)
			if String(stats.get("visual_active_buff_scene", "")).begins_with(ROOT) or stats.has("active_buff_projectile_visual"):
				return system_names()
	return []
