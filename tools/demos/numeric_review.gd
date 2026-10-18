extends SceneTree
## 查看实际卡牌详情和塔生命整数；输出卡牌数值清单。headless 仅检查与输出数值，不截图。
var OUTPUT := preload("res://tools/lib/development_paths.gd").output("clash-numeric-review")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var rows: Array[String] = ["| 卡牌 | 生命 | 基础伤害¹ | 攻击间隔（秒） | 首次命中（秒） | 移速 |", "| --- | ---: | ---: | ---: | ---: | ---: |"]
	for id in CardDB.all():
		var stats := CardDB.get_card(id)
		if String(stats.type) == "spell":
			continue
		var entity := CardDB.get_unit_stats(String(id))
		if entity.is_empty():
			var plan := CardDB.deployment_plan(String(id))
			var counts := {}
			for member_id in plan.get("members", []):
				counts[member_id] = int(counts.get(member_id, 0)) + 1
			for member_id in counts:
				var member := CardDB.get_unit_stats(String(member_id))
				rows.append(_row("%s / %s ×%d（单体数值）" % [stats.name, member.name, counts[member_id]], member))
			continue
		rows.append(_row(String(stats.name), entity))
		if entity.has("transformed_stats"):
			rows.append(_row(String(stats.name) + "（变形）", entity.transformed_stats))
	FileAccess.open(OUTPUT + "/card-values.md", FileAccess.WRITE).store_string("\n".join(rows) + "\n")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	var builder := DeckBuilder.new()
	main.add_child(builder)
	builder.open(["pix", "aurelionsol", "ashe", "garen", "gwen", "teemo", "freeze", "heal"], {}, {}, func(_a, _b, _c): pass)
	var review_cards: Array = ["pix", "aurelionsol", "ashe"]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--cards="): review_cards.assign(argument.trim_prefix("--cards=").split(","))
	for id in review_cards:
		builder._open_card_info(id)
		await create_timer(0.3).timeout
		await _capture(id)
	builder.queue_free()
	await process_frame
	main._start_local()
	main._ai.enabled = false
	main.runtime._minion_waves_enabled = false
	main.set_process(false)
	for tower in main.world.towers_snapshot():
		tower.take_damage(101.5)
		print("[数值渲染] tower hp=", tower.hp, " text=", tower._health_text())
	await create_timer(0.3).timeout
	await _capture("tower-health")
	main.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
	quit()
func _row(label: String, stats: Dictionary) -> String:
	return "| %s | %s | %s%s | %s | %s | %s |" % [label, BattleNumbers.format_value(float(stats.hp)), BattleNumbers.format_value(float(stats.damage)), " DPS" if bool(stats.get("is_continuous_attack", false)) else "", BattleNumbers.format_value(float(stats.interval)), BattleNumbers.format_value(float(stats.get("first_hit", 0))), BattleNumbers.format_value(float(stats.speed))]
func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "/" + label + ".png")
