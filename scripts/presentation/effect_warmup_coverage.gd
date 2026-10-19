extends RefCounted
## Opt-in coverage, not a shader/RID equivalence heuristic. See docs/EFFECT_WARMUP_COVERAGE.md.
const LEGACY := "legacy-age-identity-v1"
const STATIC := "static-untextured-primitives-v1"

static func plan(recipe: Dictionary, errors: PackedStringArray) -> Dictionary:
	# Explicit migration policy: undeclared providers keep the complete old algorithm.
	# No unknown/invalid opt-in declaration is allowed to fall back to it.
	if not recipe.has("coverage"):
		return {"strategy": LEGACY, "reason": "unmigrated: full age/identity/force policy retained"}
	var value: Variant = recipe.coverage
	if not value is Dictionary or not value.get("strategy") is String:
		errors.append("效果覆盖契约缺少策略")
		return {}
	if value.strategy == LEGACY: return value
	if value.strategy != STATIC or typeof(value.get("version")) != TYPE_INT or value.version != 1:
		errors.append("未知效果覆盖策略/版本")
		return {}
	if not value.get("samples") is Array or value.samples.is_empty() or value.samples.size() > 32 or not value.get("states") is Array or value.states.is_empty() or value.states.size() > 32:
		errors.append("效果覆盖契约缺少样本/状态")
		return {}
	var ids: Array = []
	for state in value.states:
		if not state is Dictionary or not state.get("id") is String or state.id.is_empty() or state.id in ids or not state.get("shader") is String or not state.shader.begins_with("res://") or not state.shader.ends_with(".gdshader") or not state.get("count") is int or state.count < 1 or state.count > 256:
			errors.append("效果覆盖状态身份/数量错误")
			return {}
		if not state.get("mesh") is String or state.mesh not in ["SphereMesh", "QuadMesh"] or not state.get("geometry") is Array or not state.get("uniforms") is Array or not state.get("render_modes") is Array:
			errors.append("效果覆盖状态几何/材质声明错误")
			return {}
		if state.geometry.size() != (4 if state.mesh == "SphereMesh" else 2) or not state.geometry.all(func(number): return typeof(number) in [TYPE_INT, TYPE_FLOAT] and is_finite(number) and number > 0):
			errors.append("效果覆盖几何参数错误")
			return {}
		if not state.uniforms.all(func(name): return name is String) or not state.render_modes.all(func(name): return name is String):
			errors.append("效果覆盖材质字段错误")
			return {}
		var limits: Variant = state.get("uniform_ranges", {})
		if not limits is Dictionary:
			errors.append("效果覆盖uniform值域错误")
			return {}
		for name in limits:
			var bounds: Variant = limits[name]
			if name not in state.uniforms or not bounds is Array or bounds.size() != 2 or not bounds.all(func(number): return typeof(number) in [TYPE_FLOAT, TYPE_INT] and is_finite(number)) or bounds[0] > bounds[1]:
				errors.append("效果覆盖uniform值域错误")
				return {}
		ids.append(state.id)
	for sample in value.samples:
		if not sample is Dictionary or typeof(sample.get("age")) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(sample.age) or sample.age < 0.0 or not sample.get("states") is Array or sample.states.is_empty() or not sample.states.all(func(id): return id in ids) or sample.states.size() != _unique(sample.states).size():
			errors.append("效果覆盖样本年龄/状态错误")
			return {}
	var covered: Array = []
	for sample in value.samples: covered.append_array(sample.states)
	if not ids.all(func(id): return id in covered):
		errors.append("效果覆盖声明有未采样状态")
		return {}
	return value

static func _unique(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if value not in result: result.append(value)
	return result

## Model-attached context owns its own draw; no cross-context completion bit.
static func prepare_attached(root: Node, declaration: Dictionary, draw: Callable) -> PackedStringArray:
	var errors := PackedStringArray()
	var coverage := plan({"coverage": declaration}, errors)
	if coverage.is_empty(): return errors
	if coverage.strategy != STATIC or not root.has_method("seek") or not draw.is_valid():
		errors.append("附属覆盖缺少明确static策略/seek/绘制所有者")
		return errors
	for sample in coverage.samples:
		root.seek(sample.age)
		inspect(root, coverage, sample, errors)
		if not errors.is_empty(): return errors
		draw.call()
	return errors

## Development/generation only. Runtime does not read shader source.
static func validate_sources(coverage: Dictionary, errors: PackedStringArray) -> void:
	if coverage.get("strategy") != STATIC: return
	for state in coverage.states:
		var source := FileAccess.get_file_as_string(state.shader)
		var comments := RegEx.create_from_string("(?s)/\\*.*?\\*/|//[^\\n]*")
		source = comments.sub(source, "", true)
		var modes := RegEx.create_from_string("render_mode\\s+([^;]+);").search(source)
		var actual: Array = []
		if modes != null:
			for mode in modes.get_string(1).split(","): actual.append(mode.strip_edges())
		actual.sort()
		var expected: Array = state.render_modes.duplicate()
		expected.sort()
		var uniforms: Array = []
		for uniform in RegEx.create_from_string("\\buniform\\s+(\\w+)\\s+(\\w+)").search_all(source):
			if uniform.get_string(1) != "float": errors.append("静态无纹理覆盖只允许float uniform: " + state.shader)
			uniforms.append(uniform.get_string(2))
		uniforms.sort()
		var expected_uniforms: Array = state.uniforms.duplicate()
		expected_uniforms.sort()
		if actual != expected or uniforms != expected_uniforms or not RegEx.create_from_string("shader_type\\s+spatial\\s*;").search(source) or RegEx.create_from_string("\\b(sampler\\w*|texture\\w*|instance|SCREEN_TEXTURE|DEPTH_TEXTURE)\\b|#include").search(source):
			errors.append("静态覆盖Shader模式/参数/上下文超出声明: " + state.shader)

## Validate every actual instance at the representative sample, including hidden extras.
## Counts, fixed geometry/channels, no skin/overlay/next_pass, texture-free scalar uniforms,
## render priority and shadow policy matter in addition to shader identity.
static func inspect(root: Node, coverage: Dictionary, sample: Dictionary, errors: PackedStringArray) -> Dictionary:
	var counts := {}
	for id in sample.states: counts[id] = 0
	_inspect_node(root, coverage, counts, errors)
	for state in coverage.states:
		if state.id in sample.states and counts[state.id] != state.count:
			errors.append("效果覆盖状态数量/可见性不符: " + state.id)
	return counts

static func _inspect_node(node: Node, coverage: Dictionary, counts: Dictionary, errors: PackedStringArray) -> void:
	if node is CanvasItem or (node is GeometryInstance3D and not node is MeshInstance3D):
		errors.append("静态覆盖不支持2D/动态几何")
	if node is MeshInstance3D:
		var matched := false
		for state in coverage.states:
			if _matches(node, state):
				matched = true
				if not counts.has(state.id) or not node.is_visible_in_tree(): errors.append("效果出现未声明/不可见状态: " + state.id)
				else: counts[state.id] += 1
				break
		if not matched: errors.append("效果网格/通道/蒙皮/材质链超出静态覆盖: " + String(node.name))
	for child in node.get_children(): _inspect_node(child, coverage, counts, errors)

static func _matches(node: MeshInstance3D, state: Dictionary) -> bool:
	var mesh := node.mesh as PrimitiveMesh
	if mesh == null or mesh.get_class() != state.mesh or mesh.get_script() != null or mesh.get_surface_count() != 1 or node.skin != null or node.get_node_or_null(node.skeleton) is Skeleton3D or node.material_overlay != null: return false
	if node.layers != 1 or node.transparency != 0.0 or node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: return false
	if not node.global_transform.is_finite() or absf(node.global_basis.determinant()) < 0.000000001: return false
	if mesh.flip_faces or mesh.add_uv2: return false
	if mesh is SphereMesh:
		if mesh.is_hemisphere or not is_equal_approx(mesh.radius, state.geometry[0]) or not is_equal_approx(mesh.height, state.geometry[1]) or mesh.radial_segments != state.geometry[2] or mesh.rings != state.geometry[3]: return false
	elif mesh is QuadMesh:
		if mesh.orientation != PlaneMesh.FACE_Z or mesh.center_offset != Vector3.ZERO or not is_equal_approx(mesh.size.x, state.geometry[0]) or not is_equal_approx(mesh.size.y, state.geometry[1]): return false
	# These exact built-in primitive classes always produce indexed triangles;
	# the ArrayMesh-only surface_get_primitive_type API does not apply here.
	var arrays := mesh.surface_get_arrays(0)
	for channel in Mesh.ARRAY_MAX:
		var present: bool = arrays[channel] != null and arrays[channel].size() > 0
		if present != (channel in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]): return false
	if arrays[Mesh.ARRAY_INDEX].size() % 3 != 0: return false
	var material := node.get_active_material(0) as ShaderMaterial
	if material == null or material.get_script() != null or material.shader == null or material.shader.resource_path != state.shader or material.next_pass != null or material.render_priority != 0: return false
	var uniforms: Array = []
	for uniform in material.shader.get_shader_uniform_list():
		# Inspector group headers are not shader parameters.
		if uniform.type == TYPE_NIL: continue
		if uniform.type != TYPE_FLOAT or not uniform.name in state.uniforms: return false
		uniforms.append(String(uniform.name))
	for name in state.uniforms:
		var value: Variant = material.get_shader_parameter(name)
		if name not in uniforms or typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(value): return false
		if state.get("uniform_ranges", {}).has(name):
			var bounds: Array = state.uniform_ranges[name]
			if value < bounds[0] or value > bounds[1]: return false
	return uniforms.size() == state.uniforms.size()
