extends SceneTree
## 双进程正式握手/随机首手/出牌确认/镜像技能快照回放。
var main: Node2D
var started := 0
var phase := 0
var previous_history := ""
var opening_ok := false
var copied_seen := false
var skill_requested := false
var skill_executed := false
const DECK := ["mirror", "ashe", "garen", "heal", "freeze", "kayle", "shurima_guard", "tombstone"]
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main._deck = DECK.duplicate()
	main._active_skill_choices = {"garen": 1, "heal": 1}
	root.add_child(main)
	current_scene = main
	started = Time.get_ticks_msec()
	var last_request := 0
	while Time.get_ticks_msec() - started < 45000:
		await process_frame
		if not main._match_started or main._battle_loading: continue
		main._minion_waves_enabled = false
		for tower in main._towers: tower.can_attack = false
		if main.mode == "host":
			main._elixir_p1.elixir = 10
			for unit in get_nodes_in_group("combatants"):
				if unit is Unit: unit.move_speed = 0
			if not opening_ok:
				opening_ok = "mirror" not in main.get_authoritative_hand(1)
				print("MIRROR_OPENING ", JSON.stringify(main.get_authoritative_hand(1)))
			for id in main._active_skills.ids():
				var entry: Dictionary = main._active_skills.entry(id)
				if entry.team == 1 and entry.slot == 0:
					copied_seen = true
					skill_executed = int(entry.uses_remaining) < int(entry.max_uses)
			if copied_seen and skill_executed and main._sim_tick_id > 160:
				print("MIRROR_NETWORK ", JSON.stringify({"role": "host", "passed": opening_ok and copied_seen and skill_executed, "source": main._card_history.get_last(1), "slots": main._active_skills.ids().size()}))
				await create_timer(2.0).timeout
				_finish(0)
				return
		else:
			if not opening_ok:
				opening_ok = "mirror" not in main.get_authoritative_hand(1)
				print("MIRROR_OPENING ", JSON.stringify(main.get_authoritative_hand(1)))
			if main.get_authoritative_server_tick() < 5: continue
			for id in main._active_skills.ids():
				var entry: Dictionary = main._active_skills.entry(id)
				if entry.team == 1 and entry.slot == 0 and entry.unit.is_deployed():
					copied_seen = true
					skill_executed = int(entry.uses_remaining) < int(entry.max_uses)
					if not skill_requested:
						skill_requested = main.use_active_skill(int(id), 1, 0, true)
			if copied_seen and skill_executed and main.get_authoritative_server_tick() > 170:
				print("MIRROR_NETWORK ", JSON.stringify({"role": "client", "passed": opening_ok and copied_seen and main._card_history.get_last(1).card_id == "garen", "source": main._card_history.get_last(1), "slots": main._active_skills.ids().size()}))
				await create_timer(0.5).timeout
				_finish(0)
				return
			if phase == 1 or Time.get_ticks_msec() - last_request < 600: continue
			var hand: Array = main.get_authoritative_hand(1)
			var card := ""
			var last: Dictionary = main._card_history.get_last(1)
			if "mirror" in hand and last.get("card_id", "") == "garen": card = "mirror"
			elif "garen" in hand: card = "garen"
			else:
				for candidate in hand:
					if candidate != "mirror":
						card = String(candidate)
						break
			if card.is_empty() or main._hand.is_card_pending(card): continue
			var position := Vector2(300, 460)
			if card == "tombstone": position = Vector2(460, 380)
			if main.play_card(1, card, position, {"elixir": main._elixir, "client_request": true}):
				last_request = Time.get_ticks_msec()
				if card == "mirror": phase = 1
	print("MIRROR_NETWORK ", JSON.stringify({"role": main.mode, "passed": false, "phase": int(main._session.phase), "tick": main._sim_tick_id}))
	_finish(1)
func _finish(code: int) -> void:
	main.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	quit(code)
