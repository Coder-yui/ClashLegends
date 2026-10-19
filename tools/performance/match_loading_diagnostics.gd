extends RefCounted
## Opt-in observation; no draw, window mutation or gameplay action.
var process_frames := 0
var post_draws := 0
var last_process_usec := 0
var last_post_draw_usec := 0
var current := {}
var events: Array = []
var event_sequence := 0
var dropped_events := 0
var observer_usec := 0
var snapshots_usec := 0
var _tree: SceneTree
var _file: FileAccess

func _init(tree: SceneTree, output: String) -> void:
	_tree = tree
	_file = FileAccess.open(output.path_join("diagnostic-timeline.jsonl"), FileAccess.WRITE)
	_tree.process_frame.connect(_on_process)
	RenderingServer.frame_post_draw.connect(_on_post_draw)

func _on_process() -> void:
	process_frames += 1
	last_process_usec = Time.get_ticks_usec()

func _on_post_draw() -> void:
	post_draws += 1
	last_post_draw_usec = Time.get_ticks_usec()

func observe(stage: String, detail: Dictionary) -> void:
	var started := Time.get_ticks_usec()
	current.merge(detail, true)
	event_sequence += 1
	current.merge({"stage": stage, "at_usec": started, "event_sequence": event_sequence,
		"process_frames": process_frames, "post_draws": post_draws}, true)
	if events.size() < 2048: events.append(current.duplicate())
	else: dropped_events += 1
	observer_usec += Time.get_ticks_usec() - started

func snapshot(main: Node) -> Dictionary:
	var started := Time.get_ticks_usec()
	var presentation: Node = main.get("_battle_presentation")
	var valid_presentation := is_instance_valid(presentation)
	var warm: RefCounted = presentation.get("spell_warmup") if valid_presentation else null
	var world: Node = presentation.get("_world_root") if valid_presentation else null
	var camera: Node = presentation.get("_camera") if valid_presentation else null
	var window: Window = _tree.root
	var player: Object = instance_from_id(int(current.get("player_id", 0))) if int(current.get("player_id", 0)) > 0 else null
	var result := {"at_usec": started, "current": current.duplicate(), "process_frames": process_frames,
		"post_draws": post_draws, "last_process_usec": last_process_usec, "last_post_draw_usec": last_post_draw_usec,
		"observer_usec": observer_usec, "snapshots_usec_before_this": snapshots_usec, "dropped_events": dropped_events,
		"valid": {"main": is_instance_valid(main), "presentation": valid_presentation, "world": is_instance_valid(world),
			"camera": is_instance_valid(camera), "warm": is_instance_valid(warm), "player": is_instance_valid(player)},
		"window": {"visible": window.visible, "mode": window.mode, "minimized": window.mode == Window.MODE_MINIMIZED,
			"focused": window.has_focus(), "size": [window.size.x, window.size.y]},
		"paused": _tree.paused, "game_over": main.get("runtime").game_over,
		"decks": [main.get("runtime")._deck, main.get("runtime")._remote_deck],
		"choices": [main.get("runtime")._active_skill_choices, main.get("runtime")._remote_active_skill_choices]}
	if valid_presentation:
		result.viewport_update_mode = presentation.get("_viewport").render_target_update_mode
		result.model_cancelled = presentation.get("model_pool").cancelled
	if is_instance_valid(warm):
		result.merge({"draws": warm.draws, "skipped": warm.repeated_draws_skipped, "completed_recipes": warm._completed.size(),
			"retained": warm.retained.size(), "errors": warm.errors, "sampled_layers": warm.sampled_layers})
	result.events_since_snapshot = events.duplicate()
	events.clear()
	if _file != null:
		_file.store_line(JSON.stringify(result))
		_file.flush()
	snapshots_usec += Time.get_ticks_usec() - started
	return result

func observation_outcome() -> String:
	if current.get("stage", "") != "draw_wait": return ""
	if Time.get_ticks_usec() - int(current.at_usec) < 5000000: return ""
	if process_frames - int(current.process_frames) < 30: return ""
	if post_draws == int(current.post_draws): return "process_frames_advanced_without_post_draw_signal_for_5s"
	if post_draws - int(current.post_draws) >= 10: return "post_draw_signals_advanced_without_draw_coroutine_resume_for_5s"
	return ""
