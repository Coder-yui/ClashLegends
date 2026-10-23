extends Node3D
## 只读20Hz表现采样：四秒前骨骼、路径与原版R各阶段，不参与回溯落点或伤害。
const PLAYER = preload("res://assets/effects/ekko/player.gd")
const MODEL = preload("res://assets/units/ekko/ekko.glb")
const NATIVE_SCALE := 0.01345
const AREA_SCALE := 140.0 / 40.0 / 375.0
const REWIND_START := 0.25
const LAND_TIME := 0.75
var unit_ref: WeakRef
var _skeleton: Skeleton3D
var _ghost: Node3D
var _ghost_skeleton: Skeleton3D
var _ghost_fx: Node3D
var _indicator: Node3D
var _device: Node3D
var _history: Array[Dictionary] = []
var _motion: Array[Dictionary] = []
var _ghost_motion: Array[Dictionary] = []
var _cast_history: Array[Dictionary] = []
var _last_tick := -1
var _cast_serial := -1
var _cast_start := 0.0
var _used := false
var _transients: Array[Dictionary] = []
var _pose_index := -1
var _clock := 0.0
var _ready_visual := false
var _enemy_visual := false

func configure_unit_visual(unit: Unit) -> void:
	for child in get_children():
		if child.name != "Model": child.free()
	_history.clear()
	_motion.clear()
	_ghost_motion.clear()
	_cast_history.clear()
	_transients.clear()
	_ready_visual = false
	_last_tick = -1
	_cast_serial = -1
	_used = false
	unit_ref = weakref(unit)
	_enemy_visual = unit.battle_context != null and unit.team != unit.battle_context.local_player_team()

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null: return found
	return null

func _effect(kind: String) -> Node3D:
	var effect := PLAYER.new()
	add_child(effect)
	effect.top_level = true
	effect.load_kind(kind)
	effect.setup_native(NATIVE_SCALE)
	return effect

func _initialize_visual() -> void:
	_skeleton = _find_skeleton($Model)
	_ghost = MODEL.instantiate()
	add_child(_ghost)
	_ghost.top_level = true
	for player in _ghost.find_children("*", "AnimationPlayer", true, false):
		player.stop()
		player.active = false
	_ghost_skeleton = _find_skeleton(_ghost)
	_ghost_fx = _effect("r-TrailEnd_Red" if _enemy_visual else "r-TrailEnd")
	for mesh in _ghost.find_children("*", "MeshInstance3D", true, false):
		mesh.add_to_group("presentation_fx")
		mesh.material_overlay = null
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.material_override = _ghost_fx.make_overlay(null)
	_indicator = _effect("r-RewindIndicator_Red" if _enemy_visual else "r-RewindIndicator")
	_device = _effect("r-TimeDevice_Active")
	_ready_visual = true

func _sample(time: float, history: Array[Dictionary]) -> Dictionary:
	if history.is_empty(): return {}
	var previous: Dictionary = history[0]
	for point in history:
		if float(point.time) >= time:
			var result := previous.duplicate()
			var weight := clampf((time-float(previous.time))/maxf(float(point.time)-float(previous.time),0.00001),0.0,1.0)
			result.transform = (previous.transform as Transform3D).interpolate_with(point.transform,weight)
			return result
		previous = point
	return previous

func _spawn_pose(kind: String, sample: Dictionary, start: float) -> void:
	if sample.is_empty(): return
	var effect := _effect(kind)
	var transform: Transform3D = sample.transform
	effect.global_transform = Transform3D(transform.basis.orthonormalized().scaled(Vector3.ONE*(AREA_SCALE if kind == "end" else NATIVE_SCALE)),transform.origin)
	_transients.append({"node":effect,"start":start,"duration":0.5 if kind == "end" else 0.75,"kind":kind})

func _process(_delta: float) -> void:
	var unit = unit_ref.get_ref() if unit_ref != null else null
	if not is_instance_valid(unit) or unit.battle_context == null: return
	if not unit.battle_context.has_carried_skill_visual(unit):
		if _ready_visual:
			configure_unit_visual(unit)
		$Model.visible = true
		return
	if not _ready_visual: _initialize_visual()
	var tick: int = unit.battle_context.simulation_tick()
	_clock = float(tick) / 20.0
	var shown: bool = unit.hp > 0.0 and unit.visible_to_local_player() and unit.get_visual_state_code() != 0
	if tick != _last_tick and shown:
		_last_tick = tick
		var bones: Array[Dictionary] = []
		for i in _skeleton.get_bone_count(): bones.append({"position":_skeleton.get_bone_pose_position(i),"rotation":_skeleton.get_bone_pose_rotation(i),"scale":_skeleton.get_bone_pose_scale(i)})
		_history.append({"time":_clock,"transform":$Model.global_transform,"bones":bones})
		_motion.append({"time":_clock,"position":global_position,"distance":(float(_motion.back().distance)+global_position.distance_to(_motion.back().position)) if not _motion.is_empty() else 0.0})
		while _history.size() > 90: _history.pop_front()
		while _motion.size() > 170: _motion.pop_front()
	var casting: bool = shown and unit.get_visual_action_name() == &"rewind" and unit.get_visual_action_time_left() > 0.0 and unit.get_visual_action_serial() > unit.cancelled_visual_serial
	var age: float = unit.get_visual_action_duration()-unit.get_visual_action_time_left() if casting else -1.0
	if casting and unit.get_visual_action_serial() != _cast_serial:
		_cast_serial = unit.get_visual_action_serial()
		_cast_start = _clock-age
		_cast_history.assign(_history)
		_used = true
		_pose_index = -1
		_spawn_pose("r-ChargeUp", _sample(_cast_start, _cast_history), _cast_start)
		_spawn_pose("end", _sample(_cast_start-4.0, _cast_history), _cast_start+REWIND_START)
	# 起手0.25秒，回卷0.5秒；落地立即恢复本体和行动。
	$Model.visible = not casting or age < REWIND_START or age >= LAND_TIME
	if casting and age < LAND_TIME:
		var step := mini(int(maxf(age-REWIND_START,0.0)/((LAND_TIME-REWIND_START)/6.0)),5)
		while age >= REWIND_START and _pose_index < step:
			_pose_index += 1
			var sample := _sample(_cast_start-4.0*float(_pose_index+1)/6.0, _cast_history)
			_spawn_pose("r-RewindPose%d" % (_pose_index+1),sample,_cast_start+REWIND_START+_pose_index*(LAND_TIME-REWIND_START)/6.0)
	var ghost_sample := _sample(_clock-4.0,_history)
	var ghost_shown := shown and not _used and not ghost_sample.is_empty()
	_ghost.visible = ghost_shown
	_ghost_fx.visible = ghost_shown
	_indicator.visible = ghost_shown
	_device.visible = shown and (not _used or (casting and age < LAND_TIME))
	if ghost_shown:
		_ghost.global_transform = ghost_sample.transform
		for i in mini(_ghost_skeleton.get_bone_count(),ghost_sample.bones.size()):
			_ghost_skeleton.set_bone_pose_position(i,ghost_sample.bones[i].position)
			_ghost_skeleton.set_bone_pose_rotation(i,ghost_sample.bones[i].rotation)
			_ghost_skeleton.set_bone_pose_scale(i,ghost_sample.bones[i].scale)
		_ghost_skeleton.force_update_all_bone_transforms()
		_ghost_fx.global_position = _ghost.global_position
		if _ghost_motion.is_empty() or float(_ghost_motion.back().time) < _clock:
			_ghost_motion.append({"time":_clock,"position":_ghost.global_position})
		while _ghost_motion.size() > 170: _ghost_motion.pop_front()
		_ghost_fx.motion_history = _ghost_motion
		_ghost_fx.motion_time = _clock
		_ghost_fx.seek(1.0+fmod(_clock,4.0))
		_ghost_fx.update_attached(true)
		_indicator.global_position = global_position
		_indicator.motion_history = _motion
		_indicator.motion_time = _clock
		_indicator.seek_history(4.0)

	else:
		_ghost_fx.update_attached(false)
	if _device.visible:
		var bone := _skeleton.find_bone("Weapon_Back_Base")
		_device.global_position = (_skeleton.global_transform * _skeleton.get_bone_global_pose(bone)).origin if bone >= 0 else global_position+Vector3.UP
		_device.motion_time = _clock
		_device.seek(1.0+fmod(_clock,4.0))
	for i in range(_transients.size()-1,-1,-1):
		var entry: Dictionary = _transients[i]
		var elapsed := _clock-float(entry.start)
		if elapsed > float(entry.duration) or not shown or (_used and not casting) or (casting and age >= LAND_TIME and String(entry.kind).begins_with("r-RewindPose")):
			entry.node.queue_free()
			_transients.remove_at(i)
		else:
			entry.node.visible = elapsed >= 0.0
			if elapsed >= 0.0: entry.node.seek(maxf(elapsed,0.0001))
