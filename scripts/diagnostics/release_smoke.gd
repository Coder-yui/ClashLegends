extends RefCounted
## 只由 --release-smoke 启动；固定夹具覆盖真实付款、轮换及不同部署结果。
const SMOKE_DECK := ["garen", "freeze", "melee_minion_squad", "tombstone", "ashe", "xin", "teemo", "gnar"]
const MAX_RESULT_TICKS := 120

static func run(scene: Node, menu_only: bool) -> void:
	var tree := scene.get_tree()
	await tree.process_frame
	var passed: bool = scene._menu_layer != null
	var probes: Array[Dictionary] = []
	if not menu_only:
		scene.runtime._deck = SMOKE_DECK.duplicate()
		scene.runtime._active_skill_choices.clear()
		scene._start_local()
		scene.set_process(false)
		scene._ai.enabled = false
		scene.runtime._minion_waves_enabled = false
		# 仅探针固定开局；正常比赛的 Crypto 洗牌保持不变。
		scene.runtime._authoritative_card_cycles[0] = CardCycle.new(SMOKE_DECK, false)
		scene._sync_card_cycle_ui(0)
		passed = passed and scene.get_authoritative_hand(0) == SMOKE_DECK.slice(0, 4) and scene.runtime._deck.size() == 8
		for card in SMOKE_DECK.slice(0, 4):
			var probe := await _play_probe(scene, String(card))
			probes.append(probe)
			passed = passed and bool(probe.passed)
		scene._end_game(-1, "draw")
		passed = passed and scene._audio_manager.battle_audio_stopped()
	await tree.create_timer(0.25).timeout
	scene.free()
	await tree.create_timer(0.25).timeout
	print("[RELEASE_SMOKE] " + JSON.stringify({"schema": 2, "passed": passed, "case": "menu" if menu_only else "match", "probes": probes, "exported": not OS.has_feature("editor")}))
	tree.quit(0 if passed else 1)

static func _play_probe(scene: Node, card: String) -> Dictionary:
	var hand: Array = scene.get_authoritative_hand(0)
	var consistent: bool = hand.size() == 4 and hand == scene._hand._hand and card in hand
	scene.runtime.account(0 if scene.runtime.mode == "server" else scene.runtime.local_team).elixir = 10.0
	var cost: float = scene.runtime.card_cost_for_team(0, card)
	var position := Vector2(120, 850) if card != "tombstone" else Vector2(580, 900)
	if card == "freeze": position = scene.world.towers_snapshot()[2].global_position
	var accepted: bool = consistent and scene.play_card(0, card, position, {"elixir": scene.runtime.account(0 if scene.runtime.mode == "server" else scene.runtime.local_team), "require_team_deck": true})
	var paid: bool = is_equal_approx(scene.runtime.account(0 if scene.runtime.mode == "server" else scene.runtime.local_team).elixir, 10.0 - cost)
	var rotated: bool = scene.get_authoritative_hand(0) != hand and scene.get_authoritative_hand(0) == scene._hand._hand
	var ticks := 0
	var observed := false
	if accepted:
		# 命令缓冲、预部署各有自己的时钟；到达结果即停，并保留超时失败。
		while ticks < MAX_RESULT_TICKS and not observed:
			scene._sim_step(FixedStepClock.STEP)
			ticks += 1
			observed = _probe_result(scene, card)
			await scene.get_tree().create_timer(FixedStepClock.STEP).timeout
	return {"card": card, "accepted": accepted, "paid": paid, "rotated": rotated, "observed": observed, "ticks": ticks, "passed": accepted and paid and rotated and observed}

static func _probe_result(scene: Node, card: String) -> bool:
	if card == "freeze": return scene.world.towers_snapshot()[2].frozen_timer > 0.0
	var members := 0
	for unit in scene.get_tree().get_nodes_in_group("combatants"):
		if not unit is Unit or unit.team != 0: continue
		if card == "melee_minion_squad":
			if unit.card_id == "melee_minion" and unit.deployment_group_id >= 0: members += 1
		elif unit.card_id == card:
			return true
	return card == "melee_minion_squad" and members == 4
