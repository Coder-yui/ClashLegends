extends SceneTree
## 读取编译后的 CardDB，不解析 GDScript 数值表达式；输出供文档校验使用。
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Expected an output JSON path")
		quit(1)
		return
	var cards := {}
	for card_id in CardDB.all():
		var stats := CardDB.get_card(card_id)
		var facts := {}
		for field in ["cost", "hp", "damage", "interval", "deploy_time", "pre_deploy_time"]:
			if stats.has(field):
				facts[field] = stats[field]
		# 通过实际消费者解析实体部署锁，避免检查器另存默认值。
		if String(stats.get("type", "")) != "spell":
			var unit := Unit.new()
			unit.setup(0, stats, str(stats.name))
			facts["deploy_time"] = unit.deploy_time
			unit.free()
		facts["pre_deploy_time"] = stats.get("pre_deploy_time", 0.0)
		var skills := CardDB.active_skills_for(card_id)
		for index in skills.size():
			for field in ["cost", "max_uses", "cooldown"]:
				facts["active_skills.%d.%s" % [index, field]] = skills[index][field]
		cards[card_id] = facts
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		push_error("Cannot write card facts: " + args[0])
		quit(1)
		return
	file.store_string(JSON.stringify({"schema": 1, "cards": cards}, "\t") + "\n")
	print("Exported compiled card facts: ", cards.size())
	quit()
