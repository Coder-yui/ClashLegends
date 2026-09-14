class_name VisualActionSequence
extends RefCounted
## 纯表现序列：持有片段、裁剪区间、目标时长及游标，不访问 Unit、Main 或 AnimationPlayer。
var _clips: Array[Dictionary] = []
var _index := 0
var index: int:
	get: return _index

func configure(names: Array, durations: Array, ranges: Array, lengths: Dictionary, authoritative_duration: float) -> bool:
	clear()
	for candidate in names.size():
		var name := StringName(names[candidate])
		if name == &"" or not lengths.has(name): continue
		var length := float(lengths[name])
		var section := Vector2(0.0, length)
		if candidate < ranges.size() and ranges[candidate] is Array and ranges[candidate].size() == 2:
			section.x = clampf(float(ranges[candidate][0]), 0.0, length)
			section.y = clampf(float(ranges[candidate][1]), section.x, length)
		var duration := maxf(float(durations[candidate]), 0.0) if candidate < durations.size() else 0.0
		_clips.append({"name": name, "range": section, "duration": duration})
	var configured_total := 0.0
	var source_total := 0.0
	for clip in _clips:
		configured_total += float(clip.duration)
		source_total += maxf(clip.range.y - clip.range.x, 0.0)
	if configured_total <= 0.001 and authoritative_duration > 0.001 and source_total > 0.001:
		for clip in _clips:
			clip.duration = authoritative_duration * (clip.range.y - clip.range.x) / source_total
	return not _clips.is_empty()

func current() -> Dictionary:
	if _index >= _clips.size(): return {}
	var clip: Dictionary = _clips[_index].duplicate()
	clip["speed"] = maxf((clip.range.y - clip.range.x) / float(clip.duration), 0.01) if float(clip.duration) > 0.001 else 1.0
	return clip

## 返回素材内部秒数；晚到超过总时长时保持末段末帧。
func seek(elapsed: float) -> float:
	if _clips.is_empty(): return 0.0
	var remaining := maxf(elapsed, 0.0)
	for candidate in _clips.size():
		var clip: Dictionary = _clips[candidate]
		var duration := float(clip.duration)
		var section: Vector2 = clip.range
		if duration <= 0.001: duration = section.y - section.x
		if remaining >= duration and candidate + 1 < _clips.size():
			remaining -= duration
			continue
		_index = candidate
		var speed := (section.y - section.x) / maxf(duration, 0.001)
		return clampf(section.x + remaining * speed, section.x, section.y)
	return 0.0

func advance() -> bool:
	_index += 1
	return _index < _clips.size()

func clear() -> void:
	_clips.clear()
	_index = 0
