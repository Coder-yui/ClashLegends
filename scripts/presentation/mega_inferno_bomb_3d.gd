extends Node3D
## 原版R粒子及Bomb引线子粒子；权威抵达事件唯一驱动爆炸切换。
const PROJECTION = preload("res://scripts/presentation/spell_effect_projection.gd")
const PLAYER_PATH := "res://assets/effects/mega_inferno_bomb/player.gd"
const PLAYER = preload(PLAYER_PATH)
const MOTION = preload("res://scripts/presentation/mega_inferno_bomb_motion.gd")
var _views: Dictionary = {}

func _player(kind: String, native_scale: float) -> Node3D:
	var player: Node3D = load(PLAYER_PATH).new()
	add_child(player)
	player.load_kind(kind)
	player.setup_native(native_scale)
	return player

func _flight_pose(camera: Camera3D, effect: Dictionary, age: float, travel: float) -> Transform3D:
	var t := clampf(age / maxf(travel, 0.001), 0.0, 1.0)
	var start := PROJECTION.ground(camera, effect.origin)
	var end := PROJECTION.ground(camera, effect.pos)
	var units_per_pixel := PROJECTION.ground(camera, effect.pos + Vector2(1, 0)).distance_to(end)
	# 沿原版GravityHeightSolver使用抛物线；水晶出发高度与弧顶为本项目适配值。
	var height := MOTION.height(t) * units_per_pixel
	var tangent := end-start + Vector3.UP * (MOTION.slope(t) * units_per_pixel)
	var turn := Basis.looking_at(tangent.normalized(), Vector3.UP) if tangent.cross(Vector3.UP).length_squared() > 0.0001 else Basis.IDENTITY
	return Transform3D(turn, start.lerp(end,t) + Vector3.UP * height)

func sync_effects(spells: RefCounted, camera: Camera3D, viewer_team: int = 0) -> void:
	var present := {}
	for effect in spells.bomb_effects:
		present[effect.id] = true
		var center := PROJECTION.ground(camera, effect.pos)
		var radius := PROJECTION.ground(camera, effect.pos + Vector2(float(effect.radius), 0)).distance_to(center)
		var native_scale := radius / PLAYER.RANGE_RING_RADIUS
		if not _views.has(effect.id):
			_views[effect.id] = {"warning_ally": _player("warning_ally", native_scale), "warning_enemy": _player("warning_enemy", native_scale), "missile": _player("missile", native_scale), "impact": _player("impact", native_scale), "stopped": false}
		var view: Dictionary = _views[effect.id]
		for kind in ["warning_ally", "warning_enemy", "missile", "impact"]:
			view[kind].scale = Vector3.ONE * native_scale
		var impacted := bool(effect.impacted)
		var travel := float(int(effect.impact_tick) - int(effect.start_tick)) * FixedStepClock.STEP
		var flight_age := travel if impacted else float(effect.progress) * travel
		var tail_age := float(effect.duration) - float(effect.timer) if impacted else 0.0
		var side := Vector2(0, 100.0 if int(effect.team) == 0 else -100.0)
		var toward_caster := (PROJECTION.ground(camera, effect.pos + side) - center).normalized()
		for kind in ["warning_ally", "warning_enemy"]:
			# 原贴图下巴朝局部-Z，映射到施法方半场方向，与观看方无关。
			view[kind].transform = Transform3D(Basis.looking_at(toward_caster, Vector3.UP).scaled(Vector3.ONE * native_scale), center)
			view[kind].visible = not impacted and ((int(effect.team) == viewer_team) == (kind == "warning_ally"))
			view[kind].seek(float(effect.progress) * 1.5)
		var flight_pose := func(age: float) -> Transform3D: return _flight_pose(camera, effect, age, travel)
		# 父Bomb和子Fuse_Trail已按源层级联合采样，运行时只变换共同根。
		view.missile.visible = true
		if impacted and not view.stopped:
			view.missile.seek_path(travel, travel, flight_pose, native_scale)
			view.missile.stop_emitting()
			view.stopped = true
		view.missile.seek_path(flight_age + tail_age, travel, flight_pose, native_scale)
		view.impact.position = center
		view.impact.visible = impacted
		if impacted: view.impact.seek(tail_age)
	for id in _views.keys():
		if not present.has(id):
			for player in _views[id].values():
				if player is Node: player.free()
			_views.erase(id)
