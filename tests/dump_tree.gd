extends SceneTree
## 临时诊断：打印 main 子树结构、节点类型与 z_index，理解血条被遮挡的原因。

const DECK := ["garen", "xin", "ashe", "teemo", "freeze", "masteryi", "gwen", "sett"]

func _initialize() -> void:
	_run.call_deferred()

func _dump(node: Node, depth: int) -> void:
	var zi := "?"
	if node is CanvasItem:
		zi = str((node as CanvasItem).z_index)
	print("%s%s (%s) z=%s" % ["  ".repeat(depth), node.name, node.get_class(), zi])
	for child in node.get_children():
		_dump(child, depth + 1)

func _run() -> void:
	var err := change_scene_to_file("res://scenes/main.tscn")
	if err != OK:
		quit(1)
		return
	await process_frame
	await process_frame
	var main: Node = current_scene
	main.set("_deck", DECK.duplicate())
	main.call("_start_local")
	await process_frame
	await process_frame
	_dump(main, 0)
	quit(0)
