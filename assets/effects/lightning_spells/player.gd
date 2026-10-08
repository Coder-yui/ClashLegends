extends Node3D
## 符文电刑/风暴狂涌原始粒子采样重播，只读取表现年龄。
## The authority supplies age; this node never advances battle state.
const ROOT := "res://assets/effects/lightning_spells/"
static var _datasets: Dictionary = {}
static var _meshes: Dictionary = {}
var _data: Dictionary
var _materials: Array = []
var _pools: Array = []
var _age := 0.0
var _frame := -1
var _sky_scale := 1.0
var ground_basis := Basis.IDENTITY

static func prewarm(source: String) -> Dictionary:
	if _datasets.has(source): return _datasets[source]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + source + "/sampled.json"))
	var materials: Array = []
	for e in data.emitters:
		var mesh_path: String = e.mesh_path
		if not _meshes.has(mesh_path): _meshes[mesh_path] = _mesh(mesh_path)
		materials.append(_material(e, source))
	_datasets[source] = {"data": data, "materials": materials}
	return _datasets[source]

func setup_native(source: String, unit_scale: float) -> void:
	var prepared := prewarm(source)
	_data = prepared.data
	_materials = prepared.materials
	scale = Vector3.ONE * unit_scale
	for e in _data.emitters: _pools.append([])
	seek(0.0)

func configure_sky(height: float, source: String) -> void:
	# 只伸长天空落雷层，地面圈/火花/云雾保持原尺寸。
	var native_top := 1500.0 if source == "electrocute" else 1280.0
	_sky_scale = maxf(1.0, height / (native_top * scale.x))

func advance(delta: float) -> void:
	seek(_age + delta)

func seek(age: float) -> void:
	_age = maxf(age, 0.0)
	var frame := mini(int(_age * float(_data.fps)), _data.frames.size() - 1)
	if frame == _frame: return
	_frame = frame
	var values: Array = _data.frames[frame]
	for emitter_index in values.size():
		var e: Dictionary = _data.emitters[emitter_index]
		var pool: Array = _pools[emitter_index]
		var particles: Array = values[emitter_index]
		while pool.size() < particles.size():
			var item := MeshInstance3D.new()
			item.mesh = _meshes[e.mesh_path]
			item.material_override = _materials[emitter_index].duplicate()
			if String(e.name) in ["Bolt", "Bolt1", "boltSmokeStag", "DownwardLight1", "Lightning_", "Beam_Core", "Lightning_2"]:
				item.material_override.set_shader_parameter("sky_scale", _sky_scale)
				item.material_override.set_shader_parameter("bolt_width", 1.8)
			item.material_override.set_shader_parameter("ground_basis", ground_basis)
			item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			item.custom_aabb = AABB(Vector3(-2500, -2500, -2500), Vector3(5000, 5000, 5000))
			add_child(item)
			pool.append(item)
		for j in pool.size():
			var item: MeshInstance3D = pool[j]
			item.visible = j < particles.size() and _age <= float(_data.duration)
			if item.visible:
				item.material_override.set_shader_parameter("p", PackedFloat32Array(particles[j]))
				var camera := get_viewport().get_camera_3d()
				if camera != null:
					var values_j: Array = particles[j]
					var center := to_global(Vector3(values_j[1], values_j[2], values_j[3]))
					item.sorting_offset = camera.global_position.distance_to(center) - camera.global_position.distance_to(global_position)

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

static func _material(e: Dictionary, source: String) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	var shader_name := "warp" if e.distortion != null else ("pure_add" if int(e.blendMode) == 0 else ("add" if int(e.blendMode) == 4 else "mix"))
	# 两种法术始终可见，保留原层顺序但关闭场景深度遮挡。
	shader_name += "_no_depth"
	result.shader = load(ROOT + shader_name + ".gdshader")
	result.render_priority = 100 + (int(e.rank) + 1000000 if int(e.rank) < 0 else int(e.rank))
	# Original distortionMode=2 is the early, pre-particle phase.
	if e.distortion != null: result.render_priority = -110
	var params := {
		"is_mesh":e.meshDraw, "cull_mesh":e.backfaceCull, "billboard":e.billboard, "directed":e.directionOriented,
		"is_ray":e.ray, "reach":e.reach, "pivot":0.5 if e.pivotUp else 0.0,
		"ground_layer":e.groundLayer or (source == "stormsurge" and String(e.name) in ["blackhole", "cast_pulse"]), "cell":_v2(e.cell), "cell_mult":_v2(e.cellMult),
		"uv_center":_v2(e.uv.center), "uv_flip":Vector2(float(e.uv.flipU),float(e.uv.flipV)),
		"address_mode":int(e.uv.addressMode), "alpha_ref":e.alphaRef,
		"has_mult":not e.mult_path.is_empty(), "has_ramp":not e.color_path.is_empty() and e.erosion == null,
		"has_erosion":e.erosion != null, "has_soft":false, "push_pull":e.depthPushPull,
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
