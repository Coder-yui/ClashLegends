extends Node3D
## 皇子E旗面与W粒子采样；三维比例与逐层深度标志保持原值。
const NATIVE_SCALE := 0.01
const ROOT := "res://assets/effects/demacian_standard/"
static var _cache: Dictionary = {}
var _data: Dictionary = {}
var _sample_values: Array = []
static var _meshes: Dictionary = {}
var _materials: Array[ShaderMaterial] = []
var _pools: Array = []
var _trails: Dictionary = {}
var _unit_scale := 1.0
var _age := 0.0
var _frame := -1
var _last_basis := Basis.IDENTITY
var _last_trail_view := Basis.IDENTITY
var projection_basis := Basis.IDENTITY
var pin_trail_root := false
var range_radius := 0.0
func shape_basis_for(_emitter_name: String) -> Basis:
	return Basis.IDENTITY

func load_kind(kind: String) -> void:
	if not _cache.has(kind):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + kind + "/sampled.json"))
		var materials: Array[ShaderMaterial] = []
		for e in data.emitters:
			if not _meshes.has(e.mesh_path): _meshes[e.mesh_path] = _mesh(e.mesh_path)
			materials.append(_material(e))
		_cache[kind] = {"data": data, "materials": materials}
	_data = _cache[kind].data
	_materials.assign(_cache[kind].materials)

func setup_native(unit_scale: float) -> void:
	_unit_scale = unit_scale
	scale = Vector3.ONE * unit_scale
	for e in _data.emitters: _pools.append([])
	seek(0.0)

func set_effect_fade(value: float) -> void:
	for pool in _pools:
		for item in pool:
			item.material_override.set_shader_parameter("effect_fade", value)

func advance(delta: float) -> void:
	seek(_age + delta)

func seek(age: float) -> void:
	_age = maxf(age, 0.0)
	var frame := mini(int(_age * float(_data.fps)), _data.frames.size() - 1)
	var camera := get_viewport().get_camera_3d()
	var trail_view := global_basis.inverse() * camera.global_basis if camera != null else Basis.IDENTITY
	var trail_changed := not _trails.is_empty() and trail_view != _last_trail_view
	if frame == _frame and projection_basis == _last_basis and not trail_changed: return
	_last_trail_view = trail_view
	_frame = frame
	_last_basis = projection_basis
	_sample_values = _data.frames[frame]
	var values: Array = _sample_values
	for emitter_index in values.size():
		var e: Dictionary = _data.emitters[emitter_index]
		if int(e.get("quadType", -1)) in [4, 5, 6, 11]: continue
		var pool: Array = _pools[emitter_index]
		var particles: Array = values[emitter_index]
		while pool.size() < particles.size():
			var item := MeshInstance3D.new()
			item.add_to_group("presentation_fx")
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
				item.material_override.set_shader_parameter("projection_basis", projection_basis)
				item.material_override.set_shader_parameter("shape_basis", shape_basis_for(e.name))
				var particle := PackedFloat32Array(particles[j])
				item.material_override.set_shader_parameter("p", particle)
				if camera != null:
					var values_j: Array = particles[j]
					var center := to_global(projection_basis * Vector3(values_j[1], values_j[2], values_j[3]))
					item.sorting_offset = camera.global_position.distance_to(center) - camera.global_position.distance_to(global_position)

	for i in values.size():
		if int(_data.emitters[i].get("quadType", -1)) == 4:
			_sync_trail(i, _data.emitters[i], values[i])

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
	# 源烟尘开启Z测试，但未配置软粒子；为项目实体地面增加35源单位柔和交界。
	if String(e.name) in ["Dustring", "smoke"] and int(e.get("quadType", -1)) == 0:
		params["has_soft"] = true
		params["soft_params"] = Vector4(0.0, 1e8, 1.0 / 35.0, 1.0)
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
	if variant not in ["flag", "nova", "shield", "fall", "fall_red", "landing"]: return {}
	return {"paths": ["res://assets/effects/sona/trail.gdshader", "res://assets/effects/sona/trail_mix.gdshader", "res://assets/effects/sona/trail_no_depth.gdshader", "res://assets/effects/sona/trail_mix_no_depth.gdshader"], "json": [ROOT + variant + "/sampled.json"], "sample": {"player": "res://assets/effects/demacian_standard/player.gd", "kind": variant, "setup": "native"}}

static func resource_shader_path(e: Dictionary) -> String:
	if int(e.get("quadType", -1)) in [4, 5]: return preload("res://scripts/presentation/particle_render_policy.gd").shader_path("res://assets/effects/sona/" + ("trail_mix.gdshader" if int(e.blendMode) == 1 else "trail.gdshader"), e)
	var shader_name := "opaque" if int(e.blendMode) == 3 else ("add" if int(e.blendMode) == 4 else "mix")
	return preload("res://scripts/presentation/particle_render_policy.gd").shader_path("res://assets/effects/demacian_standard/native/" + shader_name + ".gdshader", e)

func _sync_trail(index: int, emitter: Dictionary, particles: Array) -> void:
	if not _trails.has(index):
		var item := MeshInstance3D.new()
		item.add_to_group("presentation_fx")
		item.mesh = ImmediateMesh.new()
		var mat := ShaderMaterial.new()
		mat.shader = load(resource_shader_path(emitter))
		mat.set_shader_parameter("source_texture", load(emitter.texture_path))
		mat.render_priority = clampi(int(emitter.rank) + 999900 if int(emitter.rank) < 0 else int(emitter.rank), -128, 127)
		mat.set_shader_parameter("cell", _v2(emitter.cell))
		mat.set_shader_parameter("alpha_ref", float(emitter.alphaRef))
		if emitter.erosion != null:
			mat.set_shader_parameter("has_erosion", true)
			mat.set_shader_parameter("erosion_address", int(emitter.erosion.addressMode))
			if not String(emitter.erosion_path).is_empty():
				mat.set_shader_parameter("erosion_texture", load(emitter.erosion_path))
			mat.set_shader_parameter("erosion_mixer", _v4(emitter.erosion.mixer.constant))
			mat.set_shader_parameter("erosion_band", Vector3(emitter.erosion.sliceWidth, emitter.erosion.featherIn, emitter.erosion.featherOut))
		item.material_override = mat
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(item)
		_trails[index] = item
		_pools[index].append(item)
	var item: MeshInstance3D = _trails[index]
	var mesh: ImmediateMesh = item.mesh
	mesh.clear_surfaces()
	if particles.size() < 2: return
	var ordered := particles.duplicate()
	ordered.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var points: Array[Vector3] = []
	var samples: Array = []
	var sides: Array[Vector3] = []
	for values in ordered:
		var sample: Array = values.duplicate()
		samples.append(sample)
		sides.append(-Vector3(sample[12], sample[15], sample[18]))
		points.append(Vector3(sample[1], sample[2], sample[3]))
	# 原版CameraTrail沿中心轨迹累计UV；平滑与遍历方向读取源定义。
	var smoothing := int(emitter.trail.smoothing)
	var order: Array[int] = []
	for index_j in points.size(): order.append(index_j)
	if smoothing != 2: order.reverse()
	var distance := 0.0
	var previous := Vector3.ZERO
	var previous_side := Vector3.ZERO
	var base_u := 0.0
	var emitted := 0
	var vertices: Array[Vector3] = []
	var texcoords: Array[Vector2] = []
	var colors: Array[Color] = []
	var erosions: Array[float] = []
	for j in order:
		var point := points[j]
		if smoothing != 0 and emitted > 0 and j != 0:
			point = Vector3.ZERO
			var low := maxi(j - 3, 0)
			var high := mini(j + 3, points.size() - 1)
			for neighbor in range(low, high + 1): point += points[neighbor]
			point /= float(high - low + 1)
		if emitted > 0: distance += point.distance_to(previous)
		if float(emitter.trail.cutoff) > 0.0 and distance >= float(emitter.trail.cutoff): break
		var side := sides[j]
		if int(emitter.get("quadType", -1)) == 4:
			var camera := get_viewport().get_camera_3d()
			if camera != null:
				var tangent := points[mini(j + 1, points.size() - 1)] - points[maxi(j - 1, 0)]
				var view := global_basis.inverse() * -camera.global_basis.z
				if not tangent.cross(view).is_zero_approx(): side = tangent.cross(view).normalized()
		# 旗面的缝合边绑定杆身竖轴；远端仍按源CameraTrail展开。
		if pin_trail_root and j == points.size() - 1:
			point = Vector3(0.0, 200.0, 0.0)
			side = Vector3.UP
		var raw_side := side
		if smoothing != 0 and emitted > 0:
			var bisector := side + previous_side
			if not bisector.is_zero_approx(): side = bisector.normalized()
		var sample: Array = samples[j]
		var width := float(sample[4])
		var key := str(index) + ":" + str(int(sample[0]))
		var travelled := float(_data.get("birth_odometer", {}).get(key, distance)) if int(emitter.trail.mode) == 1 else distance
		var tiling: Array = emitter.trail.tiling.constant
		var u := travelled / float(tiling[0]) if float(tiling[0]) > 0.0 else 0.0
		if emitted == 0: base_u = u - fmod(u, 2.0)
		u -= base_u
		var span := width / float(tiling[1]) if float(tiling[1]) > 0.0 else (1.0 if float(tiling[1]) == 0.0 else -float(tiling[1]))
		for edge in 2:
			vertices.append(point + side * width * (1.0 if edge == 0 else -1.0))
			var uv := Vector2(u, 0.5 + span * (-0.5 if edge == 0 else 0.5))
			var center := _v2(emitter.uv.center)
			uv = ((uv - center) * Vector2(sample[22], sample[23])).rotated(float(sample[21])) + center + Vector2(sample[24], sample[25])
			if emitter.uv.flipU: uv.x = 1.0 - uv.x
			if emitter.uv.flipV: uv.y = 1.0 - uv.y
			texcoords.append(uv)
			colors.append(Color(sample[7], sample[8], sample[9], sample[10]))
			erosions.append(float(sample[37]))
		previous = point
		previous_side = raw_side
		emitted += 1
	if emitted < 2: return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for vertex in vertices.size():
		mesh.surface_set_color(colors[vertex])
		mesh.surface_set_uv2(Vector2(erosions[vertex], 0))
		mesh.surface_set_uv(texcoords[vertex])
		mesh.surface_add_vertex(vertices[vertex])
	mesh.surface_end()
