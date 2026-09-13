extends SceneTree
## 实际运行冰风暴起止音并录制主混音；同时观察盖伦正式下卡绕出水晶。
## Godot --path . --script tools/demos/card_playtest_fixes_preview.gd
## 输出 /tmp/clash-card-playtest-fixes/；记录仅用于人工验收，不驱动任何结算。
const OUTPUT := "/tmp/clash-card-playtest-fixes"
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_local()
	main._ai.enabled = false
	main._minion_waves_enabled = false
	for tower in main._towers:
		tower.can_attack = false
	main.play_card(0, "garen", Vector2(340, 1260), {"immediate": true})
	main.play_card(0, "anivia", Vector2(380, 820), {"immediate": true})
	var anivia: Unit
	for combatant in get_nodes_in_group("combatants"):
		if combatant is Unit and combatant.card_id == "anivia":
			anivia = combatant
	await create_timer(1.1).timeout
	var record := AudioEffectRecord.new()
	var effect_index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	main.preview_active_skill(anivia, CardDB.active_skills_for("anivia")[0])
	await create_timer(1.0).timeout
	await _capture("storm_active")
	await create_timer(5.0).timeout
	record.set_recording_active(false)
	var recording := record.get_recording()
	if recording != null:
		recording.save_to_wav(OUTPUT + "/anivia_live_mix.wav")
	AudioServer.remove_bus_effect(0, effect_index)
	await _capture("storm_ended_garen_escaped")
	main.queue_free()
	await process_frame
	quit()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "/" + label + ".png")
