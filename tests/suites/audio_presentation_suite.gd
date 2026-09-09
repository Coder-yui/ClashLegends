class_name AudioPresentationSuite
extends RefCounted

func run(harness: Object, main: Node2D) -> void:
	var audio: GameAudioManager = main._audio_manager
	var cues: Array[StringName] = []
	var on_cue := func(card_id: String, cue: StringName, _position: Vector2):
		if card_id == "garen":
			cues.append(cue)
	audio.cue_played.connect(on_cue)
	var stats := CardDB.get_card("garen")
	var previewed := audio.preview_attack("garen", stats, Vector2(360.0, 640.0))
	audio._process(float(stats.first_hit) + 0.01)
	var preview_timeline_ok := previewed and cues == [&"attack_swing", &"attack_hit"]

	var unit := Unit.new()
	unit.card_id = "garen"
	unit.setup(0, stats, stats.name)
	main.add_child(unit)
	audio.attach_unit(unit, stats)
	unit._attack_visual_serial = 1
	audio._process(0.0)
	var real_start_ok := cues.count(&"attack_swing") == 2
	var hp_before := unit.hp
	var real_hit_ok := audio.play_attack_hit(unit, Vector2(360.0, 600.0)) and cues.count(&"attack_hit") == 2
	harness._expect(
		preview_timeline_ok and real_start_ok and real_hit_ok and is_equal_approx(unit.hp, hp_before)
		and main.has_method("_rpc_attack_audio_hit"),
		"音频表现按攻击序号播放挥击、按命中事件播放冲击，开发面板试听不修改权威状态且客户端有独立重放入口",
	)
	audio.cue_played.disconnect(on_cue)
	unit.free()
