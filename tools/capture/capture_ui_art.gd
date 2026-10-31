extends SceneTree
## Actual production UI/arena rendering, bounded to two prepared unit resources.
## Godot --path . --script tools/capture/capture_ui_art.gd -- --output=<absolute directory> [--size=720x1280]
var output := ""
var main: Node2D
var dimensions := Vector2i(720, 1280)
const DECK := ["garen", "ashe", "final_spark", "soul_tentacle", "mirror", "heal", "medium_lightning", "kayle"]

func _initialize() -> void:
	capture.call_deferred()

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("UI art capture requires graphics rendering")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument.begins_with("--size="):
			var parts := argument.trim_prefix("--size=").split("x")
			dimensions = Vector2i(int(parts[0]), int(parts[1]))
	if output.is_empty():
		push_error("Pass --output inside the development material library")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	set_meta("display_window_initialized", true)
	root.size = dimensions
	root.content_scale_size = Vector2i(720, 1280)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main.set_process(false)
	main.runtime._deck = DECK.duplicate()
	# Fail explicitly if the curated capture deck changes.
	for i in main.runtime._deck.size():
		assert(CardDB.has_card(main.runtime._deck[i]), "Capture card missing: " + main.runtime._deck[i])
	var color_groups: Dictionary = {}
	var color_examples: Dictionary = {}
	for id in CardDB.selectable_ids():
		var color := UIPalette.card_border(CardDB.get_card(id).get("color", CardArt.DEFAULT_ACCENT)).to_html(false)
		color_groups[color] = int(color_groups.get(color, 0)) + 1
		if not color_examples.has(color) and id not in DECK: color_examples[color] = id
	print("[UI_ART] shared card border groups ", color_groups)
	main._pick_deck_ui(func(): pass)
	await save_frame("deck")
	var builder: DeckBuilder = main._deck_builder
	for pair in [[UIPalette.CARD_AMBER, UIPalette.CARD_SILVER], [UIPalette.CARD_AMETHYST, UIPalette.CARD_CYAN]]:
		for slot in 2: builder._deck_selected[slot] = color_examples[pair[slot].to_html(false)]
		builder._update_deck_ui()
		await save_frame("deck_slot_contrast_" + pair[0].to_html(false))
	builder._deck_selected = DECK.duplicate()
	builder._update_deck_ui()
	builder._filter_buttons[3].emit_signal("pressed")
	await save_frame("deck_buildings_cost_asc")
	builder._deck_sort_kind.emit_signal("pressed")
	await save_frame("deck_buildings_name_asc")
	builder._deck_sort_direction.emit_signal("pressed")
	await save_frame("deck_buildings_name_desc")
	builder._deck_sort_kind.emit_signal("pressed")
	await save_frame("deck_buildings_cost_desc")
	builder._filter_buttons[0].emit_signal("pressed")
	builder._on_deck_sort_selected(1)
	builder._on_deck_slot_pressed(0)
	await save_frame("deck_context")
	builder._open_selected_card_info()
	await save_frame("deck_details")
	builder._close_card_info()
	builder._deck_selected = []
	builder._refresh_deck_pool()
	builder._update_deck_ui()
	await save_frame("deck_empty")
	builder._clear_deck_ui()
	main._resources.prepare(["garen", "ashe"])
	main._battle_loading = true
	main._start_local()
	main._battle_loading = false
	main._ai.enabled = false
	main.runtime._minion_waves_enabled = false
	main._refresh_display_layout()
	for spec in [[0, "garen", Vector2(140, 760)], [1, "garen", Vector2(140, 520)], [0, "ashe", Vector2(580, 840)]]:
		main.runtime.account(spec[0]).elixir = 10.0
		assert(main.play_card(spec[0], spec[1], spec[2], {"immediate": true}))
	for i in 40:
		main._sim_step(.05)
		await process_frame
	main.runtime.account(0).set_process(false)
	main.runtime.account(0).elixir = 4.0
	main._hand.set_visible_state(["garen", "ashe", "soul_tentacle", "mirror"], "kayle")
	main._hand._refresh(4.0)
	# Preview the official active controls from card definitions without granting gameplay qualification.
	for slot in 2:
		var skill: Dictionary = CardDB.active_skills_for(DECK[slot])[0]
		main._active_skill_bar.show_skill(slot, 900 + slot, skill.name, Color.WHITE, float(skill.cost), 2, 2, float(skill.get("cooldown", 0)), true, CardArt.skill_icon(skill))
	await save_frame("battle")
	main._hand._on_slot_pressed(1)
	await save_frame("battle_selected")
	main._hand.set_card_pending("garen", true)
	main.runtime.account(0).elixir = 0.0
	main._hand._refresh(0.0)
	await save_frame("battle_poor_pending")
	main._skill_presentation.present_fixed_area(Vector2(360, 640), 1.5, 1.5, 1.2, 0, &"gold_reward")
	main._skill_presentation.present_fixed_area(Vector2(360, 500), 2.0, 2.0, 1.2, 1, &"gold_reward")
	await save_frame("battle_reward")
	main.runtime.account(0).elixir = 10.0
	main._hand.cost_query = Callable()
	main._hand.clear_selection()
	main._hand.set_visible_state(["kayle", "mirror", "final_spark", "heal"], "garen")
	main._hand.set_mirror_copy({})
	await save_frame("battle_full_unknown")
	# Feed presentation snapshots through the existing queries; no Kayn model spawn.
	main._hand.set_visible_state(["kayn", "garen", "ashe", "heal"], "kayle")
	for progress in [[0, 0, "kayn_empty"], [2, 3, "kayn_partial"], [3, 5, "kayn_near_full"]]:
		main.runtime._card_growth.replace_replica({0: {"kayn": {"ranged": progress[0], "melee": progress[1], "unlocked": "kayn"}}})
		main._hand._refresh(10.0)
		await save_frame("battle_" + String(progress[2]))
	main._hand._on_slot_pressed(0)
	await save_frame("battle_kayn_selected")
	main.runtime.account(0).elixir = 0.0
	main._hand._refresh(0.0)
	await save_frame("battle_kayn_poor")
	main.runtime._card_growth.replace_replica({0: {"kayn": {"ranged": 4, "melee": 3, "unlocked": "kayn_assassin"}}})
	main._hand._refresh(0.0)
	await save_frame("battle_kayn_unlocked")
	main.clear_preview_battle()
	main.free()
	await process_frame
	print("[UI_ART] completed ", dimensions)
	quit()

func save_frame(label: String) -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join("%s_%dx%d.png" % [label, dimensions.x, dimensions.y])
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("[UI_ART] saved ", path)
