extends RefCounted
## Narrow, development-only literal grammar for this reviewed sampled shader family.
## Unknown expressions/types fail; this is not a replacement shader compiler.
const COVERAGE = preload("res://scripts/presentation/sampled_effect_coverage.gd")

static func build(shader: Shader, errors: PackedStringArray) -> Dictionary:
	var sources := {}
	var source := expand(shader.resource_path, sources, errors)
	var declarations := {}
	for match in RegEx.create_from_string("uniform\\s+(\\w+)\\s+(\\w+)(\\[[^]]+\\])?([^;]*);").search_all(source):
		declarations[match.get_string(2)] = {"type": match.get_string(1), "suffix": match.get_string(4)}
	var defaults := {}
	var types := {}
	for uniform in shader.get_shader_uniform_list():
		if uniform.type == TYPE_NIL or uniform.name in COVERAGE.VARIABLE: continue
		var name := String(uniform.name)
		if not declarations.has(name): errors.append("Missing literal uniform declaration: " + name); return {}
		var declaration: Dictionary = declarations[name]
		var value: Variant = literal(declaration.type, declaration.suffix, errors)
		defaults[name] = COVERAGE.encoded(value)
		types[name] = {"variant": uniform.type, "shader_type": declaration.type, "declaration": declaration.suffix.strip_edges()}
	var modes: Array = []
	var match := RegEx.create_from_string("render_mode\\s+([^;]+);").search(source)
	if match != null:
		for mode in match.get_string(1).split(","): modes.append(mode.strip_edges())
	return {"defaults": defaults, "uniform_types": types, "render_modes": modes, "shader_inputs": sources, "engine": Engine.get_version_info().string}

static func expand(path: String, sources: Dictionary, errors: PackedStringArray) -> String:
	if sources.has(path): errors.append("Repeated/cyclic shader include: " + path); return ""
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty(): errors.append("Missing shader source: " + path); return ""
	sources[path] = source.sha256_text()
	for match in RegEx.create_from_string("#include\\s+\"([^\"]+)\"").search_all(source):
		var child := match.get_string(1)
		if not child.begins_with("res://"): child = path.get_base_dir().path_join(child)
		source = source.replace(match.get_string(), expand(child, sources, errors))
	return RegEx.create_from_string("(?s)/\\*.*?\\*/|//[^\\n]*").sub(source, "", true)

static func literal(type: String, suffix: String, errors: PackedStringArray) -> Variant:
	var expression := suffix.split("=", true, 1)[1].strip_edges() if "=" in suffix else ""
	if type == "sampler2D" and expression.is_empty(): return null
	if type == "bool" and expression in ["false", "true"]: return expression == "true"
	if type == "int" and expression.is_valid_int(): return int(expression)
	if type == "float" and expression.is_valid_float(): return float(expression)
	if type in ["vec2", "vec3", "vec4", "mat3"] and expression.begins_with(type + "(") and expression.ends_with(")"):
		var values := []
		for token in expression.trim_prefix(type + "(").trim_suffix(")").split(","):
			if not token.strip_edges().is_valid_float(): errors.append("Unsupported shader default: " + expression); return null
			values.append(float(token))
		var count := 9 if type == "mat3" else int(type.right(1))
		if values.size() == 1:
			if type == "mat3": return Basis.IDENTITY.scaled(Vector3.ONE * values[0])
			while values.size() < count: values.append(values[0])
		if values.size() == count:
			match type:
				"vec2": return Vector2(values[0], values[1])
				"vec3": return Vector3(values[0], values[1], values[2])
				"vec4": return Vector4(values[0], values[1], values[2], values[3])
	errors.append("Unsupported shader default literal: " + type + " " + suffix)
	return null
