extends Node3D
## 瑟提基础皮肤预警与普通/满豪意轰拳的原版采样；只消费表现时间。
## The authority supplies age; this node never advances battle state.
const GEOMETRY = preload("res://scripts/data/sett_w_geometry.gd")
const ROOT := "res://assets/effects/sett/"
static var _cache: Dictionary = {}
var attachment_target: MeshInstance3D
var native_space := false
var opacity := 1.0
var range_params := GEOMETRY.RANGE
var _kind := ""
var _last_position := Vector3.INF
var _data: Dictionary = {}
static var _meshes: Dictionary = {}
var _materials: Array[ShaderMaterial] = []
var _pools: Array = []
var _age := 0.0
var _frame := -1
var _last_opacity := -1.0
var _last_basis := Basis.IDENTITY
var projection_basis := Basis.IDENTITY
func shape_basis_for(_emitter_name: String) -> Basis:
	return projection_basis

static func layer_enabled(_kind: String, _emitter: String) -> bool:
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
	if _kind in ["full_body", "cast_body"] and not is_instance_valid(attachment_target):
		# Resource preparation uses the same skinned mesh and shader variants as live attachment.
		var model := load("res://assets/units/sett/sett_view.tscn").instantiate() as Node3D
		add_child(model)
		scale = Vector3.ONE
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin != null:
				attachment_target = mesh
				break
	for e in _data.emitters: _pools.append([])
	seek(0.0)

func advance(delta: float) -> void:
	seek(_age + delta)

func seek(age: float) -> void:
	_age = maxf(age, 0.0)
	var frame := mini(int(_age * float(_data.fps)), _data.frames.size() - 1)
	if frame == _frame and opacity == _last_opacity and projection_basis == _last_basis and global_position == _last_position: return
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
			item.mesh = attachment_target.mesh if _kind in ["full_body", "cast_body"] else _meshes[e.mesh_path]
			item.material_override = _materials[emitter_index].duplicate()
			item.material_override.set_shader_parameter("projection_basis", projection_basis)
			item.material_override.set_shader_parameter("shape_basis", shape_basis_for(e.name))
			item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			item.custom_aabb = AABB(Vector3(-2500, -2500, -2500), Vector3(5000, 5000, 5000))
			if _kind in ["full_body", "cast_body"]:
				attachment_target.add_child(item)
				item.skin = attachment_target.skin
				var skeleton := attachment_target.get_node_or_null(attachment_target.skeleton)
				if skeleton != null: item.skeleton = item.get_path_to(skeleton)
			else: add_child(item)
			pool.append(item)
		for j in pool.size():
			var item: MeshInstance3D = pool[j]
			item.visible = j < particles.size() and _age <= float(_data.duration)
			if item.visible:
				item.material_override.set_shader_parameter("projection_basis", projection_basis)
				item.material_override.set_shader_parameter("shape_basis", shape_basis_for(e.name))
				item.material_override.set_shader_parameter("opacity", opacity)
				item.material_override.set_shader_parameter("range_params", range_params)
				item.material_override.set_shader_parameter("native_space", native_space)
				var sample: Array = particles[j]

				item.material_override.set_shader_parameter("p", PackedFloat32Array(sample))
				var camera := get_viewport().get_camera_3d()
				if camera != null and _kind not in ["full_body", "cast_body"]:
					var values_j: Array = particles[j]
					var source_center := Vector3(values_j[1], values_j[2], values_j[3])
					if not native_space: source_center = (source_center - Vector3(0, 0, GEOMETRY.SOURCE_ORIGIN_Z)) * (range_params.x / GEOMETRY.SOURCE_RANGE.x)
					var center := to_global(projection_basis * source_center)
					item.sorting_offset = camera.global_position.distance_to(center) - camera.global_position.distance_to(global_position)

static func _mesh(path: String) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	if path.is_empty():
		for y in 32:
			for x in 32:
				for offset in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
					var point: Vector2 = (Vector2(x,y)+offset)/32.0-Vector2(0.5,0.5)
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
		"source_length": GEOMETRY.SOURCE_RANGE.x, "source_origin_z": GEOMETRY.SOURCE_ORIGIN_Z,
		"is_mesh":e.meshDraw, "cull_mesh":e.backfaceCull, "billboard":e.billboard, "directed":e.directionOriented,
		"is_ray":e.ray, "reach":e.reach, "pivot":0.5 if e.pivotUp else 0.0,
		"cell":_v2(e.cell), "cell_mult":_v2(e.cellMult),
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
	if e.reflection != null:
		var reflection: Dictionary = e.reflection
		params.merge({"has_reflection":true,"rim":Vector4(reflection.fresnelColor[0],reflection.fresnelColor[1],reflection.fresnelColor[2],reflection.fresnel),"reflection_params":Vector4(reflection.reflectionFresnel,reflection.opacityDirect,reflection.opacityGlancing,0),"reflection_tint":Vector3(reflection.reflectionFresnelColor[0],reflection.reflectionFresnelColor[1],reflection.reflectionFresnelColor[2]),"reflection_texture":load(e.reflection_path)})
	for name in params: result.set_shader_parameter(name,params[name])
	for pair in [["source_texture","texture_path"],["mult_texture","mult_path"],["ramp_texture","color_path"],["erosion_texture","erosion_path"],["normal_texture","normal_path"]]:
		if not e[pair[1]].is_empty(): result.set_shader_parameter(pair[0],load(e[pair[1]]))
	return result

## 对外资源契约：定义读取不会创建粒子或加载纹理。
static func resource_manifest(variant: String) -> Dictionary:
	if variant not in ["warning", "min", "max", "full_body", "cast_body"]: return {}
	return {"paths": ["res://assets/units/sett/sett_view.tscn"] if variant in ["full_body", "cast_body"] else [], "json": [ROOT + variant + "/sampled.json"], "sample": {"player": "res://assets/effects/sett/player.gd", "kind": variant, "setup": "native"}}

static func resource_shader_path(e: Dictionary) -> String:
	var shader_name := "warp" if e.distortion != null else ("pure_add" if int(e.blendMode) == 0 else ("add" if int(e.blendMode) == 4 else "mix"))
	if String(e.texture_path).begins_with(ROOT + "full_body/") or String(e.texture_path).begins_with(ROOT + "cast_body/"):
		return ROOT + "body_" + shader_name + ("_overlay" if (int(e.miscRenderFlags) & 1) != 0 else "") + ".gdshader"
	var overlay := "_overlay" if (int(e.miscRenderFlags) & 1) != 0 else ""
	return ROOT + shader_name + overlay + ".gdshader"

func _exit_tree() -> void:
	if _kind not in ["full_body", "cast_body"]: return
	for pool in _pools:
		for item in pool:
			if is_instance_valid(item): item.free()
