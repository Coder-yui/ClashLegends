extends RefCounted
## Fixed sampled layers: generated representatives, never a shader/RID deduplication rule.
const STRATEGY := "sampled-fixed-layers-v1"
const VARIABLE := ["p", "opacity", "projection_basis", "shape_basis"]

static func encoded(value: Variant) -> Dictionary:
	if value is Texture2D:
		return {"type": TYPE_OBJECT, "class": value.get_class(), "path": value.resource_path, "width": value.get_width(), "height": value.get_height()}
	return {"type": typeof(value), "bits": var_to_bytes(value).hex_encode()}

static func signature(item: MeshInstance3D, contract: Dictionary) -> Dictionary:
	var mesh := item.mesh as ArrayMesh
	var material := item.material_override as ShaderMaterial
	if mesh == null or mesh.get_script() != null or mesh.get_surface_count() != 1 or mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES or item.skin != null or item.get_node_or_null(item.skeleton) is Skeleton3D or item.material_overlay != null or item.layers != 1 or item.transparency != 0.0 or item.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: return {}
	if material == null or material.get_script() != null or material.shader == null or material.next_pass != null or not contract.has("defaults") or contract.get("engine") != Engine.get_version_info().string: return {}
	var arrays := mesh.surface_get_arrays(0)
	for channel in Mesh.ARRAY_MAX:
		var present: bool = arrays[channel] != null and arrays[channel].size() > 0
		if present != (channel in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV]): return {}
	var parameters := {}
	var bindings := {}
	for uniform in material.shader.get_shader_uniform_list():
		var key := String(uniform.name)
		if uniform.type == TYPE_NIL or key in VARIABLE: continue
		if not contract.defaults.has(key) or not contract.uniform_types.has(key) or contract.uniform_types[key].variant != uniform.type: return {}
		var value: Variant = material.get_shader_parameter(key)
		# Unset means exactly the generated, version-bound shader default. Never a wildcard.
		# duplicate() may materialize that same default; any different value still fails.
		parameters[key] = contract.defaults[key] if value == null else encoded(value)
		bindings[key] = contract.get("bindings", {}).get(key, "default" if value == null else "override")
	if parameters.size() != contract.defaults.size(): return {}
	if material.get_shader_parameter("has_soft") != false or material.shader.resource_path.get_file().begins_with("warp"): return {}
	return {"shader": material.shader.resource_path, "format": str(mesh.surface_get_format(0)), "vertices": arrays[Mesh.ARRAY_VERTEX].size(), "priority": material.render_priority, "parameters": parameters, "bindings": bindings, "defaults": contract.defaults, "uniform_types": contract.uniform_types, "render_modes": contract.render_modes, "shader_inputs": contract.shader_inputs, "engine": Engine.get_version_info().string}

static func valid(coverage: Dictionary) -> bool:
	if coverage.get("strategy") != STRATEGY or coverage.get("version") != 1 or not coverage.get("layers") is Array or coverage.layers.is_empty() or coverage.layers.size() > 64: return false
	var ids := []
	for layer in coverage.layers:
		if not layer is Dictionary or (not layer.get("index") is float and not layer.get("index") is int): return false
		if layer.index < 0 or layer.index != int(layer.index) or layer.index in ids or not layer.get("signature") is Dictionary or layer.signature.is_empty() or not layer.get("row") is Array or layer.row.size() != 38: return false
		if not layer.row.all(func(value): return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(value)): return false
		if layer.row[10] <= 0 or absf(layer.row[4] * layer.row[5]) <= 0.000001: return false
		ids.append(layer.index)
	return true

## load_kind has already prepared ALL source mesh/material templates, as in formal use.
## Only temporary draw representatives are reduced; formal particle pools are untouched.
static func prepare(player: Node3D, coverage: Dictionary, camera: Camera3D, errors: PackedStringArray) -> void:
	if not valid(coverage) or player.get_child_count() != 0:
		errors.append("固定采样层产物错误/非空代表宿主")
		return
	var enabled := []
	for index in player._data.emitters.size():
		if player.get_script().layer_enabled(player._kind, player._data.emitters[index].name): enabled.append(index)
	var declared: Array = coverage.layers.map(func(layer): return int(layer.index))
	if declared != enabled:
		errors.append("固定采样层覆盖遗漏/多余层"); return
	player.scale = Vector3.ONE * 0.01
	for layer in coverage.layers:
		var index := int(layer.index)
		if index >= player._data.emitters.size() or index >= player._materials.size():
			errors.append("固定采样层索引错误"); return
		var emitter: Dictionary = player._data.emitters[index]
		if emitter.get("trail") != null or emitter.get("soft") != null or emitter.get("distortion") != null or player._materials[index] == null:
			errors.append("固定采样层超出资格"); return
		var item := MeshInstance3D.new()
		item.mesh = player.get_script()._meshes[emitter.mesh_path]
		item.material_override = player._materials[index].duplicate()
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		item.custom_aabb = AABB(Vector3(-2500, -2500, -2500), Vector3(5000, 5000, 5000))
		var material := item.material_override as ShaderMaterial
		material.set_shader_parameter("projection_basis", player.projection_basis)
		material.set_shader_parameter("shape_basis", player.shape_basis_for(emitter.name))
		material.set_shader_parameter("opacity", 1.0)
		material.set_shader_parameter("p", PackedFloat32Array(layer.row))
		if signature(item, layer.signature) != layer.signature:
			var actual := signature(item, layer.signature)
			item.free(); errors.append("固定采样层几何/材质链不符: " + str(actual) + " expected=" + str(layer.signature)); return
		player.add_child(item)
		# Separate visible cells. Position changes introduce no new render state.
		var target := Vector2(180 + (index % 4) * 120, 400 + (index / 4) * 80)
		var center: Vector3 = player.projection_basis * Vector3(layer.row[1], layer.row[2], layer.row[3])
		item.position = player.to_local(preload("res://scripts/presentation/spell_effect_projection.gd").ground(camera, target)) - center
		item.set_meta("coverage_layer", index)
