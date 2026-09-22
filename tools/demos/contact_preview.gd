extends SceneTree
## 接触/桥口实际渲染验收。保留卡牌定义，仅对演示实例设置快慢行军。
## Godot --path . --script tools/demos/contact_preview.gd
var OUTPUT := preload("res://tools/lib/development_paths.gd").output("clash-contact-render")
var main: Node2D
var trace: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._start_local()
	main.set_process(false)
	main._ai.enabled = false
	main._minion_waves_enabled = false
	if "--knockback" in OS.get_cmdline_user_args():
		await _review_knockback()
		quit()
		return
	var front: Unit = main._spawn_unit(0, "garen", Vector2(140, 860), 0.0)
	var rear: Unit = main._spawn_unit(0, "masteryi", Vector2(140, 930), 0.0)
	front.move_speed = CardDB.SPEED_SLOW
	rear.move_speed = CardDB.SPEED_FAST
	var bridge_units: Array[Unit] = [front, rear]
	for i in 4:
		bridge_units.append(main._spawn_unit(0, "melee_minion", Vector2(550 + i * 14, 780 + i * 16), 0.0))
	await _capture("00_start")
	for tick in 220:
		main._sim_step(main.SIM_DT)
		var row := {"tick": tick, "positions": []}
		for unit in bridge_units:
			if is_instance_valid(unit):
				row.positions.append({"id":unit.get_instance_id(),"card":unit.card_id,"x":unit.position.x,"y":unit.position.y,"alive":unit.hp > 0.0,"walkable":unit.is_walkable_at(unit.position)})
		trace.append(row)
		if tick in [39,79,119,159,219]:
			await _capture("tick_%03d" % tick)
		await create_timer(0.05).timeout
	var output := FileAccess.open(OUTPUT + "/trace.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(trace, "\t"))
	print("[接触渲染 QA] 220 Tick、6 个渲染帧与位置轨迹：" + OUTPUT)
	quit()

func _capture(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUTPUT + "/" + label + ".png")

## 普通击退：一名撞岸、两名真实接触；不提供尚未实现的强制位移演示。
func _review_knockback() -> void:
	for tower in main._towers: tower.can_attack = false
	var shore: Unit = main._spawn_unit(0, "masteryi", Vector2(360, 750), 0)
	var mover: Unit = main._spawn_unit(0, "masteryi", Vector2(260, 850), 0)
	var receiver: Unit = main._spawn_unit(1, "masteryi", Vector2(360, 850), 0)
	for unit in [shore, mover, receiver]: unit.freeze(3.0)
	await _capture("knockback_start")
	shore.apply_knockback(Vector2(360, 850), 800, 0.5)
	mover.apply_knockback(Vector2(160, 850), 800, 0.5)
	for tick in 14:
		main._sim_step(main.SIM_DT)
		var row := {"tick": tick, "units": []}
		for unit in [shore, mover, receiver]:
			row.units.append({"position": [unit.position.x, unit.position.y], "lock": unit._knockback_timer, "reason": String(unit.knockback.end_reason), "legal": unit.is_walkable_at(unit.position)})
		trace.append(row)
		await create_timer(0.05).timeout
		if tick in [0, 3, 8, 13]: await _capture("knockback_%02d" % tick)
	var file := FileAccess.open(OUTPUT + "/knockback_trace.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(trace, "\t"))
	print("[普通击退渲染] " + OUTPUT)
