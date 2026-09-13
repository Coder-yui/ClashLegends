class_name GameAudioManager
extends Node2D
## 纯表现音频入口：轮询权威/快照中的动作序号并播放声音，但绝不参与模拟。

signal cue_played(card_id: String, cue: StringName, position: Vector2)

const COMBAT_BUS := &"Combat"
const WORLD_PLAYER_COUNT := 24
const SUSTAIN_PLAYER_COUNT := 24
const WORLD_MAX_DISTANCE := 1100.0
const WORLD_ATTENUATION := 0.55
const WORLD_PANNING_STRENGTH := 0.35

var _announcer: AudioStreamPlayer
var _building_audio: Dictionary = {}
var _building_damage_audio: Dictionary = {}

var _world_players: Array[AudioStreamPlayer2D] = []
var _projectile_launch_players: Dictionary = {}
var _last_projectile_launch_id := -1
var _sustain_players: Dictionary = {}
var _unit_entries: Dictionary = {}
var _stream_pool_cache: Dictionary = {}
var _preview_hit_queue: Array[Dictionary] = []
var _preview_serials: Dictionary = {}
var _recycle_cursor := 0
var _zone_players: Dictionary = {}
var _last_zone_event_id := -1
var _played_attack_groups: Dictionary = {}

func _exit_tree() -> void:
	if is_instance_valid(_announcer):
		_announcer.stop()
		_announcer.stream = null
	for id in _building_audio.keys():
		stop_building_audio(id)
	clear_projectile_launch_audio()
	clear_zone_audio()
	# 换场时主动释放音频线程的播放引用，而非等声音自然结束。
	for player in _world_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	for player in _sustain_players.values():
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_sustain_players.clear()
	_unit_entries.clear()
	_stream_pool_cache.clear()

func _ready() -> void:
	process_priority = 20
	for index in range(WORLD_PLAYER_COUNT):
		var player := _new_world_player()
		player.name = "CombatVoice%02d" % index
		add_child(player)
		_world_players.append(player)

func attach_unit(unit: Unit, stats: Dictionary) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var already_attached := _unit_entries.has(unit.get_instance_id())
	if not already_attached:
		# 新实例可能复用上局的 net_id；旧声音去重不能屏蔽新一局首次连击。
		var source_prefix := "%s:%s:" % [unit.net_id if unit.net_id >= 0 else unit.get_instance_id(), unit.card_id]
		for group_key in _played_attack_groups.keys():
			if String(group_key).begins_with(source_prefix):
				_played_attack_groups.erase(group_key)
	_stop_sustain(unit.get_instance_id())
	var audio = PresentationConfig.audio_for(stats, unit.team, unit.get_form_index())
	if audio.is_empty() and stats.get("transformed_stats", {}).get("audio", {}).is_empty():
		_unit_entries.erase(unit.get_instance_id())
		return
	_unit_entries[unit.get_instance_id()] = {
		"unit_ref": weakref(unit),
		"card_id": unit.card_id,
		"audio": audio,
		"stats": stats,
		"form": unit.get_form_index(),
		"last_attack_serial": unit.get_attack_visual_serial(),
		"last_swing_serial": unit.get_attack_visual_serial(),
		"shroud_active": false,
		"resource_full": unit.is_skill_resource_visible() and unit.get_skill_resource_ratio() >= 0.999,
		"last_empowered_serial": unit.get_empowered_attack_visual_serial(),
		"empowered_ready": unit.is_empowered_attack_ready_visual(),
		"action_serial": unit.get_visual_action_serial(),
		"active_action": &"",
		"active_buff": unit.get_active_buff_active_visual(),
		"continuous_active": false,
		"idle_active": false,
	}
	var death_callback := _on_unit_death.bind(unit.get_instance_id())
	if not unit.died.is_connected(death_callback):
		unit.died.connect(death_callback)
	var exit_callback := _detach_unit.bind(unit.get_instance_id())
	if not unit.tree_exiting.is_connected(exit_callback):
		unit.tree_exiting.connect(exit_callback)
	if not already_attached:
		play_event(unit, &"spawn:start", unit.get_visual_screen_position())
	# 生成时播放一次；重绑与晚到快照不补播已过去的部署声音。
	if not already_attached and unit._deploy_timer > 0.0 and unit.deploy_time - unit._deploy_timer <= 0.1:
		play_event(unit, &"deploy:start", unit.get_visual_screen_position())
		play_event(unit, &"deploy:voice", unit.get_visual_screen_position())

	# 定时复生过程由存活单位持有；死亡/销毁立即停止，结束不循环。
	if not already_attached and unit.hp > 0.0 and not unit.timed_revival_id.is_empty():
		_start_sustain(unit, _unit_entries[unit.get_instance_id()], &"revival", &"revival")

func _process(delta: float) -> void:
	_tick_building_damage_audio()
	_tick_building_audio(delta)
	_tick_attached_units()
	_tick_preview_hits(delta)

## 固定落地区域拥有自己的声音，施法者死亡/受控不终止已经生成的区域。
## 带 ID 的可靠通知只创建一次；生命周期与表现区域一样按秒推进。
func start_zone_audio(event_id: int, card_id: String, form: int, action: String, position: Vector2, duration: float) -> void:
	if event_id <= _last_zone_event_id:
		return
	_last_zone_event_id = event_id
	var events: Dictionary = PresentationConfig.for_form(PresentationConfig.audio_stats(card_id), form).get("audio", {}).get("events", {})
	var cue := StringName(action + ":zone_sustain")
	var event: Dictionary = events.get(String(cue), {})
	var ending: Dictionary = events.get(action + ":zone_end", {})
	if duration <= 0.0 or (event.is_empty() and ending.is_empty()):
		return
	if _zone_players.size() >= SUSTAIN_PLAYER_COUNT:
		_stop_zone_audio(_zone_players.keys()[0], false)
	var player := _new_world_player()
	player.bus = StringName(event.get("bus", "Combat"))
	player.volume_db = float(event.get("volume_db", 0.0))
	add_child(player)
	player.global_position = position
	player.stream = _randomized_stream(PackedStringArray(event.get("pool", [])))
	_zone_players[event_id] = {"player": player, "time_left": duration, "card_id": card_id, "action": action, "ending": ending, "position": position}
	if player.stream != null:
		player.finished.connect(func():
			if _zone_players.has(event_id):
				player.play()
		)
		player.play()
		cue_played.emit(card_id, cue, position)

func _tick_zone_audio(delta: float) -> void:
	for id in _zone_players.keys():
		_zone_players[id].time_left -= maxf(delta, 0.0)
		if float(_zone_players[id].time_left) <= 0.0001:
			_stop_zone_audio(id, true)

func _stop_zone_audio(event_id: int, natural_end: bool) -> void:
	var entry: Dictionary = _zone_players.get(event_id, {})
	if entry.is_empty():
		return
	_zone_players.erase(event_id)
	var player: AudioStreamPlayer2D = entry.player
	player.stop()
	player.stream = null
	player.queue_free()
	if natural_end:
		var ending: Dictionary = entry.ending
		_play_pool(entry.card_id, StringName(entry.action + ":zone_end"), ending.get("pool", []), entry.position, float(ending.get("volume_db", 0.0)), StringName(ending.get("bus", "Combat")))

func clear_zone_audio() -> void:
	for id in _zone_players.keys():
		_stop_zone_audio(id, false)

func _tick_attached_units() -> void:
	var stale_ids: Array = []
	for instance_id in _unit_entries:
		var entry: Dictionary = _unit_entries[instance_id]
		var unit = (entry.unit_ref as WeakRef).get_ref()
		if not unit is Unit or not is_instance_valid(unit):
			stale_ids.append(instance_id)
			continue
		if int(entry.form) != unit.get_form_index():
			_stop_sustain(instance_id)
			entry.form = unit.get_form_index()
			entry.audio = PresentationConfig.audio_for(entry.stats, unit.team, entry.form)
			entry.active_action = &""
			entry.action_serial = -1
			entry.active_buff = false
			entry.continuous_active = false
			entry.idle_active = false
		var state: UnitPresentationState = unit.presentation_state()
		var idle := state.behavior == 1 and state.action_time_left <= 0.0 and not state.dead
		if idle and not bool(entry.idle_active):
			_start_sustain(unit, entry, &"idle", &"idle")
		elif not idle and bool(entry.idle_active):
			_stop_sustain(instance_id, &"idle")
		entry.idle_active = idle

		# 和模型读取同一持续目标视图，客户端只消费现有快照。
		# 控制期间保留音轨所有权并暂停；技能、丢失目标和死亡释放。
		var controlled := state.frozen or state.stunned
		var breathing: bool = unit.has_continuous_visual_target() and not controlled and not state.dead and state.action_time_left <= 0.0
		if controlled and bool(entry.continuous_active) and not state.dead and state.action_time_left <= 0.0:
			breathing = true
		if breathing and not bool(entry.continuous_active):
			play_event(unit, &"continuous_attack:start", unit.get_visual_screen_position())
			play_event(unit, &"continuous_attack:release", unit.get_visual_screen_position())
			_start_sustain(unit, entry, &"continuous_attack", &"attack")
		elif not breathing and bool(entry.continuous_active):
			_stop_sustain(instance_id, &"attack")
			play_event(unit, &"continuous_attack:end", unit.get_visual_screen_position())
		entry.continuous_active = breathing
		var serial := state.attack_serial
		var empowered_serial: int = unit.get_empowered_attack_visual_serial()
		var ready: bool = unit.is_empowered_attack_ready_visual()
		if ready and not bool(entry.empowered_ready):
			play_event(unit, &"empowered_ready", unit.get_visual_screen_position())
		if ready != bool(entry.empowered_ready):
			play_event(unit, &"empowered_buff:start" if ready else &"empowered_buff:end", unit.get_visual_screen_position())
		entry.empowered_ready = ready
		var swing_lead := float(entry.audio.get("attack_swing_lead_time", -1.0))
		var swing_delay := maxf(unit.first_hit_time - swing_lead, 0.0) if swing_lead >= 0.0 else 0.0
		var swing_due := state.attack_elapsed + 0.001 >= swing_delay
		if swing_delay > 0.0 and (state.dead or state.action_time_left > 0.0 or (state.behavior != 3 and not controlled)):
			entry.last_swing_serial = serial
		# 技能可在当前攻击前摇中强化这一击；同一个攻击序号也需要切换声音。
		if serial > 0 and empowered_serial == serial and empowered_serial != int(entry.last_empowered_serial):
			entry.last_swing_serial = serial
			if not play_event(unit, &"empowered_swing", unit.get_visual_screen_position()):
				_play_attack_swing(String(entry.card_id), entry.audio, unit.get_visual_screen_position(), serial)
		elif serial > 0 and serial != int(entry.last_swing_serial) and swing_due and (swing_delay <= 0.0 or not controlled):
			entry.last_swing_serial = serial
			if unit.is_attack_visual_first_strike():
				if not play_event(unit, &"first_strike:cast", unit.get_visual_screen_position()):
					_play_attack_swing(String(entry.card_id), entry.audio, unit.get_visual_screen_position(), serial)
			else:
				_play_attack_swing(String(entry.card_id), entry.audio, unit.get_visual_screen_position(), serial)
		entry.last_attack_serial = serial
		entry.last_empowered_serial = empowered_serial
		var action_serial := state.action_serial
		var action := state.action
		var active := state.action_time_left > 0.0
		if StringName(entry.active_action) != &"" and (not active or action_serial != int(entry.action_serial)):
			_stop_sustain(instance_id, &"action")
			play_event(unit, StringName(String(entry.active_action) + ":end"), unit.get_visual_screen_position())
			entry.active_action = &""
		if action_serial != int(entry.action_serial) and active:
			play_event(unit, StringName(String(action) + ":start"), unit.get_visual_screen_position())
			play_event(unit, StringName(String(action) + ":voice"), unit.get_visual_screen_position())
			_start_sustain(unit, entry, action)
			entry.active_action = action
		var active_buff := state.active_buff
		if active_buff and not bool(entry.active_buff):
			play_event(unit, &"active_buff:start", unit.get_visual_screen_position())
			_start_sustain(unit, entry, &"active_buff", &"buff")
		elif not active_buff and bool(entry.active_buff):
			_stop_sustain(instance_id, &"buff")
			play_event(unit, &"active_buff:end", unit.get_visual_screen_position())
		var full: bool = unit.is_skill_resource_visible() and unit.get_skill_resource_ratio() >= 0.999 and not state.dead
		if full and not bool(entry.resource_full):
			play_event(unit, &"resource_full", unit.get_visual_screen_position())
		entry.resource_full = full
		var shroud := state.shroud_active
		shroud = shroud and not state.dead
		if shroud and not bool(entry.shroud_active):
			play_event(unit, &"shroud:start", unit.get_visual_screen_position())
			_start_sustain(unit, entry, &"shroud", &"shroud")
		elif not shroud and bool(entry.shroud_active):
			_stop_sustain(instance_id, &"shroud")
			play_event(unit, &"shroud:end", unit.get_visual_screen_position())
		entry.shroud_active = shroud
		for layer in [&"action", &"buff", &"attack", &"shroud", &"revival", &"idle"]:
			var sustained: AudioStreamPlayer2D = _sustain_players.get(_sustain_key(instance_id, layer))
			if sustained != null:
				sustained.global_position = unit.get_visual_screen_position()
				sustained.stream_paused = layer != &"revival" and (unit.is_frozen() or unit.is_stunned())
		entry.active_buff = active_buff
		entry.action_serial = action_serial
		_unit_entries[instance_id] = entry
	for instance_id in stale_ids:
		_detach_unit(instance_id)

## 每单位 action/buff/attack 独立长音层；只有持续普攻片段结束后续播。
func _start_sustain(unit: Unit, entry: Dictionary, action: StringName, layer: StringName = &"action") -> void:
	var cue := StringName(String(action) + ":sustain")
	var event: Dictionary = entry.audio.get("events", {}).get(String(cue), {})
	if event.is_empty():
		return
	_stop_sustain(unit.get_instance_id(), layer)
	if _sustain_players.size() >= SUSTAIN_PLAYER_COUNT:
		_stop_sustain_key(_sustain_players.keys()[0])
	var player := _new_world_player()
	player.bus = StringName(event.get("bus", "Combat"))
	player.volume_db = float(event.get("volume_db", 0.0))
	player.stream = _randomized_stream(PackedStringArray(event.get("pool", [])))
	add_child(player)
	player.global_position = unit.get_visual_screen_position()
	var key := _sustain_key(unit.get_instance_id(), layer)
	_sustain_players[key] = player
	player.finished.connect(_on_sustain_finished.bind(key, player))
	player.play()
	cue_played.emit(String(entry.card_id), cue, player.global_position)

func _sustain_key(instance_id: int, layer: StringName = &"action") -> String:
	return "%d:%s" % [instance_id, layer]

func _stop_sustain(instance_id: int, layer: StringName = &"") -> void:
	for candidate in [&"action", &"buff", &"attack", &"shroud", &"revival", &"idle"] if layer == &"" else [layer]:
		_stop_sustain_key(_sustain_key(instance_id, candidate))

func _stop_sustain_key(key: String) -> void:
	var player: AudioStreamPlayer2D = _sustain_players.get(key)
	if player != null:
		player.stop()
		player.queue_free()
		_sustain_players.erase(key)

## 成功复生移除蛋时，沿用同一播放器播完尾音；不 seek、不重新触发。
func complete_revival(unit: Unit) -> void:
	var key := _sustain_key(unit.get_instance_id(), &"revival")
	var player: AudioStreamPlayer2D = _sustain_players.get(key)
	if player == null:
		return
	var tail_key := key + "_tail"
	player.finished.disconnect(_on_sustain_finished.bind(key, player))
	_sustain_players.erase(key)
	_sustain_players[tail_key] = player
	player.finished.connect(_on_sustain_finished.bind(tail_key, player))

func _detach_unit(instance_id: int) -> void:
	_stop_sustain(instance_id)
	_unit_entries.erase(instance_id)
func _on_unit_death(instance_id: int) -> void:
	_stop_sustain(instance_id)
	var entry: Dictionary = _unit_entries.get(instance_id, {})
	if entry.is_empty():
		return
	var unit = (entry.unit_ref as WeakRef).get_ref()
	if unit is Unit and is_instance_valid(unit):
		play_event(unit, &"death", unit.get_visual_screen_position())
	# 死亡不补播技能结束声；已释放单位也不会遗留轮询项。
	_unit_entries.erase(instance_id)

## 通用纯表现事件入口；未配置的事件保持静音，不猜测或替代技能素材。
func play_event(unit: Unit, cue: StringName, position: Vector2, attack_serial: int = -1) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	var entry: Dictionary = _unit_entries.get(unit.get_instance_id(), {})
	if entry.is_empty():
		return false
	var current_audio: Dictionary = PresentationConfig.audio_for(entry.stats, unit.team, unit.get_form_index())
	var event: Dictionary = current_audio.get("events", {}).get(String(cue), {})
	if event.is_empty() and String(cue).ends_with("_center"):
		event = current_audio.get("events", {}).get(String(cue).trim_suffix("_center"), {})
	if event.is_empty() and String(cue).trim_suffix("_center").get_slice(":", 1) in ["hit_first", "hit_middle", "hit_last"]:
		event = current_audio.get("events", {}).get(String(cue).get_slice(":", 0) + ":hit", {})
	if cue == &"attack_launch":
		var segments: Array = current_audio.get("attack_launch_by_segment", [])
		if not segments.is_empty():
			var serial := unit.presentation_state().attack_serial if attack_serial < 0 else attack_serial
			var index := posmod(maxi(serial, 1) - 1, segments.size())
			return _play_pool(String(entry.card_id), cue, segments[index], position, 0.0, &"Combat")
	return _play_pool(String(entry.card_id), cue, event.get("pool", []), position, float(event.get("volume_db", 0.0)), StringName(event.get("bus", "Combat")))
## 真实伤害结算成功后由 Main 调用。position 是命中点，来源单位只用于选择声音配置。
## first_strike 为权威攻击效果携带的首次命中标记；有专用素材时替换普通命中音。
func play_attack_hit(unit: Unit, position: Vector2, first_strike: bool = false) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	return play_attack_source(PresentationConfig.attack_source(unit), position, first_strike)

func play_attack_source(source: Dictionary, position: Vector2, first_strike: bool = false) -> bool:
	var card_id := String(source.get("card_id", ""))
	var stats := PresentationConfig.for_form(PresentationConfig.audio_stats(card_id), int(source.get("form", 0)))
	var audio: Dictionary = PresentationConfig.audio_for(stats, int(source.get("team", 0)))
	var cue := &"attack_hit"
	var configured = audio.get("attack_hit", [])
	var segments: Array = audio.get("attack_hit_by_segment", [])
	if not segments.is_empty() and int(source.get("serial", 0)) > 0:
		configured = segments[(int(source.serial) - 1) % segments.size()]
	if bool(source.get("empowered", false)) and not audio.get("empowered_hit", []).is_empty():
		configured = audio.empowered_hit
		cue = &"empowered_hit"
	var special = audio.get("first_strike_hit", [])
	if first_strike and special is Array and not special.is_empty():
		cue = &"first_strike_hit"
		configured = special
	var grouped: Array = audio.get("attack_hit_once_by_segment", [])
	var serial := int(source.get("serial", 0))
	var once := serial > 0 and not grouped.is_empty() and bool(grouped[(serial - 1) % grouped.size()])
	var group_key := "%s:%s:%s:%s" % [source.get("unit_id", -1), card_id, source.get("form", 0), serial]
	if once and _played_attack_groups.has(group_key):
		return false
	var played := _play_pool(card_id, cue, configured, position, float(audio.get("attack_hit_volume_db", -4.0)))
	if once and played:
		_played_attack_groups[group_key] = true
		if _played_attack_groups.size() > 512:
			_played_attack_groups.erase(_played_attack_groups.keys()[0])
	if played and cue == &"first_strike_hit":
		var event: Dictionary = audio.get("events", {}).get("first_strike:hit_location", {})
		_play_pool(card_id, &"first_strike:hit_location", event.get("pool", []), position, float(event.get("volume_db", 0.0)))
	return played

## 开发面板专用试听：复用正式随机池与 first_hit 时序，但不创建攻击或伤害。
func preview_attack(card_id: String, stats: Dictionary, position: Vector2) -> bool:
	var audio = stats.get("audio", {})
	if not audio is Dictionary or (audio as Dictionary).is_empty():
		return false
	var serial := int(_preview_serials.get(card_id, 0)) + 1
	_preview_serials[card_id] = serial
	var windup := maxf(float(stats.get("first_hit", 0.0)), 0.0)
	var lead := float(audio.get("attack_swing_lead_time", -1.0))
	var delay := maxf(windup - lead, 0.0) if lead >= 0.0 else 0.0
	var swings: Array = audio.get("attack_swing", [])
	if swings.is_empty():
		return false
	var swing_pool: Array = swings[(serial - 1) % swings.size()]
	_queue_preview_pool(card_id, &"attack_swing", swing_pool, position, delay, float(audio.get("attack_swing_volume_db", -5.0)))
	var speed := float(stats.get("projectile_speed", 0.0))
	if speed > 0.0:
		for cue in ["attack_missile_cast", "attack_launch"]:
			var event: Dictionary = audio.get("events", {}).get(cue, {})
			var launch_pool: Array = event.get("pool", [])
			var segments: Array = audio.get("attack_launch_by_segment", [])
			if cue == "attack_launch" and not segments.is_empty():
				launch_pool = segments[(serial - 1) % segments.size()]
			_queue_preview_pool(card_id, StringName(cue), launch_pool, position, windup, float(event.get("volume_db", 0.0)))
	var hits: Array = audio.get("attack_hit_by_segment", [])
	var hit_pool: Array = hits[(serial - 1) % hits.size()] if not hits.is_empty() else audio.get("attack_hit", [])
	# 无真实目标的试听用卡牌射程估算飞行时间；实战仍只由碰撞派发。
	var flight := maxf(float(stats.get("range", 0.0)), 0.0) / speed if speed > 0.0 else 0.0
	_queue_preview_pool(card_id, &"attack_hit", hit_pool, position, windup + flight, float(audio.get("attack_hit_volume_db", -4.0)))
	return true

func _queue_preview_pool(card_id: String, cue: StringName, pool: Array, position: Vector2, delay: float, volume: float) -> void:
	if pool.is_empty():
		return
	if delay <= 0.001:
		_play_pool(card_id, cue, pool, position, volume)
	else:
		_preview_hit_queue.append({"card_id": card_id, "cue": cue, "pool": pool, "position": position, "time_left": delay, "volume": volume})

func _tick_preview_hits(delta: float) -> void:
	var waiting: Array[Dictionary] = []
	for pending in _preview_hit_queue:
		pending.time_left = maxf(float(pending.time_left) - maxf(delta, 0.0), 0.0)
		if float(pending.time_left) > 0.001:
			waiting.append(pending)
			continue
		_play_pool(pending.card_id, pending.cue, pending.pool, pending.position, pending.volume)
	_preview_hit_queue.assign(waiting)

func _play_attack_swing(card_id: String, audio: Dictionary, position: Vector2, serial: int) -> bool:
	var configured = audio.get("attack_swing", [])
	if not configured is Array or (configured as Array).is_empty():
		return false
	var groups: Array = configured as Array
	var pool = groups[(serial - 1) % groups.size()]
	return _play_pool(
		card_id,
		&"attack_swing",
		pool,
		position,
		float(audio.get("attack_swing_volume_db", -5.0))
	)

## 弹体独占播放器，不占用/回收短音池，命中一枚只停止该枚的发射尾音。
func start_projectile_launch(id: int, source: Dictionary, position: Vector2) -> void:
	# 主机的弹体 ID 单调递增；可靠同通道保证开始/结束顺序，不依赖来源单位仍存活。
	if id <= _last_projectile_launch_id:
		return
	_last_projectile_launch_id = id
	var card_id := String(source.get("card_id", ""))
	var audio: Dictionary = PresentationConfig.for_form(PresentationConfig.audio_stats(card_id), int(source.get("form", 0))).get("audio", {})
	if not bool(audio.get("attack_launch_until_impact", false)):
		return
	var event: Dictionary = audio.get("events", {}).get("attack_launch", {})
	var pool: Array = event.get("pool", [])
	var segments: Array = audio.get("attack_launch_by_segment", [])
	if not segments.is_empty():
		pool = segments[posmod(maxi(int(source.get("serial", 1)), 1) - 1, segments.size())]
	if pool.is_empty():
		return
	if _projectile_launch_players.size() >= WORLD_PLAYER_COUNT:
		stop_projectile_launch(int(_projectile_launch_players.keys()[0]))
	var player := _new_world_player()
	player.bus = StringName(event.get("bus", COMBAT_BUS))
	player.volume_db = float(event.get("volume_db", 0.0)) if segments.is_empty() else 0.0
	player.stream = _randomized_stream(PackedStringArray(pool))
	add_child(player)
	player.global_position = position
	_projectile_launch_players[id] = player
	player.finished.connect(stop_projectile_launch.bind(id))
	player.play()
	cue_played.emit(card_id, &"attack_launch", position)

func stop_projectile_launch(id: int) -> void:
	var player = _projectile_launch_players.get(id)
	if is_instance_valid(player):
		player.stop()
		player.stream = null
		player.queue_free()
	_projectile_launch_players.erase(id)

func clear_projectile_launch_audio() -> void:
	for id in _projectile_launch_players.keys():
		stop_projectile_launch(int(id))

func _play_pool(card_id: String, cue: StringName, configured: Variant, position: Vector2, volume_db: float, bus: StringName = COMBAT_BUS) -> bool:
	if not configured is Array or (configured as Array).is_empty():
		return false
	var paths := PackedStringArray()
	for value in configured as Array:
		paths.append(String(value))
	var stream := _randomized_stream(paths)
	if stream == null:
		return false
	var player := _available_world_player()
	if player == null:
		return false
	player.global_position = position
	player.bus = bus
	player.volume_db = volume_db
	player.stream = stream
	player.play()
	cue_played.emit(card_id, cue, position)
	return true

func _randomized_stream(paths: PackedStringArray) -> AudioStreamRandomizer:
	var cache_key := "\n".join(paths)
	if _stream_pool_cache.has(cache_key):
		return _stream_pool_cache[cache_key] as AudioStreamRandomizer
	var randomizer := AudioStreamRandomizer.new()
	randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	for path in paths:
		var stream := load(path) as AudioStream
		if stream != null:
			randomizer.add_stream(-1, stream, 1.0)
	if randomizer.streams_count == 0:
		return null
	_stream_pool_cache[cache_key] = randomizer
	return randomizer

func _available_world_player() -> AudioStreamPlayer2D:
	for player in _world_players:
		if not player.playing:
			return player
	if _world_players.is_empty():
		return null
	var player := _world_players[_recycle_cursor % _world_players.size()]
	_recycle_cursor = (_recycle_cursor + 1) % _world_players.size()
	player.stop()
	return player

func play_card_event(card_id: String, cue: String, position: Vector2, form: int = 0) -> bool:
	var event: Dictionary = PresentationConfig.for_form(PresentationConfig.audio_stats(card_id), form).get("audio", {}).get("events", {}).get(cue, {})
	return _play_pool(card_id, StringName(cue), event.get("pool", []), position, float(event.get("volume_db", 0.0)), StringName(event.get("bus", "Combat")))

func _on_sustain_finished(key: String, player: AudioStreamPlayer2D) -> void:
	if _sustain_players.get(key) == player:
		# 持续普攻是无固定总时长的状态；重放完整循环片段，仍由状态退出清理。
		if key.ends_with(":attack") or key.ends_with(":shroud") or key.ends_with(":idle"):
			player.play()
			return
		_stop_sustain_key(key)

## 系统建筑的出生/待机独占播放器。时长与模型读取同一表现配置，不参与战斗模拟。
func attach_building_audio(tower: Tower, visual_config: Dictionary) -> void:
	var id := tower.get_instance_id()
	if _building_audio.has(id) or tower.hp <= 0.0:
		return
	var card_id := PresentationConfig.world_card_id(tower)
	var events: Dictionary = PresentationConfig.audio_stats(card_id).get("audio", {}).get("events", {})
	if events.has("damage:stage1") and not _building_damage_audio.has(id):
		_building_damage_audio[id] = {"source": weakref(tower), "card_id": card_id, "stage": PresentationConfig.structure_damage_stage(tower.hp, tower.max_hp)}
		tower.tree_exiting.connect(_detach_building_damage_audio.bind(id))
	if not events.has("spawn:start") and not events.has("idle:sustain"):
		return
	if _building_audio.size() >= SUSTAIN_PLAYER_COUNT:
		return
	var player := _new_world_player()
	add_child(player)
	var entry := {"source": weakref(tower), "player": player, "card_id": card_id, "events": events,
		"remaining": float(visual_config.get("animations", {}).get("spawn_duration", 0.0)),
		"hold": float(visual_config.get("animations", {}).get("spawn_hold_duration", 0.0)), "idle": false, "fade": 0.0, "tail": null}
	_building_audio[id] = entry
	tower.tree_exiting.connect(stop_building_audio.bind(id))
	if float(entry.hold) <= 0.0:
		_play_building_phase(entry, &"spawn:start")

func _play_building_phase(entry: Dictionary, cue: StringName) -> void:
	var player: AudioStreamPlayer2D = entry.player
	player.stop()
	var event: Dictionary = entry.events.get(String(cue), {})
	var paths := PackedStringArray(event.get("pool", []))
	if paths.is_empty():
		return
	player.stream = _randomized_stream(paths)
	player.volume_db = float(event.get("volume_db", 0.0))
	player.global_position = entry.source.get_ref().global_position
	player.play()
	cue_played.emit(entry.card_id, cue, player.global_position)

func _tick_building_audio(delta: float) -> void:
	for id in _building_audio.keys():
		var entry: Dictionary = _building_audio[id]
		var source = entry.source.get_ref()
		if not is_instance_valid(source) or source.hp <= 0.0:
			stop_building_audio(id)
			continue
		if float(entry.hold) > 0.0:
			entry.hold = maxf(0.0, float(entry.hold) - delta)
			if float(entry.hold) <= 0.000001:
				entry.hold = 0.0
				_play_building_phase(entry, &"spawn:start")
			continue
		var player: AudioStreamPlayer2D = entry.player
		player.global_position = source.global_position
		if not entry.idle:
			entry.remaining = maxf(0.0, float(entry.remaining) - delta)
			if entry.remaining <= 0.000001:
				entry.idle = true
				entry.tail = entry.player
				var incoming := _new_world_player()
				add_child(incoming)
				entry.player = incoming
				entry.fade = 1.5
				_play_building_phase(entry, &"idle:sustain")
				incoming.volume_db = -80.0
		elif not player.playing and entry.events.has("idle:sustain"):
			_play_building_phase(entry, &"idle:sustain")

		if entry.idle and float(entry.fade) > 0.0:
			entry.fade = maxf(0.0, float(entry.fade) - delta)
			var progress := 1.0 - float(entry.fade) / 1.5
			var incoming: AudioStreamPlayer2D = entry.player
			var target_db := float(entry.events.get("idle:sustain", {}).get("volume_db", 0.0))
			incoming.volume_db = lerpf(0.0, target_db, progress) + linear_to_db(maxf(minf(progress * 6.0, 1.0), 0.0001))
			var tail: AudioStreamPlayer2D = entry.tail
			if is_instance_valid(tail):
				tail.volume_db = float(entry.events.get("spawn:start", {}).get("volume_db", 0.0)) + linear_to_db(maxf(1.0 - progress, 0.0001))
				if entry.fade <= 0.000001:
					tail.stop()
					tail.stream = null
					tail.queue_free()
					entry.tail = null

func stop_building_audio(id: int) -> void:
	if not _building_audio.has(id):
		return
	var tail = _building_audio[id].get("tail")
	if is_instance_valid(tail):
		tail.stop()
		tail.stream = null
		tail.queue_free()
	var player: AudioStreamPlayer2D = _building_audio[id].player
	player.stop()
	player.stream = null
	player.queue_free()
	_building_audio.erase(id)

func _tick_building_damage_audio() -> void:
	for id in _building_damage_audio.keys():
		var entry: Dictionary = _building_damage_audio[id]
		var source = entry.source.get_ref()
		if not is_instance_valid(source) or source.hp <= 0.0:
			_building_damage_audio.erase(id)
			continue
		var stage := PresentationConfig.structure_damage_stage(source.hp, source.max_hp)
		if stage > int(entry.stage):
			entry.stage = stage
			play_card_event(entry.card_id, "damage:stage%d" % stage, source.global_position)

func _detach_building_damage_audio(id: int) -> void:
	_building_damage_audio.erase(id)


## 全局中文播报：无空间衰减；结尾可替换尚未结束的开局播报。
func play_match_event(cue: String) -> void:
	var event: Dictionary = preload("res://scripts/data/match_audio.gd").EVENTS.get(cue, {})
	if event.is_empty(): return
	if not is_instance_valid(_announcer):
		_announcer = AudioStreamPlayer.new()
		_announcer.bus = &"Voice"
		add_child(_announcer)
	_announcer.stop()
	_announcer.stream = _randomized_stream(PackedStringArray(event.pool))
	_announcer.volume_db = float(event.get("volume_db", 0.0))
	_announcer.play()
	cue_played.emit("match", StringName(cue), Vector2.ZERO)

## 所有空间声音共用相同衰减；调用方继续拥有播放器的挂载与生命周期。
func _new_world_player() -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.bus = COMBAT_BUS
	player.max_distance = WORLD_MAX_DISTANCE
	player.attenuation = WORLD_ATTENUATION
	player.panning_strength = WORLD_PANNING_STRENGTH
	return player
