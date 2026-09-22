extends SceneTree
## 实际渲染 QA 工具，不是自动 mechanics 入口。截图输出 /Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/预览与验证/clash-maintenance-render。
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--status-migration" in OS.get_cmdline_user_args():
		await _status_migration()
		return
	DirAccess.make_dir_recursive_absolute(preload("res://tools/lib/development_paths.gd").output("clash-maintenance-render"))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_local()
	main._ai.enabled = false
	main._minion_waves_enabled = false
	var left: Unit = main._spawn_unit(0, "garen", Vector2(260, 920), 0.0)
	var right: Unit = main._spawn_unit(1, "garen", Vector2(260, 790), 0.0)
	main._spawn_unit(0, "missfortune", Vector2(450, 1000), 0.0)
	main._spawn_unit(1, "garen", Vector2(450, 800), 0.0)
	var gnar: Unit = main._spawn_unit(0, "gnar", Vector2(550, 950), 0.0)
	main._spawn_unit(1, "aurelionsol", Vector2(480, 450), 0.0)
	await create_timer(1.2).timeout
	await _capture("01_attack")
	left.freeze(1.5)
	right.stun(1.5)
	gnar.transform_to_mega()
	await create_timer(0.5).timeout
	await _capture("02_control_transform")
	left.take_damage(99999.0)
	await create_timer(0.25).timeout
	await _capture("03_control_death")
	await create_timer(1.2).timeout
	await _capture("04_recovery")
	print("[渲染 QA] 四个实际渲染帧已保存")
	quit()

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preload("res://tools/lib/development_paths.gd").output("clash-maintenance-render/") + label + ".png")

## 正式战斗入口驱动状态改造的双方动作/混音配方，不复制伤害实现。
func _status_migration() -> void:
	var output := preload("res://tools/lib/development_paths.gd").output("status-migration")
	DirAccess.make_dir_recursive_absolute(output)
	print("[STATUS_REVIEW_OUTPUT] ", output)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_local()
	while not main._match_started: await process_frame
	main.set_process(false)
	main._ai.enabled = false
	main._minion_waves_enabled = false
	for tower in main._towers: tower.can_attack = false
	var recorder := AudioEffectRecord.new()
	var slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, recorder)
	main._audio_manager.cue_played.connect(func(card, cue, _pos): print("[STATUS_CUE] ", card, " ", cue))
	print("[STATUS_AUDIO] output=", AudioServer.output_device, " enabled=", AudioServer.is_bus_effect_enabled(0, slot))
	await create_timer(0.2).timeout
	var cards: Array = ["garen", "sett", "gwen", "gnar", "aurelionsol", "ashe", "twisted_fate", "apex_turret", "xin", "rift_herald", "masteryi", "missfortune", "aatrox", "anivia"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cards="): cards.assign(arg.trim_prefix("--cards=").split(","))
	for card in cards:
		if CardDB.get_card(card).is_empty():
			push_error("未知预览卡牌：" + str(card))
			main.free()
			quit(1)
			return
	for team in [0, 1]:
		for card in cards:
			for unit in get_nodes_in_group("combatants"):
				if unit is Unit: unit.free()
			main._commands.impacts.clear()
			main._active_skill_effect_system.clear()
			main._projectile_system.clear_all()
			main._audio_manager.clear_zone_audio()
			await process_frame
			var source: Unit = main._spawn_unit(team, card, Vector2(360, 940), 0)
			var target: Unit = main._spawn_unit(1 - team, "garen", Vector2(360, 815), 0)
			target.max_hp = 100000
			target.hp = 100000
			target.freeze(100)
			var skills := CardDB.active_skills_for(card)
			var skill: Dictionary = skills[0].duplicate(true) if not skills.is_empty() else {}
			if card == "garen": skill = skills[1].duplicate(true)
			if not skill.is_empty():
				skill["cast_forward"] = Vector2.UP
				source.configure_carried_active_skill(skill)
				source.skill_resource_value = source.skill_resource_max
			recorder.set_recording_active(true)
			if not skill.is_empty() and "--no-skill" not in OS.get_cmdline_user_args(): main._start_active_skill_cast(source, skill)
			var label := "%s-%s" % ["blue" if team == 0 else "red", card]
			for tick in 62:
				if tick == 5: source.stun(0.6)
				if tick == 11:
					source.freeze(0.6)
					source.apply_knockback(source.position + Vector2.LEFT * 40, 45, 0.4)
				main._sim_step(0.05)
				main._active_skill_effect_system.tick_visuals(0.05)
				main._effects_view.queue_redraw()
				await create_timer(0.05).timeout
				if tick in [4, 9, 12, 21, 40, 61]:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.path_join(label + "-%02d.png" % tick))
			print("[STATUS_MIX] active=", recorder.is_recording_active(), " last_mix=", AudioServer.get_time_since_last_mix(), " peak=", AudioServer.get_bus_peak_volume_left_db(0, 0))
			recorder.set_recording_active(false)
			await create_timer(0.1).timeout
			var wav := recorder.get_recording()
			if wav != null: wav.save_to_wav(output.path_join(label + ".wav"))
			print("[STATUS_REVIEW] ", label, " hp=", source.hp if is_instance_valid(source) else -1, " form=", source.form_index if is_instance_valid(source) else -1, " target_hp=", target.hp)
	AudioServer.remove_bus_effect(0, slot)
	main.free()
	await create_timer(0.25).timeout
	quit()
