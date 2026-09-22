class_name UnitModel3D
extends Node3D
## 单个 3D 模型的表现代理。只读取 Unit 的插值位置与表现状态，不参与模拟。

const STATE_KEYS := [&"deploy", &"idle", &"move", &"attack"]
const ACTION_PRIORITY := {
	&"locomotion": 0,
	&"attack": 20,
	&"skill": 40,
	&"transform": 60,
	&"deploy": 80,
	&"death": 100,
}
const TRANSITION_DEFAULTS := {
	&"default": 0.08,
	&"locomotion": 0.10,
	&"action_in": 0.08,
	&"action_out": 0.14,
	&"attack": 0.06,
	&"sequence": 0.04,
	&"death": 0.10,
	&"model_swap": 0.02,
}

var _active_buff_visual: ActiveBuffVisual3D
var _model_resources := ModelVisualResources.new()
var _last_buff_visible := false

var _state: UnitPresentationState
var _control_stage := &""
var _saved_control_clip := &""
var _saved_control_position := 0.0
var _saved_control_speed := 1.0
var _saved_control_section := Vector2(-1.0, -1.0)
var _saved_control_loop_mode := Animation.LOOP_NONE
var _saved_control_action_serial := -1
var _saved_control_action_name := &""
var _saved_control_attack_serial := -1
var _saved_control_state := -1
var _saved_control_locomotion_state := -1
var _current_clip_speed := 1.0
var _stable_head_offset := NAN
var _last_frozen_overlay := false
var _was_controlled := false
var _source: Unit
var _camera: Camera3D
var _model_root: Node3D
var _animation_player: AnimationPlayer
var _animation_names: Dictionary
var _team_ring: MeshInstance3D
var _forward_yaw := 0.0
var _attack_duration := 1.0
var _current_state := -1
var _last_attack_serial := 0
var _pending_attack_serial := 0
var _last_visual_action_serial := 0
var _playing_visual_action := false
var _active_visual_action := &""
var _action_sequence := VisualActionSequence.new()
var _active_action_name := &""
var _active_action_kind := &"locomotion"
var _active_action_priority := 0
var _active_action_blend_in := -1.0
var _active_action_blend_out := -1.0
var _active_action_sequence_blend := -1.0
var _playing_attack := false
var _holding_attack_pose := false
var _active_attack_animation := &""
var _active_attack_index := 0
var _active_attack_empowered := false
var _attack_clip_start := 0.0
var _attack_clip_end := 0.0
var _attack_hit_timer := 0.0
var _attack_recover_timer := 0.0
var _attack_hit_pending := false
var _attack_recover_pending := false
# 持续攻击单位使用“进入攻击 → 循环攻击”，移动则可使用“进入移动 → 多段循环”。
# 这些状态仅消费 Unit 的粗粒度表现状态，不驱动索敌、伤害或移动。
var _continuous_attack_active := false
var _continuous_attack_animation := &""
var _continuous_attack_sequence: Array = []
var _continuous_attack_sequence_index := 0
var _move_sequence: Array = []
var _move_sequence_index := 0
var _move_sequence_exit_blend := -1.0
var _move_cycle: Array = []
var _move_cycle_index := 0
var _move_sequence_active := false
var _move_active_animation := &""
var _move_override_animation := &""
## 可选待机序列在静止状态内循环；例如 [idle1, idle1, idle2]。
## 它只选择表现片段，不改变权威状态或固定模拟节奏。
var _idle_cycle_index := 0
var _idle_cycle_active_animation := &""
var _idle_transition_animation := &""
var _idle_transition_exit_blend := -1.0
# 最近一次统一播放入口实际采用的策略与时长，供表现回归验证；不参与状态决策。
var _last_clip_transition_kind := &""
var _last_clip_blend_time := 0.0
var _last_empowered_ready := false
var _last_haste_active := false
# 出场技能序列：deploy 配置为数组时，从单位生成的部署阶段首帧开始依次播放；
# 单段部署（如赵信 1 秒 Spell4）继续由基础状态通道按 deploy_time 缩放；
# 部署结束前不被基础状态切换打断。
var _deploy_sequence: Array = []
var _deploy_sequence_index := 0
var _deploy_sequence_speeds: Array = []
var _playing_deploy_sequence := false
var _deploy_active_animation := &""
var _deploy_sequence_started := false
var _death_animation := &""
var _dying := false
var _death_followup_started := false
var _hit_flash_timer := 0.0
var _spawn_transition_kind: StringName = &""
var _spawn_transition_initialized := false
var _spawn_transition_active := false
var _spawn_transition_elapsed := 0.0
var _spawn_transition_duration := 0.0
var _spawn_transition_start_position := Vector3.ZERO
var _spawn_transition_base_position := Vector3.ZERO
var _spawn_transition_start_scale := Vector3.ONE
var _spawn_transition_base_scale := Vector3.ONE

var _visual_air := false
var _model_ground_height := 0.0
var _model_air_height := 0.0
var _height_transition := false
var _height_from := 0.0
var _height_to := 0.0
var _height_elapsed := 0.0
var _height_duration := -1.0
var model_factory: Callable
var model_recycler: Callable

func setup(unit: Unit, packed: PackedScene, camera: Camera3D, animations: Dictionary, forward_yaw: float, buff_scene_path: String = "") -> bool:
	# 客户端 Unit 会在默认优先级更新快照插值；3D 代理随后读取最终位置。
	process_priority = 10
	_source = unit
	_state = unit.presentation_state()
	_spawn_transition_kind = unit.visual_spawn_transition
	_spawn_transition_initialized = false
	_source.died.connect(_on_source_died)
	_source.visual_hit.connect(_on_source_visual_hit)
	_source.action_cancelled.connect(_on_action_cancelled)
	_camera = camera
	# 一套完整挥剑（前摇、命中、后摇）占满一个攻击周期；动画长度不改变战斗计时。
	_attack_duration = maxf(unit.attack_interval, 0.05)
	return replace_visual(packed, animations, forward_yaw, buff_scene_path)

## 形态改变更新映射；支持原位换形的包装保留模型/播放器，其他单位仍替换模型。
func replace_visual(packed: PackedScene, animations: Dictionary, forward_yaw: float, buff_scene_path: String = "") -> bool:
	# 死亡代理独立持有当前模型直到 Death 播完。即使权威层发生同帧晚到的
	# form_changed，也不能替换掉死亡动画并留下一个永不再同步的静止模型。
	if _dying:
		return false
	var had_model := _model_root != null and is_instance_valid(_model_root)
	var reuse := had_model and _model_root.has_method("set_visual_form") and _model_root.has_method("can_reuse_visual") and bool(_model_root.call("can_reuse_visual", packed.resource_path))
	var previous_height := _model_root.position.y if had_model else 0.0
	var air_changed := had_model and _visual_air != _source.is_air
	if not reuse:
		var instance: Node = model_factory.call(packed) if model_factory.is_valid() else packed.instantiate()
		if not instance is Node3D:
			instance.queue_free()
			return false
		if had_model:
			_release_model()
		_model_root = instance as Node3D
	_animation_names = animations.duplicate(true)
	_idle_transition_animation = &""
	_forward_yaw = forward_yaw
	_attack_duration = maxf(_source.attack_interval, 0.05)
	if not reuse:
		_animation_player = null
		_model_resources.clear()
	_current_state = -1
	_pending_attack_serial = 0
	_playing_attack = false
	_active_attack_empowered = false
	_holding_attack_pose = false
	_playing_visual_action = false
	_active_visual_action = &""
	_action_sequence.clear()
	_active_action_name = &""
	_active_action_kind = &"locomotion"
	_active_action_priority = 0
	_active_action_blend_in = -1.0
	_active_action_blend_out = -1.0
	_active_action_sequence_blend = -1.0
	_playing_deploy_sequence = false
	_deploy_sequence_started = false
	_continuous_attack_active = false
	_continuous_attack_sequence.clear()
	_move_sequence_active = false
	_move_sequence_exit_blend = -1.0
	_move_override_animation = &""
	_idle_cycle_index = 0
	_idle_cycle_active_animation = &""
	_last_clip_transition_kind = &""
	_last_clip_blend_time = 0.0
	_last_empowered_ready = _source.is_empowered_attack_ready_visual()
	_last_haste_active = _source.get_active_speed_multiplier_visual() > 1.001
	if not reuse:
		add_child(_model_root)
		_model_ground_height = _model_root.position.y
		_align_air_visual_elevation()
		_model_air_height = _model_root.position.y
	_model_root.position.y = _model_air_height if _source.is_air else _model_ground_height
	if _model_root.has_method("set_visual_form"):
		_model_root.call("set_visual_form", _source.get_form_index())
	_visual_air = _source.is_air
	_height_transition = air_changed
	if air_changed:
		_height_from = previous_height
		_height_to = _model_root.position.y
		_height_elapsed = 0.0
		_height_duration = -1.0
		_model_root.position.y = _height_from
	_start_spawn_transition_if_needed()
	if _model_root.has_method("prepare_visual_animations") and not _model_root.has_meta("prepared_model_resources"):
		_model_root.call("prepare_visual_animations")
	if _model_root.has_method("configure_unit_visual"):
		_model_root.call("configure_unit_visual", _source)
	if reuse:
		pass # 保留播放器、骨骼姿势与混合历史。
	elif _model_root.has_meta("prepared_model_resources"):
		_model_resources = _model_root.get_meta("prepared_model_resources")
		_animation_player = _model_root.get_meta("prepared_animation_player")
		_model_root.remove_meta("prepared_model_resources")
		_model_root.remove_meta("prepared_animation_player")
	else:
		_animation_player = _model_resources.bind_model(_model_root)
	_stable_head_offset = NAN
	_control_stage = &""
	if _animation_player == null:
		push_warning("单位 3D 模型中未找到 AnimationPlayer")
	else:
		if not _animation_player.animation_finished.is_connected(_on_animation_finished):
			_animation_player.animation_finished.connect(_on_animation_finished)
	_replace_active_buff_visual(buff_scene_path)
	_configure_looping_animations()
	_recreate_team_ring()
	if not reuse:
		_sync_visual(true, 0.0)
	_update_health_bar_anchor()
	return true

func _process(delta: float) -> void:
	_update_active_buff_visual(delta)
	_update_hit_flash(delta)
	if _dying:
		return
	if _source == null or not is_instance_valid(_source):
		_retire()
		return
	_tick_form_elevation(delta)
	_tick_spawn_transition(delta)
	if _sync_control_override():
		_sync_transform(false, delta)
		_update_continuous_beam_origin()
		_update_health_bar_anchor()
		return
	_update_attack_stages(delta)
	_sync_visual(false, delta)
	_update_continuous_beam_origin()
	_update_health_bar_anchor()

## 死亡替身与计时复生没有专用动作素材时，使用纯表现的通用模型过渡：
## 蛋从空中落到地面，凤凰从蛋的位置缩放升起。过渡不修改 Unit 的权威位置或碰撞。
func _start_spawn_transition_if_needed() -> void:
	if _spawn_transition_initialized or _spawn_transition_kind == &"" or _model_root == null:
		return
	_spawn_transition_initialized = true
	_spawn_transition_base_position = _model_root.position
	_spawn_transition_base_scale = _model_root.scale
	_spawn_transition_start_position = _spawn_transition_base_position
	_spawn_transition_start_scale = _spawn_transition_base_scale
	match _spawn_transition_kind:
		&"drop":
			_spawn_transition_duration = 0.28
			_spawn_transition_start_position += Vector3.UP * CardDB.AIR_VISUAL_ELEVATION
		&"rebirth":
			_spawn_transition_duration = 0.42
			_spawn_transition_start_position += Vector3.UP * 0.24
			_spawn_transition_start_scale *= 0.24
		_:
			return
	_spawn_transition_elapsed = 0.0
	_spawn_transition_active = true
	_model_root.position = _spawn_transition_start_position
	_model_root.scale = _spawn_transition_start_scale

func _tick_spawn_transition(delta: float) -> void:
	if not _spawn_transition_active or _model_root == null or not is_instance_valid(_model_root):
		return
	_spawn_transition_elapsed = minf(_spawn_transition_elapsed + maxf(delta, 0.0), _spawn_transition_duration)
	var ratio := _spawn_transition_elapsed / maxf(_spawn_transition_duration, 0.001)
	var eased := 1.0 - pow(1.0 - ratio, 3.0)
	_model_root.position = _spawn_transition_start_position.lerp(_spawn_transition_base_position, eased)
	_model_root.scale = _spawn_transition_start_scale.lerp(_spawn_transition_base_scale, eased)
	if ratio >= 0.999:
		_model_root.position = _spawn_transition_base_position
		_model_root.scale = _spawn_transition_base_scale
		_spawn_transition_active = false

## 换形时继承正在显示的高度。属性已由权威层切换；升降只覆盖模型根偏移。
func _tick_form_elevation(delta: float) -> void:
	if not _height_transition:
		return
	if _height_duration < 0.0:
		_height_duration = _source.get_visual_action_time_left()
		# 本帧 delta 可能包含换形发生前的时间，首帧保留原高度。
		delta = 0.0
	if _height_duration <= 0.001:
		_model_root.position.y = _height_to
		_height_transition = false
		return
	if _state.frozen:
		return
	_height_elapsed = minf(_height_elapsed + delta, _height_duration)
	_model_root.position.y = lerpf(_height_from, _height_to, _height_elapsed / _height_duration)
	if _height_elapsed >= _height_duration or _source.get_visual_action_time_left() <= 0.0:
		_model_root.position.y = _height_to
		_height_transition = false

func _sync_transform(force: bool, delta: float) -> void:
	var screen_position := _source.get_visual_screen_position()
	var ground_position := _screen_to_ground(screen_position)
	position = ground_position

	var facing_2d := _source.get_visual_facing_direction()
	var facing_ground := _screen_to_ground(screen_position + facing_2d * 20.0)
	var facing_3d := facing_ground - ground_position
	facing_3d.y = 0.0
	if facing_3d.length_squared() > 0.0001:
		var target_yaw := atan2(facing_3d.x, facing_3d.z) + _forward_yaw
		rotation.y = target_yaw if force else lerp_angle(rotation.y, target_yaw, minf(delta * 12.0, 1.0))
		if _model_root != null and _model_root.has_method("sync_visual_facing"):
			_model_root.call("sync_visual_facing", rotation.y)

func _sync_visual(force: bool, delta: float) -> void:
	_sync_transform(force, delta)
	# visual_action 先于同一快照内的攻击序号处理，确保技能/变形动作能按优先级
	# 挡住并排队普攻，不会先播一帧 Attack 再被技能覆盖。
	var visual_action_serial := _source.get_visual_action_serial()
	if visual_action_serial != _last_visual_action_serial:
		_last_visual_action_serial = visual_action_serial
		var action_name := _source.get_visual_action_name()
		_play_visual_action(action_name)
	var attack_serial := _source.get_attack_visual_serial()
	var attack_serial_changed := attack_serial != _last_attack_serial
	if attack_serial_changed:
		_last_attack_serial = attack_serial
		if not _uses_continuous_state_animations():
			if _playing_visual_action and _active_action_priority > int(ACTION_PRIORITY.get(&"attack", 20)):
				_pending_attack_serial = attack_serial
			else:
				_play_attack(attack_serial)
	# 控制恢复后的 play_section 在部分 AnimationPlayer 时序下会先清空
	# current_animation，再错过 animation_finished 回调；权威动作窗口已结束且
	# 播放器已停止时，必须主动交还给基础状态，不能把最后一帧出拳姿态留住。
	if _playing_visual_action and _source.get_visual_action_time_left() <= 0.0 and not _animation_player.is_playing():
		_finish_visual_action()
	var state := _source.get_visual_state_code()
	var locomotion_state := _source.get_locomotion_visual_state_code()
	var empowered_ready := _source.is_empowered_attack_ready_visual()
	if empowered_ready != _last_empowered_ready:
		_last_empowered_ready = empowered_ready
		# 强化或循环被动就绪时，同步基础姿态；只换表现，不改位移。
		if not _playing_visual_action and not _playing_attack and locomotion_state in [1, 2]:
			_transition_to_basic_state(locomotion_state, _transition_blend(&"locomotion"))
	var haste_active := _source.get_active_speed_multiplier_visual() > 1.001
	if haste_active != _last_haste_active:
		_last_haste_active = haste_active
		if not _playing_visual_action and not _playing_attack and locomotion_state == 2:
			_transition_to_basic_state(2, _transition_blend(&"locomotion"))
	# 出场演出：单位生成首帧启动序列；部署结束后让位给基础状态机。
	_update_deploy_sequence_lifecycle()
	# 出场技能序列在部署锁定期间保持动作，不被其他状态打断。
	if _playing_visual_action:
		pass
	elif _playing_deploy_sequence:
		pass
	# 龙王等持续攻击单位用状态区分移动/攻击，并用目标序号识别“原地换目标”。
	# 两种进入动作最终都接循环吐息，退出攻击则在同一帧打断循环。
	elif _uses_continuous_state_animations():
		_sync_continuous_state_animations(state, force, attack_serial_changed)
	# attack_serial 只触发一次挥剑；逻辑仍处于攻击状态时，动作结束后保持末帧。
	# 只有失去目标或开始移动，才从当前攻击姿态混合回对应的基础状态。
	elif state != 3 and (_playing_attack or _holding_attack_pose):
		_playing_attack = false
		_holding_attack_pose = false
		_attack_hit_pending = false
		_attack_recover_pending = false
		_active_attack_animation = &""
		_transition_to_basic_state(locomotion_state, _transition_blend(&"action_out"), &"attack")
	elif state != 3 and not _playing_attack and (force or state != _current_state):
		_transition_to_basic_state(locomotion_state)
	elif state == 3 and not _playing_attack and not _holding_attack_pose and force:
		_current_state = 1
		_play_state(1)
	if _animation_player != null:
		var playback_scale := _state.attack_rate if _playing_attack else (_state.movement_rate if _current_state == 2 and not _playing_visual_action else 1.0)
		_animation_player.speed_scale = 0.0 if _state.frozen else playback_scale

func _play_visual_action(action_name: StringName, preserve_visual_pose: bool = false) -> void:
	_idle_transition_animation = &""
	if action_name == &"":
		if _control_stage != &"":
			_invalidate_control_restore()
		_clear_visual_action_state()
		return
	if _animation_player == null:
		return
	var actions: Dictionary = _animation_names.get("visual_actions", {})
	var configured = actions.get(String(action_name), [])
	var descriptor: Dictionary = configured if configured is Dictionary else {}
	var action_kind := StringName(descriptor.get("kind", _default_action_kind(action_name)))
	var action_priority := int(descriptor.get("priority", ACTION_PRIORITY.get(action_kind, ACTION_PRIORITY.get(&"skill", 40))))
	# 新事件只有达到当前覆盖动作的优先级才可打断；death 走独立最高优先级入口。
	if _playing_visual_action and action_priority < _active_action_priority:
		return
	if not descriptor.is_empty():
		configured = descriptor.get("animation", [])
	var candidates: Array = configured if configured is Array else [configured]
	var action_durations: Dictionary = _animation_names.get("visual_action_durations", {})
	var configured_durations = descriptor.get("durations", action_durations.get(String(action_name), []))
	var duration_candidates: Array = configured_durations if configured_durations is Array else [configured_durations]
	var configured_ranges = descriptor.get("clip_ranges", [])
	var range_candidates: Array = configured_ranges if configured_ranges is Array else []
	var lengths := {}
	for candidate in candidates:
		var animation_name := StringName(candidate)
		if animation_name != &"" and _animation_player.has_animation(animation_name):
			var animation := _animation_player.get_animation(animation_name)
			if animation != null: lengths[animation_name] = animation.length
	var authoritative_duration := _source.get_visual_action_duration()
	if not _action_sequence.configure(candidates, duration_candidates, range_candidates, lengths, authoritative_duration):
		return
	_playing_visual_action = true
	_active_action_name = action_name
	_active_action_kind = action_kind
	_active_action_priority = action_priority
	_active_action_blend_in = float(descriptor.get("blend_in", -1.0))
	_active_action_blend_out = float(descriptor.get("blend_out", -1.0))
	_active_action_sequence_blend = float(descriptor.get("sequence_blend", -1.0))
	if preserve_visual_pose:
		_invalidate_control_restore()
	_playing_attack = false
	_holding_attack_pose = false
	_attack_hit_pending = false
	_attack_recover_pending = false
	_move_sequence_active = false
	_move_active_animation = &""
	if not preserve_visual_pose:
		_play_visual_action_clip(StringName(_action_sequence.current().name))
	# 晚到客户端从权威时间轴对应位置开始，不会把已过去的 Spell2 从头补播。
	if not preserve_visual_pose and authoritative_duration > 0.001:
		_seek_visual_action(maxf(authoritative_duration - _source.get_visual_action_time_left(), 0.0))

func _play_visual_action_clip(animation_name: StringName) -> void:
	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		return
	animation.loop_mode = Animation.LOOP_NONE
	_active_visual_action = animation_name
	var clip := _action_sequence.current()
	var clip_range: Vector2 = clip.range
	var playback_speed: float = clip.speed
	_current_clip_speed = playback_speed
	_set_model_visual_clip(animation_name)
	var first_clip := _action_sequence.index == 0
	var blend_override := _active_action_blend_in if first_clip else _active_action_sequence_blend
	var transition_kind := &"action_in" if first_clip else &"sequence"
	var blend_time := _resolve_clip_blend(animation_name, transition_kind, blend_override)
	_last_clip_transition_kind = transition_kind
	_last_clip_blend_time = blend_time
	_animation_player.play_section(animation_name, clip_range.x, clip_range.y, blend_time, playback_speed)

func _seek_visual_action(elapsed: float) -> void:
	if _action_sequence.current().is_empty():
		return
	# elapsed==0 也要通过序列求值；clip_ranges 的起点可能不是素材零秒。
	var position := _action_sequence.seek(maxf(elapsed, 0.0))
	var clip_name := StringName(_action_sequence.current().name)
	if _active_visual_action != clip_name:
		_play_visual_action_clip(clip_name)
	_animation_player.seek(position, true)

func _clear_visual_action_state() -> void:
	# 取消只清理动作所有权与续播资格，保留当前 AnimationPlayer 姿势；控制覆盖
	# 会继续暂停它，之后由基础状态通道决定自然衔接。
	_playing_visual_action = false
	_active_visual_action = &""
	_action_sequence.clear()
	_active_action_name = &""
	_active_action_kind = &"locomotion"
	_active_action_priority = 0
	_active_action_blend_in = -1.0
	_active_action_blend_out = -1.0
	_active_action_sequence_blend = -1.0
	_pending_attack_serial = 0
	_move_sequence_active = false
	_move_active_animation = &""
	_playing_attack = false
	_holding_attack_pose = false
	_attack_hit_pending = false
	_attack_recover_pending = false

func _invalidate_control_restore() -> void:
	_saved_control_clip = &""
	_saved_control_position = 0.0
	_saved_control_speed = 1.0
	_saved_control_section = Vector2(-1.0, -1.0)
	_saved_control_loop_mode = Animation.LOOP_NONE
	_saved_control_action_serial = -1
	_saved_control_action_name = &""
	_saved_control_attack_serial = -1
	_saved_control_state = -1
	_saved_control_locomotion_state = -1

func _default_action_kind(action_name: StringName) -> StringName:
	return &"transform" if String(action_name).contains("transform") or action_name == &"revert" else &"skill"

func _set_model_visual_clip(animation_name: StringName) -> void:
	if _model_root != null and _model_root.has_method("set_visual_clip"):
		_model_root.call("set_visual_clip", animation_name)

## 所有 AnimationPlayer 切换都经过这一层：Godot 会从当前任意播放进度的骨骼 Pose
## crossfade 到目标片段，不再假设源末帧与目标首帧天然一致。
func _play_clip(animation_name: StringName, transition_kind: StringName = &"default", playback_speed: float = 1.0, blend_override: float = -1.0) -> void:
	_current_clip_speed = playback_speed
	if _animation_player == null or animation_name == &"" or not _animation_player.has_animation(animation_name):
		return
	var blend_time := _resolve_clip_blend(animation_name, transition_kind, blend_override)
	_last_clip_transition_kind = transition_kind
	_last_clip_blend_time = blend_time
	_animation_player.play(animation_name, blend_time, playback_speed)

## 原始片段对的例外覆盖通用策略；目标通配只用于已核验的一组入口。
func _resolve_clip_blend(target: StringName, kind: StringName, fallback: float = -1.0) -> float:
	var blends: Dictionary = _animation_names.get("clip_blends", {})
	var source := _animation_player.assigned_animation
	var edge := "%s>%s" % [source, target]
	if blends.has(edge):
		return float(blends[edge])
	var target_edge := "*>%s" % target
	if blends.has(target_edge):
		return float(blends[target_edge])
	return _transition_blend(kind) if fallback < 0.0 else maxf(fallback, 0.0)

func _transition_blend(transition_kind: StringName) -> float:
	var configured: Dictionary = _animation_names.get("transition_blends", {})
	return maxf(float(configured.get(transition_kind, TRANSITION_DEFAULTS.get(transition_kind, TRANSITION_DEFAULTS.get(&"default", 0.08)))), 0.0)

## 专门制作的 transition clip 优先；没有配置时调用方直接走通用 Pose crossfade。
func _transition_clip(from_action: StringName, to_action: StringName) -> StringName:
	var configured = _transition_config(from_action, to_action)
	if configured is Dictionary:
		configured = (configured as Dictionary).get("animation", "")
	var candidates: Array = configured if configured is Array else [configured]
	for candidate in candidates:
		var animation_name := StringName(candidate)
		if animation_name != &"" and _animation_player.has_animation(animation_name):
			return animation_name
	return &""

func _transition_config(from_action: StringName, to_action: StringName) -> Variant:
	var transitions: Dictionary = _animation_names.get("transitions", {})
	var clip_edge := "%s>%s" % [_animation_player.assigned_animation, to_action]
	return transitions.get(clip_edge, transitions.get("%s>%s" % [from_action, to_action], ""))

## 单条 transitions route 可只覆盖两条素材边界；未配置的边继续使用全局 sequence。
func _transition_route_blend(from_action: StringName, to_action: StringName, edge: StringName) -> float:
	var configured = _transition_config(from_action, to_action)
	if not configured is Dictionary or not (configured as Dictionary).has(edge):
		return -1.0
	return maxf(float((configured as Dictionary)[edge]), 0.0)

## 普通单位也可配置 move_enter。过渡动作只表现移动起步，移动仍由权威模拟决定。
func _transition_to_basic_state(state: int, blend_time: float = -1.0, from_action: StringName = &"locomotion") -> void:
	_idle_transition_animation = &""
	var previous_state := _current_state
	_current_state = state
	_move_sequence_active = false
	_move_active_animation = &""
	if state == 2:
		var route_from := from_action
		if from_action == &"locomotion":
			if previous_state == 0:
				route_from = &"deploy"
			elif previous_state == 3:
				route_from = &"attack"
			elif previous_state == 2:
				route_from = &"move"
			else:
				route_from = &"idle"
		_start_move_sequence(route_from, blend_time)
	elif state == 1 and _transition_clip(from_action, &"idle") != &"":
		_idle_transition_animation = _transition_clip(from_action, &"idle")
		var entry_blend := _transition_route_blend(from_action, &"idle", &"blend_in")
		_idle_transition_exit_blend = _transition_route_blend(from_action, &"idle", &"blend_out")
		var start_time := maxf(_transition_route_blend(from_action, &"idle", &"start_time"), 0.0)
		_animation_player.get_animation(_idle_transition_animation).loop_mode = Animation.LOOP_NONE
		_play_clip(_idle_transition_animation, &"sequence", 1.0, entry_blend)
		_animation_player.seek(start_time, true)
	else:
		_play_state(state, _transition_blend(&"locomotion") if blend_time < 0.0 else blend_time)

func _uses_continuous_state_animations() -> bool:
	return String(_animation_names.get("attack_loop", "")) != ""

func _sync_continuous_state_animations(state: int, force: bool, target_changed: bool) -> void:
	if not force and state == _current_state and not (state == 3 and target_changed):
		return
	var previous_state := _current_state
	var retargeting_without_move := state == 3 and previous_state == 3 and target_changed
	_current_state = state
	_source.set_continuous_beam_visible(false)
	_continuous_attack_active = false
	_continuous_attack_animation = &""
	_continuous_attack_sequence.clear()
	_move_sequence_active = false
	_move_active_animation = &""
	match state:
		3:
			_start_continuous_attack(retargeting_without_move)
		2:
			_start_move_sequence(&"attack" if previous_state == 3 else &"locomotion")
		_:
			# 立即关闭持续攻击，再按实际源片段接收势；不等待吐息循环结束。
			_transition_to_basic_state(state, _transition_blend(&"locomotion") if force else _transition_blend(&"action_out"), &"attack" if previous_state == 3 else &"locomotion")

func _start_continuous_attack(retargeting_without_move: bool = false, blend_override: float = -1.0) -> void:
	if _animation_player == null:
		return
	# 权威攻击进入范围即开始；光柱在所有进入/换目标/循环动画中持续显示。
	_source.set_continuous_beam_visible(true)
	_continuous_attack_active = true
	var enter_key := "attack_retarget_enter" if retargeting_without_move else "attack_enter"
	var configured = _animation_names.get(enter_key, _animation_names.get("attack_enter", ""))
	var candidates: Array = configured if configured is Array else [configured]
	_continuous_attack_sequence.clear()
	for candidate in candidates:
		var enter_name := StringName(candidate)
		if enter_name != &"" and _animation_player.has_animation(enter_name):
			_continuous_attack_sequence.append(enter_name)
	_continuous_attack_sequence_index = 0
	if not _continuous_attack_sequence.is_empty():
		_play_continuous_attack_enter(
			StringName(_continuous_attack_sequence[0]),
			&"sequence" if retargeting_without_move else &"action_in",
			blend_override
		)
		return
	_play_continuous_attack_loop(&"sequence" if retargeting_without_move else &"action_in", blend_override)

func _play_continuous_attack_enter(animation_name: StringName, transition_kind: StringName = &"sequence", blend_override: float = -1.0) -> void:
	var enter_animation := _animation_player.get_animation(animation_name)
	if enter_animation == null:
		return
	enter_animation.loop_mode = Animation.LOOP_NONE
	_continuous_attack_animation = animation_name
	_play_clip(animation_name, transition_kind, 1.0, blend_override)

func _play_continuous_attack_loop(transition_kind: StringName = &"sequence", blend_override: float = -1.0) -> void:
	if _animation_player == null or not _continuous_attack_active or _current_state != 3:
		return
	var loop_name := StringName(_animation_names.get("attack_loop", ""))
	if loop_name == &"" or not _animation_player.has_animation(loop_name):
		return
	var loop_animation := _animation_player.get_animation(loop_name)
	if loop_animation != null:
		loop_animation.loop_mode = Animation.LOOP_LINEAR
	_continuous_attack_animation = loop_name
	_play_clip(loop_name, transition_kind, 1.0, blend_override)
	_source.set_continuous_beam_visible(true)

## Move route 分为两类且互斥：技能/特殊动作专用 ToRun 直接接 Run；否则部署、Idle、
## 普攻可复用通用 RunIn/IntoRun。只要 route 含作者制作的 transition，首尾都用 sequence；
## 完全没有 transition 时才让 action_out generic crossfade 承担完整姿态转换。
func _start_move_sequence(from_action: StringName = &"locomotion", blend_override: float = -1.0) -> void:
	if _animation_player == null:
		return
	_move_sequence.clear()
	_move_sequence_exit_blend = -1.0
	_move_override_animation = _move_animation_for_route(from_action)
	var dedicated_transition := &""
	var route_transition_used := false
	if from_action == &"attack" and _active_attack_empowered:
		dedicated_transition = _first_valid_animation("empowered_attack_to_move")
	if dedicated_transition == &"":
		dedicated_transition = _transition_clip(from_action, &"move")
		route_transition_used = dedicated_transition != &""
	if dedicated_transition != &"":
		_move_sequence.append(dedicated_transition)
	# 没有整条 attack>move 路由时，按当前攻击段选取 attack_to_move。
	elif from_action == &"attack":
		var indexed_transition := _indexed_animation("attack_to_move", _active_attack_index)
		if indexed_transition != &"":
			dedicated_transition = indexed_transition
			_move_sequence.append(indexed_transition)
	# 专用 ToRun 已经完成动作到跑步的完整转换，不能再在其后重复串通用 RunIn。
	# 通用 RunIn/IntoRun 只覆盖部署、Idle、普通攻击到移动。
	var use_generic_move_enter := dedicated_transition == &"" and from_action in [&"deploy", &"idle", &"locomotion", &"attack"]
	if use_generic_move_enter:
		_append_valid_animations(_move_sequence, "move_enter")
	_move_cycle.clear()
	_append_valid_animations(_move_cycle, "move_cycle")
	_move_sequence_index = 0
	_move_cycle_index = 0
	_move_sequence_active = not _move_sequence.is_empty() or not _move_cycle.is_empty()
	var has_transition_clip := not _move_sequence.is_empty()
	var route_entry_blend := _transition_route_blend(from_action, &"move", &"blend_in") if route_transition_used else -1.0
	if route_transition_used:
		_move_sequence_exit_blend = _transition_route_blend(from_action, &"move", &"blend_out")
	var entry_blend := route_entry_blend if route_entry_blend >= 0.0 else _move_route_entry_blend(from_action, has_transition_clip, blend_override)
	var start_time := maxf(_transition_route_blend(from_action, &"move", &"start_time"), 0.0) if route_transition_used else 0.0
	if not _move_sequence.is_empty():
		_play_move_clip(StringName(_move_sequence[0]), entry_blend)
		if start_time > 0.0:
			_animation_player.seek(start_time, true)
	elif not _move_cycle.is_empty():
		_play_move_cycle_clip(entry_blend)
	else:
		_play_state(2, entry_blend)

func _move_route_entry_blend(from_action: StringName, has_transition_clip: bool, blend_override: float) -> float:
	if has_transition_clip:
		return _transition_blend(&"sequence")
	if blend_override >= 0.0:
		return maxf(blend_override, 0.0)
	if from_action in [&"attack", &"skill", &"deploy", &"transform"]:
		return _transition_blend(&"action_out")
	return _transition_blend(&"locomotion")

func _move_animation_for_route(from_action: StringName) -> StringName:
	if _source.get_attack_visual_serial() == 0 and maxi(_source.form_change_serial, _source.net_form_change_serial) == 0:
		var initial_move := _first_valid_animation("initial_move")
		if initial_move != &"":
			return initial_move
	if _source.get_active_speed_multiplier_visual() > 1.001:
		var haste_move := _first_valid_animation("haste_move")
		if haste_move != &"":
			return haste_move
	if _source.is_empowered_attack_ready_visual():
		var empowered_move := _first_valid_animation("empowered_move")
		if empowered_move != &"":
			return empowered_move
	if from_action == &"attack" and not _active_attack_empowered:
		var routed_move := _indexed_animation("attack_move", _active_attack_index)
		if routed_move != &"":
			return routed_move
	return &""

func _indexed_animation(key: String, index: int) -> StringName:
	var values := _animation_list(key)
	if values.is_empty():
		return &""
	var candidate := StringName(values[index % values.size()])
	return candidate if candidate != &"" and _animation_player.has_animation(candidate) else &""

func _first_valid_animation(key: String) -> StringName:
	for value in _animation_list(key):
		var candidate := StringName(value)
		if candidate != &"" and _animation_player.has_animation(candidate):
			return candidate
	return &""

func _append_valid_animations(target: Array, key: String) -> void:
	for value in _animation_list(key):
		var animation_name := StringName(value)
		if animation_name != &"" and _animation_player.has_animation(animation_name):
			target.append(animation_name)

func _play_move_clip(animation_name: StringName, blend_override: float = -1.0) -> void:
	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		return
	animation.loop_mode = Animation.LOOP_NONE
	_move_active_animation = animation_name
	_set_model_visual_clip(animation_name)
	_play_clip(animation_name, &"sequence", 1.0, blend_override)

func _play_move_cycle_clip(blend_override: float = -1.0) -> void:
	if _move_cycle.is_empty() or _current_state != 2:
		return
	_play_move_clip(StringName(_move_cycle[_move_cycle_index]), blend_override)

func _advance_move_sequence() -> void:
	if _move_sequence_index < _move_sequence.size():
		_move_sequence_index += 1
		if _move_sequence_index < _move_sequence.size():
			_play_move_clip(StringName(_move_sequence[_move_sequence_index]))
			return
	var exit_blend := _move_sequence_exit_blend if _move_sequence_exit_blend >= 0.0 else _transition_blend(&"sequence")
	_move_sequence_exit_blend = -1.0
	if _move_cycle.is_empty():
		_move_sequence_active = false
		_play_state(2, exit_blend)
		return
	_move_cycle_index = 0
	_play_move_cycle_clip(exit_blend)

func _advance_move_cycle() -> void:
	if _move_cycle.is_empty():
		return
	_move_cycle_index = (_move_cycle_index + 1) % _move_cycle.size()
	_play_move_cycle_clip()

func _screen_to_ground(screen_position: Vector2) -> Vector3:
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return Vector3.ZERO
	return origin + direction * (-origin.y / direction.y)


## 不依赖素材原点：读取全部网格的实际底部，再整体平移包装根节点到统一空军高度。
func _align_air_visual_elevation() -> void:
	var current_bottom := _visual_bounds_bottom_y()
	if not is_finite(current_bottom):
		return
	_model_root.position.y += CardDB.AIR_VISUAL_ELEVATION - current_bottom


func _visual_bounds_bottom_y() -> float:
	if _model_root == null or not is_instance_valid(_model_root):
		return INF
	var bottom := INF
	for node in _model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var bounds := mesh_instance.get_aabb()
		for corner_index in range(8):
			var corner := Vector3(
				bounds.position.x + bounds.size.x * float(corner_index & 1),
				bounds.position.y + bounds.size.y * float((corner_index >> 1) & 1),
				bounds.position.z + bounds.size.z * float((corner_index >> 2) & 1)
			)
			bottom = minf(bottom, to_local(mesh_instance.to_global(corner)).y)
	return bottom

## 用包装场景中全部网格的实际投影顶部定位血条；模型缩放或脚底校正后无需再手填像素偏移。
func _update_health_bar_anchor() -> void:
	if _source == null or _camera == null or not _model_resources.has_meshes():
		return
	var ground_screen := _camera.unproject_position(global_position)
	# 建筑等横向展开模型可由包装场景提供稳定的 3D 顶端锚点；仍只影响 UI 投影。
	if _model_root != null and _model_root.has_method("get_health_bar_anchor_local"):
		var local_anchor = _model_root.call("get_health_bar_anchor_local")
		if local_anchor is Vector3:
			var world_anchor := _model_root.to_global(local_anchor as Vector3)
			if not _camera.is_position_behind(world_anchor):
				var anchor_screen := _camera.unproject_position(world_anchor)
				_source.set_visual_head_world_position(Vector2(ground_screen.x, anchor_screen.y))
				return
	var anchor_node := _model_root.get_node_or_null("HeadAnchor") as Node3D
	if anchor_node != null:
		_source.set_visual_head_world_position(Vector2(ground_screen.x, _camera.unproject_position(anchor_node.global_position).y))
		return
	if not is_nan(_stable_head_offset):
		_source.set_visual_head_world_position(Vector2(ground_screen.x, ground_screen.y + _stable_head_offset))
		return
	var screen_sign := -1.0 if bool(_camera.get_meta("canvas_flipped", false)) else 1.0
	var top_screen_y := ground_screen.y * screen_sign
	var found_visible_point := false
	for mesh_instance in _model_resources.meshes():
		if mesh_instance == null or not is_instance_valid(mesh_instance):
			continue
		var bounds := mesh_instance.get_aabb()
		for corner_index in range(8):
			var corner := Vector3(
				bounds.position.x + bounds.size.x * float(corner_index & 1),
				bounds.position.y + bounds.size.y * float((corner_index >> 1) & 1),
				bounds.position.z + bounds.size.z * float((corner_index >> 2) & 1)
			)
			var world_corner := mesh_instance.to_global(corner)
			if _camera.is_position_behind(world_corner):
				continue
			top_screen_y = minf(top_screen_y, _camera.unproject_position(world_corner).y * screen_sign)
			found_visible_point = true
	if found_visible_point:
		# 武器/披风等网格也在 AABB 内，直接取最顶点会把血条拉离头部；
		# 以体型半径给人物头顶设合理上限。空军从统一离地平面而非权威地面计算，
		# 让血条随模型一起上移，同时避免红蓝朝向或动作造成大幅漂移。
		var max_head_height := _source.visual_radius * 3.25
		var visual_base_screen_y := ground_screen.y * screen_sign
		if _source.is_air:
			var air_base_world := global_position + Vector3.UP * CardDB.AIR_VISUAL_ELEVATION
			if not _camera.is_position_behind(air_base_world):
				visual_base_screen_y = _camera.unproject_position(air_base_world).y * screen_sign
		top_screen_y = maxf(top_screen_y, visual_base_screen_y - max_head_height)
		_stable_head_offset = top_screen_y * screen_sign - ground_screen.y
		_source.set_visual_head_world_position(Vector2(ground_screen.x, top_screen_y * screen_sign))

func _play_state(state: int, blend_time: float = -1.0) -> void:
	_idle_transition_animation = &""
	if _animation_player == null:
		return
	if state == 1 and not _animation_list("idle_cycle").is_empty():
		_start_idle_cycle(true, blend_time)
		return
	if state != 1:
		_idle_cycle_active_animation = &""
	var key: StringName = STATE_KEYS[clampi(state, 0, STATE_KEYS.size() - 1)]
	if state != 2:
		_move_override_animation = &""
	var configured = _move_override_animation if state == 2 and _move_override_animation != &"" else _animation_names.get(String(key), "")
	if state == 1 and _source.is_empowered_attack_ready_visual():
		var empowered_idle := _first_valid_animation("empowered_idle")
		if empowered_idle != &"":
			configured = empowered_idle
	if state == 2 and _source.get_active_speed_multiplier_visual() > 1.001:
		var haste_move := _first_valid_animation("haste_move")
		if haste_move != &"":
			configured = haste_move
	# deploy 配置为数组时由部署序列生命周期单独处理。
	if configured is Array:
		configured = ""
	var animation_name := StringName(configured)
	if animation_name == &"" or not _animation_player.has_animation(animation_name):
		animation_name = StringName(_animation_names.get("idle", ""))
	if animation_name != &"" and _animation_player.has_animation(animation_name):
		var playback_speed := _state_playback_speed(state, animation_name)
		_set_model_visual_clip(animation_name)
		_play_clip(animation_name, &"locomotion", playback_speed, _transition_blend(&"locomotion") if blend_time < 0.0 else blend_time)

func _start_idle_cycle(reset_index: bool, blend_time: float = -1.0) -> void:
	var configured := _animation_list("idle_cycle")
	if configured.is_empty():
		return
	if reset_index:
		_idle_cycle_index = 0
	else:
		_idle_cycle_index = (_idle_cycle_index + 1) % configured.size()
	var animation_name := StringName(configured[_idle_cycle_index])
	if animation_name == &"" or not _animation_player.has_animation(animation_name):
		return
	_idle_cycle_active_animation = animation_name
	var animation := _animation_player.get_animation(animation_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_NONE
	_set_model_visual_clip(animation_name)
	var resolved_blend := _transition_blend(&"sequence") if blend_time < 0.0 else blend_time
	_play_clip(animation_name, &"locomotion", 1.0, resolved_blend)

## 出场演出生命周期：生成首帧启动序列；权威部署计时耗尽时终止序列。
func _update_deploy_sequence_lifecycle() -> void:
	if _dying or _source == null:
		return
	var deploy_names = _animation_names.get("deploy", "")
	var has_sequence: bool = deploy_names is Array and not (deploy_names as Array).is_empty()
	var deploying := _source._deploy_timer > 0.0
	if has_sequence and deploying and not _deploy_sequence_started and not _source.cancelled_deployment:
		_deploy_sequence_started = true
		_start_deploy_sequence(deploy_names as Array)
	# 权威部署已结束（解锁移动/攻击）而序列尚未播完：立即让位给基础状态机。
	if _playing_deploy_sequence and not deploying:
		_finish_deploy_sequence()

## 出场技能序列只影响表现：优先按 deploy_durations 逐段缩放播放，
## 没有逐段配置时才按权威部署总时长统一缩放。视觉序列不参与权威效果结算。
func _start_deploy_sequence(names: Array) -> void:
	_playing_deploy_sequence = true
	_deploy_sequence = names
	_deploy_sequence_index = 0
	_current_state = 0
	var total_length := 0.0
	var clip_lengths: Array = []
	for value in names:
		var clip := StringName(value)
		var clip_length := 0.0
		if clip != &"" and _animation_player != null and _animation_player.has_animation(clip):
			var animation := _animation_player.get_animation(clip)
			if animation != null:
				clip_length = animation.length
		total_length += clip_length
		clip_lengths.append(clip_length)
	_deploy_sequence_speeds.clear()
	var configured_durations = _animation_names.get("deploy_durations", [])
	for index in names.size():
		var target_duration := 0.0
		if configured_durations is Array and index < (configured_durations as Array).size():
			target_duration = maxf(float((configured_durations as Array)[index]), 0.0)
		var playback_speed := 1.0
		if target_duration > 0.001 and float(clip_lengths[index]) > 0.001:
			playback_speed = float(clip_lengths[index]) / target_duration
		elif total_length > 0.001 and _source.deploy_time > 0.001:
			playback_speed = total_length / _source.deploy_time
		_deploy_sequence_speeds.append(playback_speed)
	_play_deploy_clip(StringName(names[0]))

func _play_deploy_clip(animation_name: StringName) -> void:
	if animation_name == &"" or not _animation_player.has_animation(animation_name):
		return
	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		return
	animation.loop_mode = Animation.LOOP_NONE
	_deploy_active_animation = animation_name
	var playback_speed := 1.0
	if _deploy_sequence_index < _deploy_sequence_speeds.size():
		playback_speed = float(_deploy_sequence_speeds[_deploy_sequence_index])
	_play_clip(animation_name, &"sequence", playback_speed)

func _advance_deploy_sequence() -> void:
	_deploy_sequence_index += 1
	if _deploy_sequence_index < _deploy_sequence.size():
		_play_deploy_clip(StringName(_deploy_sequence[_deploy_sequence_index]))
		return
	_finish_deploy_sequence()

## 终止出场演出：交还基础状态机，按当前权威状态混合回 Idle/Move/Attack。
func _finish_deploy_sequence() -> void:
	_playing_deploy_sequence = false
	_deploy_active_animation = &""
	var state := _source.get_visual_state_code()
	var locomotion_state := _source.get_locomotion_visual_state_code()
	_current_state = 0
	if state != 0:
		if state == 3 and _pending_attack_serial > 0:
			var pending_serial := _pending_attack_serial
			_pending_attack_serial = 0
			_play_attack(pending_serial)
		else:
			_transition_to_basic_state(locomotion_state, _transition_blend(&"action_out"), &"deploy")

func _play_attack(serial: int, blend_override: float = -1.0) -> void:
	if _animation_player == null or serial <= 0:
		return
	_idle_cycle_active_animation = &""
	_idle_transition_animation = &""
	# 出场演出期间权威锁定攻击，不会推进攻击序号；此防御仅兜底客户端快照乱序。
	if _playing_deploy_sequence:
		_pending_attack_serial = serial
		return
	if _playing_visual_action and _active_action_priority > int(ACTION_PRIORITY.get(&"attack", 20)):
		_pending_attack_serial = serial
		return
	var entry_transition_kind := &"sequence" if _current_state == 3 else &"action_in"
	_active_attack_empowered = serial == _source.get_empowered_attack_visual_serial()
	var attack_key := "empowered_attack" if _active_attack_empowered else ("attack_structure" if _source.is_attacking_structure_visual() else "attack")
	var configured = _animation_names.get(attack_key, _animation_names.get("attack", []))
	var attacks: Array = configured if configured is Array else [configured]
	if attacks.is_empty():
		return
	_active_attack_index = 0 if _active_attack_empowered else (serial - 1) % attacks.size()
	var animation_name := StringName(attacks[_active_attack_index])
	if animation_name == &"" or not _animation_player.has_animation(animation_name):
		return
	_attack_hit_pending = false
	_attack_recover_pending = false
	_attack_hit_timer = 0.0
	_attack_recover_timer = 0.0
	_active_attack_animation = animation_name
	_playing_attack = true
	_holding_attack_pose = false
	_move_sequence_active = false
	_move_active_animation = &""
	_move_override_animation = &""
	_current_state = 3
	var hit_animations := _active_attack_animation_list("attack_hit")
	if _active_attack_index < hit_animations.size() and StringName(hit_animations[_active_attack_index]) != &"":
		# 分段普攻只影响表现：Start 在权威 first_hit 窗口内播放，计时到点切到 Hit。
		_attack_hit_pending = true
		_attack_hit_timer = maxf(_source.get_attack_first_hit_time_visual(), 0.01)
		_play_attack_clip(animation_name, _attack_hit_timer, entry_transition_kind, blend_override, _attack_section("attack_clip_ranges"))
	else:
		_play_attack_clip(animation_name, _attack_duration, entry_transition_kind, blend_override, _attack_section("attack_clip_ranges"))
	_align_attack_progress(_state.attack_elapsed)

func _update_attack_stages(delta: float) -> void:
	if not _playing_attack or _animation_player == null:
		return
	# 权威状态已离开 Attack 时不要在同一渲染帧补播收势；否则刚命中且无目标的
	# 瑟提会先闪过 Into_Idle，再被 _sync_visual 切到移动。
	var state := _source.get_visual_state_code()
	if state != 3 and _source.attack_recovery_cancel_every_hits > 0:
		return
	# 冰冻期间模拟攻击计时不推进，分段表现计时也必须同步暂停。
	if _state.frozen or _state.stunned:
		return
	delta *= _state.attack_rate
	if _attack_hit_pending:
		var consumed := minf(_attack_hit_timer, delta)
		_attack_hit_timer -= consumed
		delta -= consumed
		if _attack_hit_timer <= 0.0:
			_attack_hit_pending = false
			var hit_animations := _active_attack_animation_list("attack_hit")
			if _active_attack_index < hit_animations.size():
				var hit_name := StringName(hit_animations[_active_attack_index])
				var recover_animations := _active_attack_animation_list("attack_recover")
				var recover_name := &""
				if _active_attack_index < recover_animations.size():
					recover_name = StringName(recover_animations[_active_attack_index])
				var recover_delay := _attack_recover_delay(_active_attack_index)
				_play_attack_clip(hit_name, recover_delay if recover_name != &"" else _attack_hit_duration(_active_attack_index), &"sequence", -1.0, _attack_section("attack_hit_clip_ranges"))
				if recover_name != &"":
					_attack_recover_pending = true
					_attack_recover_timer = recover_delay
		else:
			return
	if _attack_recover_pending:
		_attack_recover_timer = maxf(0.0, _attack_recover_timer - delta)
		if _attack_recover_timer <= 0.0:
			_attack_recover_pending = false
			var recover_animations := _active_attack_animation_list("attack_recover")
			if _active_attack_index < recover_animations.size():
				_play_attack_clip(StringName(recover_animations[_active_attack_index]), 0.0)

func _attack_section(key: String) -> Vector2:
	var ranges: Array = _animation_names.get(key, [])
	if _active_attack_empowered or _active_attack_index >= ranges.size() or ranges[_active_attack_index].size() != 2:
		return Vector2(-1.0, -1.0)
	return Vector2(float(ranges[_active_attack_index][0]), float(ranges[_active_attack_index][1]))

func _play_attack_clip(animation_name: StringName, target_duration: float, transition_kind: StringName = &"sequence", blend_override: float = -1.0, section: Vector2 = Vector2(-1.0, -1.0)) -> void:
	if animation_name == &"" or not _animation_player.has_animation(animation_name):
		return
	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		return
	animation.loop_mode = Animation.LOOP_NONE
	_attack_clip_start = maxf(section.x, 0.0)
	_attack_clip_end = minf(section.y, animation.length) if section.y > 0.0 else animation.length
	var playback_speed := 1.0 / _attack_reference_time_scale()
	if target_duration > 0.001:
		playback_speed = maxf((_attack_clip_end - _attack_clip_start) / target_duration, 0.01)
	_active_attack_animation = animation_name
	_set_model_visual_clip(animation_name)
	if section.x >= 0.0:
		_current_clip_speed = playback_speed
		var blend := _resolve_clip_blend(animation_name, transition_kind, blend_override)
		_last_clip_transition_kind = transition_kind
		_last_clip_blend_time = blend
		_animation_player.play_section(animation_name, _attack_clip_start, _attack_clip_end, blend, playback_speed)
		_animation_player.seek(_attack_clip_start, true)
	else:
		_play_clip(animation_name, transition_kind, playback_speed, blend_override)

func _animation_list(key: String) -> Array:
	var configured = _animation_names.get(key, [])
	return configured if configured is Array else [configured]

func _active_attack_animation_list(base_key: String) -> Array:
	if _active_attack_empowered:
		var empowered_key := "empowered_%s" % base_key
		if _animation_names.has(empowered_key):
			return _animation_list(empowered_key)
	return _animation_list(base_key)

func _attack_recover_delay(index: int) -> float:
	if _animation_names.has("attack_reference_interval"):
		return _reference_hit_duration(index)
	var configured = _animation_names.get("attack_recover_delay", 0.3)
	if configured is Array:
		var values := configured as Array
		if not values.is_empty():
			return maxf(float(values[index % values.size()]), 0.01)
	return maxf(float(configured), 0.01)

func _attack_hit_duration(index: int) -> float:
	if _animation_names.has("attack_reference_interval") and not _active_attack_empowered:
		return _reference_hit_duration(index)
	# 强化攻击的专用后摇默认按素材原速播放，允许下一次普攻或移动在任意进度打断。
	if _active_attack_empowered and not _animation_names.has("empowered_attack_hit_duration"):
		return 0.0
	var configured = _animation_names.get("attack_hit_duration", _attack_duration)
	if configured is Array:
		var values := configured as Array
		if not values.is_empty():
			return maxf(float(values[index % values.size()]), 0.01)
	return maxf(float(configured), 0.01)

## 参考攻速下保留 Hit/Recover 的素材时长；基础数值变化与局内 Buff 分开缩放。
func _attack_reference_time_scale() -> float:
	var reference := float(_animation_names.get("attack_reference_interval", 0.0))
	return _source.attack_interval / reference if reference > 0.0 else 1.0

func _reference_hit_duration(index: int) -> float:
	var hits := _active_attack_animation_list("attack_hit")
	if index < hits.size() and _animation_player.has_animation(StringName(hits[index])):
		return _animation_player.get_animation(StringName(hits[index])).length * _attack_reference_time_scale()
	return _attack_duration

## 部署动画按部署窗口缩放；逐次攻击动作有独立时长，不在这里绑定攻击间隔。
func _state_playback_speed(state: int, animation_name: StringName) -> float:
	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		return 1.0
	var target_duration := 0.0
	match state:
		0:
			# 可选的通用裁剪：只播放部署动画开头的一段，剩余部分由普通状态机接管。
			var deploy_ratio := clampf(float(_animation_names.get("deploy_clip_ratio", 1.0)), 0.01, 1.0)
			target_duration = _source.deploy_time / deploy_ratio
	if target_duration <= 0.001:
		return 1.0
	return maxf(float(animation.length) / target_duration, 0.01)

func _configure_looping_animations() -> void:
	if _animation_player == null:
		return
	for key in ["idle"]:
		var animation_name := StringName(_animation_names.get(key, ""))
		if animation_name == &"" or not _animation_player.has_animation(animation_name):
			continue
		var animation := _animation_player.get_animation(animation_name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR
	# 普通单位的单段移动继续原地循环；配置 move_cycle 时由结束事件按数组推进。
	if _animation_list("move_cycle").is_empty():
		var move_name := StringName(_animation_names.get("move", ""))
		if move_name != &"" and _animation_player.has_animation(move_name):
			var move_animation := _animation_player.get_animation(move_name)
			if move_animation != null:
				move_animation.loop_mode = Animation.LOOP_LINEAR
	for key in ["initial_move", "attack_move", "empowered_idle", "empowered_move", "haste_move"]:
		for value in _animation_list(key):
			var routed_move := StringName(value)
			if routed_move != &"" and _animation_player.has_animation(routed_move):
				var routed_animation := _animation_player.get_animation(routed_move)
				if routed_animation != null:
					routed_animation.loop_mode = Animation.LOOP_LINEAR
	var continuous_loop := StringName(_animation_names.get("attack_loop", ""))
	if continuous_loop != &"" and _animation_player.has_animation(continuous_loop):
		var continuous_animation := _animation_player.get_animation(continuous_loop)
		if continuous_animation != null:
			continuous_animation.loop_mode = Animation.LOOP_LINEAR
	# 出场技能与攻击分段动画都必须是非循环完整动作。
	for key in ["attack", "attack_structure", "attack_hit", "attack_recover", "empowered_attack", "empowered_attack_hit", "empowered_attack_recover", "empowered_attack_to_move", "deploy", "attack_enter", "attack_retarget_enter", "attack_to_move", "idle_cycle", "move_enter", "move_cycle"]:
		for value in _animation_list(key):
			var animation_name := StringName(value)
			if animation_name != &"" and _animation_player.has_animation(animation_name):
				var animation := _animation_player.get_animation(animation_name)
				if animation != null:
					animation.loop_mode = Animation.LOOP_NONE
	var visual_actions: Dictionary = _animation_names.get("visual_actions", {})
	for value in visual_actions.values():
		if value is Dictionary:
			value = (value as Dictionary).get("animation", [])
		var configured: Array = value if value is Array else [value]
		for configured_name in configured:
			var animation_name := StringName(configured_name)
			if animation_name != &"" and _animation_player.has_animation(animation_name):
				var animation := _animation_player.get_animation(animation_name)
				if animation != null:
					animation.loop_mode = Animation.LOOP_NONE
	var transitions: Dictionary = _animation_names.get("transitions", {})
	for value in transitions.values():
		if value is Dictionary:
			value = (value as Dictionary).get("animation", [])
		var configured: Array = value if value is Array else [value]
		for configured_name in configured:
			var animation_name := StringName(configured_name)
			if animation_name != &"" and _animation_player.has_animation(animation_name):
				var animation := _animation_player.get_animation(animation_name)
				if animation != null:
					animation.loop_mode = Animation.LOOP_NONE

func _on_animation_finished(animation_name: StringName) -> void:
	# 场景重建可先释放权威单位；死亡表现仍独立播放，其余回调不再读取旧单位。
	if not _dying and not is_instance_valid(_source):
		return
	if not _dying and _control_stage != &"":
		if _control_stage == &"enter":
			_play_control_clip("stun_loop", &"loop")
		elif _control_stage == &"exit":
			_restore_control_pose()
		return
	if _dying:
		if animation_name == _death_animation:
			if not _start_death_followup():
				_finish_model_visual_death()
				_retire()
		return
	if _playing_visual_action:
		if animation_name == _active_visual_action:
			if _action_sequence.advance():
				_play_visual_action_clip(StringName(_action_sequence.current().name))
			else:
				_finish_visual_action()
		return
	# 出场技能序列按段推进；只有当前段播完才进入下一段，其余动画结束事件忽略。
	if _playing_deploy_sequence:
		if animation_name == _deploy_active_animation:
			_advance_deploy_sequence()
		return
	if _continuous_attack_active:
		if animation_name == _continuous_attack_animation and _current_state == 3:
			_continuous_attack_sequence_index += 1
			if _continuous_attack_sequence_index < _continuous_attack_sequence.size():
				_play_continuous_attack_enter(StringName(_continuous_attack_sequence[_continuous_attack_sequence_index]), &"sequence")
			else:
				_play_continuous_attack_loop(&"sequence")
		return
	if _move_sequence_active:
		if animation_name != _move_active_animation or _current_state != 2:
			return
		if _move_sequence_index < _move_sequence.size():
			_advance_move_sequence()
		else:
			_advance_move_cycle()
		return
	if animation_name == _idle_cycle_active_animation and _current_state == 1:
		_start_idle_cycle(false)
		return
	if animation_name == _idle_transition_animation and _current_state == 1:
		var exit_blend := _idle_transition_exit_blend
		_idle_transition_animation = &""
		_play_state(1, _transition_blend(&"sequence") if exit_blend < 0.0 else exit_blend)
		return
	if not _playing_attack or animation_name != _active_attack_animation:
		return
	# 分段动作的 Start/Hit 由表现计时器继续推进，不能被普通“动作播完”逻辑提前截断。
	if _attack_hit_pending or _attack_recover_pending:
		return
	_playing_attack = false
	# AnimationPlayer 停在非循环动画的最后一帧。只要模拟仍锁定攻击目标，
	# 就保留这套骨骼姿态，下一次攻击从此处短混合到另一套动作。
	var state := _source.get_visual_state_code()
	if state == 3:
		_holding_attack_pose = true
		_current_state = 3
	else:
		_holding_attack_pose = false
		_active_attack_animation = &""
		var locomotion_state := _source.get_locomotion_visual_state_code()
		_transition_to_basic_state(locomotion_state, _transition_blend(&"action_out"), &"attack")

func _finish_visual_action() -> void:
	var action_kind := _active_action_kind
	var blend_out := _transition_blend(&"action_out") if _active_action_blend_out < 0.0 else _active_action_blend_out
	_playing_visual_action = false
	_active_visual_action = &""
	_action_sequence.clear()
	_active_action_name = &""
	_active_action_kind = &"locomotion"
	_active_action_sequence_blend = -1.0
	_active_action_priority = 0
	_active_action_blend_in = -1.0
	_active_action_blend_out = -1.0
	_current_state = -1
	var state := _source.get_visual_state_code()
	var locomotion_state := _source.get_locomotion_visual_state_code()
	if _pending_attack_serial > 0 and state == 3:
		var pending_serial := _pending_attack_serial
		_pending_attack_serial = 0
		_play_attack(pending_serial, blend_out)
		return
	_pending_attack_serial = 0
	if state == 3 and _uses_continuous_state_animations():
		# Skill/Transform -> continuous Attack 由源动作的 action_out 承担进入混合。
		_current_state = 3
		_source.set_continuous_beam_visible(false)
		_continuous_attack_active = false
		_continuous_attack_animation = &""
		_continuous_attack_sequence.clear()
		_move_sequence_active = false
		_move_active_animation = &""
		_start_continuous_attack(false, blend_out)
		return
	if state == 3:
		_current_state = 1
		_play_state(1, blend_out)
		return
	_transition_to_basic_state(locomotion_state, blend_out, action_kind)

func _on_source_died() -> void:
	if _dying:
		return
	_dying = true
	_idle_transition_animation = &""
	_pending_attack_serial = 0
	_death_followup_started = false
	_playing_attack = false
	_holding_attack_pose = false
	_playing_deploy_sequence = false
	_deploy_active_animation = &""
	_continuous_attack_active = false
	_continuous_attack_animation = &""
	_move_sequence_active = false
	_playing_visual_action = false
	_idle_cycle_active_animation = &""
	_active_visual_action = &""
	_action_sequence.clear()
	_active_action_name = &""
	_active_action_kind = &"death"
	_active_action_priority = int(ACTION_PRIORITY.get(&"death", 100))
	_active_action_blend_in = -1.0
	_active_action_blend_out = -1.0
	_active_action_sequence_blend = -1.0
	_move_active_animation = &""
	_source.set_continuous_beam_visible(false)
	_attack_hit_pending = false
	_attack_recover_pending = false
	_active_attack_animation = &""
	_hit_flash_timer = 0.0
	_set_hit_flash(false)
	if _team_ring != null:
		_team_ring.hide()
	if _animation_player == null:
		_finish_model_visual_death()
		_retire()
		return
	if bool(_animation_names.get("death_followup_immediate", false)) and _start_death_followup():
		return
	_death_animation = StringName(_animation_names.get("death", ""))
	if _death_animation == &"" or not _animation_player.has_animation(_death_animation):
		_finish_model_visual_death()
		_retire()
		return
	var animation := _animation_player.get_animation(_death_animation)
	var death_playback_speed := 1.0
	var death_duration := float(_animation_names.get("death_duration", 0.0))
	var death_end := animation.length if animation != null else 0.0
	death_end = minf(float(_animation_names.get("death_clip_end", death_end)), death_end)
	if animation != null:
		animation.loop_mode = Animation.LOOP_NONE
		if death_duration > 0.0 and animation.length > 0.0:
			death_playback_speed = death_end / death_duration
	# 包装场景可选择同步淡出粒子/雾气等纯表现节点；动画仍不参与死亡判定。
	if _model_root != null and _model_root.has_method("begin_visual_death"):
		var visual_duration := death_duration
		if visual_duration <= 0.0 and animation != null:
			visual_duration = death_end
		_model_root.call("begin_visual_death", maxf(visual_duration, 0.05))
	# 死亡不再受生前冰冻状态影响；按卡牌配置时长播完动作后清理纯视觉代理。
	_animation_player.speed_scale = 1.0
	_set_model_visual_clip(_death_animation)
	_play_clip(_death_animation, &"death", death_playback_speed)
	_animation_player.set_section(0.0, death_end)


func _finish_model_visual_death() -> void:
	if _model_root != null and _model_root.has_method("finish_visual_death"):
		_model_root.call("finish_visual_death")

## 大纳尔死亡的第一段很短，结束后在同一纯表现代理中换成小纳尔模型继续播放 Death。
## 战斗单位在第一帧已经退出权威模拟，这个模型切换不会复活、改碰撞或延迟死亡。
func _start_death_followup() -> bool:
	if _death_followup_started:
		return false
	var scene_path := String(_animation_names.get("death_followup_scene_path", ""))
	var followup_name := StringName(_animation_names.get("death_followup_animation", ""))
	if scene_path.is_empty() or followup_name == &"":
		return false
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return false
	var instance: Node = model_factory.call(packed) if model_factory.is_valid() else packed.instantiate()
	if not instance is Node3D:
		instance.queue_free()
		return false
	if _model_root != null and is_instance_valid(_model_root):
		_release_model()
	_model_root = instance as Node3D
	add_child(_model_root)
	_model_resources.clear()
	if _model_root.has_meta("prepared_model_resources"):
		_model_resources = _model_root.get_meta("prepared_model_resources")
		_animation_player = _model_root.get_meta("prepared_animation_player")
		_model_root.remove_meta("prepared_model_resources")
		_model_root.remove_meta("prepared_animation_player")
	else:
		_animation_player = _model_resources.bind_model(_model_root)
	_stable_head_offset = NAN
	_control_stage = &""
	if _animation_player == null or not _animation_player.has_animation(followup_name):
		return false
	_animation_player.animation_finished.connect(_on_animation_finished)
	_death_followup_started = true
	_death_animation = followup_name
	var animation := _animation_player.get_animation(followup_name)
	var playback_speed := 1.0
	var target_duration := float(_animation_names.get("death_followup_duration", 0.0))
	if animation != null:
		animation.loop_mode = Animation.LOOP_NONE
		if target_duration > 0.0 and animation.length > 0.0:
			playback_speed = animation.length / target_duration
	_set_model_visual_clip(followup_name)
	_play_clip(followup_name, &"model_swap", playback_speed)
	return true

func _update_continuous_beam_origin() -> void:
	if _model_root == null or _camera == null:
		return
	var mouth_world: Vector3
	if _model_root.has_method("get_beam_origin_world"):
		mouth_world = _model_root.call("get_beam_origin_world")
	else:
		var anchor := _model_root.get_node_or_null("BeamOrigin") as Node3D
		if anchor == null:
			return
		mouth_world = anchor.global_position
	if not _camera.is_position_behind(mouth_world):
		_source.set_continuous_beam_origin_world_position(_camera.unproject_position(mouth_world))

func _create_team_ring() -> void:
	if not _source.show_team_ring:
		return
	var ring_mesh := CylinderMesh.new()
	var ring_radius := maxf(_source.visual_radius / 40.0, 0.42)
	ring_mesh.top_radius = ring_radius
	ring_mesh.bottom_radius = ring_radius
	ring_mesh.height = 0.025
	ring_mesh.radial_segments = 40

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.20, 0.55, 1.0, 0.72) if _source.team == 0 else Color(1.0, 0.24, 0.18, 0.72)
	ring_mesh.material = material

	_team_ring = MeshInstance3D.new()
	_team_ring.name = "TeamRing"
	_team_ring.mesh = ring_mesh
	_team_ring.position.y = 0.01
	_team_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_team_ring)

func _recreate_team_ring() -> void:
	if _team_ring != null and is_instance_valid(_team_ring):
		_team_ring.queue_free()
	_team_ring = null
	_create_team_ring()

func _on_source_visual_hit() -> void:
	if _dying:
		return
	if is_instance_valid(_active_buff_visual):
		_active_buff_visual.on_hit()
	_hit_flash_timer = 0.05
	_set_hit_flash(true)

func _update_hit_flash(delta: float) -> void:
	if _last_frozen_overlay != (_state.frozen and not _dying):
		_last_frozen_overlay = _state.frozen and not _dying
		_set_hit_flash(_hit_flash_timer > 0.0)
	if _hit_flash_timer <= 0.0:
		return
	_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
	if _hit_flash_timer <= 0.0:
		_set_hit_flash(false)

func _set_hit_flash(enabled: bool) -> void:
	_model_resources.apply_overlays(enabled, _state.frozen and not _dying, _last_buff_visible)

## 冰冻优先保持当前姿态；眩晕片段自身播放。无素材明确回退为保持姿态。
func _on_action_cancelled(payload: Dictionary) -> void:
	if _dying or _animation_player == null:
		return
	if int(payload.get("form", 0)) < maxi(_source.form_change_serial, _source.net_form_change_serial): return
	var cancel_attack := _last_attack_serial <= int(payload.get("attack", 0))
	var freeze_pose := String(payload.get("reason", "")) == "freeze" and _last_visual_action_serial <= int(payload.get("action", 0))
	if not cancel_attack and not freeze_pose: return
	if cancel_attack:
		_last_attack_serial = maxi(_last_attack_serial, int(payload.get("attack", 0)))
		_pending_attack_serial = 0
		_playing_attack = false
		_holding_attack_pose = false
		_attack_hit_pending = false
		_continuous_attack_active = false
		_continuous_attack_sequence.clear()
		_source.set_continuous_beam_visible(false)
	if freeze_pose:
		# 清理调度但不 play/seek，当前已经绘制的骨骼姿势原地保留。
		_playing_visual_action = false
		_playing_deploy_sequence = false
		_deploy_sequence_started = true
		_action_sequence.clear()
		_active_visual_action = &""
		_active_action_priority = 0
		_last_visual_action_serial = maxi(_last_visual_action_serial, int(payload.get("action", 0)))
		_animation_player.speed_scale = 0.0
		_was_controlled = true
	elif cancel_attack and not _state.frozen and not _playing_visual_action and not _playing_deploy_sequence:
		_transition_to_basic_state(1, 0.1)

func _sync_control_override() -> bool:
	if _animation_player == null:
		return false
	if _state.frozen:
		_was_controlled = true
		_animation_player.speed_scale = 0.0
		# 冻结期间可能换形，消费新模型动作身份，不补播转换。
		_last_visual_action_serial = _source.get_visual_action_serial()
		return true
	if _was_controlled:
		_was_controlled = false
		_animation_player.speed_scale = 1.0
		_playing_attack = false
		_playing_visual_action = false
		_playing_deploy_sequence = false
		_action_sequence.clear()
		_transition_to_basic_state(1, 0.1)
	# 眩晕保留已开始的技能/部署/转换；普通动作由取消事件切到 Idle。
	if _state.stunned and not _playing_visual_action and not _playing_deploy_sequence and _source._deploy_timer <= 0.0:
		if _current_state != 1:
			_transition_to_basic_state(1, 0.1)
		return true
	return false

func _sync_visual_action_while_controlled() -> void:
	var serial := _source.get_visual_action_serial()
	if serial == _last_visual_action_serial:
		return
	_last_visual_action_serial = serial
	_play_visual_action(_source.get_visual_action_name(), true)

func _play_control_clip(key: String, stage: StringName) -> void:
	var clip := _first_valid_animation(key)
	if clip == &"" and stage == &"enter":
		_play_control_clip("stun_loop", &"loop")
		return
	_control_stage = stage if clip != &"" else &"hold"
	if clip != &"":
		_animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if stage == &"loop" else Animation.LOOP_NONE
		_play_clip(clip, &"action_in")

func _restore_control_pose() -> void:
	_control_stage = &""
	var action_still_valid := (
		_saved_control_action_serial >= 0
		and _source.get_visual_action_serial() == _saved_control_action_serial
		and _source.get_visual_action_name() == _saved_control_action_name
		and _saved_control_action_name != &""
	)
	var non_action_context_still_valid := (
		_saved_control_action_name == &""
		and _source.get_visual_action_serial() == _saved_control_action_serial
		and _source.get_attack_visual_serial() == _saved_control_attack_serial
		and _source.get_visual_state_code() == _saved_control_state
		and _source.get_locomotion_visual_state_code() == _saved_control_locomotion_state
	)
	var restore_context_valid := action_still_valid or non_action_context_still_valid
	if restore_context_valid and _saved_control_clip != &"" and _animation_player.has_animation(_saved_control_clip):
		var saved_animation := _animation_player.get_animation(_saved_control_clip)
		if saved_animation != null:
			saved_animation.loop_mode = _saved_control_loop_mode
		_set_model_visual_clip(_saved_control_clip)
		_current_clip_speed = _saved_control_speed
		var section := _saved_control_section
		var has_saved_section := section.y > section.x + 0.0001
		if has_saved_section:
			var restore_blend_fallback := _active_action_blend_out if action_still_valid else -1.0
			var blend := _resolve_clip_blend(_saved_control_clip, &"action_out", restore_blend_fallback)
			_last_clip_transition_kind = &"action_out"
			_last_clip_blend_time = blend
			_animation_player.play_section(_saved_control_clip, section.x, section.y, blend, _saved_control_speed)
			_animation_player.seek(clampf(_saved_control_position, section.x, section.y), true)
		else:
			_play_clip(_saved_control_clip, &"action_out", _saved_control_speed)
			_animation_player.seek(_saved_control_position, true)
	else:
		_invalidate_control_restore()
		# 取消或新序号替换了旧动作时，不恢复旧 Pose；新动作由权威剩余时间对齐。
		if _source.get_visual_action_name() != &"" and _source.get_visual_action_time_left() > 0.0:
			_play_visual_action(_source.get_visual_action_name())
	_animation_player.speed_scale = 1.0

## 晚到的普攻序号从权威已流逝阶段开始；分段计时仍纯表现，不触发命中。
func _align_attack_progress(elapsed: float) -> void:
	# 新攻击即使进度恰为零也必须 seek；play(同名片段) 会继续上一轮进度。
	if not _playing_attack or _animation_player == null:
		return
	_update_attack_stages(elapsed / maxf(_state.attack_rate, 0.01))
	var clip_elapsed := elapsed
	var hits := _active_attack_animation_list("attack_hit")
	if _active_attack_index < hits.size() and StringName(hits[_active_attack_index]) != &"" and not _attack_hit_pending:
		clip_elapsed = maxf(elapsed - _source.get_attack_first_hit_time_visual(), 0.0)
		var recovers := _active_attack_animation_list("attack_recover")
		if _active_attack_index < recovers.size() and StringName(recovers[_active_attack_index]) != &"" and not _attack_recover_pending:
			clip_elapsed = maxf(clip_elapsed - _attack_recover_delay(_active_attack_index), 0.0)
	var clip := _animation_player.get_animation(_animation_player.current_animation)
	if clip != null:
		_animation_player.seek(minf(_attack_clip_start + clip_elapsed * _current_clip_speed, _attack_clip_end), true)


func _replace_active_buff_visual(scene_path: String) -> void:
	if is_instance_valid(_active_buff_visual):
		_active_buff_visual.hide()
		_active_buff_visual.queue_free()
	_active_buff_visual = null
	_model_resources.configure_buff()
	_last_buff_visible = false
	if scene_path.is_empty():
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return
	_active_buff_visual = (model_factory.call(packed) if model_factory.is_valid() else packed.instantiate()) as ActiveBuffVisual3D
	if _active_buff_visual == null:
		return
	add_child(_active_buff_visual)
	_active_buff_visual.configure(_source.visual_radius, _source.team)
	_model_resources.configure_buff(_active_buff_visual.make_overlay)
	_update_active_buff_visual(0.0)


func _update_active_buff_visual(delta: float) -> void:
	if not is_instance_valid(_active_buff_visual):
		return
	var enabled := not _dying and is_instance_valid(_source) and _state.active_buff
	_active_buff_visual.advance(enabled, delta)
	var shown := _active_buff_visual.visible
	if shown != _last_buff_visible:
		_last_buff_visible = shown
		_set_hit_flash(_hit_flash_timer > 0.0)

func _exit_tree() -> void:
	_model_resources.clear()

## 完成死亡片段或换模型后才移交；代理、源信号和附属效果不进入模型池。
func _release_model() -> void:
	if not is_instance_valid(_model_root): return
	if _animation_player != null and _animation_player.animation_finished.is_connected(_on_animation_finished):
		_animation_player.animation_finished.disconnect(_on_animation_finished)
	var recycled := model_recycler.is_valid() and bool(model_recycler.call(_model_root, _model_resources, _animation_player))
	if not recycled:
		_model_resources.clear()
		_model_root.hide()
		_model_root.queue_free()
	_model_resources = ModelVisualResources.new()
	_model_root = null
	_animation_player = null

func _retire() -> void:
	if is_instance_valid(_source):
		if _source.died.is_connected(_on_source_died): _source.died.disconnect(_on_source_died)
		if _source.visual_hit.is_connected(_on_source_visual_hit): _source.visual_hit.disconnect(_on_source_visual_hit)
		if _source.action_cancelled.is_connected(_on_action_cancelled): _source.action_cancelled.disconnect(_on_action_cancelled)
	_source = null
	_release_model()
	queue_free()
