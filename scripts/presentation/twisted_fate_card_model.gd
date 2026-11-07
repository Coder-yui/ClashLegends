extends Node3D
## 只绘制原版卡片本体；不创建光晕、拖尾、闪点或扭曲层。
const ROOT := "res://assets/projectiles/twisted_fate/"
const NATIVE_SCALE := 0.012
var _data: Dictionary
var _cards: Array[MeshInstance3D] = []
var _card_mesh: ArrayMesh
var _card_material: ShaderMaterial
static var _cache: Dictionary = {}

func load_kind(kind: String) -> void:
	assert(kind in ["basic", "wild_blue", "wild_red", "wild_yellow"])
	if not _cache.has(kind):
		_cache[kind] = JSON.parse_string(FileAccess.get_file_as_string(ROOT + kind + ".json"))
	_data = _cache[kind]
	var layer: Dictionary = _data.emitters[0]
	_card_mesh = _mesh(layer.mesh_path)
	_card_material = _material(layer)

func setup_native(unit_scale: float) -> void:
	scale = Vector3.ONE * unit_scale

func seek(age: float) -> void:
	seek_motion(age, global_position, basis.orthonormalized())

func seek_motion(age: float, origin: Vector3, orientation: Basis) -> void:
	global_position = origin
	basis = orientation.scaled(Vector3.ONE * NATIVE_SCALE)
	var frame := mini(int(age * float(_data.fps)), _data.frames.size() - 1)
	var cards: Array = _data.frames[frame][0]
	while _cards.size() < cards.size():
		var card := MeshInstance3D.new()
		card.mesh = _card_mesh
		card.material_override = _card_material.duplicate()
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		card.custom_aabb = AABB(Vector3(-250, -250, -250), Vector3(500, 500, 500))
		add_child(card)
		_cards.append(card)
	for index in _cards.size():
		_cards[index].visible = index < cards.size()
		if index < cards.size():
			_cards[index].material_override.set_shader_parameter("p", PackedFloat32Array(cards[index]))

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

static func resource_manifest(variant: String) -> Dictionary:
	if variant not in ["basic", "wild_blue", "wild_red", "wild_yellow"]: return {}
	return {"json": [ROOT + variant + ".json"], "sample": {"player": "res://scripts/presentation/twisted_fate_card_model.gd", "kind": variant, "setup": "native"}}

static func resource_shader_path(_layer: Dictionary) -> String:
	return "res://assets/effects/solar_flare/mix.gdshader"
