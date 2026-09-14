extends "res://tests/suites/battle_suite.gd"

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var audio := GameAudioManager.new()
	main.add_child(audio)
	var cues: Array[StringName] = []
	audio.cue_played.connect(func(card, cue, _position):
		if card == "match": cues.append(cue))
	# 短 WAV 只替代本用例混音输入；仍使用真实 AudioStreamPlayer 的自然 finished。
	for tower in [main._king_player, main._king_enemy]:
		var card := PresentationConfig.world_card_id(tower)
		var event: Dictionary = audio._card_audio(card).events.death
		var wav := AudioStreamWAV.new()
		wav.mix_rate = 22050
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		var samples := PackedByteArray()
		samples.resize(4410 if tower.team == 0 else 8820)
		wav.data = samples
		var randomizer := AudioStreamRandomizer.new()
		randomizer.add_stream(0, wav)
		audio._stream_pool_cache["\n".join(PackedStringArray(event.pool))] = randomizer
	audio.play_nexus_destruction(main._king_enemy)
	var existing: AudioStreamPlayer2D = audio._nexus_players.values()[0]
	audio.finish_match_audio("victory", [main._king_player, main._king_enemy])
	_expect(audio._nexus_players.size() == 2 and audio._nexus_players[main._king_enemy.get_instance_id()] == existing and existing.playing, "终局沿用已播放爆炸实例，并等待本次双方爆炸音轨")
	_expect(cues.is_empty(), "爆炸未自然结束不播结果")
	audio.finish_match_audio("victory", [main._king_enemy])
	var deadline := Time.get_ticks_msec() + 3000
	while cues.is_empty() and Time.get_ticks_msec() < deadline:
		await harness.create_timer(0.02).timeout
	_expect(cues == [&"victory"] and audio._nexus_players.is_empty(), "所有真实播放器自然结束立即触发一次胜利播报")
	audio.finish_match_audio("victory", [main._king_enemy])
	_expect(cues.size() == 1, "重复终态不重复自然结束序列")
	audio.begin_battle()
	cues.clear()
	audio.finish_match_audio("defeat", [main._king_enemy])
	var stale: AudioStreamPlayer2D = audio._nexus_players.values()[0]
	var generation := audio._terminal_audio_generation
	audio.end_battle()
	audio._on_nexus_finished(main._king_enemy.get_instance_id(), stale, generation)
	_expect(cues.is_empty() and not audio._terminal_audio_pending, "主动停止/菜单清理取消序列，旧 finished 回调失效")
	audio.begin_battle()
	audio.definition_lookup = func(_id): return {"audio": {"events": {}}}
	audio.finish_match_audio("defeat", [main._king_enemy])
	_expect(cues == [&"defeat"], "缺少爆炸资源记录诊断并直接播报，不永久等待")
	audio.begin_battle()
	cues.clear()
	audio.finish_match_audio("", [main._king_player, main._king_enemy])
	_expect(cues.is_empty() and not audio._terminal_audio_pending, "双水晶平局无胜利或失败语音")
	audio.free()
