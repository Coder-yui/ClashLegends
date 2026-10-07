extends RefCounted
## 本地专项复现不接受旧双进程配方，避免无效联网参数被静默当作单机成功。
static func local_only(tree: SceneTree) -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode=") or argument.begins_with("--network"):
			push_error("此配方仅用于单机复现；联网请运行 python3 tools/dev.py verify --network-render")
			tree.quit(2)
			return false
	return true
