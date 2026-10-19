extends SceneTree
## Tiny resource-only identity/order/lifetime checks, not the heavy warmup suite.
const HEARTBEAT = preload("res://tools/performance/safe_probe_heartbeat.gd")
var pulse: RefCounted
var output := ""

func _initialize() -> void:
	pulse = HEARTBEAT.new(self)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	call_deferred("run")

func run() -> void:
	if not pulse.enabled or output.is_empty(): quit(1); return
	pulse.set_phase("retained-identity")
	var script: Script = load("res://tests/suites/presentation/spell_warmup_suite.gd")
	if script == null or not script.can_instantiate(): quit(1); return
	var suite: RefCounted = script.new()
	var report: Dictionary = suite.check_retained_identity()
	FileAccess.open(output.path_join("retained-identity.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("[RETAINED_IDENTITY_RESULT] ", JSON.stringify(report))
	pulse.set_phase("complete", true)
	await create_timer(0.3).timeout
	quit(0 if report.passed else 1)
