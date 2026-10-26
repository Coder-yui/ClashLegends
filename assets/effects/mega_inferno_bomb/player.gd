extends Node3D
## 炸弹人原版R粒子采样，保留原生XYZ比例。
const NATIVE_SCALE := 0.0125
const ROOT := "res://assets/effects/mega_inferno_bomb/"
static var _cache: Dictionary = {}
var _data: Dictionary = {}
static var _meshes: Dictionary = {}
var _materials: Array[ShaderMaterial] = []
var _pools: Array = []
var _attached: Array[Dictionary] = []
var _stopped := false
var _survivors: Dictionary = {}
var _age := 0.0
var _frame := -1
var _last_basis := Basis.IDENTITY
var projection_basis := Basis.IDENTITY
var inner_ring_ratio := 0.5
# 可见亮线：网格半径25.225～30.554，纹理Alpha峰值行106/256。
const RANGE_RING_RADIUS := 28.337 * 16.8
# 原生三维比例，不做地面拉伸或高度压平。
const GROUND_PLANES := ["ring_ground_add", "Decal_SmokeRingBG", "ring_ground1", "ground_burn", "Dissolve"]

func shape_basis_for(emitter_name: String) -> Basis:
	# 源内外圈birthScale为8:16.8，先校准项目半径比，再统一缩放整套效果。
	if emitter_name == "CenterRange": return Basis.IDENTITY.scaled(Vector3.ONE * (inner_ring_ratio * 16.8 / 8.0))
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
			if item.visible and _stopped: item.visible = _survivors.has(str(emitter_index) + ":" + str(particles[j][0]))
			if item.visible:
				item.material_override.set_shader_parameter("projection_basis", projection_basis)
				item.material_override.set_shader_parameter("shape_basis", shape_basis_for(e.name))
				var particle := PackedFloat32Array(particles[j])
				if _stopped and float(e.get("bindWeight", {}).get("constant", [0.0])[0]) >= 1.0:
					var held: Array = _survivors[str(emitter_index) + ":" + str(particles[j][0])]
					for k in [1,2,3,12,13,14,15,16,17,18,19,20]: particle[k] = held[k]
				item.material_override.set_shader_parameter("p", particle)
				var camera := get_viewport().get_camera_3d()
				if camera != null:
					var values_j: Array = particles[j]
					var center := to_global(projection_basis * Vector3(values_j[1], values_j[2], values_j[3]))
					item.sorting_offset = camera.global_position.distance_to(center) - camera.global_position.distance_to(global_position)

## 停发后只保留当前粒子ID，继续采样其原生曲线，不生成新粒子。
func stop_emitting() -> void:
	if _stopped: return
	_stopped = true
	_survivors.clear()
	for i in _data.frames[maxi(_frame, 0)].size():
		for particle in _data.frames[maxi(_frame, 0)][i]:
			if _data.emitters[i].name != "Bomb": _survivors[str(i) + ":" + str(particle[0])] = particle.duplicate()

	# 同一采样帧也必须立即重建可见性，不能残留已抵达的Bomb网格。
	_frame = -1

func restart_emitting() -> void:
	_stopped = false
	_survivors.clear()
	_frame = -1
	seek(0.0)

func has_live_particles() -> bool:
	for pool in _pools:
		for item in pool:
			if item.visible: return true
	return false

## bindWeight=0拖尾使用出生时的世界位姿；绑定粒子跟随当前弹体。
func seek_path(age: float, travel: float, pose_at: Callable, unit_scale: float) -> void:
	var current: Transform3D = pose_at.call(minf(age, travel))
	global_transform = Transform3D(current.basis.scaled(Vector3.ONE * unit_scale), current.origin)
	seek(age)
	var values: Array = _data.frames[maxi(_frame, 0)]
	var inverse_pose := global_transform.affine_inverse()
	var birth_poses := {}
	for i in values.size():
		var bind_weight := float(_data.emitters[i].get("bindWeight", {}).get("constant", [1.0])[0])
		for j in values[i].size():
			if not _pools[i][j].visible: continue
			if bind_weight >= 1.0:
				_pools[i][j].transform = Transform3D.IDENTITY
				continue
			var birth := float(_data.get("births", {}).get(str(int(values[i][j][0])), 0.0))
			if not birth_poses.has(birth): birth_poses[birth] = pose_at.call(minf(birth, travel))
			var born: Transform3D = birth_poses[birth]
			var blended := born.interpolate_with(current, bind_weight)
			_pools[i][j].transform = inverse_pose * Transform3D(blended.basis.scaled(Vector3.ONE * unit_scale), blended.origin)

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
		var pivot_values: Array = raw.get("source_central_point", [0.0, 0.0, 0.0])
		var pivot := Vector3(pivot_values[0], pivot_values[1], pivot_values[2])
		# Preserve SCB center before the single X-axis conversion.
		# Mirrored X with Godot's clockwise front faces; original SCB corner order.
		for i in raw.vertices.size() / 3:
			var source := Vector3(raw.vertices[i*3],raw.vertices[i*3+1],raw.vertices[i*3+2]) - pivot
			vertices.append(Vector3(-source.x, source.y, source.z))
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
	if variant not in ["warning_ally", "warning_enemy", "missile", "impact"]: return {}
	return {"json": [ROOT + variant + "/sampled.json"], "sample": {"player": "res://assets/effects/mega_inferno_bomb/player.gd", "kind": variant, "setup": "native"}}

static func resource_shader_path(e: Dictionary) -> String:
	if int(e.get("quadType", -1)) == 11: return ROOT + "attached.gdshader"
	var shader_name := "warp" if e.distortion != null else ("subtract" if int(e.blendMode) == 2 else ("pure_add" if int(e.blendMode) == 0 else ("add" if int(e.blendMode) == 4 else "mix")))
	return preload("res://scripts/presentation/particle_render_policy.gd").shader_path(ROOT + shader_name + ".gdshader", e)

func set_fade(value: float) -> void:
	for pool in _pools:
		for item in pool: item.material_override.set_shader_parameter("effect_fade", clampf(value, 0.0, 1.0))
