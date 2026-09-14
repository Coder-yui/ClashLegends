extends RefCounted
## Shared per-process output batch for reusable preview/capture tools.
static var _batch := ""

static func output(relative: String) -> String:
	if _batch.is_empty():
		var root := ProjectSettings.globalize_path("res://ClashLegends-开发素材库/04-中间产物/预览与验证")
		# A staged preview writes back to the source project's material library.
		var source_root := OS.get_environment("CLASH_SOURCE_PROJECT")
		if not source_root.is_empty():
			root = source_root.path_join("ClashLegends-开发素材库/04-中间产物/预览与验证")
		_batch = root.path_join("%d-%d" % [int(Time.get_unix_time_from_system()), OS.get_process_id()])
	var path := _batch.path_join(relative)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return path
