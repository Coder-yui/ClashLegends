extends Node3D
## MissFortune基础W原版粒子采样，保留双枪及结束四个系统18层。
## The authority supplies age; this node never advances battle state.
const ROOT := "res://assets/effects/missfortune_w/"
static var _cache: Dictionary = {}
static var _draw_keys: Array = []
const BLEND_RANK := [1, 2, 1, 0, 2, 2, 2, 2, 3]
var opacity := 1.0
## 原定义宿主selectionRadius=70，仅用于原生FlexShape的视觉尺寸。
var bound_object_diameter := 140.0
var _kind := ""
var _birth_positions: Dictionary = {}
var _last_position := Vector3.INF
var _last_world_basis := Basis.IDENTITY
var _last_camera := Transform3D.IDENTITY
var _data: Dictionary = {}
static var _meshes: Dictionary = {}
var _materials: Array[ShaderMaterial] = []
var _pools: Array = []
var _age := 0.0
var _frame := -1
var _last_opacity := -1.0
var _last_basis := Basis.IDENTITY
var projection_basis := Basis.IDENTITY
## 武器火光与环状网格保持原生三维组织。
const GROUND_PLANES := []
# Uniform project calibration; preserve authored layer proportions and curves.
const NATIVE_SCALES := {"body": 0.014, "left": 0.014, "right": 0.014, "end_left": 0.014, "end_right": 0.014}

static func native_scale(kind: String) -> float:
	return float(NATIVE_SCALES.get(kind, 0.006))

func shape_basis_for(_emitter_name: String) -> Basis:
	return projection_basis

static func layer_enabled(kind: String, emitter: String) -> bool:
	return true

func load_kind(kind: String) -> void:
	_kind = kind
	if not _cache.has(kind):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + kind + "/sampled.json"))
		var materials: Array[ShaderMaterial] = []
		for e in data.emitters:
			if not layer_enabled(kind, String(e.name)):
				materials.append(null)
				continue
			if not _meshes.has(e.mesh_path): _meshes[e.mesh_path] = _mesh(e.mesh_path)
			materials.append(_material(e))
		_cache[kind] = {"data": data, "materials": materials}
	_data = _cache[kind].data
	_materials.assign(_cache[kind].materials)

func setup_native(unit_scale: float) -> void:
	scale = Vector3.ONE * unit_scale
	for e in _data.emitters: _pools.append([])
	seek(0.0)

func advance(delta: float) -> void:
	seek(_age + delta)

func seek(age: float) -> void:
	if age < _age: _birth_positions.clear()
	_age = maxf(age, 0.0)
	var frame := mini(int(_age * float(_data.fps)), _data.frames.size() - 1)
	var current_camera := get_viewport().get_camera_3d()
	var camera_frame := current_camera.global_transform if current_camera != null else Transform3D.IDENTITY
	if global_basis == _last_world_basis and camera_frame == _last_camera and frame == _frame and opacity == _last_opacity and projection_basis == _last_basis and global_position == _last_position: return
	_last_world_basis = global_basis
	_last_camera = camera_frame
	_frame = frame
	_last_position = global_position
	_last_opacity = opacity
	_last_basis = projection_basis
	var values: Array = _data.frames[frame]
	for emitter_index in values.size():
		var e: Dictionary = _data.emitters[emitter_index]
		var pool: Array = _pools[emitter_index]
		var particles: Array = values[emitter_index]
		while pool.size() < particles.size():
			var item := MeshInstance3D.new()
			item.mesh = _meshes[e.mesh_path]
			item.material_override = _materials[emitter_index].duplicate()
			item.material_override.set_shader_parameter("projection_basis", projection_basis)
			item.material_override.set_shader_parameter("shape_basis", shape_basis_for(e.name))
			item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			item.custom_aabb = AABB(Vector3(-2500, -2500, -2500), Vector3(5000, 5000, 5000))
			# Preserve native layer centers.
			item.position.y = 0.0
			add_child(item)
			pool.append(item)
		for j in pool.size():
			var item: MeshInstance3D = pool[j]
			item.visible = j < particles.size() and _age <= float(_data.duration)
			if item.visible:
				item.material_override.set_shader_parameter("projection_basis", projection_basis)
				item.material_override.set_shader_parameter("shape_basis", shape_basis_for(e.name))
				item.material_override.set_shader_parameter("opacity", opacity)
				var sample: Array = particles[j]
				var flex := float(e.get("bound_size_scale", 0.0))
				item.material_override.set_shader_parameter("bound_size_multiplier", flex * bound_object_diameter if flex > 0.0 else 1.0)
				if e.meshDraw and (bool(e.mesh.alignPitch) or bool(e.mesh.alignYaw)):
					var camera := get_viewport().get_camera_3d()
					if camera != null:
						item.material_override.set_shader_parameter("mesh_camera_basis", _camera_mesh_basis(e, sample, camera))
				if String(e.name) in GROUND_PLANES:
					item.position.y = to_local(Vector3(global_position.x, 0.09, global_position.z)).y
				if float(e.bindWeight.constant[0]) == 0.0:
					# Detached end sparks retain their birth frame as the weapon moves.
					var key := Vector2i(emitter_index, int(sample[0]))
					if not _birth_positions.has(key): _birth_positions[key] = global_transform
					var relative: Transform3D = global_transform.affine_inverse() * _birth_positions[key]
					sample = sample.duplicate()
					var center := relative * Vector3(sample[1], sample[2], sample[3])
					sample[1] = center.x
					sample[2] = center.y
					sample[3] = center.z
					var axes := Basis(Vector3(sample[12], sample[15], sample[18]), Vector3(sample[13], sample[16], sample[19]), Vector3(sample[14], sample[17], sample[20]))
					axes = relative.basis * axes
					for row in 3:
						for col in 3: sample[12 + row * 3 + col] = axes[col][row]
				item.material_override.set_shader_parameter("p", PackedFloat32Array(sample))
				var camera := get_viewport().get_camera_3d()
				if camera != null:
					var values_j: Array = particles[j]
					var center := to_global(projection_basis * Vector3(values_j[1], values_j[2], values_j[3]))
					item.sorting_offset = camera.global_position.distance_to(center) - camera.global_position.distance_to(global_position)


## 原版SCB朝镜头规则：选择Yaw/Pitch分量，以相机Up构造基，再保留粒子自身旋转。
func _camera_mesh_basis(e: Dictionary, sample: Array, camera: Camera3D) -> Basis:
	var center := Vector3(sample[1], sample[2], sample[3])
	var eye := to_local(camera.global_position)
	var forward := Vector3(eye.x - center.x if e.mesh.alignYaw else 0.0, eye.y - center.y if e.mesh.alignPitch else 0.0, eye.z - center.z).normalized()
	var up := global_basis.inverse() * camera.global_basis.y
	var aside := up.cross(forward).normalized()
	if forward.is_zero_approx() or aside.is_zero_approx(): return Basis.IDENTITY
	var lift := forward.cross(aside).normalized()
	return Basis(-aside, lift, -forward)

static func _mesh(path: String) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
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
			if raw.has("normals"):
				normals.append(Vector3(-raw.normals[i*3], raw.normals[i*3+1], raw.normals[i*3+2]))
			colors.append(Color(raw.colors[i*4]/255.0,raw.colors[i*4+1]/255.0,raw.colors[i*4+2]/255.0,raw.colors[i*4+3]/255.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	if not normals.is_empty(): arrays[Mesh.ARRAY_NORMAL] = normals
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

static func _v2(a: Array) -> Vector2: return Vector2(a[0],a[1])
static func _v4(a: Array) -> Vector4: return Vector4(a[0],a[1],a[2],a[3])

static func _material(e: Dictionary) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = load(resource_shader_path(e))
	result.render_priority = native_render_priority(e)
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
	if e.meshDraw and e.reflection != null:
		var r: Dictionary = e.reflection
		params["has_fresnel"] = true
		# mesh_vs uses RGB + exponent; fresnelColor alpha is not a multiplier.
		params["fresnel"] = Vector4(r.fresnelColor[0], r.fresnelColor[1], r.fresnelColor[2], r.fresnel)
	for name in params: result.set_shader_parameter(name,params[name])
	for pair in [["source_texture","texture_path"],["mult_texture","mult_path"],["ramp_texture","color_path"],["erosion_texture","erosion_path"],["normal_texture","normal_path"]]:
		if not e[pair[1]].is_empty(): result.set_shader_parameter(pair[0],load(e[pair[1]]))
	return result

## 对外资源契约：定义读取不会创建粒子或加载纹理。
static func resource_manifest(variant: String) -> Dictionary:
	if variant not in ["left", "right", "end_left", "end_right"]: return {}
	return {"raw": [ROOT + "render_order.json"], "json": [ROOT + variant + "/sampled.json"], "sample": {"player": "res://assets/effects/missfortune_w/player.gd", "kind": variant, "setup": "native"}}

## Compress native pass/simple/blend/flags/index keys jointly for all four systems.
## The old per-system rank put equal native passes in different Godot priorities.
static func native_render_priority(e: Dictionary) -> int:
	if _draw_keys.is_empty():
		_draw_keys = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "render_order.json"))["keys"]
	var phase := -2 if bool(e.groundLayer) else (0 if int(e.pass) < 0 else 2)
	if e.distortion != null:
		phase = 1 if int(e.distortion.mode) == 1 else -1
	var key := [phase, int(e.pass), int(e.simple), BLEND_RANK[int(e.blendMode)], int(e.miscRenderFlags), int(e.index)]
	var rank := -1
	for i in _draw_keys.size():
		var matches := true
		for j in key.size():
			if int(_draw_keys[i][j]) != int(key[j]): matches = false
		if matches:
			rank = i
			break
	assert(rank >= 0, "Unregistered native MissFortune W draw key")
	return rank - 64

static func resource_shader_path(e: Dictionary) -> String:
	return ROOT + ("pure_add" if int(e.blendMode) == 0 else ("add" if int(e.blendMode) == 4 else "mix")) + ".gdshader"
