@tool
extends EditorPlugin
## Editor F5/F6 only. No full-library hashes in the exported game.
func _build() -> bool:
	var output: Array = []
	var python := OS.get_environment("CLASH_PYTHON")
	if python.is_empty(): python = "python3"
	var status := OS.execute(python, [ProjectSettings.globalize_path("res://tools/maintenance/resource_artifacts.py"), "--check"], output, true)
	if status != 0:
		push_error("Resource artifact gate failed. Run python3 tools/dev.py resources --write.\n" + "\n".join(output))
		return false
	return true
