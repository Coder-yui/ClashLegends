extends SceneTree
## 核心机制回归编排入口：初始化测试场景 → 调用各领域 suite → 汇总失败 → 清理 → quit。
## 领域测试实现位于 tests/suites/，统一运行命令保持不变：
## Godot --headless --path . --script tests/mechanics_check.gd

const ANIVIA_SUITE_SCRIPT := preload("res://tests/suites/cards/anivia_suite.gd")
const AUDIO_PRESENTATION_SUITE_SCRIPT := preload("res://tests/suites/audio_presentation_suite.gd")

var _failed := 0
var _checks := 0
var _verbose := "--verbose-checks" in OS.get_cmdline_user_args()
var _main: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_main = scene.instantiate()
	root.add_child(_main)
	current_scene = _main
	await process_frame
	print("[套件] maintenance_suite")
	preload("res://tests/suites/maintenance_suite.gd").new().run(self)
	print("[套件] CardDBValidationSuite")
	CardDBValidationSuite.new().run(self)
	print("[套件] ContentContractSuite")
	ContentContractSuite.new().run(self)
	print("[套件] DeckBuilderSuite")
	await DeckBuilderSuite.new().run(self, _main)
	_main._start_local()
	_main.set_process(false)
	_main._ai.enabled = false
	# 常规机制用例手动推进大量固定 tick，关闭自动兵线避免跨用例污染；兵线有独立回归。
	_main._minion_waves_enabled = false

	preload("res://tests/suites/maintenance_suite.gd").new().check_contracts(self, _main)
	print("[套件] numeric_system_suite")
	preload("res://tests/suites/numeric_system_suite.gd").new().run(self, _main)
	print("[套件] ArenaDeploymentSuite")
	ArenaDeploymentSuite.new().run(self, _main)
	print("[套件] AUDIO_PRESENTATION_SUITE_SCRIPT")
	await AUDIO_PRESENTATION_SUITE_SCRIPT.new().run(self, _main)
	print("[套件] PresentationSuite")
	PresentationSuite.new().run(self, _main)
	print("[套件] BuildingMinionSuite")
	BuildingMinionSuite.new().run(self, _main)
	print("[套件] NavigationCollisionSuite")
	NavigationCollisionSuite.new().run(self, _main)
	print("[套件] ActiveSkillSuite")
	ActiveSkillSuite.new().run(self, _main)
	print("[套件] workbench_suite")
	preload("res://tests/suites/workbench_suite.gd").new().run(self, _main)
	print("[套件] AnimationStateSuite")
	AnimationStateSuite.new().run(self, _main)
	print("[套件] cards/sett_animation_suite")
	preload("res://tests/suites/cards/sett_animation_suite.gd").new().run(self, _main)
	print("[套件] HeroSkillReworkSuite")
	HeroSkillReworkSuite.new().run(self, _main)
	print("[套件] CombatTargetingSuite")
	CombatTargetingSuite.new().run(self, _main)
	print("[套件] GnarSuite")
	GnarSuite.new().run(self, _main)
	print("[套件] XinSuite")
	XinSuite.new().run(self, _main)
	print("[套件] GwenSuite")
	GwenSuite.new().run(self, _main)
	print("[套件] TwistedFateSuite")
	TwistedFateSuite.new().run(self, _main)
	print("[套件] AurelionSolSuite")
	AurelionSolSuite.new().run(self, _main)
	print("[套件] MissFortuneSuite")
	MissFortuneSuite.new().run(self, _main)
	print("[套件] PixSuite")
	PixSuite.new().run(self, _main)
	print("[套件] ANIVIA_SUITE_SCRIPT")
	ANIVIA_SUITE_SCRIPT.new().run(self, _main)
	print("[套件] ProjectileSuite")
	ProjectileSuite.new().run(self, _main)

	print("[套件] workbench_scenario_suite")
	await preload("res://tests/suites/workbench_scenario_suite.gd").new().run(self, _main)

	if "--profile-maintenance" in OS.get_cmdline_user_args():
		preload("res://tests/suites/maintenance_suite.gd").new().profile(self, _main)

	if _failed == 0:
		print("[机制检查] 全部通过（%d 项断言）" % _checks)
	else:
		push_error("[机制检查] %d 项失败" % _failed)
	var result := _failed
	_main.free()
	_main = null
	# 快速 headless 回归须给音频混音线程时间释放刚停止的流，单个渲染帧不足以完成清理。
	await create_timer(0.25).timeout
	quit(result)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		if _verbose:
			print("[通过] ", message)
	else:
		_failed += 1
		push_error("[失败] " + message)
