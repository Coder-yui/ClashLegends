extends Node3D
## 特效展台的正式卡牌组合适配器；复用运行时场景，无权威模拟。
var _data := {"duration": 3.5, "emitters": [{"name": "模型 / 部署 / 常驻范围", "quadType": -1}, {"name": "主动技能", "quadType": -1}]}
var _pools: Array = [[], []]
var _frame := -1
var _stats: Dictionary
var _kind := "deployment"
var _model: Node3D
var _buff: Node3D
var _previous := INF
var _animator: AnimationPlayer
var _deploy_duration := 1.0
var _team := 0
func set_preview_team(team: int) -> void:
	_team = team
	if is_instance_valid(_model) and _model.has_method("set_preview_team"): _model.set_preview_team(team)
func configure_card(card_id: String) -> void:
	_stats = CardDB.get_card(card_id)
	_deploy_duration = float(_stats.get("deploy_time", 1.0))
func load_kind(kind: String) -> void:
	_kind = kind
func setup_native(_scale: float) -> void:
	_model = load(PresentationConfig.scene_path(_stats, 0)).instantiate()
	add_child(_model)
	_model.set_process(false)
	set_preview_team(_team)
	_pools[0].append(_model)
	for node in _model.find_children("*", "AnimationPlayer", true, false):
		_animator = node
		var idle := String(_stats.get("visual_animations", {}).get("idle", ""))
		if _animator.has_animation(idle):
			_animator.play(idle)
			_animator.pause()
		break
	if _kind == "skill" and not String(_stats.get("visual_active_buff_scene", "")).is_empty():
		_buff = load(String(_stats.visual_active_buff_scene)).instantiate()
		add_child(_buff)
		_buff.configure(float(_stats.get("visual_radius", 18.0)), 0)
		_pools[1].append(_buff)
	seek(0.0)
func seek(value: float) -> void:
	var previous := _previous
	if value < _previous and _model.has_method("reset_pool_visual"):
		_model.reset_pool_visual()
		previous = 0.0
	_previous = value
	if _kind == "death" and _animator != null:
		var clips: Dictionary = _stats.get("visual_animations", {})
		var clip := String(clips.get("death", ""))
		if _animator.has_animation(clip):
			var source_duration := _animator.get_animation(clip).length
			var death_duration := minf(source_duration, float(clips.get("death_duration", source_duration)))
			if _model.has_method("begin_visual_death"): _model.begin_visual_death(death_duration)
			_animator.play(clip)
			_animator.seek(minf(value / maxf(death_duration, 0.01), 1.0) * source_duration, true)
			_animator.pause()
			_model.visible = value < death_duration
			if _model.has_method("seek_preview_visual"): _model.seek_preview_visual(value)
			if value >= death_duration and _model.has_method("finish_visual_death"): _model.finish_visual_death()
		return
	if _model.has_method("advance_deployment_visual"):
		# 拖动可跨过落地事件；按表现采样推进，保持与实际连续播放一致。
		if _kind == "deployment":
			for sample_index in range(int(previous * 60.0) + 1, int(value * 60.0) + 1):
				_model.advance_deployment_visual(float(sample_index) / 60.0, _deploy_duration, true)
		_model.advance_deployment_visual(value if _kind == "deployment" else _deploy_duration, _deploy_duration, true)
	if _model.has_method("seek_preview_visual"): _model.seek_preview_visual(value)
	if _animator != null and not _animator.assigned_animation.is_empty():
		_animator.seek(fmod(value, maxf(_animator.current_animation_length, 0.01)), true)
	if is_instance_valid(_buff):
		_buff.shield_active = value < float(_stats.active_skills[0].get("shield_duration", 3.0))
		_buff.on_cue(&"shield:cast")
		_buff.advance_status(true, true, value)
