extends RefCounted
## 只由 --release-smoke 启动；使用实际发布包的卡组、命令、生成与终局路径。
static func run(scene: Node, menu_only: bool) -> void:
	var tree := scene.get_tree()
	await tree.process_frame
	var passed: bool = scene._menu_layer != null
	if not menu_only:
		scene._start_local()
		scene.set_process(false)
		scene._ai.enabled = false
		scene._minion_waves_enabled = false
		scene._elixir.elixir = 10.0
		var hand: Array = scene.get_authoritative_hand(0)
		passed = passed and hand.size() == 4 and hand == scene._hand._hand and scene._deck.size() == 8
		if passed:
			var card: String = hand[0]
			var cost: float = scene.card_cost_for_team(0, card)
			passed = scene.play_card(0, card, Vector2(300, 900), {"elixir": scene._elixir}) and is_equal_approx(scene._elixir.elixir, 10.0 - cost)
			for tick in 11:
				scene._sim_step(0.05)
				await tree.create_timer(0.05).timeout
			var spawned := false
			for unit in tree.get_nodes_in_group("combatants"):
				if unit is Unit and unit.card_id == card and unit.team == 0: spawned = true
			passed = passed and spawned and scene.get_authoritative_hand(0) != hand
		scene._end_game(-1, "draw")
		passed = passed and scene._audio_manager.battle_audio_stopped()
	await tree.create_timer(0.25).timeout
	scene.free()
	await tree.create_timer(0.25).timeout
	print("[RELEASE_SMOKE] " + JSON.stringify({"schema": 1, "passed": passed, "case": "menu" if menu_only else "match", "exported": not OS.has_feature("editor")}))
	tree.quit(0 if passed else 1)
