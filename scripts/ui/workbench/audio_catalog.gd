class_name WorkbenchAudioCatalog
extends RefCounted
## 只展开已解析形态/阵营的正式音频配置；不加载资源、不读取候选清单。

static func collect(audio: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	# 正式音频以 PresentationConfig.audio_for() 的最终配置为准，不能只列举
	# 几个当时已经存在的攻击字段，否则部署、死亡和技能事件会在工作台消失。
	for cue in audio:
		var cue_name := String(cue)
		if cue_name in ["events", "team_overrides"] or cue_name.ends_with("_volume_db") or cue_name.ends_with("_lead_time"):
			continue
		_append_formal_audio(entries, cue_name, audio[cue], audio)
	var configured_events: Variant = audio.get("events", {})
	if configured_events is Dictionary:
		for cue in configured_events:
			var event: Variant = configured_events[cue]
			if event is Dictionary:
				_append_event_audio(entries, String(cue), event as Dictionary)
	return entries

static func _append_formal_audio(entries: Array[Dictionary], cue: String, value: Variant, audio: Dictionary) -> void:
	if value is String or value is StringName:
		var path := String(value)
		if path.begins_with("res://"):
			_add_audio(entries, cue, path, _formal_audio_volume(cue, audio), "Combat")
		return
	if not value is Array:
		return
	var items: Array = value
	var nested_pool := false
	for item in items:
		if item is Array:
			nested_pool = true
			break
	if nested_pool:
		for i in items.size():
			_append_formal_audio(entries, cue + "[%d]" % (i + 1), items[i], audio)
	else:
		for item in items:
			_append_formal_audio(entries, cue, item, audio)

static func _append_event_audio(entries: Array[Dictionary], cue: String, event: Dictionary) -> void:
	var pool: Variant = event.get("pool", [])
	var volume := float(event.get("volume_db", 0.0))
	var bus := String(event.get("bus", "Combat"))
	if pool is Array:
		for item in pool:
			if item is Array:
				for nested in item:
					_add_audio(entries, cue, String(nested), volume, bus)
			else:
				_add_audio(entries, cue, String(item), volume, bus)
	elif pool is String or pool is StringName:
		_add_audio(entries, cue, String(pool), volume, bus)

static func _formal_audio_volume(cue: String, audio: Dictionary) -> float:
	if cue.contains("swing") or cue.contains("launch"):
		return float(audio.get("attack_swing_volume_db", -5.0)) if cue.contains("swing") else 0.0
	return float(audio.get("attack_hit_volume_db", -4.0))

static func _add_audio(entries: Array[Dictionary], cue: String, path: String, volume: float, bus: String) -> void:
	entries.append({"cue": cue, "path": path, "volume": volume, "bus": bus})
