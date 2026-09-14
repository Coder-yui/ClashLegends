extends SceneTree
## 太阳圆盘实际战场渲染验收：Spawn 遮挡、塔墟部署、弹体起点与死亡末帧。

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	main._start_art_dev()
	main._art_dev_panel.hide()

	var ruined_tower: Tower = main._towers[0]
	ruined_tower.take_damage(ruined_tower.max_hp + 1.0)
	for _frame in range(150):
		await process_frame

	var ruined_disc: Unit = main._spawn_card_units(0, "sun_disc", ruined_tower.position)[0]
	var normal_disc: Unit = main._spawn_card_units(1, "sun_disc", Vector2(580.0, 380.0))[0]
	main._spawn_unit(1, "aurelionsol", Vector2(140.0, 770.0), 0.0)
	var projectile_target: Unit = main._spawn_unit(0, "melee_minion", Vector2(580.0, 620.0), 0.0)
	for _frame in range(12):
		await process_frame
	_save_viewport(preload("res://tools/lib/development_paths.gd").output("sun_disc_spawn_early_qa.png"))
	for _frame in range(24):
		await process_frame
	_save_viewport(preload("res://tools/lib/development_paths.gd").output("sun_disc_spawn_mid_qa.png"))

	normal_disc._deploy_timer = 0.0
	await create_timer(0.15).timeout
	main._projectile_system.launch(
		normal_disc, projectile_target, 1.0, normal_disc.projectile_speed,
		0.0, 0.0, normal_disc.projectile_color
	)
	await process_frame
	_save_viewport(preload("res://tools/lib/development_paths.gd").output("sun_disc_projectile_origin_qa.png"))
	for _frame in range(40):
		await process_frame
	_save_viewport(preload("res://tools/lib/development_paths.gd").output("sun_disc_battle_qa.png"))

	normal_disc.take_damage(normal_disc.max_hp + 1.0)
	await create_timer(0.08).timeout
	_save_viewport(preload("res://tools/lib/development_paths.gd").output("sun_disc_death_start_qa.png"))
	await create_timer(0.72).timeout
	_save_viewport(preload("res://tools/lib/development_paths.gd").output("sun_disc_death_late_qa.png"))
	await create_timer(0.35).timeout
	_save_viewport(preload("res://tools/lib/development_paths.gd").output("sun_disc_death_end_qa.png"))
	# 塔墟圆盘仍在场，证明普通圆盘死亡没有影响真实塔墟。
	assert(is_instance_valid(ruined_disc) and ruined_disc.hp > 0.0)
	quit()


func _save_viewport(path: String) -> void:
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	if error == OK:
		print("[太阳圆盘 QA] 已保存 ", path)
	else:
		push_error("太阳圆盘 QA 保存失败：%s" % path)
