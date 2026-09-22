class_name SuiteUtils
extends RefCounted
## 跨领域 suite 共用的测试工具。

static func find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := SuiteUtils.find_anim_player(child)
		if found != null:
			return found
	return null

## 静止木桩属性：不索敌、不移动、不还手，但保留质量与体型，专测横扫本身。
static func sweep_dummy_stats(base: Dictionary) -> Dictionary:
	var stats: Dictionary = base.duplicate()
	stats["deploy_time"] = 0.0
	stats["hp"] = 99999.0
	stats["damage"] = 0.0
	stats["speed"] = 0.0
	stats["sight"] = 0.0
	return stats


## 所有新卡共用的美术契约：包装场景可实例化，配置中的动画名真实存在。
## 独特动画时序仍由角色领域测试覆盖，不再为每张卡复制基础名称检查。
static func visual_contract_errors(card_id: String, stats: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_visual_stats(card_id, stats, errors)
	var transformed = stats.get("transformed_stats")
	if transformed is Dictionary and not (transformed as Dictionary).is_empty():
		_validate_visual_stats("%s.transformed_stats" % card_id, transformed, errors)
	return errors


static func _validate_visual_stats(label: String, stats: Dictionary, errors: PackedStringArray) -> void:
	var scene_paths: Array[String] = []
	var single_path := String(stats.get("visual_scene_path", ""))
	if not single_path.is_empty():
		scene_paths.append(single_path)
	for configured_path in stats.get("visual_scene_paths", []):
		if not String(configured_path).is_empty():
			scene_paths.append(String(configured_path))
	if scene_paths.is_empty():
		return
	var animations: Dictionary = stats.get("visual_animations", {})
	var animation_names := _configured_animation_names(animations)
	for scene_path in scene_paths:
		var packed := load(scene_path) as PackedScene
		if packed == null:
			errors.append("%s: 无法加载 %s" % [label, scene_path])
			continue
		var sample := packed.instantiate()
		if sample.has_method("prepare_visual_animations"):
			sample.call("prepare_visual_animations")
		var player := find_anim_player(sample)
		if player == null:
			errors.append("%s: %s 中没有 AnimationPlayer" % [label, scene_path])
		else:
			for animation_name in animation_names:
				if not player.has_animation(animation_name):
					errors.append("%s: %s 缺少动画 %s" % [label, scene_path, animation_name])
			if animations.has("death_clip_end") and player.has_animation(StringName(animations.get("death", ""))):
				if float(animations.death_clip_end) > player.get_animation(StringName(animations.death)).length:
					errors.append("%s: 死亡裁剪终点超出动画长度" % label)
			for edge in animations.get("transitions", {}):
				var descriptor = animations.transitions[edge]
				if descriptor is Dictionary and descriptor.has("start_time"):
					var clips: Array = descriptor.animation if descriptor.animation is Array else [descriptor.animation]
					for clip in clips:
						if player.has_animation(clip) and float(descriptor.start_time) >= player.get_animation(clip).length:
							errors.append("%s: %s 转场起点超出动画长度" % [label, edge])
		sample.free()
	var followup_path := String(animations.get("death_followup_scene_path", ""))
	var followup_animation := StringName(animations.get("death_followup_animation", ""))
	if not followup_path.is_empty() and followup_animation != &"":
		var followup_packed := load(followup_path) as PackedScene
		var followup_sample := followup_packed.instantiate() if followup_packed != null else null
		var followup_player := find_anim_player(followup_sample) if followup_sample != null else null
		if followup_player == null or not followup_player.has_animation(followup_animation):
			errors.append("%s: 死亡后续场景缺少动画 %s" % [label, followup_animation])
		if followup_sample != null:
			followup_sample.free()


static func _configured_animation_names(animations: Dictionary) -> Array[StringName]:
	var names: Array[StringName] = []
	for key in [
		"deploy", "idle", "idle_cycle", "move", "move_enter", "haste_move", "move_cycle",
		"attack", "attack_enter", "attack_retarget_enter", "attack_loop",
		"attack_hit", "attack_recover", "attack_structure", "attack_move", "attack_to_move",
		"empowered_move", "empowered_attack", "empowered_attack_hit", "empowered_attack_recover",
		"empowered_attack_to_move", "death",
	]:
		_append_animation_names(names, animations.get(key))
	var transitions = animations.get("transitions")
	if transitions is Dictionary:
		for edge in transitions:
			var source := String(edge).get_slice(">", 0)
			if source not in ["attack", "skill", "deploy", "transform", "idle", "move", "locomotion"]:
				_append_animation_names(names, source)
		for value in (transitions as Dictionary).values():
			if value is Dictionary:
				value = (value as Dictionary).get("animation")
			_append_animation_names(names, value)
	var blends = animations.get("clip_blends")
	if blends is Dictionary:
		for edge in blends:
			for clip in String(edge).split(">"):
				if clip != "*":
					_append_animation_names(names, clip)
	var actions = animations.get("visual_actions")
	if actions is Dictionary:
		for configured in (actions as Dictionary).values():
			_append_animation_names(names, configured.get("animation") if configured is Dictionary else configured)
	return names


static func _append_animation_names(names: Array[StringName], configured: Variant) -> void:
	var values: Array = configured if configured is Array else [configured]
	for value in values:
		if value == null:
			continue
		var animation_name := StringName(value)
		if animation_name != &"" and animation_name not in names:
			names.append(animation_name)

static func set_buff_window(unit: Unit, seconds: float) -> void:
	unit.buffs.clear_family(&"buff")
	unit.buffs.apply(&"buff", &"fixture", seconds, {})

static func replace_carried_skill(roster: ActiveSkillRoster, id: int, skill: Dictionary) -> void:
	var old := roster.entry(id)
	# 使用注册与副本替换入口构造定制动作；不开放内部集合写入。
	roster.remove(id)
	roster.register(old.unit, old.card_id, old.team, skill)
	roster.replace_replica(id, int(old.uses_remaining), float(old.cooldown_left))

static func set_control_window(control: ControlState, family: StringName, seconds: float) -> void:
	control.hard.clear_family(family)
	control.hard.apply(family, &"fixture", seconds, {})
