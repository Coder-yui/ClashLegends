extends Node3D
## 原版 Ekko R 消失/落地发射器采样，只消费权威表现时间。
## The authority supplies age; this node never advances battle state.
const ROOT := "res://assets/effects/ekko/"
static var _cache: Dictionary = {}
var _data: Dictionary = {}
var _kind := ""
static var _meshes: Dictionary = {}
var _materials: Array[ShaderMaterial] = []
var _pools: Array = []
var _attached: Array[Dictionary] = []
var _age := 0.0
var motion_history: Array[Dictionary] = []
var motion_time := 0.0
var _ribbons: Dictionary = {}
var history_window := 0.0
var _frame := -1
var _last_basis := Basis.IDENTITY
var projection_basis := Basis.IDENTITY
# 所有层保持原生三维组织。
const GROUND_PLANES := []

func shape_basis_for(emitter_name: String) -> Basis:
	return projection_basis if emitter_name in GROUND_PLANES else Basis.IDENTITY

func load_kind(kind: String) -> void:
	_kind = kind
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
	scale = Vector3.ONE * unit_scale
	for e in _data.emitters: _pools.append([])
	seek(0.0)

func advance(delta: float) -> void:
	seek(_age + delta)

func seek(age: float) -> void:
	_age = maxf(age, 0.0)
	var frame := mini(int(_age * float(_data.fps)), _data.frames.size() - 1)
	if frame == _frame and projection_basis == _last_basis and motion_history.is_empty(): return
	_frame = frame
	_last_basis = projection_basis
	var values: Array = _data.frames[frame]
	for emitter_index in values.size():
		var e: Dictionary = _data.emitters[emitter_index]
		if int(e.get("quadType", -1)) == 11: continue # 模型附着层不伪造为平面。
		var pool: Array = _pools[emitter_index]
		var particles: Array = values[emitter_index]
		if int(e.get("quadType", -1)) == 5:
			_draw_ribbon(emitter_index, particles)
			continue
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
				item.material_override.set_shader_parameter("p", PackedFloat32Array(_placed_particle(e, particles[j]).slice(0, 38)))
				var camera := get_viewport().get_camera_3d()
				if camera != null:
					var values_j: Array = particles[j]
					var center := to_global(projection_basis * Vector3(values_j[1], values_j[2], values_j[3]))
					item.sorting_offset = camera.global_position.distance_to(center) - camera.global_position.distance_to(global_position)

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
			colors.append(Color(raw.colors[i*4]/255.0,raw.colors[i*4+1]/255.0,raw.colors[i*4+2]/255.0,raw.colors[i*4+3]/255.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	for i in range(0, vertices.size(), 3):
		var normal := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		for _corner in 3: normals.append(normal)
	arrays[Mesh.ARRAY_NORMAL] = normals
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
		"ground_layer":bool(e.groundLayer), "cell":_v2(e.cell), "cell_mult":_v2(e.cellMult),
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
	if e.reflection != null and String(e.name) == "voidbladeback1":
		params["native_fresnel"] = Vector4(e.reflection.fresnelColor[0],e.reflection.fresnelColor[1],e.reflection.fresnelColor[2],e.reflection.fresnel)
	for name in params: result.set_shader_parameter(name,params[name])
	for pair in [["source_texture","texture_path"],["mult_texture","mult_path"],["ramp_texture","color_path"],["erosion_texture","erosion_path"],["normal_texture","normal_path"]]:
		if not e[pair[1]].is_empty(): result.set_shader_parameter(pair[0],load(e[pair[1]]))
	return result

## 对外资源契约：定义读取不会创建粒子或加载纹理。
static func resource_manifest(variant: String) -> Dictionary:
	if variant not in ['end', 'vanish', 'r-ChargeUp', 'r-RewindIndicator', 'r-RewindIndicator_Red', 'r-TrailEnd', 'r-TrailEnd_Red', 'r-TimeDevice_Active', 'r-Tar', 'r-Tar_Impact', 'r-RewindPose1', 'r-RewindPose2', 'r-RewindPose3', 'r-RewindPose4', 'r-RewindPose5', 'r-RewindPose6']: return {}
	return {"json": [ROOT + variant + "/sampled.json"], "sample": {"player": "res://assets/effects/ekko/player.gd", "kind": variant, "setup": "native"}}

static func resource_shader_path(e: Dictionary) -> String:
	if int(e.get("quadType", -1)) == 11: return preload("res://scripts/presentation/particle_render_policy.gd").shader_path(ROOT + ("attached_mix.gdshader" if int(e.blendMode) == 1 else "attached.gdshader"), e)
	var shader_name := "warp" if e.distortion != null else ("pure_add" if int(e.blendMode) == 0 else ("add" if int(e.blendMode) == 4 else "mix"))
	return preload("res://scripts/presentation/particle_render_policy.gd").shader_path(ROOT + shader_name + ".gdshader", e)

func attached_sample() -> Array:
	if _data.is_empty() or _frame < 0: return []
	for i in _data.emitters.size():
		if String(_data.emitters[i].name) == "RimLighting":
			var particles: Array = _data.frames[_frame][i]
			return particles[0] if not particles.is_empty() else []
	return []

static func layer_enabled(_kind: String, emitter_name: String) -> bool:
	# 两系统均无需要隐藏的发射器。
	return true

func reset_pool_visual() -> void:
	seek(0.0)
	hide()

func make_overlay(original: Material) -> Material:
	# AOERing is a pre-arrival ground system, not a persistent landed-caster buff.
	if _kind == "end": return original
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
		if not values.is_empty(): entry.material.set_shader_parameter("p", PackedFloat32Array(values[0].slice(0, 38)))

func _motion_point(time: float) -> Vector3:
	if motion_history.is_empty(): return global_position
	var previous: Dictionary = motion_history[0]
	for point in motion_history:
		if float(point.time) >= time:
			var span := float(point.time) - float(previous.time)
			return (previous.position as Vector3).lerp(point.position, clampf((time - float(previous.time)) / maxf(span, 0.00001), 0.0, 1.0))
		previous = point
	return previous.position

func _placed_particle(e: Dictionary, raw: Array) -> Array:
	var p := raw.duplicate()
	if p.size() <= 38 or motion_history.is_empty(): return p
	var bind_weight := float(e.bindWeight.constant[0])
	var birth := motion_time - _age + float(p[38])
	var offset := global_basis.inverse() * (_motion_point(birth) - global_position) * (1.0 - bind_weight)
	p[1] += offset.x
	p[2] += offset.y
	p[3] += offset.z
	return p

## Sample a complete source trail, then place its particle ages on the live history.
## Never restart its buildup every four seconds. The visible window ends at the ghost.
func seek_history(seconds: float) -> void:
	history_window = seconds
	seek(float(_data.duration))

func _history_distance(time: float) -> float:
	if motion_history.is_empty(): return 0.0
	var previous: Dictionary = motion_history[0]
	for point in motion_history:
		if float(point.time) >= time:
			var weight := clampf((time-float(previous.time))/maxf(float(point.time)-float(previous.time),0.00001),0.0,1.0)
			return lerpf(float(previous.get("distance",0.0)),float(point.get("distance",0.0)),weight)
		previous=point
	return float(previous.get("distance",0.0))

func _ribbon_particles(particles: Array) -> Array:
	var ordered := particles.duplicate()
	ordered.sort_custom(func(a,b): return float(a[38]) > float(b[38]))
	if ordered.is_empty() or history_window <= 0.0: return ordered
	var oldest := maxf(motion_time-history_window,float(motion_history[0].time))
	var result: Array = []
	# Include both endpoints; keep the source age-dependent width/colour between them.
	var head: Array = ordered[0].duplicate()
	head[38]=_age
	result.append(head)
	for p in ordered:
		if motion_time-_age+float(p[38]) >= oldest: result.append(p)
	var tail_time := _age-(motion_time-oldest)
	var tail: Array = ordered.back().duplicate()
	for i in range(1,ordered.size()):
		if float(ordered[i][38]) <= tail_time:
			var newer: Array = ordered[i-1]
			var older: Array = ordered[i]
			var weight := clampf((tail_time-float(older[38]))/maxf(float(newer[38])-float(older[38]),0.00001),0.0,1.0)
			for field in range(1,39): tail[field]=lerpf(float(older[field]),float(newer[field]),weight)
			break
	tail[38]=tail_time
	result.append(tail)
	return result

func _ribbon_uv(e: Dictionary, p: Array, value: Vector2) -> Vector2:
	var center := _v2(e.uv.center)
	var at := (value-center)*Vector2(p[22],p[23])
	at=at.rotated(float(p[21]))+center+Vector2(p[24],p[25])
	if e.uv.flipU: at.x=1.0-at.x
	if e.uv.flipV: at.y=1.0-at.y
	return Vector2(p[26],p[27])+at*_v2(e.cell)

func _draw_ribbon(index: int, particles: Array) -> void:
	if not _ribbons.has(index):
		var node := MeshInstance3D.new()
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/effects/ekko/ribbon.gdshader")
		material.set_shader_parameter("source_texture",load(_data.emitters[index].texture_path))
		node.material_override=material
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_ribbons[index]=node
	var node: MeshInstance3D = _ribbons[index]
	node.visible=particles.size()>1 and not motion_history.is_empty() and _age<=float(_data.duration)
	if not node.visible: return
	var e: Dictionary = _data.emitters[index]
	var ordered := _ribbon_particles(particles)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var distance := 0.0
	var tiling := maxf(float(e.trail.tiling.constant[0]),1.0)
	for i in range(1,ordered.size()):
		var a := _placed_particle(e,ordered[i-1])
		var b := _placed_particle(e,ordered[i])
		var start := Vector3(a[1],a[2],a[3])
		var finish := Vector3(b[1],b[2],b[3])
		var length := start.distance_to(finish)
		if length < 0.001: continue
		if float(e.trail.cutoff)>0.0 and distance+length>=float(e.trail.cutoff): break
		# Ground ribbon follows the recorded path; source scale0.x is HALF width.
		var side := (finish-start).cross(Vector3.UP).normalized()
		if side.length_squared()<0.1: side=Vector3.RIGHT
		var points := [start-side*float(a[4]),start+side*float(a[4]),finish+side*float(b[4]),finish-side*float(b[4])]
		var ua := distance/tiling
		var ub := (distance+length)/tiling
		if int(e.trail.mode)==1:
			ua=_history_distance(motion_time-_age+float(a[38]))/scale.x/tiling
			ub=_history_distance(motion_time-_age+float(b[38]))/scale.x/tiling
		var coords := [Vector2(ua,0),Vector2(ua,1),Vector2(ub,1),Vector2(ub,0)]
		for corner in [0,2,1,0,3,2]:
			var value: Array = a if corner<2 else b
			vertices.append(points[corner])
			uvs.append(_ribbon_uv(e,value,coords[corner]))
			colors.append(Color(value[7],value[8],value[9],value[10]))
		distance+=length
	if vertices.is_empty(): node.hide();return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_COLOR]=colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	node.mesh=mesh
