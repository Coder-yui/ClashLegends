extends SceneTree
## 四类兵/双阵营使用正式 play_card/技能窗口，记录强化、控制、到期与死亡。
var OUTPUT := preload("res://tools/lib/development_paths.gd").output("clash-baron-minions")
const CARDS := ["melee_minion", "ranged_minion", "siege_minion", "super_minion"]
var _main: Node2D
var _units: Array[Unit] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main
	_main._start_local()
	_main._ai.enabled = false
	_main._minion_waves_enabled = false
	for tower in _main._towers:
		tower.can_attack = false
	for team in [0, 1]:
		for i in range(4):
			_main.play_card(team, CARDS[i], Vector2(115 + i * 163, 790 if team == 0 else 440), {"immediate": true, "validate_position": false})
	await create_timer(1.1).timeout
	for team in [0, 1]:
		for card in CARDS:
			var unit: Unit = _main._latest_unit_for_card(card, team)
			unit.move_speed = 0.0
			_units.append(unit)
	await _capture("01_normal")
	for unit in _units:
		_main.preview_active_skill(unit, CardDB.active_skills_for(unit.card_id)[0])
	await create_timer(0.25).timeout
	await _capture("02_activation")
	await create_timer(0.8).timeout
	await _capture("03_sustain")
	for unit in _units:
		_main._art_dev_selection = "training_dummy"
		_main._art_dev_team = 1 - unit.team
		_main._place_art_dev_item(unit.global_position + Vector2(0, -70 if unit.team == 0 else 70))
		unit.move_speed = 60.0
	await create_timer(0.45).timeout
	await _capture("04_move_attack")
	_units[0].freeze(0.6)
	_units[4].take_damage(1.0)
	await create_timer(0.025).timeout
	await _capture("05_control_hit")
	await create_timer(4.0).timeout
	await _capture("06_expired")
	for unit in _units:
		if is_instance_valid(unit):
			# 绕过次数只在本演示重置；施放仍走正式预览技能入口。
			unit.configure_carried_active_skill(CardDB.active_skills_for(unit.card_id)[0])
			_main.preview_active_skill(unit, CardDB.active_skills_for(unit.card_id)[0])
	await create_timer(0.8).timeout
	for unit in _units:
		if is_instance_valid(unit):
			unit.take_damage(99999.0)
	await create_timer(0.12).timeout
	await _capture("07_death")
	await create_timer(0.6).timeout
	await _capture("08_cleared")
	_main.queue_free()
	await process_frame
	quit()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "/" + label + ".png")
	print("[男爵渲染] ", label)
