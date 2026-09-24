extends SceneTree
var main: Node2D
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for attempt in 300:
		if main._match_started: break
		await create_timer(0.1).timeout
	if not main._match_started:
		push_error("KAYN_NETWORK start timeout")
		quit(1)
		return
	main._minion_waves_enabled = false
	if main._ai != null: main._ai.enabled = false
	for tower in main._towers: tower.can_attack = false
	var success := false
	if main.mode == "host":
		main._deck[0] = "kayn"
		main.play_card(0,"kayn",Vector2(300,1000),{"immediate":true,"validate_position":false})
		var source: Unit = main._latest_unit_for_card("kayn",0)
		source.move_speed = 0.0
		main.play_card(1,"ashe",Vector2(500,1000),{"immediate":true,"validate_position":false})
		var target: Unit = main._latest_unit_for_card("ashe",1)
		target.move_speed = 0.0; target.damage = 0.0
		for hit in 4:
			main._combat.resolve_attack_hit(0,source.position,target,1,0,0,source,source.position,0)
		main.play_card(0,"kayn",Vector2(360,900),{"immediate":true,"validate_position":false})
		var blue: Unit = main._latest_unit_for_card("kayn",0)
		blue.move_speed = 0.0
		blue.active_ability_id = blue.net_id
		blue.active_ability_slot = 0
		main._register_active_skill(blue,"kayn",0)
		await create_timer(2.0).timeout
		main._elixir.elixir = 5.0
		main.use_active_skill(blue.active_ability_id,0)
		await create_timer(6.0).timeout
		success = blue.card_id == "kayn_assassin" and source.card_id == "kayn"
	else:
		var growth := false
		var old_form := false
		var blue_form := false
		var dash := false
		for sample in 90:
			growth = growth or main._card_growth.resolved_id(0,"kayn") == "kayn_assassin"
			for id in main.client_unit_ids():
				var unit: Unit = main.find_client_unit(id)
				old_form = old_form or unit.card_id == "kayn"
				blue_form = blue_form or unit.card_id == "kayn_assassin"
				if unit.card_id == "kayn_assassin": dash = dash or String(unit.get_visual_action_name()) == "active"
			await create_timer(0.1).timeout
		success = growth and old_form and blue_form and dash
		print("KAYN_NETWORK client growth=",growth," old=",old_form," blue=",blue_form," dash=",dash)
	print("KAYN_NETWORK ",main.mode," success=",success)
	main.mode = "local"
	if main._network_peer != null: main._network_peer.close()
	main.multiplayer.multiplayer_peer = null
	main._clear_art_dev_units()
	main.queue_free()
	await process_frame
	quit(0 if success else 1)
