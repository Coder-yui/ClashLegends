class_name UnitModel3D
extends Node3D
## 单个 3D 模型的表现代理。只读取 Unit 的插值位置与表现状态，不参与模拟。

const STATE_KEYS := [&"deploy", &"idle", &"move", &"attack"]

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
var _playing_attack := false
var _holding_attack_pose := false
var _active_attack_animation := &""
var _active_attack_index := 0
var _attack_hit_timer := 0.0
var _attack_recover_timer := 0.0
var _attack_hit_pending := false
var _attack_recover_pending := false
# 持续攻击单位使用“进入攻击 → 循环攻击”，移动则可使用“进入移动 → 多段循环”。
# 这些状态仅消费 Unit 的粗粒度表现状态，不驱动索敌、伤害或移动。
var _continuous_attack_active := false
var _continuous_attack_animation := &""
var _move_sequence: Array = []
var _move_sequence_index := 0
var _move_cycle: Array = []
var _move_cycle_index := 0
var _move_sequence_active := false
var _move_active_animation := &""
# 出场技能序列：deploy 配置为数组时，从单位生成的部署阶段首帧开始依次播放
# （如赵信 Spell4 → Spell4_To_Idle），两段合计对齐权威部署时长；
# 部署结束前不被基础状态切换打断。
var _deploy_sequence: Array = []
var _deploy_sequence_index := 0
var _deploy_sequence_speeds: Array = []
var _playing_deploy_sequence := false
var _deploy_active_animation := &""
var _deploy_sequence_started := false
var _death_animation := &""
var _dying := false
var _hit_flash_timer := 0.0
var _hit_flash_material: StandardMaterial3D
var _flash_meshes: Array[MeshInstance3D] = []
var _original_overlays: Array[Material] = []

func setup(unit: Unit, packed: PackedScene, camera: Camera3D, animations: Dictionary, forward_yaw: float) -> bool:
	# 客户端 Unit 会在默认优先级更新快照插值；3D 代理随后读取最终位置。
	process_priority = 10
	var instance := packed.instantiate()
	if not instance is Node3D:
		push_warning("单位 3D 表现场景的根节点必须是 Node3D")
		instance.queue_free()
		return false
	_source = unit
	_source.died.connect(_on_source_died)
	_source.visual_hit.connect(_on_source_visual_hit)
	_camera = camera
	_model_root = instance as Node3D
	_animation_names = animations.duplicate()
	_forward_yaw = forward_yaw
	# 一套完整挥剑（前摇、命中、后摇）占满一个攻击周期；动画长度不改变战斗计时。
	_attack_duration = maxf(unit.attack_interval, 0.05)
	add_child(_model_root)
	_animation_player = _find_animation_player(_model_root)
	if _animation_player == null:
		push_warning("单位 3D 模型中未找到 AnimationPlayer")
	else:
		_animation_player.animation_finished.connect(_on_animation_finished)
	_create_team_ring()
	_prepare_hit_flash()
	_configure_looping_animations()
	_sync_visual(true, 0.0)
	_update_health_bar_anchor()
	return true

func _process(delta: float) -> void:
	_update_hit_flash(delta)
	if _dying:
		return
	if _source == null or not is_instance_valid(_source):
		queue_free()
		return
	_update_attack_stages(delta)
	_sync_visual(false, delta)
	_update_health_bar_anchor()

func _sync_visual(force: bool, delta: float) -> void:
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

	var attack_serial := _source.net_attack_visual_serial if _source._in_client_mode() else _source.get_attack_visual_serial()
	var attack_serial_changed := attack_serial != _last_attack_serial
	if attack_serial_changed:
		_last_attack_serial = attack_serial
		if not _uses_continuous_state_animations():
			_play_attack(attack_serial)
	var state := _source.net_visual_state if _source._in_client_mode() else _source.get_visual_state_code()
	# 出场演出：单位生成首帧启动序列；部署结束后让位给基础状态机。
	_update_deploy_sequence_lifecycle()
	# 出场技能序列在部署锁定期间保持动作，不被其他状态打断。
	if _playing_deploy_sequence:
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
		_current_state = state
		_play_state(state, 0.12)
	elif state != 3 and not _playing_attack and (force or state != _current_state):
		_current_state = state
		_play_state(state)
	elif state == 3 and not _playing_attack and not _holding_attack_pose and force:
		_current_state = 1
		_play_state(1)
	if _animation_player != null:
		_animation_player.speed_scale = 0.0 if _source.frozen_timer > 0.0 else 1.0

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
	_move_sequence_active = false
	_move_active_animation = &""
	match state:
		3:
			_start_continuous_attack(retargeting_without_move)
		2:
			_start_move_sequence(previous_state == 3)
		_:
			# play() 会立即替换仍在播放的吐息循环，不等待循环素材结束。
			_play_state(state, 0.08 if force else 0.12)

func _start_continuous_attack(retargeting_without_move: bool = false) -> void:
	if _animation_player == null:
		return
	# 进入吐息动画只表现蓄势；蓝色光柱要等循环吐息真正开始后才出现。
	_source.set_continuous_beam_visible(false)
	_continuous_attack_active = true
	var enter_key := "attack_retarget_enter" if retargeting_without_move else "attack_enter"
	var enter_name := StringName(_animation_names.get(enter_key, _animation_names.get("attack_enter", "")))
	if enter_name != &"" and _animation_player.has_animation(enter_name):
		var enter_animation := _animation_player.get_animation(enter_name)
		if enter_animation != null:
			enter_animation.loop_mode = Animation.LOOP_NONE
		_continuous_attack_animation = enter_name
		_animation_player.play(enter_name, 0.06)
		return
	_play_continuous_attack_loop()

func _play_continuous_attack_loop() -> void:
	if _animation_player == null or not _continuous_attack_active or _current_state != 3:
		return
	var loop_name := StringName(_animation_names.get("attack_loop", ""))
	if loop_name == &"" or not _animation_player.has_animation(loop_name):
		return
	var loop_animation := _animation_player.get_animation(loop_name)
	if loop_animation != null:
		loop_animation.loop_mode = Animation.LOOP_LINEAR
	_continuous_attack_animation = loop_name
	_animation_player.play(loop_name, 0.05)
	_source.set_continuous_beam_visible(true)

## 进入普通移动先播 move_enter；若刚退出持续攻击，则在它之前插入
## attack_to_move。过渡完成后按 move_cycle 数组顺序逐段循环。
func _start_move_sequence(from_continuous_attack: bool) -> void:
	if _animation_player == null:
		return
	_move_sequence.clear()
	if from_continuous_attack:
		_append_valid_animations(_move_sequence, "attack_to_move")
	var use_move_enter := not from_continuous_attack or bool(_animation_names.get("move_enter_after_attack", true))
	if use_move_enter:
		_append_valid_animations(_move_sequence, "move_enter")
	_move_cycle.clear()
	_append_valid_animations(_move_cycle, "move_cycle")
	_move_sequence_index = 0
	_move_cycle_index = 0
	_move_sequence_active = not _move_sequence.is_empty() or not _move_cycle.is_empty()
	if not _move_sequence.is_empty():
		_play_move_clip(StringName(_move_sequence[0]))
	elif not _move_cycle.is_empty():
		_play_move_cycle_clip()
	else:
		_play_state(2)

func _append_valid_animations(target: Array, key: String) -> void:
	for value in _animation_list(key):
		var animation_name := StringName(value)
		if animation_name != &"" and _animation_player.has_animation(animation_name):
			target.append(animation_name)

func _play_move_clip(animation_name: StringName) -> void:
	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		return
	animation.loop_mode = Animation.LOOP_NONE
	_move_active_animation = animation_name
	_animation_player.play(animation_name, 0.06)

func _play_move_cycle_clip() -> void:
	if _move_cycle.is_empty() or _current_state != 2:
		return
	_play_move_clip(StringName(_move_cycle[_move_cycle_index]))

func _advance_move_sequence() -> void:
	if _move_sequence_index < _move_sequence.size():
		_move_sequence_index += 1
		if _move_sequence_index < _move_sequence.size():
			_play_move_clip(StringName(_move_sequence[_move_sequence_index]))
			return
	if _move_cycle.is_empty():
		_move_sequence_active = false
		_play_state(2)
		return
	_move_cycle_index = 0
	_play_move_cycle_clip()

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

## 用包装场景中全部网格的实际投影顶部定位血条；模型缩放或脚底校正后无需再手填像素偏移。
func _update_health_bar_anchor() -> void:
	if _source == null or _camera == null or _flash_meshes.is_empty():
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
	var top_screen_y := ground_screen.y
	var found_visible_point := false
	for mesh_instance in _flash_meshes:
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
			top_screen_y = minf(top_screen_y, _camera.unproject_position(world_corner).y)
			found_visible_point = true
	if found_visible_point:
		# 武器/披风等网格也在 AABB 内，直接取最顶点会把血条拉离头部；
		# 以体型半径给人物头顶设合理上限，避免红蓝朝向或动作造成大幅漂移。
		var max_head_height := _source.visual_radius * 3.25
		top_screen_y = maxf(top_screen_y, ground_screen.y - max_head_height)
		_source.set_visual_head_world_position(Vector2(ground_screen.x, top_screen_y))

func _play_state(state: int, blend_time: float = 0.08) -> void:
	if _animation_player == null:
		return
	var key: StringName = STATE_KEYS[clampi(state, 0, STATE_KEYS.size() - 1)]
	var configured = _animation_names.get(String(key), "")
	# deploy 配置为数组时由部署序列生命周期单独处理。
	if configured is Array:
		configured = ""
	var animation_name := StringName(configured)
	if animation_name == &"" or not _animation_player.has_animation(animation_name):
		animation_name = StringName(_animation_names.get("idle", ""))
	if animation_name != &"" and _animation_player.has_animation(animation_name):
		var playback_speed := _state_playback_speed(state, animation_name)
		_animation_player.play(animation_name, blend_time, playback_speed)

## 出场演出生命周期：生成首帧启动序列；权威部署计时耗尽时终止序列。
func _update_deploy_sequence_lifecycle() -> void:
	if _dying or _source == null:
		return
	var deploy_names = _animation_names.get("deploy", "")
	var has_sequence: bool = deploy_names is Array and not (deploy_names as Array).is_empty()
	var deploying := _source._deploy_timer > 0.0
	if has_sequence and deploying and not _deploy_sequence_started:
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
	_animation_player.play(animation_name, 0.08, playback_speed)

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
	var state := _source.net_visual_state if _source._in_client_mode() else _source.get_visual_state_code()
	_current_state = state
	if state != 0:
		_play_state(state, 0.12)

func _play_attack(serial: int) -> void:
	if _animation_player == null or serial <= 0:
		return
	# 出场演出期间权威锁定攻击，不会推进攻击序号；此防御仅兜底客户端快照乱序。
	if _playing_deploy_sequence:
		return
	var configured = _animation_names.get("attack", [])
	var attacks: Array = configured if configured is Array else [configured]
	if attacks.is_empty():
		return
	_active_attack_index = (serial - 1) % attacks.size()
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
	_current_state = 3
	var hit_animations := _animation_list("attack_hit")
	if _active_attack_index < hit_animations.size() and StringName(hit_animations[_active_attack_index]) != &"":
		# 分段普攻只影响表现：Start 在权威 first_hit 窗口内播放，计时到点切到 Hit。
		_attack_hit_pending = true
		_attack_hit_timer = maxf(_source.first_hit_time, 0.01)
		_play_attack_clip(animation_name, _attack_hit_timer)
	else:
		_play_attack_clip(animation_name, _attack_duration)

func _update_attack_stages(delta: float) -> void:
	if not _playing_attack or _animation_player == null:
		return
	# 冰冻期间模拟攻击计时不推进，分段表现计时也必须同步暂停。
	if _source.frozen_timer > 0.0:
		return
	if _attack_hit_pending:
		_attack_hit_timer = maxf(0.0, _attack_hit_timer - delta)
		if _attack_hit_timer <= 0.0:
			_attack_hit_pending = false
			var hit_animations := _animation_list("attack_hit")
			if _active_attack_index < hit_animations.size():
				var hit_name := StringName(hit_animations[_active_attack_index])
				var recover_animations := _animation_list("attack_recover")
				var recover_name := &""
				if _active_attack_index < recover_animations.size():
					recover_name = StringName(recover_animations[_active_attack_index])
				var recover_delay := _attack_recover_delay(_active_attack_index)
				_play_attack_clip(hit_name, recover_delay if recover_name != &"" else _attack_hit_duration(_active_attack_index))
				if recover_name != &"":
					_attack_recover_pending = true
					_attack_recover_timer = recover_delay
		return
	if _attack_recover_pending:
		_attack_recover_timer = maxf(0.0, _attack_recover_timer - delta)
		if _attack_recover_timer <= 0.0:
			_attack_recover_pending = false
			var recover_animations := _animation_list("attack_recover")
			if _active_attack_index < recover_animations.size():
				_play_attack_clip(StringName(recover_animations[_active_attack_index]), 0.0)

func _play_attack_clip(animation_name: StringName, target_duration: float) -> void:
	if animation_name == &"" or not _animation_player.has_animation(animation_name):
		return
	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		return
	animation.loop_mode = Animation.LOOP_NONE
	var playback_speed := 1.0
	if target_duration > 0.001:
		playback_speed = maxf(float(animation.length) / target_duration, 0.01)
	_active_attack_animation = animation_name
	_animation_player.play(animation_name, 0.05, playback_speed)

func _animation_list(key: String) -> Array:
	var configured = _animation_names.get(key, [])
	return configured if configured is Array else [configured]

func _attack_recover_delay(index: int) -> float:
	var configured = _animation_names.get("attack_recover_delay", 0.3)
	if configured is Array:
		var values := configured as Array
		if not values.is_empty():
			return maxf(float(values[index % values.size()]), 0.01)
	return maxf(float(configured), 0.01)

func _attack_hit_duration(index: int) -> float:
	var configured = _animation_names.get("attack_hit_duration", _attack_duration)
	if configured is Array:
		var values := configured as Array
		if not values.is_empty():
			return maxf(float(values[index % values.size()]), 0.01)
	return maxf(float(configured), 0.01)

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
	var continuous_loop := StringName(_animation_names.get("attack_loop", ""))
	if continuous_loop != &"" and _animation_player.has_animation(continuous_loop):
		var continuous_animation := _animation_player.get_animation(continuous_loop)
		if continuous_animation != null:
			continuous_animation.loop_mode = Animation.LOOP_LINEAR
	# 出场技能与攻击分段动画都必须是非循环完整动作。
	for key in ["attack", "attack_hit", "attack_recover", "deploy", "attack_enter", "attack_retarget_enter", "attack_to_move", "move_enter", "move_cycle"]:
		for value in _animation_list(key):
			var animation_name := StringName(value)
			if animation_name != &"" and _animation_player.has_animation(animation_name):
				var animation := _animation_player.get_animation(animation_name)
				if animation != null:
					animation.loop_mode = Animation.LOOP_NONE

func _on_animation_finished(animation_name: StringName) -> void:
	if _dying:
		if animation_name == _death_animation:
			queue_free()
		return
	# 出场技能序列按段推进；只有当前段播完才进入下一段，其余动画结束事件忽略。
	if _playing_deploy_sequence:
		if animation_name == _deploy_active_animation:
			_advance_deploy_sequence()
		return
	if _continuous_attack_active:
		if animation_name == _continuous_attack_animation and _current_state == 3:
			_play_continuous_attack_loop()
		return
	if _move_sequence_active:
		if animation_name != _move_active_animation or _current_state != 2:
			return
		if _move_sequence_index < _move_sequence.size():
			_advance_move_sequence()
		else:
			_advance_move_cycle()
		return
	if not _playing_attack or animation_name != _active_attack_animation:
		return
	# 分段动作的 Start/Hit 由表现计时器继续推进，不能被普通“动作播完”逻辑提前截断。
	if _attack_hit_pending or _attack_recover_pending:
		return
	_playing_attack = false
	# AnimationPlayer 停在非循环动画的最后一帧。只要模拟仍锁定攻击目标，
	# 就保留这套骨骼姿态，下一次攻击从此处短混合到另一套动作。
	var state := _source.net_visual_state if _source._in_client_mode() else _source.get_visual_state_code()
	if state == 3:
		_holding_attack_pose = true
		_current_state = 3
	else:
		_holding_attack_pose = false
		_active_attack_animation = &""
		_current_state = state
		_play_state(state, 0.12)

func _on_source_died() -> void:
	if _dying:
		return
	_dying = true
	_playing_attack = false
	_holding_attack_pose = false
	_playing_deploy_sequence = false
	_deploy_active_animation = &""
	_continuous_attack_active = false
	_continuous_attack_animation = &""
	_move_sequence_active = false
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
		queue_free()
		return
	_death_animation = StringName(_animation_names.get("death", ""))
	if _death_animation == &"" or not _animation_player.has_animation(_death_animation):
		queue_free()
		return
	var animation := _animation_player.get_animation(_death_animation)
	var death_playback_speed := 1.0
	var death_duration := float(_animation_names.get("death_duration", 0.0))
	if animation != null:
		animation.loop_mode = Animation.LOOP_NONE
		if death_duration > 0.0 and animation.length > 0.0:
			death_playback_speed = animation.length / death_duration
	# 包装场景可选择同步淡出粒子/雾气等纯表现节点；动画仍不参与死亡判定。
	if _model_root != null and _model_root.has_method("begin_visual_death"):
		var visual_duration := death_duration
		if visual_duration <= 0.0 and animation != null:
			visual_duration = animation.length
		_model_root.call("begin_visual_death", maxf(visual_duration, 0.05))
	# 死亡不再受生前冰冻状态影响；按卡牌配置时长播完动作后清理纯视觉代理。
	_animation_player.speed_scale = 1.0
	_animation_player.play(_death_animation, 0.08, death_playback_speed)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

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

func _prepare_hit_flash() -> void:
	_hit_flash_material = StandardMaterial3D.new()
	_hit_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# LoL 风格的轻微泛白：保留原材质和角色辨识度，不做整模型纯白剪影。
	_hit_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hit_flash_material.albedo_color = Color(1.0, 1.0, 1.0, 0.22)
	_collect_flash_meshes(_model_root)

func _collect_flash_meshes(node: Node) -> void:
	# 雾、光环、弹体等效果材质不参与人物闪白，也不应影响模型 AABB 血条定位。
	if node is MeshInstance3D and not node.is_in_group("presentation_fx"):
		var mesh_instance := node as MeshInstance3D
		_flash_meshes.append(mesh_instance)
		_original_overlays.append(mesh_instance.material_overlay)
	for child in node.get_children():
		_collect_flash_meshes(child)

func _on_source_visual_hit() -> void:
	if _dying:
		return
	_hit_flash_timer = 0.05
	_set_hit_flash(true)

func _update_hit_flash(delta: float) -> void:
	if _hit_flash_timer <= 0.0:
		return
	_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
	if _hit_flash_timer <= 0.0:
		_set_hit_flash(false)

func _set_hit_flash(enabled: bool) -> void:
	for i in range(_flash_meshes.size()):
		var mesh_instance := _flash_meshes[i]
		if mesh_instance == null or not is_instance_valid(mesh_instance):
			continue
		mesh_instance.material_overlay = _hit_flash_material if enabled else _original_overlays[i]
