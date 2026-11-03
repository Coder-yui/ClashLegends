extends Node3D
## Shaco原版魔盒粒子采样；三维比例与逐层深度标志保持原值。
# 主可见波纹的原生半径：顶视逐帧渲染标定（颜色差8/255），非透明quad边界650。
const ACTIVATION_VISIBLE_RADIUS := 373.0
const ACTIVATION_PROJECT_RADIUS := 160.0
const ACTIVATION_DURATION := 0.625
# 项目弹体约8px核心、28px纵向光束；各轴等比，不沿距离拉长。
const NATIVE_SCALE := 0.007
const ROOT := "res://assets/effects/jack_in_the_box/"
static var _cache: Dictionary = {}
var _data: Dictionary = {}
static var _meshes: Dictionary = {}
var _materials: Array[ShaderMaterial] = []
var _pools: Array = []
var _motion_births: Dictionary = {}
var _trails: Dictionary = {}
var _birth_positions: Dictionary = {}
var _birth_times: Dictionary = {}
var _motion_previous_time := -1.0
var _motion_previous := Transform3D.IDENTITY
var _unit_scale := 1.0
var _age := 0.0
var _frame := -1
var _last_basis := Basis.IDENTITY
var projection_basis := Basis.IDENTITY
func shape_basis_for(_emitter_name: String) -> Basis:
	return Basis.IDENTITY

func load_kind(kind: String) -> void:
	if not _cache.has(kind):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + kind + "/sampled.json"))
		var materials: Array[ShaderMaterial] = []
		for e in data.emitters:
			if not _meshes.has(e.mesh_path): _meshes[e.mesh_path] = _mesh(e.mesh_path)
			materials.append(_material(e))
		var births := {}
		for frame_index in data.frames.size():
			for emitter_index in data.frames[frame_index].size():
				for particle in data.frames[frame_index][emitter_index]:
					var key := Vector2i(emitter_index, int(particle[0]))
					if not births.has(key): births[key] = float(frame_index) / float(data.fps)
		_cache[kind] = {"data": data, "materials": materials, "births": births}
	_data = _cache[kind].data
	_materials.assign(_cache[kind].materials)
	_birth_times = _cache[kind].births

func setup_native(unit_scale: float) -> void:
	_unit_scale = unit_scale
	scale = Vector3.ONE * unit_scale
	for e in _data.emitters: _pools.append([])
	seek(0.0)

func advance(delta: float) -> void:
	seek(_age + delta)

func seek(age: float) -> void:
	_age = maxf(age, 0.0)
	var frame := mini(int(_age * float(_data.fps)), _data.frames.size() - 1)
	if frame == _frame and projection_basis == _last_basis: return
	_frame = frame
	_last_basis = projection_basis
	var values: Array = _data.frames[frame]
	for emitter_index in values.size():
		var e: Dictionary = _data.emitters[emitter_index]
		if int(e.get("quadType", -1)) in [5, 6, 11]: continue
		var pool: Array = _pools[emitter_index]
		var particles: Array = values[emitter_index]
		while pool.size() < particles.size():
			var item := MeshInstance3D.new()
			item.add_to_group("presentation_fx")
			item.mesh = _meshes[e.mesh_path]
			item.material_override = _materials[emitter_index].duplicate()
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
				var camera := get_viewport().get_camera_3d()
				if camera != null:
					var values_j: Array = particles[j]
					var center := to_global(projection_basis * Vector3(values_j[1], values_j[2], values_j[3]))
					item.sorting_offset = camera.global_position.distance_to(center) - camera.global_position.distance_to(global_position)

## 按采样出生时刻在两次权威路径位置间插值，避免20Hz一批拖尾点重叠。
func _birth_pose(index: int, serial: int, age: float, current: Transform3D) -> Transform3D:
	if _motion_previous_time < 0.0 or age <= _motion_previous_time: return current
	var born := float(_birth_times.get(Vector2i(index, serial), age))
	var weight := clampf((born - _motion_previous_time) / (age - _motion_previous_time), 0.0, 1.0)
	return _motion_previous.interpolate_with(current, weight)

## 对bindWeight=0的烟尘/拖尾保留出生世界位置。
func seek_motion(age: float, origin: Vector3, orientation: Basis) -> void:
	if age < _age:
		_motion_births.clear()
		_birth_positions.clear()
		_motion_previous_time = -1.0
	global_position = origin
	global_basis = orientation.scaled(Vector3.ONE * _unit_scale)
	seek(age)
	var inverse := global_basis.inverse()
	var values: Array = _data.frames[maxi(_frame, 0)]
	var live := {}
	for i in values.size():
		var emitter: Dictionary = _data.emitters[i]
		if int(emitter.get("quadType", -1)) in [5, 6, 11]: continue
		var bind_weight := float(emitter.get("bindWeight", {}).get("constant", [1.0])[0])
		var emitter_basis := orientation if bool(emitter.get("localOrientation", true)) else Basis.IDENTITY
		for j in values[i].size():
			var key := str(i) + ":" + str(values[i][j][0])
			if not _motion_births.has(key):
				var pose := _birth_pose(i, int(values[i][j][0]), age, global_transform)
				_motion_births[key] = {"origin": pose.origin, "basis": pose.basis.orthonormalized() if bool(emitter.get("localOrientation", true)) else Basis.IDENTITY}
			var birth: Dictionary = _motion_births[key]
			live[key] = birth
			var particle_basis: Basis = emitter_basis if bool(emitter.get("particleLocalOrientation", false)) else birth.basis
			var item: MeshInstance3D = _pools[i][j]
			item.basis = orientation.inverse() * particle_basis
			item.position = inverse * ((birth.origin as Vector3) - origin) * (1.0-bind_weight)
	_motion_births = live
	var trail_live := {}
	for i in values.size():
		var e: Dictionary = _data.emitters[i]
		if int(e.get("quadType", -1)) != 5: continue
		for particle in values[i]:
			var key := Vector2i(i, int(particle[0]))
			if not _birth_positions.has(key): _birth_positions[key] = _birth_pose(i, int(particle[0]), age, global_transform)
			trail_live[key] = _birth_positions[key]
		_sync_trail(i, e, values[i])
	_birth_positions = trail_live
	_motion_previous = global_transform
	_motion_previous_time = age

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
	if variant not in ["missile", "aoe"]: return {}
	return {"paths": [ROOT + "trail.gdshader", ROOT + "trail_mix.gdshader"], "json": [ROOT + variant + "/sampled.json"], "sample": {"player": "res://assets/effects/jack_in_the_box/player.gd", "kind": variant, "setup": "native"}}

static func resource_shader_path(e: Dictionary) -> String:
	if int(e.get("quadType", -1)) == 5: return ROOT + ("trail_mix.gdshader" if int(e.blendMode) == 1 else "trail.gdshader")
	var shader_name := "warp" if e.distortion != null else ("subtract" if int(e.blendMode) == 2 else ("pure_add" if int(e.blendMode) == 0 else ("add" if int(e.blendMode) == 4 else "mix")))
	return preload("res://scripts/presentation/particle_render_policy.gd").shader_path("res://assets/effects/solar_flare/" + shader_name + ".gdshader", e)

func _sync_trail(index: int, emitter: Dictionary, particles: Array) -> void:
	if not _trails.has(index):
		var item := MeshInstance3D.new()
		item.mesh = ImmediateMesh.new()
		var mat := ShaderMaterial.new()
		mat.shader = load(ROOT + ("trail_mix.gdshader" if int(emitter.blendMode) == 1 else "trail.gdshader"))
		mat.set_shader_parameter("source_texture", load(emitter.texture_path))
		mat.render_priority = int(emitter.rank)
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
	for values in ordered:
		var sample: Array = values.duplicate()
		var key := Vector2i(index, int(sample[0]))
		var frame: Transform3D = _birth_positions.get(key, global_transform)
		var center := to_local(frame * Vector3(sample[1], sample[2], sample[3]))
		sample[1] = center.x
		sample[2] = center.y
		sample[3] = center.z
		samples.append(sample)
		points.append(Vector3(sample[1], sample[2], sample[3]))
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var distance := 0.0
	for j in points.size():
		if j > 0: distance += points[j].distance_to(points[j-1])
		var tangent := points[mini(j + 1, points.size() - 1)] - points[maxi(j - 1, 0)]
		var facing := to_local(camera.global_position) - points[j]
		var side := tangent.cross(facing).normalized()
		if side.length_squared() < 0.001: side = Vector3.RIGHT
		var sample: Array = samples[j]
		var width := float(sample[4])
		mesh.surface_set_color(Color(sample[7], sample[8], sample[9], sample[10]))
		mesh.surface_set_uv2(Vector2(float(sample[37]), 0))
		mesh.surface_set_uv(Vector2(distance / maxf(float(emitter.trail.tiling.constant[0]), 1.0) + float(sample[24]), 0))
		mesh.surface_add_vertex(points[j] - side * width)
		mesh.surface_set_uv(Vector2(distance / maxf(float(emitter.trail.tiling.constant[0]), 1.0) + float(sample[24]), 1))
		mesh.surface_add_vertex(points[j] + side * width)
	mesh.surface_end()
