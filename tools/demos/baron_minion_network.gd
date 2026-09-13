extends SceneTree
## -- --mode=host / --mode=join --ip=127.0.0.1；真实 Snapshot 验证双方四种兵 Buff 启停。
const CARDS := ["melee_minion", "ranged_minion", "siege_minion", "super_minion"]
var _seen_on := {}
var _seen_off := {}
var _seen_flight := false
var _seen_bursts := {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._minion_waves_enabled = false
	if main._ai != null: main._ai.enabled = false
	var client: bool = main.mode == "client"
	var deadline := Time.get_ticks_msec() + 15000
	while (main._battle_presentation == null if client else not main._match_started) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if main._battle_presentation == null if client else not main._match_started:
		push_error("[男爵网络] 连接超时")
		quit(1)
		return
	main._projectile_system.impact_added.connect(func(_pos, _radius, _color, visual): _seen_bursts[visual] = true)
	for tower in main._towers: tower.can_attack = false
	if not client:
		for team in [0, 1]:
			for i in range(4):
				main.play_card(team, CARDS[i], Vector2(115 + 163 * i, 850 if team == 0 else 400), {"immediate": true, "validate_position": false})
		await create_timer(1.2).timeout
		for team in [0, 1]:
			for card in CARDS:
				var unit: Unit = main._latest_unit_for_card(card, team)
				unit.move_speed = 0.0
				main.preview_active_skill(unit, CardDB.active_skills_for(card)[0])
		var cannon: Unit = main._latest_unit_for_card("siege_minion", 0)
		var target: Unit = main._latest_unit_for_card("siege_minion", 1)
		main._projectile_system.launch(cannon, target, 1.0, cannon.projectile_speed, 0.0, 0.0, cannon.color)
	var until := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < until:
		await process_frame
		if client:
			for p in main._projectile_system.client_projectiles.values():
				if p.visual == &"baron_siege": _seen_flight = true
			for child in main._battle_presentation._world_root.get_children():
				if not child is UnitModel3D or not is_instance_valid(child._source): continue
				var unit: Unit = child._source
				if unit.card_id not in CARDS: continue
				var key := "%s_%d" % [unit.card_id, unit.team]
				if child._active_buff_visual != null and child._active_buff_visual.active and unit.net_active_buff_active:
					_seen_on[key] = true
				elif _seen_on.has(key) and not unit.net_active_buff_active and not child._active_buff_visual.visible:
					_seen_off[key] = true
	var ok := not client or (_seen_on.size() == 8 and _seen_off.size() == 8 and _seen_flight and _seen_bursts.has(&"baron_siege_cast") and _seen_bursts.has(&"baron_siege_hit"))
	print("[男爵网络] ", main.mode, " on=", _seen_on.size(), " off=", _seen_off.size(), " flight=", _seen_flight, " bursts=", _seen_bursts.keys(), " passed=", ok)
	main.set_process(false)
	main.multiplayer.multiplayer_peer.close()
	main.multiplayer.multiplayer_peer = null
	main.free()
	await process_frame
	quit(0 if ok else 1)
