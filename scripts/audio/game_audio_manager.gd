class_name GameAudioManager
extends Node2D
## 纯表现音频入口：轮询权威/快照中的动作序号并播放声音，但绝不参与模拟。

signal cue_played(card_id: String, cue: StringName, position: Vector2)

const COMBAT_BUS := &"Combat"
const WORLD_PLAYER_COUNT := 24
const WORLD_MAX_DISTANCE := 1100.0
const WORLD_ATTENUATION := 0.55
const WORLD_PANNING_STRENGTH := 0.35

var _world_players: Array[AudioStreamPlayer2D] = []
var _unit_entries: Dictionary = {}
var _stream_pool_cache: Dictionary = {}
var _preview_hit_queue: Array[Dictionary] = []
var _preview_serials: Dictionary = {}
var _recycle_cursor := 0

func _ready() -> void:
	process_priority = 20
	for index in range(WORLD_PLAYER_COUNT):
		var player := AudioStreamPlayer2D.new()
		player.name = "CombatVoice%02d" % index
		player.bus = COMBAT_BUS
		player.max_distance = WORLD_MAX_DISTANCE
		player.attenuation = WORLD_ATTENUATION
		player.panning_strength = WORLD_PANNING_STRENGTH
		add_child(player)
		_world_players.append(player)

func attach_unit(unit: Unit, stats: Dictionary) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var audio = stats.get("audio", {})
	if not audio is Dictionary or (audio as Dictionary).is_empty():
		return
	_unit_entries[unit.get_instance_id()] = {
		"unit_ref": weakref(unit),
		"card_id": unit.card_id,
		"audio": (audio as Dictionary).duplicate(true),
		"last_attack_serial": _attack_serial(unit),
	}

func _process(delta: float) -> void:
	_tick_attached_units()
	_tick_preview_hits(delta)

func _tick_attached_units() -> void:
	var stale_ids: Array = []
	for instance_id in _unit_entries:
		var entry: Dictionary = _unit_entries[instance_id]
		var unit = (entry.unit_ref as WeakRef).get_ref()
		if not unit is Unit or not is_instance_valid(unit):
			stale_ids.append(instance_id)
			continue
		var serial := _attack_serial(unit as Unit)
		if serial == int(entry.last_attack_serial):
			continue
		entry.last_attack_serial = serial
		_unit_entries[instance_id] = entry
		if serial > 0:
			_play_attack_swing(String(entry.card_id), entry.audio, (unit as Unit).get_visual_screen_position(), serial)
	for instance_id in stale_ids:
		_unit_entries.erase(instance_id)

func _attack_serial(unit: Unit) -> int:
	if unit.battle_context != null and unit.battle_context.is_net_client():
		return unit.net_attack_visual_serial
	return unit.get_attack_visual_serial()

## 真实伤害结算成功后由 Main 调用。position 是命中点，来源单位只用于选择声音配置。
func play_attack_hit(unit: Unit, position: Vector2) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	var entry: Dictionary = _unit_entries.get(unit.get_instance_id(), {})
	if entry.is_empty():
		return false
	var audio: Dictionary = entry.audio
	return _play_pool(
		String(entry.card_id),
		&"attack_hit",
		audio.get("attack_hit", []),
		position,
		float(audio.get("attack_hit_volume_db", -4.0))
	)

## 开发面板专用试听：复用正式随机池与 first_hit 时序，但不创建攻击或伤害。
func preview_attack(card_id: String, stats: Dictionary, position: Vector2) -> bool:
	var audio = stats.get("audio", {})
	if not audio is Dictionary or (audio as Dictionary).is_empty():
		return false
	var serial := int(_preview_serials.get(card_id, 0)) + 1
	_preview_serials[card_id] = serial
	var played := _play_attack_swing(card_id, audio as Dictionary, position, serial)
	if played:
		_preview_hit_queue.append({
			"card_id": card_id,
			"audio": (audio as Dictionary).duplicate(true),
			"position": position,
			"time_left": maxf(float(stats.get("first_hit", 0.0)), 0.0),
		})
	return played

func _tick_preview_hits(delta: float) -> void:
	var waiting: Array[Dictionary] = []
	for pending in _preview_hit_queue:
		pending.time_left = maxf(float(pending.time_left) - maxf(delta, 0.0), 0.0)
		if float(pending.time_left) > 0.001:
			waiting.append(pending)
			continue
		var audio: Dictionary = pending.audio
		_play_pool(
			String(pending.card_id),
			&"attack_hit",
			audio.get("attack_hit", []),
			pending.position,
			float(audio.get("attack_hit_volume_db", -4.0))
		)
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

func _play_pool(card_id: String, cue: StringName, configured: Variant, position: Vector2, volume_db: float) -> bool:
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
