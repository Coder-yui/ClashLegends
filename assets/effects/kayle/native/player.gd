extends Node2D
## 原始发射器采样投影；仅消费可见路径和表现时间。
const ROOT := "res://assets/effects/kayle/native/"
static var _cache: Dictionary = {}
var _data: Dictionary
var _pools: Array = []
var _births: Dictionary = {}
var _last_age := -1.0
var unit_scale := 0.12
var wave_radius := 0.0
var _tip_offset := 0.0

static func dependency_paths() -> Array:
	var paths: Array = []
	for kind in ["sword", "wave"]:
		var data := _load_data(kind)

		for e in data.emitters:
			for field in ["texture_path", "mult_path", "color_path", "palette_path"]:
				if not String(e[field]).is_empty(): paths.append(e[field])
	for blend in ["add", "pure_add", "mix", "sub"]: paths.append(ROOT + blend + ".gdshader")
	return paths

static func _load_data(kind: String) -> Dictionary:
	if not _cache.has(kind):
		_cache[kind] = JSON.parse_string(FileAccess.get_file_as_string(ROOT + kind + "/sampled.json"))
	return _cache[kind]

func setup(kind: String) -> void:
	_data = _load_data(kind)
	for e in _data.emitters: _pools.append([])

func sample(age: float, strength: float) -> void:
	if age < _last_age: _births.clear()
	_last_age = age
	var frame: Array = _data.frames[clampi(roundi(age * float(_data.fps)), 0, _data.frames.size() - 1)]
	if wave_radius > 0.0:
		# Arc2贴图亮弧横向约覆盖原四边形的78%，顶点V约0.15。
		var core: Array = frame[5]
		if not core.is_empty():
			unit_scale = wave_radius / maxf(float(core[0][5])*0.78, 0.001)
			_tip_offset = (0.70*float(core[0][4])-30.0)*unit_scale
	for index in _data.emitters.size():
		var e: Dictionary = _data.emitters[index]
		var samples: Array = frame[index]
		var pool: Array = _pools[index]
		var trail: bool = e.trail != null
		if trail:
			samples = samples.duplicate()
			samples.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
		var count := maxi(samples.size() - 1, 0) if trail else samples.size()
		while pool.size() < count:
			var item := Polygon2D.new()
			item.texture = load(e.texture_path)
			item.material = _material(e)
			item.z_index = int(e.rank) + 999990 if int(e.rank) < -1000 else int(e.rank)
			add_child(item)
			pool.append(item)
		for j in pool.size():
			var item: Polygon2D = pool[j]
			item.visible = j < count
			if not item.visible: continue
			var p: Array = samples[j]
			var vertices := PackedVector2Array()
			var uvs := PackedVector2Array()
			var colors := PackedColorArray()
			if trail:
				var q: Array = samples[j + 1]
				var a := _center(p, e)
				var b := _center(q, e)
				var normal := (b - a).normalized().orthogonal()
				if normal.is_zero_approx(): normal = Vector2.RIGHT
				vertices = PackedVector2Array([a-normal*absf(p[4])*unit_scale, a+normal*absf(p[4])*unit_scale, b+normal*absf(q[4])*unit_scale, b-normal*absf(q[4])*unit_scale])
				var ca := Color(p[7],p[8],p[9],p[10])
				var cb := Color(q[7],q[8],q[9],q[10])
				colors = PackedColorArray([ca,ca,cb,cb])
				# 以原版1500单位平铺长度沿实际轨迹延展，避免每段重置纹理。
				var tiling := 1500.0 if e.trail.tiling.constant[0] > 0 else 100.0
				var va := float(p[0]) / float(e.rate.constant[0]) * 1400.0 / tiling
				var vb := float(q[0]) / float(e.rate.constant[0]) * 1400.0 / tiling
				uvs = PackedVector2Array([Vector2(0,va),Vector2(1,va),Vector2(1,vb),Vector2(0,vb)])
			else:
				var center := _center(p, e)
				var x := Vector2(p[12],-p[15])
				var y := Vector2(p[13],-p[16])
				if bool(e.billboard) and not bool(e.directionOriented):
					x = Vector2(cos(p[11]),sin(p[11]))
					y = x.orthogonal()
				for corner in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]:
					vertices.append(center + (x*corner.x*float(p[4])+y*corner.y*float(p[5]))*float(e.reach)*unit_scale)
					uvs.append(Vector2(corner.x+0.5,0.5-corner.y) if bool(e.billboard) else Vector2(corner.y+0.5,corner.x+0.5))
					colors.append(Color(p[7],p[8],p[9],p[10]))
			for n in uvs.size(): uvs[n] *= Vector2(item.texture.get_size())
			item.polygon = vertices
			item.uv = uvs
			item.vertex_colors = colors
			item.material.set_shader_parameter("p", PackedFloat32Array(p))
			item.material.set_shader_parameter("opacity", strength)

func _center(p: Array, e: Dictionary) -> Vector2:
	var point := Vector2(p[1],-p[2])*unit_scale + Vector2(0,_tip_offset)
	if float(e.bindWeight.constant[0]) > 0.0: return point
	var id := int(p[0])
	if not _births.has(id): _births[id] = global_position
	return point + to_local(_births[id])

static func _v2(v: Array) -> Vector2: return Vector2(v[0],v[1])
static func _material(e: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(resource_shader_path(e))
	var params := {"cell":_v2(e.cell),"cell_mult":_v2(e.cellMult),"uv_center":_v2(e.uv.center),"uv_flip":Vector2(float(e.uv.flipU),float(e.uv.flipV)),"address_mode":e.uv.addressMode,"has_mult":not e.mult_path.is_empty(),"has_palette":e.palette != null,"has_ramp":not e.color_path.is_empty()}
	if e.multUv != null: params.merge({"mult_center":_v2(e.multUv.center),"mult_flip":Vector2(float(e.multUv.flipU),float(e.multUv.flipV)),"mult_address":e.multUv.addressMode})
	if e.palette != null:
		params.palette_row = (float(e.palette.selector.constant[0])+0.5)/float(e.palette.count)
		var mix: Array = e.palette.mix.constant
		params.palette_mix = Vector4(mix[0],mix[1],mix[2],mix[3])
	for key in params: m.set_shader_parameter(key,params[key])
	for pair in [["mult_texture","mult_path"],["palette_texture","palette_path"],["ramp_texture","color_path"]]:
		if not e[pair[1]].is_empty(): m.set_shader_parameter(pair[0],load(e[pair[1]]))
	return m

static func resource_manifest(variant: String) -> Dictionary:
	if variant not in ["sword", "wave"]: return {}
	return {"json": [ROOT + variant + "/sampled.json"], "sample": {"player": "res://assets/effects/kayle/native/player.gd", "kind": variant, "setup": "2d"}}

static func resource_shader_path(e: Dictionary) -> String:
	var blend: String = {0:"pure_add",1:"mix",2:"sub",4:"add"}.get(int(e.blendMode),"mix")
	return ROOT + blend + ".gdshader"
