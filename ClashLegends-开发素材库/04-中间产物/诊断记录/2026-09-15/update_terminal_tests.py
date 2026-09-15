from pathlib import Path
p=Path('tests/suites/terminal_audio_suite.gd');old=p.read_text();helper=old[old.index('func _check_tower_only_results'):];p.write_text('''extends "res://tests/suites/battle_suite.gd"

func _stream(seconds: float) -> AudioStreamRandomizer:
	var wav := AudioStreamWAV.new()
	wav.mix_rate = 22050
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	var samples := PackedByteArray()
	samples.resize(roundi(seconds * 44100))
	wav.data = samples
	var pool := AudioStreamRandomizer.new()
	pool.add_stream(0, wav)
	return pool

func run(harness: Object, main: Node2D) -> void:
	_harness = harness
	_main = main
	var audio := GameAudioManager.new()
	main.add_child(audio)
	audio.set_process(false)
	var cues: Array[StringName] = []
	audio.cue_played.connect(func(card, cue, _position):
		if card == "match": cues.append(cue))
	for tower in [main._king_player, main._king_enemy]:
		var event: Dictionary = audio._card_audio(PresentationConfig.world_card_id(tower)).events.death
		audio._stream_pool_cache["\\n".join(PackedStringArray(event.pool))] = _stream(12.0)
	for cue in ["victory", "defeat"]:
		var event: Dictionary = preload("res://scripts/data/match_audio.gd").EVENTS[cue]
		audio._stream_pool_cache["\\n".join(PackedStringArray(event.pool))] = _stream(0.1)
	for tower in [main._king_player, main._king_enemy]:
		audio.begin_battle()
		cues.clear()
		audio.play_nexus_destruction(tower)
		var player: AudioStreamPlayer2D = audio._nexus_players.values()[0]
		audio._tick_terminal_audio(0.75)
		var cue := "defeat" if tower.team == 0 else "victory"
		audio.finish_match_audio(cue, [tower])
		audio._tick_terminal_audio(4.249)
		_expect(cues.is_empty() and player.playing, "红蓝水晶爆炸4.999秒前不播结果，终态不重启爆炸计时")
		audio._tick_terminal_audio(0.001)
		_expect(cues == [StringName(cue)] and player.playing, "红蓝爆炸第五秒播报结果并保留爆炸尾音")
		audio.finish_match_audio(cue, [tower])
		var deadline := Time.get_ticks_msec() + 3000
		while audio._terminal_phase == "announcing" and Time.get_ticks_msec() < deadline:
			await harness.create_timer(0.02).timeout
		_expect(audio._terminal_phase == "fading" and is_equal_approx(audio._terminal_fade_remaining, 1.0), "真实播报播放器自然结束后启动1秒淡出")
		var initial_db := player.volume_db
		audio._tick_terminal_audio(0.5)
		_expect(player.playing and absf(player.volume_db - initial_db - linear_to_db(0.5)) < 0.01, "淡出半秒保留声音并降至一半振幅")
		audio._tick_terminal_audio(0.5)
		_expect(not player.playing and player.stream == null and not audio._terminal_audio_pending and cues.size() == 1, "一秒淡出完成全部静音，重复终态不重播")
	# 退出菜单或开始新局后，旧爆炸和旧播报回调均不能触发结果或淡出。
	audio.begin_battle()
	cues.clear()
	audio.finish_match_audio("defeat", [main._king_enemy])
	var stale: AudioStreamPlayer2D = audio._nexus_players.values()[0]
	var generation := audio._terminal_audio_generation
	audio.end_battle()
	audio._on_nexus_finished(main._king_enemy.get_instance_id(), stale, generation)
	audio._on_result_announcement_finished(generation)
	audio._tick_terminal_audio(10.0)
	_expect(cues.is_empty() and not audio._terminal_audio_pending, "菜单清理取消第五秒播报及旧淡出回调")
	audio.begin_battle()
	audio.definition_lookup = func(_id): return {"audio": {"events": {}}}
	audio.finish_match_audio("defeat", [main._king_enemy])
	_expect(cues == [&"defeat"], "爆炸资源缺失直接播报，不永久等待")
	audio.begin_battle()
	cues.clear()
	audio.finish_match_audio("", [])
	_expect(cues.is_empty() and not audio._terminal_audio_pending, "平局不伪造胜利或失败语音")
	audio.free()
	_check_tower_only_results()

'''+helper)
p=Path('tests/suites/terminal_state_suite.gd');s=p.read_text().replace('客户端爆炸未结束前不播失败','客户端爆炸第五秒前不播失败').replace('\t\tplayer.finished.emit() # 生命周期单元测试：自然结束信号，真实混音另测。','\t\tmain._audio_manager._tick_terminal_audio(5.0)\n\t\tplayer.finished.emit() # 第五秒播报后，爆炸自然结束不重复播报。').replace('自然结束只触发一次本地阵营失败播报','爆炸第五秒只触发一次本地阵营失败播报');p.write_text(s)
