extends SceneTree
## 镜像正式手牌、技能槽替换、卡牌详情与继承音频的实际渲染配方。
var output := preload("res://tools/lib/development_paths.gd").output("mirror-review")
var main: Node2D
const DECK := ["mirror", "ashe", "garen", "heal", "freeze", "kayle", "shurima_guard", "tombstone"]
func _initialize() -> void:
	_run.call_deferred()
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/" + label + ".png")
func _run() -> void:
	root.audio_listener_enable_2d = true
	DirAccess.make_dir_recursive_absolute(output)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._deck = DECK.duplicate()
	main._active_skill_choices = {"garen": 1, "heal": 1}
	main._start_local()
	main._ai.enabled = false
	main._minion_waves_enabled = false
	for tower in main._towers: tower.can_attack = false
	await create_timer(0.6).timeout
	await shot("01_random_opening")
	var record := AudioEffectRecord.new()
	var slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, record)
	record.set_recording_active(true)
	await play("garen", Vector2(300, 900))
	put_in_hand("mirror")
	await shot("02_mirror_garen_card")
	await play("mirror", Vector2(420, 900))
	await play("ashe", Vector2(220, 1000))
	await shot("03_two_skill_slots")
	await play("mirror", Vector2(500, 1000))
	await shot("04_replaced_mirror_slot")
	for id in main._active_skills.ids():
		if main._active_skills.entry(id).slot == 0:
			main._elixir.elixir = 10
			main.use_active_skill(int(id), 0)
	await create_timer(1.2).timeout
	await play("heal", Vector2(380, 960))
	await play("mirror", Vector2(380, 960))
	await shot("05_copied_spell_clears_slot")
	record.set_recording_active(false)
	await create_timer(0.2).timeout
	var wav := record.get_recording()
	if wav != null: wav.save_to_wav(output + "/battle_mix.wav")
	AudioServer.remove_bus_effect(0, slot)
	main._deck_builder = DeckBuilder.new()
	main.add_child(main._deck_builder)
	main._deck_builder.open(main._deck, main._active_skill_choices, {}, func(_deck, _skills, _skins): pass)
	main._deck_builder._open_card_info("mirror")
	await create_timer(0.3).timeout
	await shot("06_mirror_details")
	print("MIRROR_REVIEW_OUTPUT ", output)
	main._audio_manager.end_battle()
	main.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	quit()

func put_in_hand(card_id: String) -> void:
	var cycle: CardCycle = main._authoritative_card_cycles[0]
	var hand := cycle.hand()
	var queue := cycle.queue()
	if card_id not in hand:
		var index := queue.find(card_id)
		queue[index] = hand[0]
		hand[0] = card_id
		cycle.replace_replica(hand, queue)
	main._sync_card_cycle_ui(0)

func play(card_id: String, pos: Vector2) -> void:
	put_in_hand(card_id)
	main._elixir.elixir = 10
	if not main.play_card(0, card_id, pos, {"elixir": main._elixir}): push_error("镜像渲染配方下牌失败: " + card_id)
	await create_timer(1.25).timeout
	for unit in get_nodes_in_group("combatants"):
		if unit is Unit: unit.move_speed = 0
