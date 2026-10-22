extends Node3D
## 战争之影原版W粒子采样；权威时钟只读，不参与战斗。
# 默认使用W实测外层半径换算；Q使用独立几何参数。
const NATIVE_SCALE := preload("res://assets/effects/hecarim/geometry.gd").W_SCALE
const CAST_PARTICLE_SCALE := 1.0
const ROOT := "res://assets/effects/hecarim/"
static var _cache: Dictionary = {}
var _data: Dictionary = {}
static var _meshes: Dictionary = {}
var _materials: Array[ShaderMaterial] = []
var _pools: Array = []
var _attached: Array[Dictionary] = []
const RIBBON = preload("res://assets/effects/hecarim/ribbon.gd")
const RIBBON_SHADER = preload("res://assets/effects/hecarim/ribbon.gdshader")
var _weapon_points: Array = []
var _birth_frames: Dictionary = {}
var _ribbon: MeshInstance3D
var _kind := ""
var _age := 0.0
var _particle_scale := 1.0
var _frame := -1
var _last_basis := Basis.IDENTITY
var projection_basis := Basis.IDENTITY
# 原生三维比例，不做地面拉伸或高度压平。

func shape_basis_for(_emitter_name: String) -> Basis:
	return Basis.IDENTITY

func load_kind(kind: String) -> void:
	_kind = kind
	_particle_scale = CAST_PARTICLE_SCALE if kind == "cas" else 1.0
	if not _cache.has(kind):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + kind + "/sampled.json"))
		var materials: Array[ShaderMaterial] = []
		for e in data.emitters:
			if not _meshes.has(e.mesh_path): _meshes[e.mesh_path] = _mesh(e.mesh_path)
			materials.append(_material(e))
		_cache[kind] = {"data": data, "materials": materials}
	_data = _cache[kind].data
	_materials.assign(_cache[kind].materials)
	if kind == "qbuf":
		_weapon_points = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "q_weapon_path.json")).points
		for f in _data.frames.size():
			for e in range(3, _data.emitters.size()):
				for p in _data.frames[f][e]:
					if not _birth_frames.has(int(p[0])): _birth_frames[int(p[0])] = f
		_ribbon = MeshInstance3D.new()
		var material := ShaderMaterial.new()
		material.shader = RIBBON_SHADER
		material.render_priority = int(_data.emitters[7].rank)
		material.set_shader_parameter("source_texture", load(_data.emitters[7].texture_path))
		_ribbon.material_override = material
		_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ribbon)

func setup_native(unit_scale: float) -> void:
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
		if int(e.get("quadType", -1)) in [6, 11]: continue
		if _kind == "qbuf" and int(e.get("quadType", -1)) == 4:
			_update_ribbon(values[emitter_index], e)
			continue
		# 无贴图的占位带状层没有可绘制颜色，不能用Godot默认白色采样器补成矩形。
		if String(e.get("texture_path", "")).is_empty() and String(e.get("mesh_path", "")).is_empty(): continue
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
			add_child(item)
			pool.append(item)
		for j in pool.size():
			var item: MeshInstance3D = pool[j]
			item.visible = j < particles.size() and _age <= float(_data.duration)
			if item.visible:
				item.material_override.set_shader_parameter("projection_basis", projection_basis)
				item.material_override.set_shader_parameter("shape_basis", shape_basis_for(e.name))
				var particle := PackedFloat32Array(particles[j])
				if _kind == "qbuf":
					var center := _weapon_particle(particles[j], e)
					particle[1] = center.x
					particle[2] = center.y
					particle[3] = center.z
				for axis in range(4, 7): particle[axis] *= _particle_scale
				item.material_override.set_shader_parameter("p", particle)
				var camera := get_viewport().get_camera_3d()
				if camera != null:
					var values_j: Array = particles[j]
					var center := to_global(projection_basis * Vector3(values_j[1], values_j[2], values_j[3]))
					item.sorting_offset = camera.global_position.distance_to(center) - camera.global_position.distance_to(global_position)

func _weapon_particle(p: Array, emitter: Dictionary) -> Vector3:
	var born := int(_birth_frames.get(int(p[0]), _frame))
	var bind_weight := float(emitter.bindWeight.constant[0])
	var anchor_frame := _frame if bind_weight >= 1.0 else born
	var anchor: Array = _weapon_points[mini(anchor_frame, _weapon_points.size()-1)]
	var offset: Array = emitter.shape.offset
	# 源坐标已镜像X；去掉静态武器偏移，由原版动画中的武器挂点接替。
	return Vector3(float(anchor[0]),float(anchor[1]),float(anchor[2])) / scale.x + Vector3(float(p[1])+float(offset[0]),float(p[2])-float(offset[1]),float(p[3])-float(offset[2]))

func _update_ribbon(particles: Array, emitter: Dictionary) -> void:
	var ordered := particles.duplicate()
	ordered.sort_custom(func(a,b): return int(a[0]) < int(b[0]))
	var positions: Array[Vector3] = []
	for p in ordered: positions.append(_weapon_particle(p,emitter))
	var camera := get_viewport().get_camera_3d()
	var view := Vector3(0,1,1).normalized()
	if camera != null: view = global_basis.inverse() * camera.global_basis.z
	_ribbon.mesh = RIBBON.build(ordered,positions,view.normalized(),float(emitter.trail.cutoff),float(emitter.trail.tiling.constant[0]))

func make_overlay(original: Material) -> Material:
	var chain := original
	for index in _data.emitters.size():
		if int(_data.emitters[index].get("quadType", -1)) != 11: continue
		var material := _materials[index].duplicate() as ShaderMaterial
		material.next_pass = chain
		chain = material
		_attached.append({"index": index, "material": material})
	return chain

func update_attached(shown: bool) -> void:
	for entry in _attached:
		var values: Array = _data.frames[maxi(_frame, 0)][entry.index]
		entry.material.set_shader_parameter("attached_enabled", shown and not values.is_empty() and _age <= float(_data.duration))
		if not values.is_empty(): entry.material.set_shader_parameter("p", PackedFloat32Array(values[0]))

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
	if variant not in ["aoe", "cas", "eff", "qcas", "qbuf", "qtar"]: return {}
	return {"paths": [ROOT + "ribbon.gdshader"] if variant == "qbuf" else [], "raw": [ROOT + "q_weapon_path.json"] if variant == "qbuf" else [], "json": [ROOT + variant + "/sampled.json"], "sample": {"player": "res://assets/effects/hecarim/player.gd", "kind": variant, "setup": "native"}}

static func resource_shader_path(e: Dictionary) -> String:
	if String(e.get("texture_path", "")).ends_with("hecarim_base_w_indicator_ult.png"):
		return preload("res://scripts/presentation/particle_render_policy.gd").shader_path(ROOT + "mix.gdshader", e)
	if int(e.get("quadType", -1)) == 11: return ROOT + "attached.gdshader"
	var shader_name := "warp" if e.distortion != null else ("subtract" if int(e.blendMode) == 2 else ("pure_add" if int(e.blendMode) == 0 else ("add" if int(e.blendMode) == 4 else "mix")))
	return preload("res://scripts/presentation/particle_render_policy.gd").shader_path(ROOT + shader_name + ".gdshader", e)
