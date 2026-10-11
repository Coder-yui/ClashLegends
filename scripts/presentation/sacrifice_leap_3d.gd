extends Node3D
## 起跳与抵达用同一sacrifice_id连接。抵达前只播原片前23帧，不预测伤害/爆炸。
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const BURST = preload("res://assets/effects/void_spawn/player.gd")
const SOURCE_IMPACT_TIME := 23.0 / 30.0
var _views := {}
var _bursts := {}
var _impact_poses := {}

static func resource_manifest(_variant: String) -> Dictionary:
	return {"paths": []} # 动作由卡牌场景预热；各原版粒子由卡牌分别声明。

func sync_effects(skills: RefCounted, camera: Camera3D) -> void:
	var impacts := {}
	for effect in skills.frontal_effects:
		if String(effect.shape) == "sacrifice_burst": impacts[int(effect.sacrifice_id)] = effect
	var present := {}
	for effect in skills.frontal_effects:
		if String(effect.shape) != "sacrifice_leap": continue
		var id := int(effect.sacrifice_id)
		present[id] = true
		if not _views.has(id):
			var stats := CardDB.get_unit_stats(String(effect.card_id))
			var model := (load(String(stats.visual_scene_path)) as PackedScene).instantiate() as Node3D
			add_child(model)
			var player := _player(model)
			var offset := Vector3.ZERO
			if player != null:
				player.play(String(stats.visual_animations.attack[0]))
				player.pause()
				player.seek(SOURCE_IMPACT_TIME, true)
				if model.has_method("sacrifice_impact_offset"):
					offset = model.call("sacrifice_impact_offset")
					_impact_poses[String(effect.card_id)] = Transform3D(model.call("sacrifice_impact_basis"), offset)
				player.seek(0.0, true)
			_views[id] = {"model": model, "player": player, "offset": offset, "yaw": float(stats.get("visual_forward_yaw", 0.0))}
		var view: Dictionary = _views[id]
		var age := maxf(float(effect.duration) - float(effect.timer), 0.0)
		var progress := clampf(age / float(effect.impact_delay), 0.0, 1.0)
		var start := PROJECTION.ground(camera, effect.pos)
		var end := PROJECTION.ground(camera, effect.end_position)
		var model: Node3D = view.model
		var direction := end - start
		model.rotation.y = atan2(direction.x, direction.z) + float(view.yaw)
		model.scale = Vector3.ONE * float(effect.get("visual_scale", 1.0))
		# 原片自带Root位移；补偿爆炸挂点的水平偏移，使动作在建筑近侧接上爆炸。
		var offset: Vector3 = model.basis * Vector3(view.offset)
		offset.y = 0.0
		model.position = start.lerp(end - offset, progress)
		var burst_age := -1.0
		if impacts.has(id):
			burst_age = maxf(float(impacts[id].duration) - float(impacts[id].timer), 0.0)
			model.position = end - offset
			progress = 1.0
		var source_age := SOURCE_IMPACT_TIME * progress
		var player: AnimationPlayer = view.player
		if player != null: player.seek(source_age, true)
		if model.has_method("seek_sacrifice_visual"):
			model.call("seek_sacrifice_visual", source_age + maxf(burst_age, 0.0), burst_age)
	for id in _views.keys():
		if not present.has(id):
			_views[id].model.free()
			_views.erase(id)
	_sync_unpaired_impacts(impacts, present, camera)

func _player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found := _player(child)
		if found != null: return found
	return null

func _sync_unpaired_impacts(impacts: Dictionary, paired: Dictionary, camera: Camera3D) -> void:
	# 起跳窗口已结束但抵达通知刚到时，仍消费这次真实抵达；不留下静止身体。
	var present := {}
	for id in impacts:
		if paired.has(id): continue
		present[id] = true
		var effect: Dictionary = impacts[id]
		if not _bursts.has(id):
			var view := BURST.new()
			add_child(view)
			view.load_kind("burst")
			view.setup_native(BURST.native_scale("burst"))
			_bursts[id] = view
		var view: Node3D = _bursts[id]
		var forward: Vector2 = effect.forward
		var origin := PROJECTION.ground(camera, effect.pos)
		var direction := PROJECTION.ground(camera, effect.pos + forward) - origin
		var visual_scale := float(effect.get("visual_scale", 1.0))
		var pose := _impact_pose(String(effect.card_id))
		view.position = origin + Vector3.UP * pose.origin.y * visual_scale
		var stats := CardDB.get_unit_stats(String(effect.card_id))
		view.basis = Basis(Vector3.UP, atan2(direction.x, direction.z) + float(stats.get("visual_forward_yaw", 0.0))) * pose.basis * Basis.from_scale(Vector3.ONE * BURST.native_scale("burst") * visual_scale)
		view.seek(maxf(float(effect.duration) - float(effect.timer), 0.0))
	for id in _bursts.keys():
		if not present.has(id):
			_bursts[id].free()
			_bursts.erase(id)

## 缺少起跳代理的抵达也从原片采样挂点，避免手填高度/旋转与模型脱节。
func _impact_pose(card_id: String) -> Transform3D:
	if _impact_poses.has(card_id): return _impact_poses[card_id]
	var stats := CardDB.get_unit_stats(card_id)
	var model := (load(String(stats.visual_scene_path)) as PackedScene).instantiate() as Node3D
	add_child(model)
	var player := _player(model)
	player.play(String(stats.visual_animations.attack[0]))
	player.pause()
	player.seek(SOURCE_IMPACT_TIME, true)
	var pose := Transform3D(model.call("sacrifice_impact_basis"), model.call("sacrifice_impact_offset"))
	_impact_poses[card_id] = pose
	model.free()
	return pose
