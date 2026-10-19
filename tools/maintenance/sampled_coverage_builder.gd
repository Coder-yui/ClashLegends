extends RefCounted
## Development-only lifecycle scan, one source at a time. No player or full effect pool.
const COVERAGE = preload("res://scripts/presentation/sampled_effect_coverage.gd")

static func compile(sample: Dictionary, source: String, errors: PackedStringArray) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	var provider: Script = load(sample.player)
	var layers := []
	for index in data.emitters.size():
		var emitter: Dictionary = data.emitters[index]
		if not provider.layer_enabled(sample.kind, emitter.name): continue
		if emitter.get("trail") != null or emitter.get("soft") != null or emitter.get("distortion") != null:
			errors.append("固定采样资格含动态/屏幕深度层: " + source); return {}
		var first := -1
		var best: Array = []
		var score := 0.0
		var peak := 0
		var best_frame := -1
		var best_particle := -1
		for frame in data.frames.size():
			peak = maxi(peak, data.frames[frame][index].size())
			for particle in data.frames[frame][index].size():
				var row: Array = data.frames[frame][index][particle]
				var area: float = absf(row[4] * row[5]) * maxf(row[10], 0.0)
				if area <= 0.000001: continue
				if first < 0: first = frame
				if area > score:
					best = row; score = area; best_frame = frame; best_particle = particle
		if first < 0:
			errors.append("固定采样层无有效代表: " + emitter.name); return {}
		var item := MeshInstance3D.new()
		item.mesh = provider._mesh(emitter.mesh_path)
		item.material_override = provider._material(emitter)
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var contract := preload("res://tools/maintenance/sampled_shader_contract.gd").build(item.material_override.shader, errors)
		var signature := COVERAGE.signature(item, contract)
		item.free()
		if signature.is_empty(): errors.append("固定采样层不支持的几何/材质: " + emitter.name); return {}
		var shader_source := FileAccess.get_file_as_string(signature.shader)
		var modes := RegEx.create_from_string("render_mode\\s+([^;]+);").search(shader_source)
		var render_modes := []
		if modes != null:
			for mode in modes.get_string(1).split(","): render_modes.append(mode.strip_edges())
		layers.append({"render_modes": render_modes, "context": "ordinary textures; dormant depth sampler, has_soft=false; no screen branch","index": index, "name": emitter.name, "first_frame": first, "frame": best_frame, "particle": best_particle, "peak_particles": peak, "row": best, "signature": signature})
	return {"strategy": COVERAGE.STRATEGY, "version": 1, "layers": layers}
