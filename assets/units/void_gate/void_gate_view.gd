extends Node3D
## 待机粒子跨吐兽连续存在；吐兽独立叠加，死亡和回池统一清理。
const PARTICLES = preload("res://assets/effects/void_gate/player.gd")
const DURATIONS := {"spawn": 7.2, "idle": 64.0, "spit": 2.6, "death": 2.2}
var _effects := {}
var _ages := {}
var _tails: Array = []
var _animation: AnimationPlayer
var _skeleton: Skeleton3D
var _last_clip := ""
var _dying := false
var _idle_started := false
var _idle_age := 0.0
var _spit_delta: Animation

func _ready() -> void:
	process_priority = 20
	_animation = find_child("AnimationPlayer", true, false) as AnimationPlayer
	for node in find_children("*", "Skeleton3D", true, false):
		_skeleton = node
		break
	# Death源动作只有1秒。延长末姿态持有窗口，不降低原动画速度。
	if _animation != null and _animation.has_animation("Death"):
		var name := _animation.find_animation_library(_animation.get_animation("Death"))
		var library := _animation.get_animation_library(name).duplicate() as AnimationLibrary
		_spit_delta = library.get_animation("Spit")
		var absolute := _spit_delta.duplicate() as Animation
		var idle := library.get_animation("Idle1")
		# AnimationPlayer's blend source must also be absolute; retain the untouched delta
		# separately for the continuous Idle+Spit overlay below.
		for track in absolute.get_track_count():
			var base_track := idle.find_track(absolute.track_get_path(track), absolute.track_get_type(track))
			if base_track < 0: continue
			for key in absolute.track_get_key_count(track):
				var t := absolute.track_get_key_time(track, key)
				match absolute.track_get_type(track):
					Animation.TYPE_POSITION_3D:
						absolute.track_set_key_value(track, key, idle.position_track_interpolate(base_track, t) + _spit_delta.position_track_interpolate(track, t))
					Animation.TYPE_ROTATION_3D:
						absolute.track_set_key_value(track, key, idle.rotation_track_interpolate(base_track, t) * _spit_delta.rotation_track_interpolate(track, t))
					Animation.TYPE_SCALE_3D:
						absolute.track_set_key_value(track, key, idle.scale_track_interpolate(base_track, t) * _spit_delta.scale_track_interpolate(track, t))
		library.remove_animation("Spit")
		library.add_animation("Spit", absolute)
		var death := library.get_animation("Death").duplicate() as Animation
		death.length = DURATIONS.death
		library.remove_animation("Death")
		library.add_animation("Death", death)
		_animation.remove_animation_library(name)
		_animation.add_animation_library(name, library)

func _effect(kind: String) -> Node3D:
	if not _effects.has(kind):
		var effect := PARTICLES.new()
		add_child(effect)
		effect.load_kind(kind)
		effect.setup_native(PARTICLES.native_scale(kind))
		_effects[kind] = effect
	_update_anchor(_effects[kind], kind)
	return _effects[kind]

func _update_anchor(effect: Node3D, kind: String) -> void:
	if _skeleton == null: return
	_skeleton.force_update_all_bone_transforms()
	var bone := _skeleton.find_bone("Buffbone_Ground")
	if bone < 0: return
	var pose := global_transform.affine_inverse() * _skeleton.global_transform * _skeleton.get_bone_global_pose(bone)
	effect.position = pose.origin
	effect.basis = pose.basis.orthonormalized() * Basis.from_scale(Vector3.ONE * PARTICLES.native_scale(kind))

func _start(kind: String, age: float = 0.0) -> void:
	_ages[kind] = age
	var effect := _effect(kind)
	effect.show()
	effect.seek(age)

func _stop_event(kind: String, age: float, since_exit: float) -> void:
	if not _ages.has(kind): return
	var effect: Node3D = _effects[kind]
	effect.stop_emission(maxf(age, 0.0))
	_tails.append({"effect": effect, "kind": kind, "age": maxf(age, 0.0) + maxf(since_exit, 0.0)})
	_ages.erase(kind)
	_effects.erase(kind)

func _clear_tails() -> void:
	for tail in _tails: tail.effect.free()
	_tails.clear()

func begin_visual_death(_duration: float) -> void:
	_dying = true
	_clear_tails()
	_ages.clear()
	for effect in _effects.values(): effect.hide()
	_start("death")

## 显式阶段入口便于摄影与回归；不读取或修改战斗对象。
func seek_phase(clip: String, age: float, elapsed: float) -> void:
	# Advance existing tails first. Newly observed clips already include this frame
	# in their AnimationPlayer age; advancing them again skips the beginning.
	for tail in _tails: tail.age += maxf(elapsed, 0.0)
	for kind in _ages.keys(): _ages[kind] += maxf(elapsed, 0.0)
	if _idle_started and not _dying: _idle_age += maxf(elapsed, 0.0)
	if clip == "Spit": _apply_additive_spit(age)
	elif clip == "Idle1" and _animation != null and _last_clip == "Spit":
		_animation.seek(fmod(_idle_age, _animation.get_animation("Idle1").length), true)
	if clip != _last_clip:
		# Spit overlays the persistent portal; the single AnimationPlayer changing
		# clips does not end the separate idle particle event.
		if _last_clip == "Idle1" and clip != "Spit":
			_stop_event("idle", float(_ages.get("idle", 0.0)) - age, age)
		elif _last_clip == "Spit":
			_stop_event("spit", float(_ages.get("spit", 0.0)) - age, age)
		_last_clip = clip
		match clip:
			"Spawn": _start("spawn", age)
			"Idle1", "Spit":
				if not _idle_started and not _dying:
					_idle_started = true
				if not _dying and not _ages.has("idle"): _start("idle", age)
				if clip == "Spit" and not _dying: _start("spit", age)
			"Death":
				if not _dying: begin_visual_death(DURATIONS.death)
	for tail in _tails.duplicate():
		_update_anchor(tail.effect, tail.kind)
		tail.effect.seek(tail.age)
		if not tail.effect.has_live_particles():
			tail.effect.free()
			_tails.erase(tail)
	# Keep the active one-shot on the same clock as its skeleton, including seeks,
	# a late first frame and death started before AnimationPlayer advances.
	var active_kind: String = {"Spawn": "spawn", "Spit": "spit", "Death": "death"}.get(clip, "")
	if _ages.has(active_kind): _ages[active_kind] = maxf(age, 0.0)
	for kind in _ages.keys():
		var effect := _effect(kind)
		# 寿命为60秒；64秒完整采样覆盖部署及正常生命周期，无待机重播接缝。
		effect.seek(float(_ages[kind]))
		effect.visible = float(_ages[kind]) < float(DURATIONS[kind])
		if not effect.visible: _ages.erase(kind)

func _process(delta: float) -> void:
	if _animation == null: return
	var step := delta * absf(_animation.get_playing_speed()) if _animation.is_playing() else 0.0
	seek_phase(String(_animation.assigned_animation), _animation.current_animation_position, step)

func _apply_additive_spit(age: float) -> void:
	if _animation == null or _skeleton == null: return
	var base := _animation.get_animation("Idle1")
	var delta := _spit_delta
	var t := fmod(_idle_age, base.length)
	for track in delta.get_track_count():
		var path := delta.track_get_path(track)
		if path.get_subname_count() == 0: continue
		var bone := _skeleton.find_bone(String(path.get_subname(0)))
		var base_track := base.find_track(path, delta.track_get_type(track))
		if bone < 0 or base_track < 0: continue
		match delta.track_get_type(track):
			Animation.TYPE_POSITION_3D:
				_skeleton.set_bone_pose_position(bone, base.position_track_interpolate(base_track, t) + delta.position_track_interpolate(track, age))
			Animation.TYPE_ROTATION_3D:
				_skeleton.set_bone_pose_rotation(bone, base.rotation_track_interpolate(base_track, t) * delta.rotation_track_interpolate(track, age))
			Animation.TYPE_SCALE_3D:
				_skeleton.set_bone_pose_scale(bone, base.scale_track_interpolate(base_track, t) * delta.scale_track_interpolate(track, age))
	_skeleton.force_update_all_bone_transforms()

func finish_visual_death() -> void:
	_clear_tails()
	_ages.clear()
	for effect in _effects.values(): effect.hide()

func reset_pool_visual() -> void:
	_clear_tails()
	for effect in _effects.values(): effect.free()
	_effects.clear()
	_ages.clear()
	_dying = false
	_idle_started = false
	_idle_age = 0.0
	_last_clip = ""
