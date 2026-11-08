extends Node3D
## 巨魔E原生粒子与网格采样；逐层保留原生比例和深度状态。
const ROOT := "res://assets/effects/pillar_of_ice/"
static var _cache: Dictionary = {}
var _data: Dictionary = {}
var _sample_values: Array = []
static var _meshes: Dictionary = {}
var _materials: Array[ShaderMaterial] = []
var _pools: Array = []
var _age := 0.0
var _preview_phase := ""
var _emitter_times: Dictionary = {}
var _frame := -1
var _last_basis := Basis.IDENTITY
var projection_basis := Basis.IDENTITY
var range_radius := 0.0
var field_scale := 1.0:
	set(value):
		if is_equal_approx(field_scale, value): return
		field_scale = value
		_frame = -1
# These layers belong to the body, even when the aura expands.
const BODY_LAYERS := ["ice_pillar", "Splash_Out", "rays", "base_glow"]
# Dark alpha footprint is 420.43 source units; 425 includes bilinear-filter padding.
const FIELD_SOURCE_RADII := {"ice_cracks": 330.0, "smoke_fall": 400.0, "black_circle": 425.0}
func emitter_scale(emitter_name: String) -> float:
	if emitter_name in BODY_LAYERS: return 1.0
	return field_scale * 450.0 / float(FIELD_SOURCE_RADII.get(emitter_name, 450.0))
func shape_basis_for(_emitter_name: String) -> Basis:
	return Basis.IDENTITY

func load_kind(kind: String) -> void:
	_preview_phase = kind if kind in ["升起", "常驻", "死亡"] else ""
	if not _preview_phase.is_empty(): kind = "pillar"
	if not _cache.has(kind):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + kind + "/sampled.json"))
		var materials: Array[ShaderMaterial] = []
		for e in data.emitters:
			if not _meshes.has(e.mesh_path): _meshes[e.mesh_path] = _mesh(e.mesh_path)
			materials.append(_material(e))
		_cache[kind] = {"data": data, "materials": materials}
	_data = _cache[kind].data.duplicate(false)
	if not _preview_phase.is_empty():
		_data["emitters"] = _data.emitters.duplicate(true)
		var labels := {"ice_pillar": "冰柱主体", "Splash_Out": "升起喷溅", "ice_cracks": "地面冰裂纹", "smoke_fall": "常驻冷雾", "rays": "柱身光束", "base_glow": "底部蓝光", "black_circle": "地面暗底"}
		for emitter in _data.emitters: emitter["display_name"] = labels.get(emitter.name, emitter.name)
		_data["preview_duration"] = 0.8 if _preview_phase == "死亡" else (4.0 if _preview_phase == "升起" else 8.0)
	_materials.assign(_cache[kind].materials)

func setup_native(unit_scale: float) -> void:
	scale = Vector3.ONE * unit_scale
	if not _preview_phase.is_empty(): field_scale = 110.0 / 40.0 / 450.0 / unit_scale
	for e in _data.emitters: _pools.append([])
	seek(0.0)

func set_effect_fade(value: float) -> void:
	for pool in _pools:
		for item in pool:
			item.material_override.set_shader_parameter("effect_fade", value)

func advance(delta: float) -> void:
	seek(_age + delta)

## 主体升降与持续粒子分开取样，延长建筑寿命不重复升起或回放主体动画。
func set_emitter_sample_time(emitter: StringName, sample_time: float) -> void:
	if is_equal_approx(float(_emitter_times.get(emitter, -1.0)), sample_time): return
	_emitter_times[emitter] = sample_time
	_frame = -1

func seek(age: float) -> void:
	var preview_fade := 1.0
	if not _preview_phase.is_empty():
		set_emitter_sample_time(&"ice_pillar", 5.625 + age if _preview_phase == "死亡" else (minf(age, 0.36) if _preview_phase == "升起" else 0.36))
		if _preview_phase == "死亡": preview_fade = 1.0 - clampf(age / 0.8, 0.0, 1.0)
		if _preview_phase != "升起": age += 4.0
		for emitter in [&"ice_cracks", &"base_glow", &"black_circle"]:
			set_emitter_sample_time(emitter, minf(age, 4.0))
	_age = maxf(age, 0.0)
	var frame := mini(int(_age * float(_data.fps)), _data.frames.size() - 1)
	var camera := get_viewport().get_camera_3d()
	if frame == _frame and projection_basis == _last_basis: return
	_frame = frame
	_last_basis = projection_basis
	_sample_values = _data.frames[frame]
	var values: Array = _sample_values
	for emitter_index in values.size():
		var e: Dictionary = _data.emitters[emitter_index]
		if int(e.get("quadType", -1)) in [4, 5, 6, 11]: continue
		var pool: Array = _pools[emitter_index]
		var particles: Array = values[emitter_index]
		if _emitter_times.has(StringName(e.name)):
			var emitter_frame := clampi(roundi(float(_emitter_times[StringName(e.name)]) * float(_data.fps)), 0, _data.frames.size() - 1)
			particles = _data.frames[emitter_frame][emitter_index]
		while pool.size() < particles.size():
			var item := MeshInstance3D.new()
			if String(e.name) != "ice_pillar": item.add_to_group("presentation_fx")
			item.mesh = _meshes[e.mesh_path]
			item.material_override = _materials[emitter_index].duplicate()
			item.material_override.set_shader_parameter("range_radius", range_radius)
			item.material_override.set_shader_parameter("push_pull", float(e.depthPushPull))
			item.material_override.set_shader_parameter("projection_basis", projection_basis)
			item.material_override.set_shader_parameter("shape_basis", shape_basis_for(e.name))
			item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			item.custom_aabb = AABB(Vector3(-2500, -2500, -2500), Vector3(5000, 5000, 5000))
			add_child(item)
			pool.append(item)
		for j in pool.size():
			var item: MeshInstance3D = pool[j]
			item.visible = j < particles.size() and _age <= float(_data.duration)
			if item.visible:
				item.scale = Vector3.ONE * emitter_scale(String(e.name))
				item.material_override.set_shader_parameter("projection_basis", projection_basis)
				item.material_override.set_shader_parameter("shape_basis", shape_basis_for(e.name))
				var particle := PackedFloat32Array(particles[j])
				item.material_override.set_shader_parameter("p", particle)
				if camera != null:
					var values_j: Array = particles[j]
					var center := item.to_global(projection_basis * Vector3(values_j[1], values_j[2], values_j[3]))
					item.sorting_offset = camera.global_position.distance_to(center) - camera.global_position.distance_to(global_position)

	if not _preview_phase.is_empty(): set_effect_fade(preview_fade)

static func _mesh(path: String) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	if path.is_empty():
		for index in [0, 2, 1, 0, 3, 2]:
			var point: Vector2 = [Vector2(-0.5,-0.5), Vector2(0.5,-0.5), Vector2(0.5,0.5), Vector2(-0.5,0.5)][index]
			vertices.append(Vector3(point.x,point.y,0))
			uv.append(point)
			colors.append(Color.WHITE)
	else:
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		# Mirrored X with Godot's clockwise front faces; original SCB corner order.
		for i in raw.vertices.size() / 3:
			vertices.append(Vector3(-raw.vertices[i*3],raw.vertices[i*3+1],raw.vertices[i*3+2]))
			uv.append(Vector2(raw.uv[i*2],raw.uv[i*2+1]))
			colors.append(Color(raw.colors[i*4]/255.0,raw.colors[i*4+1]/255.0,raw.colors[i*4+2]/255.0,raw.colors[i*4+3]/255.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

static func _v2(a: Array) -> Vector2: return Vector2(a[0],a[1])
static func _v4(a: Array) -> Vector4: return Vector4(a[0],a[1],a[2],a[3])

static func _material(e: Dictionary) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = load(resource_shader_path(e))
	result.render_priority = int(e.rank) + 999900 if int(e.rank) < 0 else int(e.rank)
	# Original distortionMode=2 is the early, pre-particle phase.
	if e.distortion != null: result.render_priority = -110
	var params := {
		"is_mesh":e.meshDraw, "cull_mesh":e.backfaceCull, "billboard":e.billboard, "directed":e.directionOriented,
		"is_ray":e.ray, "reach":e.reach, "pivot":0.5 if e.pivotUp else 0.0,
		"ground_layer":false, "cell":_v2(e.cell), "cell_mult":_v2(e.cellMult),
		"uv_center":_v2(e.uv.center), "uv_flip":Vector2(float(e.uv.flipU),float(e.uv.flipV)),
		"address_mode":int(e.uv.addressMode), "alpha_ref":e.alphaRef,
		"has_mult":not e.mult_path.is_empty(), "has_ramp":not e.color_path.is_empty() and e.erosion == null,
		"has_erosion":e.erosion != null, "has_soft":e.soft != null, "push_pull":e.depthPushPull,
		"fixed_alpha_uv":int(e.get("uvMode", 0)) == 2,
	}
	if e.multUv != null:
		params.merge({"mult_center":_v2(e.multUv.center),"mult_flip":Vector2(float(e.multUv.flipU),float(e.multUv.flipV)),"mult_address":int(e.multUv.addressMode)})
	if e.erosion != null:
		params.merge({"erosion_mix":_v4(e.erosion.mixer.constant),"erosion_band":Vector3(e.erosion.sliceWidth,1.0/maxf(e.erosion.featherIn,0.00000001),1.0/maxf(e.erosion.featherOut,0.00000001)),"erosion_address":int(e.erosion.addressMode)})
	if e.soft != null:
		var soft: Dictionary = e.soft
		params["soft_params"] = Vector4(soft.beginIn,soft.beginOut if soft.beginOut > 0 else 1e8,1.0/maxf(soft.deltaIn,0.00000001),1.0/maxf(soft.deltaOut,0.00000001))
	if e.distortion != null: params["warp_strength"] = e.distortion.strength
	for name in params: result.set_shader_parameter(name,params[name])
	for pair in [["source_texture","texture_path"],["mult_texture","mult_path"],["ramp_texture","color_path"],["erosion_texture","erosion_path"],["normal_texture","normal_path"]]:
		if not e[pair[1]].is_empty(): result.set_shader_parameter(pair[0],load(e[pair[1]]))
	return result

## 对外资源契约：定义读取不会创建粒子或加载纹理。
static func resource_manifest(variant: String) -> Dictionary:
	if variant not in ["pillar"]: return {}
	return {"json": [ROOT + variant + "/sampled.json"], "sample": {"player": "res://assets/effects/pillar_of_ice/player.gd", "kind": variant, "setup": "native"}}

static func resource_shader_path(e: Dictionary) -> String:
	if int(e.blendMode) == 0: return preload("res://scripts/presentation/particle_render_policy.gd").shader_path("res://assets/effects/pillar_of_ice/pure_add.gdshader", e)
	var shader_name := "opaque" if int(e.blendMode) == 3 else ("add" if int(e.blendMode) == 4 else "mix")
	return preload("res://scripts/presentation/particle_render_policy.gd").shader_path("res://assets/effects/demacian_standard/native/" + shader_name + ".gdshader", e)
