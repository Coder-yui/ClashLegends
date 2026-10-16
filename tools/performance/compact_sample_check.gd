extends SceneTree
const DATASET = preload("res://scripts/presentation/compact_particle_samples.gd")
const WARMUP = preload("res://scripts/presentation/spell_effect_warmup.gd")
const HEARTBEAT = preload("res://tools/performance/safe_probe_heartbeat.gd")
var pulse: RefCounted
var output := ""

func _initialize() -> void:
	pulse = HEARTBEAT.new(self)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	call_deferred("run")

func run() -> void:
	if not pulse.enabled or output.is_empty(): quit(1); return
	var before := OS.get_static_memory_usage()
	var started := Time.get_ticks_usec()
	var samples := DATASET.new()
	var source := "res://assets/effects/void_summoning/sampled.json"
	if not samples.read("res://assets/effects/void_summoning/sampled.clps", source):
		print(samples.errors); quit(1); return
	var compact_usec := Time.get_ticks_usec() - started
	var compact_static := OS.get_static_memory_usage() - before
	pulse.set_phase("compact_loaded")
	await process_frame
	started = Time.get_ticks_usec()
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	var json_usec := Time.get_ticks_usec() - started
	var json_static := OS.get_static_memory_usage() - before - compact_static
	pulse.set_phase("comparing")
	var expected_ages := WARMUP.sample_ages(original)
	var compact_ages := samples.sample_ages()
	var ok := expected_ages == compact_ages
	var rows := 0
	for frame in original.frames.size():
		for layer in original.emitters.size():
			var source_rows: Array = original.frames[frame][layer]
			if source_rows.size() != samples.count(frame, layer): ok = false; break
			var begin := samples.begin(frame, layer)
			for index in source_rows.size():
				var source_row: Array = source_rows[index]
				var packed_row := begin + index
				var offset := packed_row * (samples.width - 1)
				if int(source_row[0]) != samples.ids[packed_row] or PackedFloat64Array(source_row.slice(1)).to_byte_array() != samples.values.slice(offset, offset + samples.width - 1).to_byte_array():
					ok = false; break
				rows += 1
		if not ok: break
		if frame % 16 == 0: await process_frame
	var source_meta := original.duplicate()
	source_meta.erase("frames")
	ok = ok and source_meta == samples.data and rows == samples.ids.size()
	original.clear()
	var report := {"passed": ok, "rows_bitwise_compared": rows, "float64_values_compared": rows * (samples.width - 1), "ids_type": typeof(samples.ids), "compact_usec": compact_usec, "json_read_parse_usec": json_usec, "compact_static_increment_bytes": compact_static, "json_static_increment_bytes": json_static, "sample_ages_equal": expected_ages == compact_ages, "sample_ages": compact_ages, "memory_scope": "same headless process; compact held while original parsed only for equivalence; not match RSS", "errors": samples.errors}
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	pulse.set_phase("done", true)
	await process_frame
	print("[COMPACT_SAMPLE_RESULT] ", JSON.stringify(report))
	quit(0 if ok else 1)
