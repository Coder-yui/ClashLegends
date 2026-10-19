extends Node3D
## 虚空献祭223069原版粒子采样；仅消费表现时钟。
## The authority supplies age; this node never advances battle state.
const ROOT := "res://assets/effects/void_summoning/"
static var _data: Dictionary = {}
static var _samples: RefCounted
var preparation_errors := PackedStringArray()
static var _meshes: Dictionary = {}
static var _materials: Array[ShaderMaterial] = []
var _pools: Array = []
var _age := 0.0
var _frame := -1
var projection_basis := Basis.IDENTITY
# Semantic footprint geometry, including unflagged near-ground quads and the central dome.
const FOOTPRINT_SHAPES := ["Temp_Mesh6", "Temp_Mesh7", "AOE_Indicator", "Voidglow", "Groundlights", "Temp_GroundGlow", "Voiddiscglow1", "Voidglow1", "Praxis", "Praxis1", "Shockwaves", "Temp_GroundGlow1", "Temp_GroundGlow2", "Temp_GroundGlow3", "Temp_GroundGlow4", "Voiddiscglow2", "Temp_GroundGlow5", "Shockwaves1", "Shockwaves2", "Shockwaves3"]
const GROUND_PLANES := ["Temp_Mesh6", "Temp_Mesh7", "AOE_Indicator", "Voidglow", "Temp_GroundGlow", "Voiddiscglow1", "Voidglow1", "Praxis", "Praxis1", "Shockwaves", "Temp_GroundGlow1", "Temp_GroundGlow2", "Temp_GroundGlow3", "Temp_GroundGlow4", "Voiddiscglow2", "Temp_GroundGlow5", "Shockwaves1", "Shockwaves2", "Shockwaves3"]

func shape_basis_for(emitter_name: String) -> Basis:
	return projection_basis if emitter_name in FOOTPRINT_SHAPES else Basis.IDENTITY

static func prewarm() -> bool:
	if not _data.is_empty(): return true
	_samples = preload("res://scripts/presentation/compact_particle_samples.gd").new()
	if not _samples.read(ROOT + "sampled.clps", "res://tools/source_assets/void_summoning/sampled.json"): return false
	_data = _samples.data
	for e in _data.emitters:
		var mesh_path: String = e.mesh_path
		if not _meshes.has(mesh_path): _meshes[mesh_path] = _mesh(mesh_path)
		_materials.append(_material(e))
	return true

func setup_native(unit_scale: float) -> void:
	if not prewarm():
		preparation_errors = _samples.errors.duplicate()
		return
	scale = Vector3.ONE * unit_scale
	for e in _data.emitters: _pools.append([])
	seek(0.0)

func advance(delta: float) -> void:
	seek(_age + delta)

func seek(age: float) -> void:
	if _data.is_empty(): return
	_age = maxf(age, 0.0)
	var frame := mini(int(_age * float(_data.fps)), _samples.frames - 1)
	if frame == _frame: return
	_frame = frame
	for emitter_index in _data.emitters.size():
		var e: Dictionary = _data.emitters[emitter_index]
		var pool: Array = _pools[emitter_index]
		var count: int = _samples.count(frame, emitter_index)
		var begin: int = _samples.begin(frame, emitter_index)
		while pool.size() < count:
			var item := MeshInstance3D.new()
			item.mesh = _meshes[e.mesh_path]
			item.material_override = _materials[emitter_index].duplicate()
			item.material_override.set_shader_parameter("projection_basis", projection_basis)
			item.material_override.set_shader_parameter("shape_basis", shape_basis_for(e.name))
			item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			item.custom_aabb = AABB(Vector3(-2500, -2500, -2500), Vector3(5000, 5000, 5000))
			add_child(item)
			pool.append(item)
		for j in pool.size():
			var item: MeshInstance3D = pool[j]
			item.visible = j < count and _age <= float(_data.duration)
			if item.visible:
				var sample: Array = _samples.row(begin + j)
				item.material_override.set_shader_parameter("p", PackedFloat32Array(sample))
				var camera := get_viewport().get_camera_3d()
				if camera != null:
					var values_j: Array = sample
					var center := to_global(projection_basis * Vector3(values_j[1], values_j[2], values_j[3]))
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

static func _material(e: Dictionary) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = load(resource_shader_path(e))
	result.render_priority = int(e.rank) + 999900 if int(e.rank) < 0 else int(e.rank)
	# Original distortionMode=2 is the early, pre-particle phase.
	if e.distortion != null: result.render_priority = -110
	var params := {
		"is_mesh":e.meshDraw, "cull_mesh":e.backfaceCull, "billboard":e.billboard, "directed":e.directionOriented,
		"is_ray":e.ray, "reach":e.reach, "pivot":0.5 if e.pivotUp else 0.0,
		"ground_layer":String(e.name) in GROUND_PLANES, "cell":_v2(e.cell), "cell_mult":_v2(e.cellMult),
		"uv_center":_v2(e.uv.center), "uv_flip":Vector2(float(e.uv.flipU),float(e.uv.flipV)),
		"address_mode":int(e.uv.addressMode), "alpha_ref":e.alphaRef,
		"has_mult":not e.mult_path.is_empty(), "has_ramp":not e.color_path.is_empty() and e.erosion == null,
		"has_erosion":e.erosion != null, "has_soft":e.soft != null, "push_pull":e.depthPushPull,
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

static func resource_shader_path(e: Dictionary) -> String:
	if int(e.blendMode) == 2: return preload("res://scripts/presentation/particle_render_policy.gd").shader_path(ROOT + "subtract.gdshader", e)
	var shader_name := "warp" if e.distortion != null else ("pure_add" if int(e.blendMode) == 0 else ("add" if int(e.blendMode) == 4 else "mix"))
	return preload("res://scripts/presentation/particle_render_policy.gd").shader_path("res://assets/effects/explosive_cask/native_end/" + shader_name + ".gdshader", e)

static func resource_manifest(variant: String) -> Dictionary:
	if variant != "zone": return {}
	return {"raw": [ROOT + "sampled.clps"], "dependency_json": ["res://tools/source_assets/void_summoning/sampled.json"], "sample": {"player": ROOT + "player.gd", "setup": "native", "kind": "zone", "scale": 0.005, "times": [0.1, 0.5, 1.5]}}

func load_kind(_kind: String) -> void:
	prewarm()

func resource_sample_ages() -> Array[float]:
	return _samples.sample_ages() if not _data.is_empty() else []
